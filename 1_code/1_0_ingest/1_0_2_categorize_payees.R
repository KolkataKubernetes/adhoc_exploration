#!/usr/bin/env Rscript

#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_0_2_categorize_payees.R
# Previous author:  Inder Majumdar
# Current author:   Inder Majumdar + Codex
# Last Updated:     March 24 2026
# Description:      Read the geocoded ad hoc MFP payment data, assign a broad
#                   payee-type category using transparent name-based rules, and
#                   write both a categorized dataset and an audit table that
#                   makes the rule system inspectable.
# INPUTS:           `2_processed_data/processed_root.txt`
#                   `adhoc_payments_geocoded.rds`
# OUTPUTS:          `adhoc_payments_geocoded_payee_categorized.rds`
#                   `adhoc_payments_payee_type_audit.csv`
#///////////////////////////////////////////////////////////////////////////////

# -----------------------------
# 0) Setup and configuration
# -----------------------------

# --- packages

library(tidyverse)

# --- command-line flags

args <- commandArgs(trailingOnly = TRUE)
overwrite <- "--overwrite" %in% args

# --- helper functions

# Origin: adapted from `1_code/1_0_ingest/1_0_0_ingest_adhoc.R`
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

# Origin: adapted from `1_code/1_0_ingest/1_0_0_ingest_adhoc.R`
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

# Origin: adapted from `1_code/1_0_ingest/1_0_0_ingest_adhoc.R`
# Create a directory if needed and return the same path for inline use.
ensure_dir <- function(path_dir) {
  dir.create(path_dir, recursive = TRUE, showWarnings = FALSE)
  path_dir
}

# Origin: adapted from `1_code/1_0_ingest/1_0_0_ingest_adhoc.R`
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

# Convert the payee name to a stable uppercase string used only for matching.
normalize_payee_name <- function(x) {
  x |>
    clean_character() |>
    stringr::str_to_upper()
}

# Identify the current script path in the two supported execution modes:
# `Rscript` from the terminal or an interactive RStudio session.
get_script_path <- function() {
  full_args <- commandArgs(trailingOnly = FALSE)
  script_arg <- grep("^--file=", full_args, value = TRUE)

  if (length(script_arg)) {
    return(
      normalizePath(
        sub("^--file=", "", script_arg[[1]]),
        winslash = "/",
        mustWork = TRUE
      )
    )
  }

  if (interactive() && requireNamespace("rstudioapi", quietly = TRUE)) {
    editor_path <- rstudioapi::getSourceEditorContext()$path

    if (nzchar(editor_path) && file.exists(editor_path)) {
      return(normalizePath(editor_path, winslash = "/", mustWork = TRUE))
    }
  }

  stop(
    paste(
      "Could not determine the current script path.",
      "Run this script with Rscript from the terminal or from RStudio's editor."
    )
  )
}

# -----------------------------
# 1) Read staged inputs
# -----------------------------

script_path <- get_script_path()
repo_root <- find_repo_root(dirname(script_path))
setwd(repo_root)

processed_root <- ensure_dir(read_root_path("2_processed_data/processed_root.txt"))

input_path <- file.path(processed_root, "adhoc_payments_geocoded.rds")
output_path <- file.path(processed_root, "adhoc_payments_geocoded_payee_categorized.rds")
audit_path <- file.path(processed_root, "adhoc_payments_payee_type_audit.csv")

if (!file.exists(input_path)) {
  stop(sprintf("Required staged input not found: %s", input_path))
}

if ((file.exists(output_path) || file.exists(audit_path)) && !overwrite) {
  if (interactive()) {
    overwrite <- TRUE
    message(
      paste(
        "Interactive session detected.",
        "Refreshing existing categorized outputs without requiring --overwrite."
      )
    )
  }
}

if ((file.exists(output_path) || file.exists(audit_path)) && !overwrite) {
  stop(
    paste(
      "Categorized outputs already exist.",
      "Re-run with --overwrite to replace the categorized dataset and audit file."
    )
  )
}

message("Starting payee categorization stage.")
message(sprintf("Reading staged input: %s", input_path))

data_input <- readRDS(input_path)

message(sprintf(
  "Loaded staged input. Rows: %s. Columns: %s.",
  scales::comma(nrow(data_input)),
  ncol(data_input)
))

# -----------------------------
# 2) Build transparent rule flags
# -----------------------------

# The classifier is intentionally simple and auditable. The goal is not to parse
# every legal entity perfectly, but to separate obvious government offices,
# financial institutions, personal trusts, farm/ranch operations, and residual
# organizations from likely individual recipients.
government_regex <- regex(
  "\\bFARM SERVICE AGENCY\\b|\\bUSDA\\b|\\bCOMMODITY CREDIT\\b|\\bCCC\\b|\\bFSA\\b",
  ignore_case = TRUE
)

financial_bank_regex <- regex(
  "\\bBANK\\b|\\bBANCORP BANK\\b|\\bNATIONAL ASSOCIATION\\b",
  ignore_case = TRUE
)

financial_credit_regex <- regex(
  "\\bCREDIT UNION\\b|\\bFARM CREDIT\\b|\\bPRODUCTION CREDIT\\b|\\bACA\\b|\\bPCA\\b|\\bFCS\\b",
  ignore_case = TRUE
)

financial_finance_regex <- regex(
  "\\bFINANCE\\b",
  ignore_case = TRUE
)

trust_regex <- regex(
  "\\bTRUST\\b|\\bREVOCABLE TRUST\\b|\\bLIVING TRUST\\b|\\bFAMILY TRUST\\b",
  ignore_case = TRUE
)

farm_ranch_regex <- regex(
  "\\bFARM\\b|\\bFARMS\\b|\\bRANCH\\b|\\bDAIRY\\b|\\bCATTLE\\b|\\bANGUS\\b|\\bLIVESTOCK\\b|\\bFEEDERS\\b",
  ignore_case = TRUE
)

business_suffix_regex <- regex(
  "\\bLLC\\b|\\bINC\\b|\\bLTD\\b|\\bLP\\b|\\bLLP\\b|\\bCORP\\b|\\bCORPORATION\\b|\\bCOMPANY\\b",
  ignore_case = TRUE
)

other_org_regex <- regex(
  "\\bCHURCH\\b|\\bBAPTIST\\b|\\bMINISTRY\\b|\\bMINISTRIES\\b|\\bSCHOOL\\b|\\bCOUNTY\\b|\\bCITY OF\\b|\\bCOOPERATIVE\\b|\\bASSOCIATION\\b|\\bUNIVERSITY\\b|\\bCOLLEGE\\b|\\bFOUNDATION\\b|\\bDISTRICT\\b|\\bHOSPITAL\\b",
  ignore_case = TRUE
)

# Manual overrides are intentionally centralized in one small object so a user
# can curate edge cases discovered during manual review without rewriting the
# broader pattern rules above.
manual_payee_overrides <- tribble(
  ~payee_name_upper, ~payee_type_manual, ~payee_type_detail_manual,
  "SARA S DAVIS ESTATE", "person_trust", "manual_override_person_trust",
  "CLARA BEN JORDAN FAMILY LIMITED P", "other", "manual_override_other",
  "JAMES H STEELE SR CREDIT SHELTER", "person_trust", "manual_override_person_trust",
  "B & B VENTURES", "other", "manual_override_other",
  "HEREFORD & SONS", "other", "manual_override_other",
  "LANE LIMITED PARTNERSHIP", "other", "manual_override_other",
  "ANDERSON BROTHERS", "other", "manual_override_other",
  "BRAGG LIMITED PARTNERSHIP I", "other", "manual_override_other",
  "DAVIS FAMILY LIMITED PARTNERSHIP", "other", "manual_override_other",
  "LKH FARMING AN ARIZONA GP", "farm_ranch", "manual_override_farm_ranch",
  "KEN SHEELY RANCHES PARTNERS", "farm_ranch", "manual_override_farm_ranch",
  "A TUMBLING T RANCHES", "farm_ranch", "manual_override_farm_ranch",
  "STOTZ FARMING", "farm_ranch", "manual_override_farm_ranch",
  "DOUG WEST FARMING JV", "farm_ranch", "manual_override_farm_ranch",
  "LOREN C PRATT FAMILY LLLP", "other", "manual_override_other",
  "HASTY FAMILY TST AGREEMENT", "person_trust", "manual_override_person_trust",
  "RJS PLANTING CO", "farm_ranch", "manual_override_farm_ranch",
  "FISH LAKE PLANTING CO", "farm_ranch", "manual_override_farm_ranch",
  "BULLOCK BROTHERS", "other", "manual_override_other",
  "DAUGHERTY BROTHERS", "other", "manual_override_other"
)

data_categorized <- data_input |>
  mutate(
    payee_name_clean = clean_character(formatted_payee_name),
    payee_name_upper = normalize_payee_name(formatted_payee_name),
    flag_missing_payee_name = is.na(payee_name_upper),
    flag_government_pattern = stringr::str_detect(
      dplyr::coalesce(payee_name_upper, ""),
      government_regex
    ),
    flag_financial_bank = stringr::str_detect(
      dplyr::coalesce(payee_name_upper, ""),
      financial_bank_regex
    ),
    flag_financial_credit = stringr::str_detect(
      dplyr::coalesce(payee_name_upper, ""),
      financial_credit_regex
    ),
    flag_financial_finance = stringr::str_detect(
      dplyr::coalesce(payee_name_upper, ""),
      financial_finance_regex
    ),
    flag_financial_pattern = (
      flag_financial_bank |
        flag_financial_credit |
        flag_financial_finance
    ),
    flag_trust_pattern = stringr::str_detect(
      dplyr::coalesce(payee_name_upper, ""),
      trust_regex
    ),
    flag_farm_ranch_pattern = stringr::str_detect(
      dplyr::coalesce(payee_name_upper, ""),
      farm_ranch_regex
    ),
    flag_business_suffix = stringr::str_detect(
      dplyr::coalesce(payee_name_upper, ""),
      business_suffix_regex
    ),
    flag_other_org_pattern = stringr::str_detect(
      dplyr::coalesce(payee_name_upper, ""),
      other_org_regex
    ),
    flag_compact_org_name = stringr::str_detect(
      dplyr::coalesce(payee_name_upper, ""),
      "^[A-Z][A-Z&.-]{3,}$"
    ),
    rule_overlap_count = (
      as.integer(flag_government_pattern) +
        as.integer(flag_financial_pattern) +
        as.integer(flag_trust_pattern) +
        as.integer(flag_farm_ranch_pattern) +
        as.integer(flag_business_suffix) +
        as.integer(flag_other_org_pattern) +
        as.integer(flag_compact_org_name)
    )
  ) |>
  mutate(
    payee_type_detail = case_when(
      flag_missing_payee_name ~ "missing_payee_name",
      flag_government_pattern ~ "government_fsa_usda",
      flag_financial_bank ~ "financial_bank",
      flag_financial_credit ~ "financial_credit",
      flag_financial_finance ~ "financial_finance_company",
      flag_trust_pattern ~ "person_trust",
      flag_farm_ranch_pattern & flag_business_suffix ~ "farm_ranch_entity",
      flag_farm_ranch_pattern ~ "farm_ranch_keyword",
      flag_business_suffix ~ "other_business_entity",
      flag_other_org_pattern ~ "other_organization",
      flag_compact_org_name ~ "other_compact_org_name",
      TRUE ~ "residual_person"
    ),
    payee_type = case_when(
      payee_type_detail == "government_fsa_usda" ~ "government",
      payee_type_detail %in% c(
        "financial_bank",
        "financial_credit",
        "financial_finance_company"
      ) ~ "financial_institution",
      payee_type_detail == "person_trust" ~ "person_trust",
      payee_type_detail %in% c(
        "farm_ranch_entity",
        "farm_ranch_keyword"
      ) ~ "farm_ranch",
      payee_type_detail %in% c(
        "missing_payee_name",
        "other_business_entity",
        "other_organization",
        "other_compact_org_name"
      ) ~ "other",
      payee_type_detail == "residual_person" ~ "person",
      TRUE ~ NA_character_
    )
  ) |>
  left_join(manual_payee_overrides, by = "payee_name_upper") |>
  mutate(
    flag_manual_override = !is.na(payee_type_manual),
    payee_type_detail = dplyr::coalesce(payee_type_detail_manual, payee_type_detail),
    payee_type = dplyr::coalesce(payee_type_manual, payee_type)
  ) |>
  select(-payee_type_manual, -payee_type_detail_manual) |>
  select(-payee_name_upper)

message("Rule construction and ordered category assignment complete.")

missing_category_count <- sum(is.na(data_categorized$payee_type))

if (missing_category_count != 0) {
  stop(sprintf(
    "Category assignment failed. Rows missing payee_type: %s",
    scales::comma(missing_category_count)
  ))
}

message(sprintf(
  "Category coverage check passed. Rows with missing payee_type: %s.",
  missing_category_count
))

message(sprintf(
  "Manual payee-name overrides applied: %s.",
  scales::comma(sum(data_categorized$flag_manual_override, na.rm = TRUE))
))

category_counts <- data_categorized |>
  count(payee_type, sort = TRUE, name = "n_rows")

detail_counts <- data_categorized |>
  count(payee_type, payee_type_detail, sort = TRUE, name = "n_rows")

top_names_by_detail <- data_categorized |>
  filter(!is.na(payee_name_clean)) |>
  count(payee_type, payee_type_detail, formatted_payee_name, sort = TRUE, name = "n_rows") |>
  group_by(payee_type_detail) |>
  mutate(rank_within_detail = row_number()) |>
  filter(rank_within_detail <= 10) |>
  ungroup()

overlap_counts <- data_categorized |>
  count(rule_overlap_count, name = "n_rows", sort = TRUE)

audit_category_counts <- category_counts |>
  mutate(
    audit_table = "category_counts",
    payee_type_detail = NA_character_,
    formatted_payee_name = NA_character_,
    rank_within_detail = NA_integer_,
    rule_overlap_count = NA_integer_
  ) |>
  select(
    audit_table,
    payee_type,
    payee_type_detail,
    formatted_payee_name,
    rank_within_detail,
    rule_overlap_count,
    n_rows
  )

audit_detail_counts <- detail_counts |>
  mutate(
    audit_table = "detail_counts",
    formatted_payee_name = NA_character_,
    rank_within_detail = NA_integer_,
    rule_overlap_count = NA_integer_
  ) |>
  select(
    audit_table,
    payee_type,
    payee_type_detail,
    formatted_payee_name,
    rank_within_detail,
    rule_overlap_count,
    n_rows
  )

audit_top_names <- top_names_by_detail |>
  mutate(
    audit_table = "top_names_by_detail",
    rule_overlap_count = NA_integer_
  ) |>
  select(
    audit_table,
    payee_type,
    payee_type_detail,
    formatted_payee_name,
    rank_within_detail,
    rule_overlap_count,
    n_rows
  )

audit_overlap_counts <- overlap_counts |>
  mutate(
    audit_table = "rule_overlap_counts",
    payee_type = NA_character_,
    payee_type_detail = NA_character_,
    formatted_payee_name = NA_character_,
    rank_within_detail = NA_integer_
  ) |>
  select(
    audit_table,
    payee_type,
    payee_type_detail,
    formatted_payee_name,
    rank_within_detail,
    rule_overlap_count,
    n_rows
  )

audit_output <- bind_rows(
  audit_category_counts,
  audit_detail_counts,
  audit_top_names,
  audit_overlap_counts
)

data_categorized |>
  select(-starts_with("flag_")) -> data_categorized_final

# -----------------------------
# 3) Save outputs and report summary
# -----------------------------

saveRDS(data_categorized_final, output_path)
readr::write_csv(audit_output, audit_path, na = "")

message(sprintf("Saved categorized dataset to %s", output_path))
message(sprintf("Saved payee-type audit table to %s", audit_path))

message("Category totals:")
purrr::walk2(
  category_counts$payee_type,
  category_counts$n_rows,
  ~message(sprintf("  %s: %s", .x, scales::comma(.y)))
)

message(sprintf(
  "Rows with multiple raw rule families before precedence: %s",
  scales::comma(sum(data_categorized$rule_overlap_count > 1, na.rm = TRUE))
))

message("Finished payee categorization stage.")

# Clear workspace
rm(list = ls(all.names = TRUE))
gc()
