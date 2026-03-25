#!/usr/bin/env Rscript

#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_1_0_prepare_descriptive_summaries.R
# Previous author:  Inder Majumdar
# Current author:   Inder Majumdar + Codex
# Last Updated:     March 25 2026
# Description:      Read the categorized ad hoc MFP payment data, build
#                   figure-ready descriptive summary tables, and write a
#                   non-destructive summary artifact plus a spatial-coverage
#                   audit used by the downstream plotting script.
# INPUTS:           `2_processed_data/processed_root.txt`
#                   `adhoc_payments_geocoded_payee_categorized.rds`
# OUTPUTS:          `adhoc_payments_descriptive_summaries.rds`
#                   `adhoc_payments_descriptive_coverage_audit.csv`
#///////////////////////////////////////////////////////////////////////////////

# -----------------------------
# 0) Setup and configuration
# -----------------------------

# --- packages

library(tidyverse)
library(lubridate)

# --- command-line flags

args <- commandArgs(trailingOnly = TRUE)
overwrite <- "--overwrite" %in% args

# --- shared helpers

script_path <- {
  full_args <- commandArgs(trailingOnly = FALSE)
  script_arg <- grep("^--file=", full_args, value = TRUE)

  if (length(script_arg)) {
    normalizePath(sub("^--file=", "", script_arg[[1]]), winslash = "/", mustWork = TRUE)
  } else if (interactive() && requireNamespace("rstudioapi", quietly = TRUE)) {
    editor_path <- rstudioapi::getSourceEditorContext()$path

    if (!nzchar(editor_path) || !file.exists(editor_path)) {
      stop("Could not determine the current script path from RStudio.")
    }

    normalizePath(editor_path, winslash = "/", mustWork = TRUE)
  } else {
    stop(
      paste(
        "Could not determine the current script path.",
        "Run this script with Rscript from the terminal or from RStudio's editor."
      )
    )
  }
}

source(file.path(dirname(script_path), "shared_descriptives_helpers.R"))

# --- repository paths

repo_root <- find_repo_root(dirname(script_path))
setwd(repo_root)

processed_root <- ensure_dir(read_root_path("2_processed_data/processed_root.txt"))

input_path <- file.path(processed_root, "adhoc_payments_geocoded_payee_categorized.rds")
summary_output_path <- file.path(processed_root, "adhoc_payments_descriptive_summaries.rds")
audit_output_path <- file.path(processed_root, "adhoc_payments_descriptive_coverage_audit.csv")

if (!file.exists(input_path)) {
  stop(sprintf("Required staged input not found: %s", input_path))
}

overwrite <- resolve_overwrite(
  output_paths = c(summary_output_path, audit_output_path),
  overwrite = overwrite,
  context_label = "descriptive summary"
)

# -----------------------------
# 1) Read staged input and validate schema
# -----------------------------

message("Starting descriptive summary stage.")
message(sprintf("Reading staged input: %s", input_path))

payment_data <- readRDS(input_path)

message(sprintf(
  "Loaded categorized payment data. Rows: %s. Columns: %s.",
  scales::comma(nrow(payment_data)),
  ncol(payment_data)
))

required_columns <- c(
  "payment_date",
  "disbursement_amount",
  "accounting_program_description",
  "payee_type",
  "state_abbreviation",
  "address_latitude",
  "address_longitude"
)

assert_required_columns(
  data = payment_data,
  required_columns = required_columns,
  data_label = "Categorized payment data"
)

# -----------------------------
# 2) Derive stable analysis fields
# -----------------------------

analysis_data <- payment_data |>
  mutate(
    payment_year = lubridate::year(payment_date),
    accounting_program_description = dplyr::coalesce(
      accounting_program_description,
      "Missing program description"
    ),
    payee_type = dplyr::coalesce(payee_type, "missing_payee_type"),
    state_abbreviation = dplyr::coalesce(state_abbreviation, "Missing"),
    census_tract = dplyr::coalesce(census_tract, NA_character_),
    has_census_tract = !is.na(census_tract)
  )

if (all(is.na(analysis_data$payment_year))) {
  stop("All `payment_date` values are missing after year extraction.")
}

message("Derived payment year and spatial coverage flags.")

# -----------------------------
# 3) Build non-spatial descriptive summaries
# -----------------------------

message("Building non-spatial grouped summaries.")

program_counts <- analysis_data |>
  count(payment_year, accounting_program_description, name = "payment_count") |>
  group_by(payment_year) |>
  mutate(
    year_total_count = sum(payment_count),
    payment_share = payment_count / year_total_count
  ) |>
  ungroup()

program_amounts <- analysis_data |>
  group_by(payment_year, accounting_program_description) |>
  summarise(
    total_amount = sum(disbursement_amount, na.rm = TRUE),
    .groups = "drop"
  ) |>
  group_by(payment_year) |>
  mutate(
    year_total_amount = sum(total_amount),
    amount_share = total_amount / year_total_amount
  ) |>
  ungroup()

payee_counts <- analysis_data |>
  count(payment_year, payee_type, name = "payment_count") |>
  group_by(payment_year) |>
  mutate(
    year_total_count = sum(payment_count),
    payment_share = payment_count / year_total_count
  ) |>
  ungroup()

payee_amounts <- analysis_data |>
  group_by(payment_year, payee_type) |>
  summarise(
    total_amount = sum(disbursement_amount, na.rm = TRUE),
    .groups = "drop"
  ) |>
  group_by(payment_year) |>
  mutate(
    year_total_amount = sum(total_amount),
    amount_share = total_amount / year_total_amount
  ) |>
  ungroup()

state_amounts <- analysis_data |>
  group_by(payment_year, state_abbreviation) |>
  summarise(
    payment_count = n(),
    total_amount = sum(disbursement_amount, na.rm = TRUE),
    .groups = "drop"
  )

message("Built non-spatial summaries for program, payee type, and state totals.")

# -----------------------------
# 4) Build spatial coverage audit and tract summaries
# -----------------------------

message("Building spatial coverage audit and tract summaries.")

coverage_by_year <- analysis_data |>
  group_by(payment_year) |>
  summarise(
    total_rows = n(),
    rows_with_census_tract = sum(has_census_tract, na.rm = TRUE),
    rows_missing_census_tract = sum(!has_census_tract, na.rm = TRUE),
    share_missing_census_tract = rows_missing_census_tract / total_rows,
    share_with_census_tract = rows_with_census_tract / total_rows,
    .groups = "drop"
  ) |>
  mutate(payment_year = as.character(payment_year))

coverage_overall <- analysis_data |>
  summarise(
    payment_year = "Overall",
    total_rows = n(),
    rows_with_census_tract = sum(has_census_tract, na.rm = TRUE),
    rows_missing_census_tract = sum(!has_census_tract, na.rm = TRUE),
    share_missing_census_tract = rows_missing_census_tract / total_rows,
    share_with_census_tract = rows_with_census_tract / total_rows
  )

coverage_audit <- bind_rows(coverage_by_year, coverage_overall)

tract_data <- analysis_data |>
  filter(has_census_tract)

overall_tract_count_summary <- tract_data |>
  group_by(census_tract) |>
  summarise(
    payment_count = n(),
    .groups = "drop"
  )

overall_tract_amount_summary <- tract_data |>
  group_by(census_tract) |>
  summarise(
    total_amount = sum(disbursement_amount, na.rm = TRUE),
    .groups = "drop"
  )

message("Built spatial coverage audit and tract-level map inputs.")

# -----------------------------
# 5) Validate grouped totals
# -----------------------------

message("Validating summary totals against the source data.")

source_row_total <- nrow(analysis_data)
source_amount_total <- sum(analysis_data$disbursement_amount, na.rm = TRUE)

if (!identical(sum(program_counts$payment_count), source_row_total)) {
  stop("Program count summary does not preserve the full source row total.")
}

if (!identical(sum(payee_counts$payment_count), source_row_total)) {
  stop("Payee count summary does not preserve the full source row total.")
}

if (!isTRUE(all.equal(sum(program_amounts$total_amount), source_amount_total, tolerance = 1e-8))) {
  stop("Program amount summary does not match the full source payment total.")
}

if (!isTRUE(all.equal(sum(payee_amounts$total_amount), source_amount_total, tolerance = 1e-8))) {
  stop("Payee amount summary does not match the full source payment total.")
}

overall_coverage_row <- coverage_audit |>
  filter(payment_year == "Overall")

if (!identical(overall_coverage_row$rows_with_census_tract, nrow(tract_data))) {
  stop("Coverage audit does not match the tract-mapped row count.")
}

message("Summary totals validated successfully.")

# -----------------------------
# 6) Save outputs
# -----------------------------

summary_metadata <- tibble(
  source_row_total = source_row_total,
  tract_row_total = nrow(tract_data)
)

descriptive_summaries <- list(
  metadata = summary_metadata,
  program_counts = program_counts,
  program_amounts = program_amounts,
  payee_counts = payee_counts,
  payee_amounts = payee_amounts,
  state_amounts = state_amounts,
  overall_tract_count_summary = overall_tract_count_summary,
  overall_tract_amount_summary = overall_tract_amount_summary,
  coverage_audit = coverage_audit
)

saveRDS(descriptive_summaries, summary_output_path)
readr::write_csv(coverage_audit, audit_output_path)

message(sprintf("Saved descriptive summary artifact to %s", summary_output_path))
message(sprintf("Saved descriptive coverage audit to %s", audit_output_path))
message("Finished descriptive summary stage.")

# Clear workspace
rm(list = ls(all.names = TRUE))
gc()
