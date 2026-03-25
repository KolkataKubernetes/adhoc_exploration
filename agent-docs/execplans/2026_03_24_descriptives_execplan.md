# Build Descriptive Visualization Stage for Ad Hoc Farm Payments

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document must be maintained in accordance with `agent-docs/PLANS.md` from the repository root.

## ExecPlan Status

Status: Execution (In Progress)  
Owner: Codex  
Created: 2026-03-24  
Last Updated: 2026-03-25  
Related Project: `adhoc_exploration` descriptives workstream

## Revision History

| Date | Change | Author |
|-----|------|------|
| 2026-03-25 | Initial ExecPlan drafted from `agent-docs/agent_context/2026_03_24_descriptives.md`, repository inspection, and live profiling of the staged categorized payment dataset | Codex |
| 2026-03-25 | Execution started; added the shared descriptives helper plus the two numbered descriptives scripts under `1_code/1_1_descriptives/` | Codex |
| 2026-03-25 | Ran the summary script, confirmed the internal total checks passed, and re-ran with elevated permission so the summary `.rds` and coverage audit `.csv` could be written to the external processed-data root | Codex |
| 2026-03-25 | Ran the plotting script, fixed the `map_data()` namespace error, removed facet-class warnings in the yearly spatial plots, and generated the full figure set under `3_outputs/3_1_descriptives/` | Codex |
| 2026-03-25 | Validated the saved summary artifact against the source categorized dataset, recorded the observed spatial coverage counts, and left the execplan open pending user review rather than closing it | Codex |
| 2026-03-25 | Revised the spatial output contract at user request: removed the program-level spatial figure, collapsed the count and dollar heatmaps across all years, regenerated the summary artifact, and removed the obsolete PNG from `3_outputs/3_1_descriptives/` | Codex |
| 2026-03-25 | Replaced the tractless lat/long heatmaps with tract-based `sf` choropleths using the local TIGER tract ZIP files in `0_inputs/census_tracts`, and rewired the summary artifact to aggregate by `census_tract` instead of map bins | Codex |
| 2026-03-25 | At user request, removed the program-level bar-chart figures, reordered the state ranking figure within each year, and revised the tract-map plotting code so unpopulated areas render grey with a more legible colorbar layout | Codex |

## Quick Summary

### Goal

Build a reproducible descriptives stage that converts the staged payment-level file into a small set of audit-friendly summaries and publication-ready figures covering program composition, payee composition, and spatial concentration. After this change, a user should be able to run the descriptives stage and regenerate the same figures without manual filtering in RStudio.

### Deliverable

The repository will contain a numbered descriptives stage under `1_code/1_1_descriptives/`, a processed summary artifact for figure inputs, a coverage-audit CSV, and a repository-local figure folder under `3_outputs/` containing the requested descriptive visuals.

### Success Criteria

- The stage runner discovers and executes new descriptives scripts in numeric order with `/usr/local/bin/Rscript 1_code/run_refactor_pipeline.R --stage descriptives`.
- A processed summary artifact is written without overwriting the existing categorized input file.
- The figure set includes stacked bars for payment counts and payment dollars by program description and payee type, plus one all-years spatial heatmap for payment counts and one all-years spatial heatmap for payment dollars.
- The spatial summaries document that they are based only on rows with non-missing latitude and longitude, and the audit artifact reports the excluded share.
- At least one direct validation confirms that grouped totals in the summary artifact match grouped totals recomputed from `adhoc_payments_geocoded_payee_categorized.rds`.

### Key Files

- `agent-docs/execplans/2026_03_24_descriptives_execplan.md`
- `agent-docs/agent_context/2026_03_24_descriptives.md`
- `agent-docs/0_0_code_format.R`
- `1_code/run_refactor_pipeline.R`
- `1_code/1_1_descriptives/shared_descriptives_helpers.R` (new)
- `1_code/1_1_descriptives/1_1_0_prepare_descriptive_summaries.R` (new)
- `1_code/1_1_descriptives/1_1_1_plot_descriptive_figures.R` (new)
- `2_processed_data/processed_root.txt`
- `3_outputs/3_1_descriptives/` (new)

## Purpose / Big Picture

The project currently stops after ingest, geocoding, and payee categorization. That means there is no reproducible path from the staged payment file to the descriptive graphics needed for memos, slides, or exploratory review. This ExecPlan adds that missing stage. When it is complete, a researcher should be able to run the descriptives stage once and obtain a stable, documented figure set that answers three first-order questions: which program descriptions dominate the data, which payee types dominate the data, and where payments are concentrated geographically.

The visible proof of success will be a new summary `.rds`, a coverage audit `.csv`, and a figure folder in `3_outputs/3_1_descriptives/` populated with named `.png` files. The code should emit `message()` progress updates at each major step so terminal execution is traceable.

## Progress

- [x] (2026-03-25 04:46Z) Reviewed `AGENTS.md`, `agent-docs/PLANS.md`, the new descriptives context note, the current README, and the stage runner.
- [x] (2026-03-25 04:46Z) Confirmed that `1_code/1_1_descriptives/` exists but is currently empty, so the next numbered descriptives scripts can start at `1_1_0_*`.
- [x] (2026-03-25 04:46Z) Profiled the staged input `adhoc_payments_geocoded_payee_categorized.rds` and confirmed the current input contract: `2,924,968` rows, `34` columns, payment dates from `2018-09-10` through `2020-12-31`, a usable dollar field `disbursement_amount`, program descriptors in `accounting_program_description`, payee categories in `payee_type`, and point coordinates in `address_latitude` and `address_longitude`.
- [x] (2026-03-25 04:46Z) Confirmed that `sf`, `ggplot2`, `dplyr`, `maps`, `patchwork`, `readr`, and `lubridate` are installed locally, so the plan does not require new package installation or downloaded shapefiles.
- [x] (2026-03-25 04:46Z) Drafted the initial ExecPlan with concrete deliverables, file names, and validation steps.
- [x] (2026-03-25 05:05Z) Added `1_code/1_1_descriptives/shared_descriptives_helpers.R`, `1_code/1_1_descriptives/1_1_0_prepare_descriptive_summaries.R`, and `1_code/1_1_descriptives/1_1_1_plot_descriptive_figures.R`.
- [x] (2026-03-25 05:10Z) Confirmed the stage runner discovers the new descriptives scripts in the intended numeric order with `/usr/local/bin/Rscript 1_code/run_refactor_pipeline.R --stage descriptives --dry-run`.
- [x] (2026-03-25 05:15Z) Ran `1_1_0_prepare_descriptive_summaries.R`, confirmed the internal summary-total checks passed, and observed that writing to the Box-backed processed-data root required elevated filesystem permission.
- [x] (2026-03-25 05:20Z) Re-ran the summary script with elevated write permission and wrote `adhoc_payments_descriptive_summaries.rds` plus `adhoc_payments_descriptive_coverage_audit.csv`.
- [x] (2026-03-25 05:25Z) Ran `1_1_1_plot_descriptive_figures.R`, fixed the `ggplot2::map_data()` namespace error, reran the plotting stage, and saved all eight planned `.png` artifacts under `3_outputs/3_1_descriptives/`.
- [x] (2026-03-25 05:30Z) Validated the saved summary artifact against the source categorized dataset: `program_counts_match = TRUE`, `payee_amounts_match = TRUE`, and the grouped count total remained `2,924,968`.
- [x] (2026-03-25 05:30Z) Confirmed the spatial audit counts are coherent: `2,433,919` rows are usable for spatial plots, `491,046` rows are missing coordinates, and only `3` rows fall outside the plotting bounds.
- [x] (2026-03-25 05:45Z) Revised the spatial design at user request so there is no multi-map program spatial figure and the count and dollar heatmaps now aggregate all years into one map each.
- [x] (2026-03-25 05:50Z) Rebuilt the summary artifact with `overall_spatial_count_bins` and `overall_spatial_amount_bins`, regenerated the figure set, and removed `1_1_1_spatial_payment_dollars_by_program.png` from `3_outputs/3_1_descriptives/`.
- [x] (2026-03-25 06:20Z) Confirmed the local tract geometry files are present under the external input root in `0_inputs/census_tracts/` and that `GEOID10` is the correct tract join key.
- [x] (2026-03-25 06:30Z) Replaced the lat/long-based spatial summaries with `overall_tract_count_summary` and `overall_tract_amount_summary`, keyed on the 11-digit `census_tract` identifier.
- [x] (2026-03-25 06:40Z) Rebuilt the spatial figures as tract-based `sf` choropleths for continental U.S. tracts and refreshed the output images in `3_outputs/3_1_descriptives/`.
- [x] (2026-03-25 06:50Z) Removed `1_1_1_payment_counts_by_program.png` and `1_1_1_payment_dollars_by_program.png` from the output inventory and from the figure-generation script at the user's request.
- [x] (2026-03-25 06:55Z) Refreshed `1_1_1_top_states_by_payment_dollars.png` so states are ordered by payment dollars within each year-specific facet.
- [ ] Re-run the tract-based spatial figure outputs after the latest legend and background-geometry changes and confirm the refreshed PNGs render as intended.
- [ ] Review the generated figures and decide whether any figure scope or styling changes are needed before closure.
- [ ] Update the README in accordance with `agent-docs/README_update_instructset.md` only after the user explicitly approves closing this execplan.

## Surprises & Discoveries

- Observation: The staged categorized file already contains everything needed for the requested descriptive graphics, so no new upstream data construction is required.
  Evidence: The live input includes `disbursement_amount`, `payment_date`, `accounting_program_description`, `payee_type`, `state_abbreviation`, `address_latitude`, and `address_longitude`.

- Observation: The data span three payment years even though `accounting_program_year` currently takes only two values.
  Evidence: `payment_date` currently ranges from `2018-09-10` to `2020-12-31`, while `accounting_program_year` counts are `2018 = 1,034,222` and `2019 = 1,890,746`.

- Observation: Spatial figures cannot represent the full sample because a non-trivial share of rows lack coordinates.
  Evidence: `491,046` rows currently have missing latitude or longitude. The current missing-coordinate share is approximately `15.7%` for 2018 payments, `17.2%` for 2019 payments, and `17.0%` for 2020 payments.

- Observation: The raw program-description field is already compact enough to plot directly without inventing a new researcher-defined grouping.
  Evidence: The current file has seven populated values in `accounting_program_description`, led by `TMP/MFP 2019 NON SPECIALTY CROPS` (`1,717,110` rows) and `MARKET FACILITATION PROGRAM - CROPS` (`967,533` rows).

- Observation: The default `Rscript` on the current PATH is broken because it resolves to an Anaconda build with a missing dynamic library.
  Evidence: A local check failed with `Library not loaded: @rpath/libreadline.6.2.dylib`; `/usr/local/bin/Rscript` ran successfully and should be used in plan commands.

- Observation: The summary script logic worked on the first pass, but saving the processed summary artifacts to the external Box-backed processed-data root required elevated filesystem permission.
  Evidence: The initial run failed at `saveRDS()` with `Operation not permitted` for `adhoc_payments_descriptive_summaries.rds`; rerunning the same script with elevated permission succeeded on 2026-03-25.

- Observation: Only a negligible number of geocoded rows fell outside the plotting domain used for the spatial figures.
  Evidence: The saved `coverage_audit` reports `3` rows outside the plotting bounds, compared with `491,046` rows missing coordinates and `2,433,919` rows usable for spatial plots.

- Observation: The first plotting pass failed because the state-outline helper was called from the wrong namespace, and the yearly spatial figures initially emitted avoidable facet warnings.
  Evidence: The first run stopped with `Error: 'map_data' is not an exported object from 'namespace:maps'`. After switching to `ggplot2::map_data()` and aligning the `payment_year` types used in the spatial plotting layers, the plotting stage completed without those warnings.

- Observation: The user preferred one map per image rather than faceted spatial outputs, and the all-years version is simpler because the spatial summaries are already strongly dominated by aggregate concentration rather than fine year-to-year visual contrast.
  Evidence: On 2026-03-25, the user explicitly requested removing `1_1_1_spatial_payment_dollars_by_program.png` and changing the count and dollar spatial figures so they are summed across all years instead of broken out by year.

- Observation: The local external input root already contains a full set of 2010 Census tract TIGER ZIP files, so switching from point heatmaps to tract polygons did not require any networked geometry download.
  Evidence: `0_inputs/census_tracts/` now contains 51 tract ZIP files such as `tl_2010_17_tract10.zip`, and a local `sf::st_read()` check confirmed the tract key field is `GEOID10`.

- Observation: The current payment file’s tract coverage aligns exactly with the matched-geocode share used by the earlier spatial summaries.
  Evidence: The refreshed coverage audit reports `2,433,922` rows with non-missing `census_tract` and `491,046` rows missing `census_tract`, matching the prior geocoded-versus-unmatched split.

- Observation: The tract choropleth rendering path is materially heavier than the earlier point-bin maps, especially when the plot attempts to display all background tracts as individual polygons.
  Evidence: On 2026-03-25, repeated full reruns of `1_1_1_plot_descriptive_figures.R` completed the lighter non-spatial work quickly but did not finish the revised tract-map rerender within multiple long polling windows, which led to a lighter background-geometry revision.

## Decision Log

- Decision: Use `adhoc_payments_geocoded_payee_categorized.rds` as the sole staged input for the descriptives stage.
  Rationale: The file already contains payee categories, program descriptions, amounts, dates, states, and coordinates, so descriptives can remain downstream of ingest and categorization without reopening upstream scripts.
  Date/Author: 2026-03-25 / Codex

- Decision: Split the descriptives work into one summary-building script and one plotting script, plus a `shared_*.R` helper file.
  Rationale: This keeps the heavy grouping logic separate from the plotting logic, makes validation easier, and matches the stage runner rule that excludes `shared_*.R` helper files from direct execution.
  Date/Author: 2026-03-25 / Codex

- Decision: Use `payment_year <- lubridate::year(payment_date)` for year panels rather than `accounting_program_year`.
  Rationale: The user asked for visuals “across years,” and the observed payments currently span 2018, 2019, and 2020. `payment_date` captures those observed payment years directly.
  Date/Author: 2026-03-25 / Codex

- Decision: Preserve `accounting_program_description` as plotted program labels rather than collapsing them into new custom groups.
  Rationale: The current field has only seven populated values. Plotting the existing values avoids introducing a new program construction that the user did not request.
  Date/Author: 2026-03-25 / Codex

- Decision: Use fixed latitude-longitude bins for spatial figures instead of plotting millions of points or relying on downloaded boundary data.
  Rationale: Binned spatial summaries are transparent, reproducible, and do not require network calls. They also scale cleanly to the current 2.9 million-row input.
  Date/Author: 2026-03-25 / Codex

- Decision: Use the `theme_im()` styling function from the context note as the shared plot theme for the descriptives stage.
  Rationale: The user explicitly supplied that theme to standardize formatting across descriptive outputs.
  Date/Author: 2026-03-25 / Codex

- Decision: Write descriptives figures to a new repository-local folder `3_outputs/3_1_descriptives/` and write the grouped summary artifact to the external processed-data root.
  Rationale: `3_outputs/` is the designated location for presentation-ready artifacts, while grouped intermediate objects belong in processed data for reuse and validation.
  Date/Author: 2026-03-25 / Codex

- Decision: Use explicit plotting bounds of longitude `[-180, -60]` and latitude `[15, 75]` for spatial figures, and record any excluded rows in the coverage audit.
  Rationale: The map figures need stable U.S.-oriented bounds to remain readable, but any exclusion created by those bounds should be visible in the audit rather than silently ignored.
  Date/Author: 2026-03-25 / Codex

- Decision: Remove the program-level spatial figure and collapse the remaining spatial count and dollar maps across all years.
  Rationale: The user explicitly asked for one map per image and preferred aggregate spatial heatmaps over faceted panels.
  Date/Author: 2026-03-25 / Codex

- Decision: Replace the lat/long-bin heatmaps with tract-based `sf` choropleths joined on `census_tract = GEOID10`.
  Rationale: The user flagged visible map artifacts outside the continental U.S. and requested that the spatial displays use the tract identifier directly rather than row-level coordinates.
  Date/Author: 2026-03-25 / Codex

- Decision: Restrict the tract choropleths to continental U.S. tract geometries by excluding Alaska, Hawaii, and territories from the plotted tract layer.
  Rationale: The user explicitly referred to the continental U.S. map frame, and this filter keeps the spatial display focused on that geography while leaving the exclusion legible in the caption.
  Date/Author: 2026-03-25 / Codex

- Decision: Remove the program-level count and dollar bar charts from the output set and keep only payee-type bars, the two spatial figures, and the top-state figure.
  Rationale: The user explicitly requested deleting the program-delineated bar charts.
  Date/Author: 2026-03-25 / Codex

## Outcomes & Retrospective

Implementation is complete, and the descriptives stage now runs end-to-end. The repository now contains a shared descriptives helper, a summary-building script, and a plotting script under `1_code/1_1_descriptives/`. Running the revised stage produced `adhoc_payments_descriptive_summaries.rds`, `adhoc_payments_descriptive_coverage_audit.csv`, and seven figure files in `3_outputs/3_1_descriptives/`, with the spatial figures now drawn from tract polygons instead of lat/long bins.

The summary artifact passed both internal and external validation. The internal script checks confirmed that non-spatial grouped counts and dollar totals match the source categorized dataset before any output is written. A separate post-run validation confirmed `program_counts_match = TRUE` and `payee_amounts_match = TRUE` when the saved summary artifact was compared directly against grouped recomputations from `adhoc_payments_geocoded_payee_categorized.rds`.

The main remaining tasks are review and closure decisions, not new implementation. The README has not been updated yet because project instructions require that update when the execplan is explicitly approved for closure, and this plan remains open pending user review of the figures.

## Context and Orientation

The existing pipeline currently contains three ingest-stage scripts under `1_code/1_0_ingest/` and a stage runner at `1_code/run_refactor_pipeline.R`. The runner already recognizes a `descriptives` stage by discovering `.R` files under `1_code/1_1_descriptives/`, but that folder is empty. No runner changes are needed if new scripts are added with the correct numeric prefixes.

The staged input for this ExecPlan is the categorized payment file referenced through `2_processed_data/processed_root.txt`. The current artifact name is `adhoc_payments_geocoded_payee_categorized.rds`. It preserves one row per payment and currently contains the fields needed for descriptives:

- `disbursement_amount`: the payment amount to use for dollar-volume figures.
- `payment_date`: the observed payment date from which payment year should be derived.
- `accounting_program_description`: the raw program-description label to use for program composition plots.
- `payee_type`: the broad payee-category label added in the prior stage.
- `state_abbreviation`: a complete geographic grouping field that can support non-spatial descriptive checks.
- `address_latitude` and `address_longitude`: coordinates for spatial binning; rows missing either coordinate must be excluded from spatial plots and counted in the coverage audit.

The phrase “spatial heatmap” in this plan means a two-dimensional latitude-longitude bin summary shown with `ggplot2::geom_tile()` or an equivalent binned geometry, optionally layered with simple state outlines available from installed packages. It does not mean a downloaded web basemap, an interactive map, or a new geocoding pass.

This plan assumes the user’s supplied `theme_im()` function is the formatting standard for the stage. That function should live in a shared descriptives helper so every plot uses the same legend position, grid treatment, and title styling.

## Plan of Work

Create `1_code/1_1_descriptives/shared_descriptives_helpers.R` first. This file should contain the small utility functions that already appear in the ingest scripts and should be reused here rather than re-invented in multiple files. At minimum, it should define repository-root discovery, pointer-file reading that strips single quotes, directory creation, output guards for non-destructive writes, and the shared `theme_im()` plotting theme taken from the user’s context note. Any helper copied or adapted from an ingest script must include an origin comment naming the source file, consistent with project instructions.

Create `1_code/1_1_descriptives/1_1_0_prepare_descriptive_summaries.R` next. This script should read `adhoc_payments_geocoded_payee_categorized.rds`, derive `payment_year`, flag rows with usable tract identifiers, and validate that the required columns exist before any grouping work begins. It should then construct a named list of summary tables that are narrow, figure-ready, and directly auditable. The minimum list should include `program_counts`, `program_amounts`, `payee_counts`, `payee_amounts`, `overall_tract_count_summary`, `overall_tract_amount_summary`, and `coverage_audit`. The `coverage_audit` table should report total rows, rows with tract IDs, rows missing tract IDs, and the associated shares by `payment_year`. The script should write the summary list to `adhoc_payments_descriptive_summaries.rds` in the external processed-data root and write `adhoc_payments_descriptive_coverage_audit.csv` alongside it. Both writes should be guarded so the stage remains non-destructive unless an explicit overwrite flag is passed.

For the spatial summaries, aggregate directly to the payment file’s `census_tract` identifier and then join those tract-level totals to the locally stored 2010 Census tract TIGER ZIP files under `0_inputs/census_tracts/`. The plotting script should use `sf` to draw tract polygons and should restrict the displayed geometry to continental U.S. tracts.

Create `1_code/1_1_descriptives/1_1_1_plot_descriptive_figures.R` after the summary script. This script should read `adhoc_payments_descriptive_summaries.rds`, create `3_outputs/3_1_descriptives/` if needed, and write the core figure set as `.png` files. The first four figures should be stacked bar charts: payment counts by `payment_year` and `accounting_program_description`, payment dollars by the same grouping, payment counts by `payment_year` and `payee_type`, and payment dollars by the same grouping. The fifth and sixth figures should be all-years tract-based choropleths, one for payment counts and one for payment dollars. Add one additional exploratory figure using complete, non-spatial data, ideally a state-level payment-dollar ranking by `payment_year`, because that gives the user one extra view of geographic concentration that is not affected by tract-map exclusions.

All scripts should emit `message()` updates at major milestones such as reading the input, finishing each summary block, and saving each output. The plotting script should annotate or caption spatial figures to state that rows with missing coordinates are excluded. If the current row counts or shares change when the input data are refreshed later, the code should recompute from source data rather than hardcoding the current counts discovered during planning.

## Concrete Steps

Work from the repository root: `/Users/indermajumdar/Research/adhoc_exploration`.

Use the local R installation that is known to work in this repository:

    /usr/local/bin/Rscript 1_code/run_refactor_pipeline.R --stage descriptives --dry-run

Expected result: the runner lists `1_code/1_1_descriptives/1_1_0_prepare_descriptive_summaries.R` and `1_code/1_1_descriptives/1_1_1_plot_descriptive_figures.R` in numeric order once they are created.

Run the stage:

    /usr/local/bin/Rscript 1_code/run_refactor_pipeline.R --stage descriptives

Expected result: terminal `message()` output reports loading the categorized input, building grouped summaries, writing `adhoc_payments_descriptive_summaries.rds`, writing `adhoc_payments_descriptive_coverage_audit.csv`, and saving the figure files under `3_outputs/3_1_descriptives/`.

For a refresh after artifacts already exist:

    /usr/local/bin/Rscript 1_code/1_1_descriptives/1_1_0_prepare_descriptive_summaries.R --overwrite
    /usr/local/bin/Rscript 1_code/1_1_descriptives/1_1_1_plot_descriptive_figures.R --overwrite

Expected result: existing descriptive artifacts are replaced intentionally, with the overwrite behavior confirmed in terminal messages.

## Validation and Acceptance

Validation must check both the grouped data products and the final figure artifacts.

First, confirm that `adhoc_payments_descriptive_summaries.rds` and `adhoc_payments_descriptive_coverage_audit.csv` exist in the processed-data root and that the figure folder `3_outputs/3_1_descriptives/` contains the expected `.png` files. The output inventory should include the four stacked bar charts, the two all-years spatial heatmaps, and the one additional exploratory state-level figure described in `Plan of Work`.

Second, directly verify one count-based and one dollar-based summary against the source dataset. For example, recompute grouped totals from `adhoc_payments_geocoded_payee_categorized.rds` and confirm that they match `program_counts` and `payee_amounts` from the summary artifact. A correct implementation should preserve the full row total of the input file in the non-spatial summaries and should use only rows with non-missing coordinates in the spatial summaries.

Third, inspect the `coverage_audit` table and confirm that the missing-coordinate share reported there matches a fresh recomputation from the input file. The exact percentages may change if the upstream data are refreshed, but the audit and the recomputed check must agree.

Fourth, open the generated figures and verify that titles, legends, captions, and tract-map extent match the intended variables. In particular, the spatial choropleths must clearly indicate that rows with missing tract IDs are excluded and that the plotted geometry is restricted to continental U.S. tracts.

## Completion Checklist

- [x] `shared_descriptives_helpers.R` exists and documents helper provenance where helpers are adapted from existing scripts.
- [x] `1_1_0_prepare_descriptive_summaries.R` runs successfully and writes the summary `.rds` plus coverage audit `.csv`.
- [x] `1_1_1_plot_descriptive_figures.R` runs successfully and writes the full figure set to `3_outputs/3_1_descriptives/`.
- [x] Non-spatial totals in the summary artifact match grouped totals recomputed from the source file.
- [x] Spatial figures use only rows with non-missing coordinates and disclose that exclusion.
- [ ] The README is updated to document the new descriptives scripts and outputs after the user explicitly approves closing the execplan.

## Idempotence and Recovery

The descriptives stage should be safe to rerun. By default, the scripts should stop rather than overwrite an existing summary artifact, audit CSV, or figure set. An explicit `--overwrite` flag should allow intentional refreshes. This preserves the project’s non-destructive default while still letting the user regenerate outputs after design edits.

If the plotting script fails after the summary script succeeds, recovery should be simple: fix the plotting issue and rerun only `1_1_1_plot_descriptive_figures.R --overwrite`. If the summary script fails before writing outputs, no upstream data should be modified because the input `.rds` is read-only in this stage. If the summary script partially writes outputs, rerun it with `--overwrite` after the fix.

## Artifacts and Notes

Current planning evidence from the live staged input:

    Rows: 2,924,968
    Columns: 34
    payment_date range: 2018-09-10 through 2020-12-31
    Current payee_type counts:
      person = 2,296,645
      farm_ranch = 361,179
      other = 133,920
      person_trust = 117,758
      financial_institution = 8,592
      government = 6,874
    Current geocode status counts:
      matched = 2,433,922
      no_match = 490,736
      invalid_address = 310

These values are planning-time diagnostics, not constants to hardcode into the scripts. They exist here so a future contributor can sanity-check whether later outputs look directionally plausible.

## Data Contracts, Inputs, and Dependencies

The primary dependency is the staged input file `adhoc_payments_geocoded_payee_categorized.rds`, located through `2_processed_data/processed_root.txt`. The summary-building script must require the following columns: `payment_date`, `disbursement_amount`, `accounting_program_description`, `payee_type`, `state_abbreviation`, `address_latitude`, and `address_longitude`. The script must stop with a clear error if any required column is missing. The input contract is one row per payment. The script must not collapse or deduplicate before the explicit grouped summaries are created.

The descriptives helper file depends on base R plus packages already observed locally: `dplyr`, `ggplot2`, `readr`, `lubridate`, `scales`, `sf`, `maps`, and `patchwork`. `sf` may be used for simple coordinate handling if helpful, but the plan does not require any networked shapefile download or web map. The plotting script must be able to complete using only local packages and local data.

`1_code/1_1_descriptives/1_1_0_prepare_descriptive_summaries.R` consumes the staged input `.rds` and writes:

- `adhoc_payments_descriptive_summaries.rds` to the processed-data root.
- `adhoc_payments_descriptive_coverage_audit.csv` to the processed-data root.

The summary `.rds` should contain named tibbles with one row per plotted group or spatial bin. Non-spatial summary tables must preserve total row counts and total disbursement sums when aggregated across groups. Spatial summary tables must include only rows with non-missing coordinates and must expose the grouping variables used for facets, bins, and fill values.

`1_code/1_1_descriptives/1_1_1_plot_descriptive_figures.R` consumes `adhoc_payments_descriptive_summaries.rds` and writes `.png` files to `3_outputs/3_1_descriptives/`. The plotting contract is that the filenames are stable, the captions clearly identify any spatial exclusions, and the figures can be regenerated without manual data edits.

Change Note: Initial planning draft created after the user supplied `agent-docs/agent_context/2026_03_24_descriptives.md`. The change records the actual staged-data contract and local package availability so implementation can begin without redoing the discovery pass.
