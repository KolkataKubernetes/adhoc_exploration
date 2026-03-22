#!/usr/bin/env Rscript

#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_0_1_geocode_adhoc.R
# Previous author:  Inder Majumdar
# Current author:   Inder Majumdar + Codex
# Last Updated:     March 22 2026
# Description:      Geocode the single row-level address in the ad hoc MFP
#                   payment data using the U.S. Census batch geocoder, append
#                   latitude/longitude and census tract fields, and write a
#                   simple audit summary of match performance.
# INPUTS:           `2_processed_data/processed_root.txt`
#                   `adhoc_payments_ingested.rds`
# OUTPUTS:          `adhoc_payments_geocoded.rds`
#                   `adhoc_payments_geocode_audit.csv`
#                   `adhoc_payments_geocode_preflight.csv` (optional)
#///////////////////////////////////////////////////////////////////////////////

# -----------------------------
# 0) Setup and configuration
# -----------------------------

# --- packages

library(tidyverse)
library(httr)

# --- command-line flags

args <- commandArgs(trailingOnly = TRUE)
check_only <- "--check-only" %in% args
overwrite <- "--overwrite" %in% args
skip_preflight <- "--skip-preflight" %in% args
preflight_only <- "--preflight-only" %in% args

if (check_only && preflight_only) {
  stop("Cannot combine --check-only and --preflight-only.")
}

if (skip_preflight && preflight_only) {
  stop("Cannot combine --skip-preflight and --preflight-only.")
}

# --- helper functions

# Identify the repository root by walking upward until AGENTS.md is found.
find_repo_root <- function(start_path = getwd()) {
  current_path <- normalizePath(start_path, winslash = "/", mustWork = TRUE)

  while (!identical(current_path, dirname(current_path))) {
    if (file.exists(file.path(current_path, "AGENTS.md"))) {
      return(current_path)
    }

    current_path <- dirname(current_path)
  }

  stop("Could not locate repository root from the current script context.")
}

# Read a root-path pointer file and strip surrounding single quotes if present.
read_root_path <- function(path_file) {
  path_value <- readLines(path_file, warn = FALSE) |>
    trimws(which = "both")

  path_value <- path_value[path_value != ""]

  if (!length(path_value)) {
    stop(sprintf("Path pointer file is empty: %s", path_file))
  }

  path_value[[1]] |>
    stringr::str_replace("^'", "") |>
    stringr::str_replace("'$", "")
}

# Create a directory if needed and return the same path for inline use.
ensure_dir <- function(path_dir) {
  dir.create(path_dir, recursive = TRUE, showWarnings = FALSE)
  path_dir
}

# Standardize character fields by casting, trimming repeated whitespace,
# and converting empty strings to explicit missing values.
clean_character <- function(x) {
  dplyr::if_else(
    is.na(x),
    NA_character_,
    as.character(x)
  ) |>
    stringr::str_squish() |>
    na_if("")
}

# Extract the first five digits of a ZIP code for Census batch input.
normalize_zip5 <- function(x) {
  x |>
    clean_character() |>
    stringr::str_extract("\\d{5}")
}

# Split an integer sequence into chunks used for the 10,000-row batch limit.
split_chunks <- function(n_rows, chunk_size) {
  if (n_rows <= 0) {
    return(list())
  }

  split(seq_len(n_rows), ceiling(seq_len(n_rows) / chunk_size))
}

# Parse the Census batch CSV response into typed fields used downstream.
parse_batch_csv <- function(csv_text) {
  response_text <- as.character(csv_text)

  if (!nzchar(stringr::str_squish(response_text))) {
    stop("Empty response body from Census geocoder.")
  }

  if (stringr::str_starts(stringr::str_trim(response_text), "<")) {
    stop("Census geocoder returned non-CSV content.")
  }

  raw_response <- read.csv(
    text = response_text,
    header = FALSE,
    stringsAsFactors = FALSE,
    na.strings = c("", "NULL"),
    fill = TRUE,
    quote = "\"",
    comment.char = ""
  )

  if (ncol(raw_response) < 8) {
    stop("Unexpected Census batch response format: fewer than 8 columns.")
  }

  names(raw_response) <- paste0("X", seq_len(ncol(raw_response)))

  parsed_response <- raw_response |>
    transmute(
      address_id = as.character(X1),
      input_address = as.character(X2),
      match_status = as.character(X3),
      geocode_match_type = as.character(X4),
      census_matched_address = as.character(X5),
      coordinates = as.character(X6),
      state_code = if (ncol(raw_response) >= 9) as.character(X9) else NA_character_,
      county_code = if (ncol(raw_response) >= 10) as.character(X10) else NA_character_,
      tract_code = if (ncol(raw_response) >= 11) as.character(X11) else NA_character_
    ) |>
    mutate(
      geocode_status = if_else(match_status == "Match", "matched", "no_match"),
      address_longitude = if_else(
        geocode_status == "matched" & !is.na(coordinates),
        stringr::str_split_fixed(coordinates, ",", 2)[, 1],
        NA_character_
      ),
      address_latitude = if_else(
        geocode_status == "matched" & !is.na(coordinates),
        stringr::str_split_fixed(coordinates, ",", 2)[, 2],
        NA_character_
      ),
      address_longitude = suppressWarnings(as.numeric(address_longitude)),
      address_latitude = suppressWarnings(as.numeric(address_latitude)),
      census_tract = if_else(
        geocode_status == "matched",
        stringr::str_c(
          stringr::str_pad(coalesce(state_code, ""), width = 2, side = "left", pad = "0"),
          stringr::str_pad(coalesce(county_code, ""), width = 3, side = "left", pad = "0"),
          stringr::str_pad(
            stringr::str_replace_all(coalesce(tract_code, ""), "\\.", ""),
            width = 6,
            side = "left",
            pad = "0"
          )
        ),
        NA_character_
      ),
      census_tract = if_else(
        geocode_status == "matched" & nchar(census_tract) == 11,
        census_tract,
        NA_character_
      )
    ) |>
    select(
      address_id,
      geocode_status,
      geocode_match_type,
      census_matched_address,
      address_latitude,
      address_longitude,
      census_tract
    )

  parsed_response
}

# Submit one or more Census batch requests and return one row per unique address.
geocode_unique_addresses <- function(unique_addresses, chunk_size, check_only = FALSE) {
  total_unique <- nrow(unique_addresses)
  chunk_index <- split_chunks(total_unique, chunk_size)
  n_batches <- length(chunk_index)

  message(sprintf(
    "Unique addresses queued for geocoding: %s. Planned API batches: %s.",
    scales::comma(total_unique),
    n_batches
  ))

  if (total_unique == 0) {
    return(
      tibble(
        address_id = character(),
        geocode_status = character(),
        geocode_match_type = character(),
        census_matched_address = character(),
        address_latitude = numeric(),
        address_longitude = numeric(),
        census_tract = character()
      )
    )
  }

  if (check_only) {
    purrr::walk(
      seq_along(chunk_index),
      ~message(sprintf("Check-only batch %s/%s planned. No API call executed.", .x, n_batches))
    )

    return(
      unique_addresses |>
        transmute(
          address_id,
          geocode_status = "check_only",
          geocode_match_type = NA_character_,
          census_matched_address = NA_character_,
          address_latitude = NA_real_,
          address_longitude = NA_real_,
          census_tract = NA_character_
        )
    )
  }

  geocoded_batches <- vector("list", n_batches)

  for (batch_number in seq_along(chunk_index)) {
    batch_rows <- chunk_index[[batch_number]]
    batch_data <- unique_addresses[batch_rows, c(
      "address_id",
      "address_street",
      "address_city",
      "address_state",
      "address_zip5"
    )]

    message(sprintf(
      "Running Census batch %s/%s with %s addresses.",
      batch_number,
      n_batches,
      scales::comma(nrow(batch_data))
    ))

    temp_csv <- tempfile(pattern = "adhoc_geocode_batch_", fileext = ".csv")

    write.table(
      batch_data[, c("address_id", "address_street", "address_city", "address_state", "address_zip5")],
      file = temp_csv,
      sep = ",",
      row.names = FALSE,
      col.names = FALSE,
      quote = TRUE,
      na = ""
    )

    batch_complete <- FALSE
    attempt <- 0L
    last_error <- NULL

    while (!batch_complete && attempt < 3L) {
      attempt <- attempt + 1L
      message(sprintf("Batch %s/%s attempt %s.", batch_number, n_batches, attempt))

      response <- tryCatch(
        {
          httr::POST(
            url = "https://geocoding.geo.census.gov/geocoder/geographies/addressbatch",
            body = list(
              addressFile = httr::upload_file(temp_csv, type = "text/csv"),
              benchmark = "4",
              vintage = "4"
            ),
            encode = "multipart",
            httr::timeout(300)
          )
        },
        error = function(e) e
      )

      if (inherits(response, "error")) {
        last_error <- conditionMessage(response)
      } else if (httr::status_code(response) != 200) {
        last_error <- sprintf("HTTP status %s", httr::status_code(response))
      } else {
        parsed_result <- tryCatch(
          parse_batch_csv(httr::content(response, as = "text", encoding = "UTF-8")),
          error = function(e) e
        )

        if (inherits(parsed_result, "error")) {
          last_error <- conditionMessage(parsed_result)
        } else {
          geocoded_batches[[batch_number]] <- batch_data |>
            left_join(parsed_result, by = "address_id") |>
            mutate(
              geocode_status = coalesce(geocode_status, "no_match"),
              geocode_match_type = if_else(
                geocode_status == "matched",
                geocode_match_type,
                NA_character_
              ),
              census_matched_address = if_else(
                geocode_status == "matched",
                census_matched_address,
                NA_character_
              ),
              address_latitude = if_else(
                geocode_status == "matched",
                address_latitude,
                NA_real_
              ),
              address_longitude = if_else(
                geocode_status == "matched",
                address_longitude,
                NA_real_
              ),
              census_tract = if_else(
                geocode_status == "matched",
                census_tract,
                NA_character_
              )
            )

          message(sprintf(
            "Batch %s/%s complete. Matched addresses: %s. Unmatched addresses: %s.",
            batch_number,
            n_batches,
            scales::comma(sum(geocoded_batches[[batch_number]]$geocode_status == "matched", na.rm = TRUE)),
            scales::comma(sum(geocoded_batches[[batch_number]]$geocode_status == "no_match", na.rm = TRUE))
          ))

          batch_complete <- TRUE
        }
      }

      if (!batch_complete && attempt < 3L) {
        message(sprintf(
          "Batch %s/%s failed on attempt %s. Retrying after delay. Error: %s",
          batch_number,
          n_batches,
          attempt,
          last_error
        ))
        Sys.sleep(3)
      }
    }

    unlink(temp_csv)

    if (!batch_complete) {
      stop(sprintf(
        "Census batch %s/%s failed after 3 attempts. Last error: %s",
        batch_number,
        n_batches,
        last_error
      ))
    }
  }

  bind_rows(geocoded_batches)
}

# --- repository paths

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- if (length(script_arg)) {
  normalizePath(sub("^--file=", "", script_arg[[1]]), winslash = "/", mustWork = TRUE)
} else {
  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

repo_root <- find_repo_root(dirname(script_path))
setwd(repo_root)

processed_root <- ensure_dir(read_root_path("2_processed_data/processed_root.txt"))

input_path <- file.path(processed_root, "adhoc_payments_ingested.rds")
output_path <- file.path(processed_root, "adhoc_payments_geocoded.rds")
audit_path <- file.path(processed_root, "adhoc_payments_geocode_audit.csv")
preflight_output_path <- file.path(processed_root, "adhoc_payments_geocode_preflight.csv")

required_cols <- c(
  "row_id",
  "address_street",
  "address_city",
  "address_state",
  "address_zip5",
  "address_geocode_key",
  "address_is_geocode_ready"
)

chunk_size <- 10000L
preflight_n <- 10L

if (!file.exists(input_path)) {
  stop(sprintf("Geocode input file not found: %s", input_path))
}

# -----------------------------
# 1) Load and validate input
# -----------------------------

message("Starting ad hoc MFP geocoding.")
message(sprintf("Input dataset: %s", input_path))

payments <- readRDS(input_path)

missing_cols <- setdiff(required_cols, names(payments))

if (length(missing_cols) > 0) {
  stop(sprintf(
    "Geocode input is missing required columns: %s",
    paste(missing_cols, collapse = ", ")
  ))
}

message(sprintf(
  "Loaded geocode input with %s rows and %s columns.",
  scales::comma(nrow(payments)),
  ncol(payments)
))

# -----------------------------
# 2) Prepare unique addresses
# -----------------------------

unique_addresses <- payments |>
  transmute(
    address_street = clean_character(address_street),
    address_city = clean_character(address_city) |> stringr::str_to_upper(),
    address_state = clean_character(address_state) |> stringr::str_to_upper(),
    address_zip5 = normalize_zip5(address_zip5),
    address_geocode_key = clean_character(address_geocode_key)
  ) |>
  filter(
    !is.na(address_geocode_key),
    !is.na(address_street),
    !is.na(address_city),
    !is.na(address_state),
    !is.na(address_zip5)
  ) |>
  distinct(address_geocode_key, .keep_all = TRUE) |>
  mutate(address_id = stringr::str_c("ADDR_", row_number())) |>
  select(address_id, address_geocode_key, address_street, address_city, address_state, address_zip5)

message(sprintf(
  "Geocode-ready unique addresses detected: %s.",
  scales::comma(nrow(unique_addresses))
))

# -----------------------------
# 3) Reuse existing geocode output when possible
# -----------------------------

cached_lookup <- tibble(
  address_geocode_key = character(),
  geocode_status = character(),
  geocode_match_type = character(),
  census_matched_address = character(),
  address_latitude = numeric(),
  address_longitude = numeric(),
  census_tract = character()
)

if (file.exists(output_path) && !overwrite) {
  existing_output <- readRDS(output_path)

  cache_cols <- c(
    "address_geocode_key",
    "geocode_status",
    "geocode_match_type",
    "census_matched_address",
    "address_latitude",
    "address_longitude",
    "census_tract"
  )

  if (all(cache_cols %in% names(existing_output))) {
    cached_lookup <- existing_output |>
      filter(!is.na(address_geocode_key), geocode_status %in% c("matched", "no_match")) |>
      distinct(
        address_geocode_key,
        geocode_status,
        geocode_match_type,
        census_matched_address,
        address_latitude,
        address_longitude,
        census_tract
      )

    message(sprintf(
      "Existing geocode cache found. Cached unique addresses: %s.",
      scales::comma(nrow(cached_lookup))
    ))
  }
}

addresses_to_geocode <- unique_addresses |>
  anti_join(cached_lookup |> select(address_geocode_key), by = "address_geocode_key")

message(sprintf(
  "Unique addresses requiring live geocoding: %s.",
  scales::comma(nrow(addresses_to_geocode))
))

# -----------------------------
# 4) Optional preflight and geocoding
# -----------------------------

preflight_lookup <- tibble(
  address_geocode_key = character(),
  geocode_status = character(),
  geocode_match_type = character(),
  census_matched_address = character(),
  address_latitude = numeric(),
  address_longitude = numeric(),
  census_tract = character()
)

preflight_input <- addresses_to_geocode |>
  slice_head(n = preflight_n)

if (check_only) {
  geocode_unique_addresses(addresses_to_geocode, chunk_size = chunk_size, check_only = TRUE)
  message("Check-only mode complete. No API calls were made and no files were written.")
  quit(save = "no", status = 0)
}

if (!skip_preflight && nrow(preflight_input) > 0) {
  message(sprintf(
    "Running preflight geocode on the first %s unique addresses.",
    scales::comma(nrow(preflight_input))
  ))

  preflight_result <- geocode_unique_addresses(preflight_input, chunk_size = chunk_size, check_only = FALSE) |>
    select(
      address_id,
      geocode_status,
      geocode_match_type,
      census_matched_address,
      address_latitude,
      address_longitude,
      census_tract
    )

  preflight_lookup <- preflight_input |>
    left_join(preflight_result, by = "address_id") |>
    select(
      address_geocode_key,
      geocode_status,
      geocode_match_type,
      census_matched_address,
      address_latitude,
      address_longitude,
      census_tract
    )

  preflight_summary <- preflight_input |>
    left_join(preflight_result, by = "address_id") |>
    transmute(
      address_id,
      address_street,
      address_city,
      address_state,
      address_zip5,
      geocode_status,
      census_matched_address,
      address_latitude,
      address_longitude,
      census_tract
    )

  message(sprintf(
    "Preflight complete. Matched: %s. Unmatched: %s.",
    scales::comma(sum(preflight_summary$geocode_status == "matched", na.rm = TRUE)),
    scales::comma(sum(preflight_summary$geocode_status == "no_match", na.rm = TRUE))
  ))

  if (preflight_only) {
    readr::write_csv(preflight_summary, preflight_output_path)
    message(sprintf("Wrote preflight summary to %s", preflight_output_path))
    quit(save = "no", status = 0)
  }

  addresses_to_geocode <- addresses_to_geocode |>
    anti_join(preflight_input |> select(address_id), by = "address_id")
}

new_lookup <- geocode_unique_addresses(addresses_to_geocode, chunk_size = chunk_size, check_only = FALSE)

new_lookup <- addresses_to_geocode |>
  select(address_id, address_geocode_key) |>
  left_join(new_lookup, by = "address_id") |>
  select(
    address_geocode_key,
    geocode_status,
    geocode_match_type,
    census_matched_address,
    address_latitude,
    address_longitude,
    census_tract
  )

full_lookup <- bind_rows(cached_lookup, preflight_lookup, new_lookup) |>
  distinct(address_geocode_key, .keep_all = TRUE)

# -----------------------------
# 5) Merge geocode results and build audit summary
# -----------------------------

geocoded_payments <- payments |>
  left_join(full_lookup, by = "address_geocode_key") |>
  mutate(
    geocode_status = case_when(
      !address_is_geocode_ready ~ "invalid_address",
      is.na(geocode_status) ~ "no_match",
      TRUE ~ geocode_status
    ),
    geocode_match_type = if_else(
      geocode_status == "matched",
      geocode_match_type,
      NA_character_
    ),
    census_matched_address = if_else(
      geocode_status == "matched",
      census_matched_address,
      NA_character_
    ),
    address_latitude = if_else(
      geocode_status == "matched",
      address_latitude,
      NA_real_
    ),
    address_longitude = if_else(
      geocode_status == "matched",
      address_longitude,
      NA_real_
    ),
    census_tract = if_else(
      geocode_status == "matched",
      census_tract,
      NA_character_
    )
  )

tract_length_ok <- all(
  nchar(geocoded_payments$census_tract[!is.na(geocoded_payments$census_tract)]) == 11
)

audit_summary <- tibble(
  run_timestamp_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
  total_rows = nrow(geocoded_payments),
  geocode_ready_rows = sum(geocoded_payments$address_is_geocode_ready, na.rm = TRUE),
  invalid_address_rows = sum(geocoded_payments$geocode_status == "invalid_address", na.rm = TRUE),
  matched_rows = sum(geocoded_payments$geocode_status == "matched", na.rm = TRUE),
  no_match_rows = sum(geocoded_payments$geocode_status == "no_match", na.rm = TRUE),
  unique_ready_addresses = nrow(unique_addresses),
  matched_unique_addresses = sum(full_lookup$geocode_status == "matched", na.rm = TRUE),
  no_match_unique_addresses = sum(full_lookup$geocode_status == "no_match", na.rm = TRUE),
  tract_length_11_check = tract_length_ok
)

# -----------------------------
# 6) Save outputs
# -----------------------------

saveRDS(geocoded_payments, output_path)
readr::write_csv(audit_summary, audit_path)

message(sprintf("Saved geocoded payment data to %s", output_path))
message(sprintf("Saved geocode audit summary to %s", audit_path))
message(sprintf("Total rows: %s", scales::comma(audit_summary$total_rows)))
message(sprintf("Matched rows: %s", scales::comma(audit_summary$matched_rows)))
message(sprintf("No-match rows: %s", scales::comma(audit_summary$no_match_rows)))
message(sprintf("Invalid-address rows: %s", scales::comma(audit_summary$invalid_address_rows)))
message(sprintf("11-digit tract check: %s", tract_length_ok))
message("Finished ad hoc MFP geocoding.")

# Clear workspace
rm(list = ls(all.names = TRUE))
gc()
