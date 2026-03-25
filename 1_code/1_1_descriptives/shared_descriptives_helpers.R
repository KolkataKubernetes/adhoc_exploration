#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        shared_descriptives_helpers.R
# Previous author:  Inder Majumdar
# Current author:   Inder Majumdar + Codex
# Last Updated:     March 25 2026
# Description:      Shared helper functions for the numbered descriptives
#                   stage scripts. These helpers standardize repository path
#                   discovery, pointer-file reading, non-destructive output
#                   handling, and plot styling.
# INPUTS:           None directly. Helpers are sourced by scripts in
#                   `1_code/1_1_descriptives/`.
# OUTPUTS:          None directly.
#///////////////////////////////////////////////////////////////////////////////

# -----------------------------
# 0) Shared path helpers
# -----------------------------

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

# Origin: adapted from `1_code/1_0_ingest/1_0_2_categorize_payees.R`
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

# -----------------------------
# 1) Validation and output guards
# -----------------------------

# Confirm that all required columns exist before the script starts grouping or
# plotting. This keeps downstream errors interpretable for the user.
assert_required_columns <- function(data, required_columns, data_label) {
  missing_columns <- setdiff(required_columns, names(data))

  if (length(missing_columns)) {
    stop(
      sprintf(
        "%s is missing required columns: %s",
        data_label,
        paste(missing_columns, collapse = ", ")
      )
    )
  }
}

# Keep the stage non-destructive by default. If outputs already exist, require
# either an explicit overwrite flag or an interactive refresh from the IDE.
resolve_overwrite <- function(output_paths, overwrite, context_label) {
  existing_outputs <- output_paths[file.exists(output_paths)]

  if (!length(existing_outputs)) {
    return(overwrite)
  }

  if (!overwrite && interactive()) {
    message(
      paste(
        "Interactive session detected.",
        sprintf("Refreshing existing %s outputs without requiring --overwrite.", context_label)
      )
    )
    return(TRUE)
  }

  if (!overwrite) {
    stop(
      paste(
        sprintf("%s outputs already exist.", context_label),
        "Re-run with --overwrite to replace them."
      )
    )
  }

  overwrite
}

# -----------------------------
# 2) Plotting helpers
# -----------------------------

# Read the locally stored 2010 Census tract TIGER ZIP files and return one
# tract geometry object keyed on the 11-digit tract identifier used downstream.
load_census_tract_geometries <- function(tract_dir) {
  tract_files <- list.files(tract_dir, full.names = TRUE)
  tract_zip_files <- tract_files[endsWith(tract_files, ".zip")]

  if (!length(tract_zip_files)) {
    stop(sprintf("No tract ZIP files found in %s", tract_dir))
  }

  tract_geometries <- purrr::map(
    tract_zip_files,
    function(zip_path) {
      sf::st_read(
        dsn = sprintf("/vsizip/%s", zip_path),
        quiet = TRUE
      ) |>
        dplyr::select(GEOID10, STATEFP10, geometry)
    }
  )

  tract_geometries |>
    dplyr::bind_rows() |>
    sf::st_as_sf() |>
    sf::st_transform(4326)
}

# Origin: provided by `agent-docs/agent_context/2026_03_24_descriptives.md`
# Keep formatting consistent across all descriptive figures in this stage.
theme_im <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title.position = "plot",
      plot.caption.position = "plot",
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_line(linewidth = 0.3),
      panel.grid.major.y = ggplot2::element_line(linewidth = 0.3),
      legend.position = "top",
      legend.title = ggplot2::element_text(face = "bold"),
      plot.title = ggplot2::element_text(face = "bold"),
      axis.title = ggplot2::element_text(face = "bold")
    )
}

# Save a plot with consistent defaults and emit a message so terminal runs show
# exactly which artifact was written.
save_descriptive_plot <- function(plot_object, output_path, width, height, dpi = 300) {
  ggplot2::ggsave(
    filename = output_path,
    plot = plot_object,
    width = width,
    height = height,
    dpi = dpi
  )

  message(sprintf("Saved figure: %s", output_path))
}
