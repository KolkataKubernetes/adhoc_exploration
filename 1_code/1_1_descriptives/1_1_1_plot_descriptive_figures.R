#!/usr/bin/env Rscript

#///////////////////////////////////////////////////////////////////////////////
#----                              Preamble                                 ----
# File name:        1_1_1_plot_descriptive_figures.R
# Previous author:  Inder Majumdar
# Current author:   Inder Majumdar + Codex
# Last Updated:     March 25 2026
# Description:      Read the prepared descriptive summary artifact and write
#                   publication-ready figures for program mix, payee mix, and
#                   spatial concentration in the ad hoc MFP payment data.
# INPUTS:           `2_processed_data/processed_root.txt`
#                   `adhoc_payments_descriptive_summaries.rds`
# OUTPUTS:          `3_outputs/3_1_descriptives/*.png`
#///////////////////////////////////////////////////////////////////////////////

# -----------------------------
# 0) Setup and configuration
# -----------------------------

# --- packages

library(tidyverse)
library(sf)
library(grid)
library(maps)

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

processed_root <- read_root_path("2_processed_data/processed_root.txt")
summary_input_path <- file.path(processed_root, "adhoc_payments_descriptive_summaries.rds")
figure_output_dir <- ensure_dir(file.path(repo_root, "3_outputs", "3_1_descriptives"))

figure_paths <- c(
  file.path(figure_output_dir, "1_1_1_payment_counts_by_payee_type.png"),
  file.path(figure_output_dir, "1_1_1_payment_dollars_by_payee_type.png"),
  file.path(figure_output_dir, "1_1_1_spatial_payment_counts_by_year.png"),
  file.path(figure_output_dir, "1_1_1_spatial_payment_dollars_by_year.png"),
  file.path(figure_output_dir, "1_1_1_top_states_by_payment_dollars.png")
)

if (!file.exists(summary_input_path)) {
  stop(sprintf("Required descriptive summary artifact not found: %s", summary_input_path))
}

overwrite <- resolve_overwrite(
  output_paths = figure_paths,
  overwrite = overwrite,
  context_label = "descriptive figure"
)

# -----------------------------
# 1) Read summary artifact and validate contents
# -----------------------------

message("Starting descriptive plotting stage.")
message(sprintf("Reading summary artifact: %s", summary_input_path))

descriptive_summaries <- readRDS(summary_input_path)

required_summary_names <- c(
  "metadata",
  "program_counts",
  "program_amounts",
  "payee_counts",
  "payee_amounts",
  "state_amounts",
  "overall_tract_count_summary",
  "overall_tract_amount_summary",
  "coverage_audit"
)

missing_summary_names <- setdiff(required_summary_names, names(descriptive_summaries))

if (length(missing_summary_names)) {
  stop(
    sprintf(
      "Summary artifact is missing required objects: %s",
      paste(missing_summary_names, collapse = ", ")
    )
  )
}

summary_metadata <- descriptive_summaries$metadata
program_counts <- descriptive_summaries$program_counts
program_amounts <- descriptive_summaries$program_amounts
payee_counts <- descriptive_summaries$payee_counts
payee_amounts <- descriptive_summaries$payee_amounts
state_amounts <- descriptive_summaries$state_amounts
overall_tract_count_summary <- descriptive_summaries$overall_tract_count_summary
overall_tract_amount_summary <- descriptive_summaries$overall_tract_amount_summary
coverage_audit <- descriptive_summaries$coverage_audit

overall_coverage <- coverage_audit |>
  filter(payment_year == "Overall")

tract_dir <- file.path(
  read_root_path("0_inputs/input_root.txt"),
  "census_tracts"
)

message(sprintf("Reading census tract geometries from %s", tract_dir))

tract_geometries <- load_census_tract_geometries(tract_dir) |>
  mutate(is_continental_us = !STATEFP10 %in% c("02", "15", "60", "66", "69", "72", "78"))

message("Loaded tract geometries and summary objects.")

# -----------------------------
# 2) Build non-spatial figures
# -----------------------------

message("Building non-spatial descriptive figures.")

payee_order <- payee_amounts |>
  group_by(payee_type) |>
  summarise(overall_amount = sum(total_amount), .groups = "drop") |>
  arrange(desc(overall_amount)) |>
  pull(payee_type)

counts_by_payee_plot <- payee_counts |>
  mutate(
    payment_year = factor(payment_year),
    payee_type = factor(payee_type, levels = payee_order)
  ) |>
  ggplot(aes(x = payment_year, y = payment_count, fill = payee_type)) +
  geom_col(width = 0.7) +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Payment Counts by Payee Type",
    x = "Payment year",
    y = "Number of payments",
    fill = "Payee type",
    caption = "Counts reflect all payment rows in the categorized payment file."
  ) +
  theme_im()

dollars_by_payee_plot <- payee_amounts |>
  mutate(
    payment_year = factor(payment_year),
    payee_type = factor(payee_type, levels = payee_order)
  ) |>
  ggplot(aes(x = payment_year, y = total_amount, fill = payee_type)) +
  geom_col(width = 0.7) +
  scale_y_continuous(labels = scales::label_dollar(scale_cut = scales::cut_short_scale())) +
  labs(
    title = "Payment Dollars by Payee Type",
    x = "Payment year",
    y = "Total disbursement amount",
    fill = "Payee type",
    caption = "Dollar totals reflect all payment rows in the categorized payment file."
  ) +
  theme_im()

top_states_plot_data <- state_amounts |>
  group_by(payment_year) |>
  slice_max(order_by = total_amount, n = 15, with_ties = FALSE) |>
  ungroup() |>
  arrange(payment_year, total_amount) |>
  mutate(
    state_rank_label = paste(state_abbreviation, payment_year, sep = "___"),
    state_rank_label = factor(state_rank_label, levels = state_rank_label)
  )

top_states_plot <- top_states_plot_data |>
  mutate(
    payment_year = factor(payment_year)
  ) |>
  ggplot(aes(x = total_amount, y = state_rank_label, fill = payment_year)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ payment_year, scales = "free_y") +
  scale_x_continuous(labels = scales::label_dollar(scale_cut = scales::cut_short_scale())) +
  scale_y_discrete(labels = function(x) sub("___.*$", "", x)) +
  labs(
    title = "Top States by Payment Dollars",
    x = "Total disbursement amount",
    y = "State abbreviation",
    caption = "This figure uses the full categorized dataset and does not depend on geocoded coordinates."
  ) +
  theme_im()

# -----------------------------
# 3) Build spatial figures
# -----------------------------

message("Building spatial descriptive figures.")

count_map_sf <- tract_geometries |>
  left_join(overall_tract_count_summary, by = c("GEOID10" = "census_tract"))

amount_map_sf <- tract_geometries |>
  left_join(overall_tract_amount_summary, by = c("GEOID10" = "census_tract"))

continental_bbox <- sf::st_bbox(
  c(xmin = -125, xmax = -66.5, ymin = 24, ymax = 50),
  crs = sf::st_crs(tract_geometries)
)

continental_count_map_sf <- count_map_sf |>
  filter(is_continental_us) |>
  suppressWarnings(sf::st_crop(continental_bbox)) |>
  sf::st_simplify(dTolerance = 0.05, preserveTopology = TRUE)

continental_amount_map_sf <- amount_map_sf |>
  filter(is_continental_us) |>
  suppressWarnings(sf::st_crop(continental_bbox)) |>
  sf::st_simplify(dTolerance = 0.05, preserveTopology = TRUE)

state_map <- ggplot2::map_data("state") |>
  dplyr::filter(!region %in% c("alaska", "hawaii"))

continental_rows_count <- count_map_sf |>
  filter(is_continental_us, !is.na(payment_count)) |>
  summarise(mapped_rows = sum(payment_count)) |>
  pull(mapped_rows)

noncontinental_rows_count <- count_map_sf |>
  filter(!is_continental_us, !is.na(payment_count)) |>
  summarise(excluded_rows = sum(payment_count)) |>
  pull(excluded_rows)

spatial_caption <- paste(
  sprintf(
    "Maps use %s payment rows with non-missing census tracts in continental U.S. tracts.",
    scales::comma(continental_rows_count)
  ),
  sprintf(
    "%s rows (%s) are excluded because census tract is missing.",
    scales::comma(overall_coverage$rows_missing_census_tract[[1]]),
    scales::percent(overall_coverage$share_missing_census_tract[[1]], accuracy = 0.1)
  ),
  sprintf(
    "%s rows with tract IDs fall outside continental U.S. tract files and are also excluded.",
    scales::comma(noncontinental_rows_count)
  )
)

spatial_counts_plot <- ggplot() +
  geom_polygon(
    data = state_map,
    aes(x = long, y = lat, group = group),
    fill = "grey85",
    color = "white",
    linewidth = 0.1
  ) +
  geom_sf(
    data = continental_count_map_sf |>
      filter(!is.na(payment_count)),
    aes(fill = payment_count),
    color = NA,
    linewidth = 0
  ) +
  coord_sf(xlim = c(-125, -66.5), ylim = c(24, 50), expand = FALSE) +
  scale_fill_viridis_c(
    option = "D",
    trans = "sqrt",
    labels = scales::comma,
    na.value = "grey85",
    guide = guide_colorbar(
      title.position = "top",
      barheight = unit(90, "pt"),
      barwidth = unit(14, "pt")
    )
  ) +
  labs(
    title = "Spatial Distribution of Payment Counts Across All Years",
    fill = "Payment count",
    caption = spatial_caption
  ) +
  theme_im(base_size = 11) +
  theme(
    legend.position = "right",
    legend.text = element_text(size = 9),
    legend.title = element_text(size = 10, face = "bold")
  )

spatial_dollars_plot <- ggplot() +
  geom_polygon(
    data = state_map,
    aes(x = long, y = lat, group = group),
    fill = "grey85",
    color = "white",
    linewidth = 0.1
  ) +
  geom_sf(
    data = continental_amount_map_sf |>
      filter(!is.na(total_amount)),
    aes(fill = total_amount),
    color = NA,
    linewidth = 0
  ) +
  coord_sf(xlim = c(-125, -66.5), ylim = c(24, 50), expand = FALSE) +
  scale_fill_viridis_c(
    option = "B",
    trans = "sqrt",
    labels = scales::label_dollar(scale_cut = scales::cut_short_scale()),
    na.value = "grey85",
    guide = guide_colorbar(
      title.position = "top",
      barheight = unit(90, "pt"),
      barwidth = unit(14, "pt")
    )
  ) +
  labs(
    title = "Spatial Distribution of Payment Dollars Across All Years",
    fill = "Payment dollars",
    caption = spatial_caption
  ) +
  theme_im(base_size = 11) +
  theme(
    legend.position = "right",
    legend.text = element_text(size = 9),
    legend.title = element_text(size = 10, face = "bold")
  )

# -----------------------------
# 4) Save outputs
# -----------------------------

message("Saving descriptive figures.")

save_descriptive_plot(
  plot_object = counts_by_payee_plot,
  output_path = file.path(figure_output_dir, "1_1_1_payment_counts_by_payee_type.png"),
  width = 10,
  height = 7
)

save_descriptive_plot(
  plot_object = dollars_by_payee_plot,
  output_path = file.path(figure_output_dir, "1_1_1_payment_dollars_by_payee_type.png"),
  width = 10,
  height = 7
)

save_descriptive_plot(
  plot_object = spatial_counts_plot,
  output_path = file.path(figure_output_dir, "1_1_1_spatial_payment_counts_by_year.png"),
  width = 11,
  height = 7
)

save_descriptive_plot(
  plot_object = spatial_dollars_plot,
  output_path = file.path(figure_output_dir, "1_1_1_spatial_payment_dollars_by_year.png"),
  width = 11,
  height = 7
)

save_descriptive_plot(
  plot_object = top_states_plot,
  output_path = file.path(figure_output_dir, "1_1_1_top_states_by_payment_dollars.png"),
  width = 11,
  height = 8
)

message("Finished descriptive plotting stage.")

# Clear workspace
rm(list = ls(all.names = TRUE))
gc()
