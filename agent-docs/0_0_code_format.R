#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        0_0_code_format.R
# Previous author:  Inder Majumdar 
# Current author:   Inder Majumdar + Codex
# Last Updated:     Month DD YYYY
# Description:      'EXAMPLE'Rebuild the consolidated wide ABAWD waiver panel from the
#                   raw annual Excel workbooks. (EXAMPLE)
# INPUTS:           `0_inputs/input_root.txt`
#                   `2_processed_data/processed_root.txt`
#                   `0_0_waivers/0_0_1_ABAWD_panels/*.xlsx`
# OUTPUTS:          `2_0_waivers/2_0_0_waiver_data_consolidated_generated.rds`
#///////////////////////////////////////////////////////////////////////////////

# Reference file: Use this if we're citing specific reference files from agent-context or a legacy code base
# - legacy/1_code/1_0_0_SNAP_waiver_ingest.R

# -----------------------------
# 0) Setup and configuration
# -----------------------------
## Packages 
library(dplyr)
library(purrr)
library(readr)
library(readxl)
library(lubridate)
library(zoo)

# --- If necessary Set local pathing to allow for script to run within IDE. Invoke helper script(s) here if any 

# --- Read paths for ingest, saving processed data. Example below 

repo_root <- get_repo_root()
setwd(repo_root)

input_root <- read_root_path("0_inputs/input_root.txt")
processed_root <- read_root_path("2_processed_data/processed_root.txt")

waiver_input_dir <- file.path(input_root, "0_0_waivers", "0_0_1_ABAWD_panels")
waiver_output_dir <- ensure_dir(file.path(processed_root, "2_0_waivers"))

# -----------------------------
# 1) Data Ingest (Step 1)
# -----------------------------

waiver_files <- list.files(
  waiver_input_dir,
  pattern = "\\.xlsx$",
  full.names = TRUE
) |>
  sort()

if (!length(waiver_files)) {
  stop(sprintf("No waiver workbooks found in %s", waiver_input_dir))
}

# -----------------------------
# 2) Step 2
# -----------------------------

# --- Subtask 1

# --- Subtask 2

# --- Subtask 3

# -----------------------------
# 3) Save, close out (this should always be the last step)
# -----------------------------

saveRDS(
  generated_wide,
  file.path(waiver_output_dir, "2_0_0_waiver_data_consolidated_generated.rds")
)

message(sprintf("Saved raw waiver ingest outputs to %s", waiver_output_dir))
