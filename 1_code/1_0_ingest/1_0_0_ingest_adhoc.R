#!/usr/bin/env Rscript

#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_0_0_ingest_adhoc.R
# Previous author:  Inder Majumdar
# Current author:   Inder Majumdar + Codex
# Last Updated:     March 22 2026
# Description:      Ingest the ad hoc MFP payment workbook, combine all workbook
#                   sheets, type the raw payment columns explicitly, and create
#                   row-level address fields used by the downstream Census
#                   geocoding script.
# INPUTS:           `0_inputs/input_root.txt`
#                   `2_processed_data/processed_root.txt`
#                   `CAS.C2602520.NA.PMTS.FINAL.DT26054.xlsx`
# OUTPUTS:          `adhoc_payments_ingested.rds`
#///////////////////////////////////////////////////////////////////////////////

# -----------------------------
# 0) Setup and configuration
# -----------------------------

# --- packages

library(tidyverse)
library(janitor)
library(readxl)

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

# Parse payment dates from the workbook's month/day/year text format.
parse_payment_date <- function(x) {
  if (inherits(x, c("Date", "POSIXct", "POSIXt"))) {
    return(as.Date(x))
  }

  x |>
    clean_character() |>
    lubridate::mdy(quiet = TRUE) |>
    as.Date()
}

# Read one workbook sheet and stamp the sheet name for provenance.
read_payment_sheet <- function(sheet_name, workbook_path) {
  message(sprintf("Reading workbook sheet: %s", sheet_name))

  readxl::read_xlsx(workbook_path, sheet = sheet_name) |>
    mutate(source_sheet_name = sheet_name)
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

input_root <- read_root_path("0_inputs/input_root.txt")
processed_root <- ensure_dir(read_root_path("2_processed_data/processed_root.txt"))

input_path <- file.path(input_root, "CAS.C2602520.NA.PMTS.FINAL.DT26054.xlsx")
output_path <- file.path(processed_root, "adhoc_payments_ingested.rds")

if (!file.exists(input_path)) {
  stop(sprintf("Input workbook not found: %s", input_path))
}

# -----------------------------
# 1) Data ingest
# -----------------------------

message("Starting ad hoc MFP ingest.")
message(sprintf("Input workbook: %s", input_path))

sheet_names <- excel_sheets(input_path)
message(sprintf("Workbook sheets detected: %s", paste(sheet_names, collapse = ", ")))

data_raw <- purrr::map_dfr(
  sheet_names,
  read_payment_sheet,
  workbook_path = input_path
)

message(sprintf(
  "Workbook ingest complete. Combined rows: %s. Combined columns: %s.",
  scales::comma(nrow(data_raw)),
  ncol(data_raw)
))

# -----------------------------
# 2) Explicit typing and field cleanup
# -----------------------------

# The workbook is split across four sheets. After binding the sheets together,
# make the typing choices explicit so the downstream geocoding script can rely
# on stable column classes and names.
data_typecast <- data_raw |>
  janitor::clean_names() |>
  mutate(
    source_sheet_name = clean_character(source_sheet_name),
    state_fsa_code = clean_character(state_fsa_code),
    state_fsa_name = clean_character(state_fsa_name),
    county_fsa_code = clean_character(county_fsa_code),
    county_fsa_name = clean_character(county_fsa_name),
    formatted_payee_name = clean_character(formatted_payee_name),
    address_information_line = clean_character(address_information_line),
    delivery_address_line = clean_character(delivery_address_line),
    city_name = clean_character(city_name),
    state_abbreviation = clean_character(state_abbreviation) |> stringr::str_to_upper(),
    zip_code = clean_character(zip_code),
    disbursement_amount = as.numeric(disbursement_amount),
    payment_date = parse_payment_date(payment_date),
    accounting_program_code = clean_character(accounting_program_code),
    accounting_program_description = clean_character(accounting_program_description),
    accounting_program_year = clean_character(accounting_program_year)
  ) |>
  mutate(row_id = row_number())

message("Explicit typing and string cleanup complete.")

# -----------------------------
# 3) Create geocoding-ready fields
# -----------------------------

# The source data expose one relevant address per row. Use the delivery line as
# the primary street field for geocoding because the information line is often a
# name or care-of field rather than a street address.
data_prepared <- data_typecast |>
  mutate(
    address_street = delivery_address_line,
    address_line_aux = address_information_line,
    address_city = city_name,
    address_state = state_abbreviation,
    address_zip5 = normalize_zip5(zip_code)
  ) |>
  mutate(
    address_geocode_key = case_when(
      is.na(address_street) ~ NA_character_,
      is.na(address_city) ~ NA_character_,
      is.na(address_state) ~ NA_character_,
      is.na(address_zip5) ~ NA_character_,
      TRUE ~ stringr::str_c(
        stringr::str_to_upper(address_street),
        stringr::str_to_upper(address_city),
        address_state,
        address_zip5,
        sep = ", "
      )
    ),
    address_is_geocode_ready = !is.na(address_geocode_key)
  )

message(sprintf(
  "Address feature creation complete. Geocode-ready rows: %s. Unique geocode-ready addresses: %s.",
  scales::comma(sum(data_prepared$address_is_geocode_ready, na.rm = TRUE)),
  scales::comma(dplyr::n_distinct(data_prepared$address_geocode_key, na.rm = TRUE))
))

# -----------------------------
# 4) Save, close out
# -----------------------------

saveRDS(data_prepared, output_path)

message(sprintf("Saved ingested payment data to %s", output_path))
message("Finished ad hoc MFP ingest.")

# Clear workspace
rm(list = ls(all.names = TRUE))
gc()
