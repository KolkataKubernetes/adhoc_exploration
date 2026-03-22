# Build Single-Address Geocoding Pipeline for Ad Hoc MFP Data

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document must be maintained in accordance with `agent-docs/PLANS.md` from the repository root.

---

## ExecPlan Status

Status: Execution (In Progress)  
Owner: Codex  
Created: 2026-03-22  
Last Updated: 2026-03-22  
Related Project: `adhoc_exploration` ingest and geolocation workstream

Optional Metadata:  
Priority: High  
Estimated Effort: 1 to 2 working sessions  
Dependencies: `0_inputs/input_root.txt`, `2_processed_data/processed_root.txt`, `1_code/1_0_ingest/1_0_0_ingest_adhoc.R`

---

## Revision History

| Date | Change | Author |
|-----|------|------|
| 2026-03-22 | Initial ExecPlan drafted from repository context, source workbook inspection, attached SBA example script, and official Census geocoder documentation | Codex |
| 2026-03-22 | Scope narrowed to one address per row; lender geocoding removed; `dplyr`-first implementation preference recorded | Codex |
| 2026-03-22 | Execution started; ingest script rewritten; geocoding script added; workbook row-count assumptions corrected to reflect all four sheets | Codex |

---

## Quick Summary

**Goal**

Create a reproducible ingest-plus-geocoding pipeline for the ad hoc MFP workbook so each payment row can be augmented with latitude, longitude, and an 11-digit census tract for the single address recorded on that row.

**Deliverable**

When complete, the ingest stage will write an analysis-ready intermediate `.rds` with cleaned address fields, and a second ingest-stage script will geocode the unique row-level addresses through the U.S. Census batch geocoder and write a geocoded `.rds` to the processed-data root.

**Success Criteria**

- `1_code/1_0_ingest/1_0_0_ingest_adhoc.R` runs without error, keeps a `dplyr`-first transformation style, and writes a typed, address-prepared intermediate dataset to the processed-data root using relative pathing.
- A new geocoding script under `1_code/1_0_ingest/` runs without error, writes a geocoded `.rds`, and logs address-match counts plus an 11-digit tract-length validation.
- The geocoded output preserves one row per raw payment row and appends geocode fields without silently dropping records.
- The geocoded output preserves one row per raw payment row and appends only the geographic fields supported by the single address in the source data.

**Key Files**

- `agent-docs/execplans/2026_03_22_mfp_geocode_execplan.md`
- `agent-docs/agent_context/2026_03_22_geolocate/2026_03_22_geolocate.md`
- `agent-docs/agent_context/2026_03_22_geolocate/SBA_7A_geocode.R`
- `agent-docs/0_0_code_format.R`
- `1_code/1_0_ingest/1_0_0_ingest_adhoc.R`
- `1_code/1_0_ingest/1_0_1_geocode_adhoc.R` (new)
- `1_code/run_refactor_pipeline.R`
- `0_inputs/input_root.txt`
- `2_processed_data/processed_root.txt`

---

## Purpose / Big Picture

After this change, a user should be able to run the ingest stage and produce an MFP dataset that includes geospatial fields for the single address recorded on each payment row, suitable for tract-level descriptive analysis, merging, and downstream aggregation. The visible proof of success will be a new processed `.rds` containing the original payment rows plus latitude, longitude, and census tract fields, along with terminal messages that report how many addresses matched successfully.

---

## Progress

- [x] (2026-03-22 18:40Z) Reviewed `AGENTS.md`, `agent-docs/PLANS.md`, `agent-docs/0_0_code_format.R`, the attached geolocation writeup, and the SBA geocoding example script.
- [x] (2026-03-22 18:55Z) Confirmed the raw workbook schema from `CAS.C2602520.NA.PMTS.FINAL.DT26054.xlsx`: 15 visible columns and four sheets; the visible address fields are `Address Information Line`, `Delivery Address Line`, `City Name`, `State Abbreviation`, and `Zip Code`.
- [x] (2026-03-22 19:05Z) Confirmed that the raw workbook contains one usable address block per row and no lender-address fields.
- [x] (2026-03-22 19:10Z) Verified official Census batch geocoder behavior needed for this plan: the batch `geographies/addressbatch` endpoint returns state, county, tract, and block codes, and the documented batch contract does not require an API key.
- [x] (2026-03-22 19:20Z) User clarified that lender geocoding is out of scope for this project and that the ingest rewrite should preserve `dplyr` syntax for readability.
- [x] (2026-03-22 20:55Z) Rewrote `1_code/1_0_ingest/1_0_0_ingest_adhoc.R` to combine all four workbook sheets, use relative path pointers, preserve `dplyr` syntax, and write `adhoc_payments_ingested.rds`.
- [x] (2026-03-22 21:10Z) Added `1_code/1_0_ingest/1_0_1_geocode_adhoc.R` with batch Census geocoding, preflight mode, cache reuse, and a simple audit-summary artifact.
- [ ] (2026-03-22 21:20Z) Run the full geocoding job and validate the final output artifacts (completed: ingest artifact and live preflight validated; remaining: finish all Census batches, save final `.rds`, inspect audit summary).
- [ ] Update the repository README mechanically after the execplan is executed and closed.

---

## Surprises & Discoveries

- Observation: The current `1_code/1_0_ingest/1_0_0_ingest_adhoc.R` is a stub and cannot run as written. It ends with `|> data_typecast`, which is undefined in the file, and it hardcodes an absolute Box path instead of using the repo pathing conventions.
  Evidence: Repository inspection on 2026-03-22.

- Observation: `Address Information Line` is not a reliable street-address field. In the raw workbook it is missing for 657,444 of 713,934 rows, and sampled non-missing values often contain names or care-of text such as `JAMES R CRISWELL`, `DUTCH FARMS`, and `% PAULA I STEELE`.
  Evidence: Local workbook inspection on 2026-03-22.

- Observation: `Delivery Address Line` is populated for all sampled rows and is the natural primary mailing-street candidate for geocoding.
  Evidence: In the raw workbook, `missing_delivery = 0` during local inspection on 2026-03-22.

- Observation: The shell-default `Rscript` in this environment points to an Anaconda-linked binary that fails before execution because `libreadline.6.2.dylib` is missing.
  Evidence: `which Rscript` returned `/Users/indermajumdar/opt/anaconda3/bin/Rscript`; `/usr/local/bin/Rscript` worked for workbook inspection.

- Observation: The attached SBA geocoding script is useful as a batching template, but it names tract output `borrower_census_tract` even in shared parsing logic and assumes both borrower and bank address fields already exist in the input dataset.
  Evidence: Inspection of `agent-docs/agent_context/2026_03_22_geolocate/SBA_7A_geocode.R`.

- Observation: The workbook-wide row count is much larger than the earlier first-sheet-only inspection suggested. The correct combined input has 2,924,968 rows across four sheets and 639,196 unique geocode-ready addresses after normalization.
  Evidence: Execution of `1_code/1_0_ingest/1_0_0_ingest_adhoc.R` on 2026-03-22.

- Observation: Writing outputs to the external processed-data folder requires elevated filesystem permissions in this environment even though reading the external input workbook does not.
  Evidence: Initial ingest save attempt failed with `Operation not permitted`; rerunning with elevated permissions succeeded on 2026-03-22.

- Observation: A live preflight against the Census batch geocoder matched 8 of the first 10 unique addresses and confirmed the request/response contract.
  Evidence: Execution of `1_code/1_0_ingest/1_0_1_geocode_adhoc.R --preflight-only` on 2026-03-22 wrote `adhoc_payments_geocode_preflight.csv`.

---

## Decision Log

- Decision: Scope this plan to the single address observed on each row and remove lender geocoding from the deliverable.
  Rationale: The user clarified on 2026-03-22 that lender addresses were a holdover from another project and do not exist in this dataset.
  Date/Author: 2026-03-22 / Codex

- Decision: Keep the ingest rewrite in `dplyr` syntax rather than switching to base-R transformation code.
  Rationale: The user explicitly prefers `dplyr` for readability, and that preference is consistent with the repository guidance favoring transparent, audit-friendly code.
  Date/Author: 2026-03-22 / Codex

- Decision: Use `Delivery Address Line` as the primary street field for geocoding, and retain `Address Information Line` as an auxiliary field for auditability rather than concatenating it blindly into the street string.
  Rationale: Sampled non-missing values in `Address Information Line` frequently contain names or care-of text rather than street addresses, so unconditional concatenation would likely reduce match quality and produce incorrect geocodes.
  Date/Author: 2026-03-22 / Codex

- Decision: Use the Census batch endpoint with return type `geographies` so the geocoder supplies both coordinates and tract components in one batch call.
  Rationale: The official Census documentation states that `geographies/addressbatch` returns state, county, tract, and block code in batch mode, which is sufficient to construct the requested 11-digit census tract while also capturing coordinates.
  Date/Author: 2026-03-22 / Codex

- Decision: Use `/usr/local/bin/Rscript` in validation examples until the shell default `Rscript` issue is resolved.
  Rationale: The current shell default is broken in this environment and would make the validation section misleading for a novice reader.
  Date/Author: 2026-03-22 / Codex

- Decision: Combine all four workbook sheets in the ingest script before any typing or geocoding preparation.
  Rationale: The workbook is partitioned across four sheets representing different year/state ranges, and using only the first sheet would silently omit most of the sample.
  Date/Author: 2026-03-22 / Codex

- Decision: Keep the geocoding sidecar output simple by writing a one-row audit summary plus an optional preflight CSV, rather than the more elaborate SBA-style unmatched and failure artifact set.
  Rationale: The user clarified that the audit requirement is mainly to document how many matches and non-matches the Census procedure produced for this single-address dataset.
  Date/Author: 2026-03-22 / Codex

---

## Outcomes & Retrospective

**Summary of Outcome**

Execution is in progress. The ingest script has been rewritten and validated through artifact creation, the geocoding script has been added and validated through a live preflight, and the full Census batch run is underway.

**Expected vs. Actual Result**

- Expected outcome: A self-contained execution plan that a novice could follow to implement the geocoding pipeline.
- Actual outcome: A self-contained execution plan plus partial execution progress, including a completed ingest artifact and a validated live preflight geocode.
- Difference (if any): The combined row count turned out to require all four workbook sheets, so the validation counts are now based on the full workbook rather than the first-sheet inspection used in the earliest draft.

**Key Challenges Encountered**

- Challenge: The attached example script carried over a lender-or-bank structure that does not apply to this dataset.
  Resolution: Remove that branch from the plan after the user clarified that each row has only one address.

- Challenge: The current ingest script is not operational and cannot be treated as an implementation baseline.
  Resolution: The plan treats the ingest script as a rewrite within the same file rather than a small patch.

**Lessons Learned**

- Lesson: The attached SBA script is a process reference, not a drop-in template. The data contract must be rewritten for the MFP workbook before coding begins.

**Follow-up Work**

- Follow-up task: Let the full geocoding job finish, inspect the audit summary and final `.rds`, then update the README mechanically and mark the plan complete.

---

## Context and Orientation

This repository currently contains only one active ingest script, `1_code/1_0_ingest/1_0_0_ingest_adhoc.R`, plus the stage runner `1_code/run_refactor_pipeline.R`. The raw input data are not stored directly in the repository. Instead, `0_inputs/input_root.txt` points to the Box-based raw-data root and `2_processed_data/processed_root.txt` points to the Box-based processed-data root. The specific raw workbook for this task is `CAS.C2602520.NA.PMTS.FINAL.DT26054.xlsx` under the input root.

The raw workbook contains four sheets and 15 visible columns. The columns relevant to geocoding are `Formatted Payee Name`, `Address Information Line`, `Delivery Address Line`, `City Name`, `State Abbreviation`, and `Zip Code`. In this dataset, `Delivery Address Line` appears to hold the actual mailing street or post-office-box string, while `Address Information Line` is often blank and, when present, often contains a name or care-of string rather than a street address. That means the geocoder should use `Delivery Address Line` as the primary street field and keep `Address Information Line` only as auxiliary context.

The term "batch geocoder" in this plan means the U.S. Census API endpoint that accepts a file of addresses rather than one address per request. The official documentation, last updated in February 2026, states that batch files are limited to 10,000 records per submission, require `Unique ID, Street address, City, State, ZIP` formatting for standard addresses, and return state, county, tract, and block code when the `geographies` batch endpoint is used. This matters because the tract is not returned as a single 11-digit string; the output must be constructed from state, county, and tract components and then validated for 11-digit length.

The user clarified on 2026-03-22 that each row has only one relevant address and that lender geocoding is not part of this project. The plan therefore covers only one geocoding branch.

---

## Data Artifact Flow

Raw Inputs  
- `0_inputs/input_root.txt`
- External raw workbook referenced by that pointer: `CAS.C2602520.NA.PMTS.FINAL.DT26054.xlsx`
- `0_inputs/census_apikey.md` should not be required for the Census batch geocoder based on the official documentation, but the file should remain untouched.

Intermediate Artifacts  
- External processed-data artifact written by `1_code/1_0_ingest/1_0_0_ingest_adhoc.R`: `adhoc_payments_ingested.rds`
- Optional audit artifact written by the geocoding script: `adhoc_payments_geocode_unmatched.csv`
- Optional batch-failure artifact written by the geocoding script: `adhoc_payments_geocode_failures.csv`

Final Outputs  
- External processed-data artifact written by `1_code/1_0_ingest/1_0_1_geocode_adhoc.R`: `adhoc_payments_geocoded.rds`

---

## Plan of Work

First, rewrite `1_code/1_0_ingest/1_0_0_ingest_adhoc.R` so it follows `agent-docs/0_0_code_format.R` rather than the current stub. The rewritten script should establish the repository root, read `0_inputs/input_root.txt` and `2_processed_data/processed_root.txt`, load the workbook from the external input root, clean names with `janitor::clean_names()`, perform explicit type casting, and write a reproducible intermediate `.rds` to the external processed-data root. The file should emit `message()` progress updates at each major step and should keep the transformation logic in readable `dplyr` pipelines.

Within that ingest script, construct geocoding-ready features for the single observed row-level address but do not call the Census API. At minimum, add fields for the raw address components, a normalized ZIP5, and a one-line address key built from `delivery_address_line`, `city_name`, `state_abbreviation`, and ZIP5. Preserve `address_information_line` separately for auditability. The ingest script should not create tract or coordinate columns because those are downstream products of the geocoding stage.

Second, add a new script at `1_code/1_0_ingest/1_0_1_geocode_adhoc.R`. This script should read the intermediate `.rds`, validate the required address columns, create a distinct table of unique addresses, split that table into batches of at most 10,000 records, submit each batch to the Census `geographies/addressbatch` endpoint, parse the returned CSV, construct an 11-digit census tract from state, county, and tract pieces, and merge the unique-address results back to the full row-level payment dataset. The batching, retry logic, and preflight pattern may borrow structure from `agent-docs/agent_context/2026_03_22_geolocate/SBA_7A_geocode.R`, but names and contracts must be rewritten for this dataset.

The new geocoding script should write one final `.rds` and should also write small audit artifacts if there are unmatched or failed addresses. At minimum, the final terminal summary should report total row count, address match count, address non-match count, and whether all non-missing tract values have length 11.

Finally, once implementation is complete and the execplan is closed, update the repository README only within the descriptive boundaries allowed by `agent-docs/README_update_instructset.md`. That update should enumerate the new ingest-stage script, the intermediate and final processed-data artifacts, and the change-log entry for the new pipeline components.

---

## Concrete Steps

Run all commands from the repository root: ` /Users/indermajumdar/Research/adhoc_exploration `

1. Inspect the ingest stage before editing.

       /usr/local/bin/Rscript 1_code/run_refactor_pipeline.R --stage ingest --dry-run

   Expected result: the runner lists `1_code/1_0_ingest/1_0_0_ingest_adhoc.R` and, after the new file is added, also lists `1_code/1_0_ingest/1_0_1_geocode_adhoc.R`.

2. Run the rewritten ingest script directly while developing it.

       /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_0_ingest_adhoc.R

   Expected result: terminal `message()` output announces data load, type casting, address feature creation, and a saved intermediate `.rds`.

3. Run a preflight geocoder test once `1_code/1_0_ingest/1_0_1_geocode_adhoc.R` exists.

       /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_1_geocode_adhoc.R --preflight-only

   Expected result: the script submits only a small address sample, writes a small preflight inspection file if that mode is kept, and exits without running the full geocode job.

4. Run the full ingest stage after both scripts are complete.

       /usr/local/bin/Rscript 1_code/run_refactor_pipeline.R --stage ingest

   Expected result: both ingest scripts run in numeric order, the final geocoded `.rds` is written to the processed-data root, and terminal messages report geocode success counts.

---

## Validation and Acceptance

Validation 1: Intermediate artifact creation and schema check.

1. Command:

       /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_0_ingest_adhoc.R

2. Expected behavior:

   The script writes `adhoc_payments_ingested.rds` to the processed-data root and the saved data contain the cleaned address fields needed by the geocoder, including `delivery_address_line`, `city_name`, `state_abbreviation`, a ZIP5 field, and an address key.

3. Why this proves correctness:

   The geocoding script depends on these fields. Before implementation, the file does not exist and the current ingest script does not create a runnable artifact.

Validation 2: Geocoded artifact creation and tract check.

1. Command:

       /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_1_geocode_adhoc.R

2. Expected behavior:

   The script writes `adhoc_payments_geocoded.rds` to the processed-data root, preserves the original row count, appends `address_latitude`, `address_longitude`, and `census_tract` columns for the single row-level address, and prints match totals plus a tract-length validation.

3. Why this proves correctness:

   The requested deliverable is not simply code changes; it is a row-level processed dataset with appended geographic fields and an explicit 11-digit tract check.

Validation 3: Post-run spot check of tract length and row preservation.

1. Command:

       /usr/local/bin/Rscript -e 'processed_root <- trimws(readLines("2_processed_data/processed_root.txt"), which = "both"); processed_root <- gsub("^'\''|'\''$", "", processed_root); x <- readRDS(file.path(processed_root, "adhoc_payments_geocoded.rds")); cat(nrow(x), "\n"); cat(all(nchar(x$census_tract[!is.na(x$census_tract)]) == 11), "\n")'

2. Expected behavior:

   The first printed value matches the raw row count from the workbook, and the second printed value is `TRUE`.

3. Why this proves correctness:

   This directly verifies that the geocoder merge did not drop rows and that the tract-format contract holds for all matched records.

---

## Idempotence and Recovery

The ingest script should be idempotent: rerunning it should recreate the same intermediate `.rds` from the same raw workbook. The geocoding script should also be safe to rerun, but because it makes outbound API requests and writes processed artifacts, it should support either an explicit `--overwrite` flag or a cache-aware append/update mode similar to the attached SBA example. Any unmatched-address or batch-failure CSV should be regenerated from the current run so they remain aligned to the current geocoded output.

If a geocoding batch fails partway through, the script should stop with a clear error message or record the failed batch rows in a dedicated failure file rather than silently writing partial tract values. If the default shell `Rscript` continues to fail in this environment, use `/usr/local/bin/Rscript` for manual recovery and validation commands.

---

## Artifacts and Notes

Key observed raw-workbook facts from planning:

    Raw workbook columns:
    State FSA Code | State FSA Name | County FSA Code | County FSA Name |
    Formatted Payee Name | Address Information Line | Delivery Address Line |
    City Name | State Abbreviation | Zip Code | Disbursement Amount |
    Payment Date | Accounting Program Code | Accounting Program Description |
    Accounting Program Year

    Correct combined workbook row count observed during execution on 2026-03-22:
    2018 AL-WY = 713,934 rows
    2019 AL-MT = 959,486 rows
    2019 NE-WY = 577,473 rows
    2020 AL-WY = 674,075 rows
    total rows = 2,924,968

    Intermediate ingest artifact summary observed on 2026-03-22:
    geocode-ready rows = 2,924,658
    unique geocode-ready addresses = 639,196

Examples showing why `Address Information Line` should not be treated as the street field:

    Address Information Line        Delivery Address Line
    JAMES R CRISWELL               151 COUNTY HIGHWAY 35
    DUTCH FARMS                    7049 COUNTY ROAD 48
    % PAULA I STEELE               PO BOX 274

Relevant official Census batch facts embedded into the plan:

    Standard batch input format:
    Unique ID, Street address, City, State, ZIP

    Batch limit:
    10,000 records per submission

    Batch geographies response:
    includes state, county, tract, and block code

---

## Data Contracts, Inputs, and Dependencies

`1_code/1_0_ingest/1_0_0_ingest_adhoc.R`

- Tooling: base R plus `tidyverse`, `janitor`, `readxl`; use the repository code format from `agent-docs/0_0_code_format.R`.
- Inputs: `0_inputs/input_root.txt`, `2_processed_data/processed_root.txt`, and the raw workbook `CAS.C2602520.NA.PMTS.FINAL.DT26054.xlsx`.
- Required columns from the workbook: `Address Information Line`, `Delivery Address Line`, `City Name`, `State Abbreviation`, `Zip Code`, plus all original payment columns that must be preserved.
- Outputs: `adhoc_payments_ingested.rds` in the processed-data root.
- Invariants: preserve one row per raw payment row; preserve all original raw columns after type cleaning; add geocoding-prep columns without dropping observations.

`1_code/1_0_ingest/1_0_1_geocode_adhoc.R`

- Tooling: base R plus `tidyverse`; `httr` or equivalent HTTP client for multipart batch submission to the Census endpoint.
- Inputs: `adhoc_payments_ingested.rds` plus the address-prep columns created upstream.
- Outputs: `adhoc_payments_geocoded.rds` in the processed-data root; optional unmatched and failure CSVs in the same root.
- Invariants: preserve the row count of the intermediate ingest artifact; create `address_latitude` and `address_longitude` as numeric columns; create `census_tract` as an 11-character string or `NA`; never create tract strings of any other length.

U.S. Census batch geocoder dependency

- Tooling: HTTP POST to `https://geocoding.geo.census.gov/geocoder/geographies/addressbatch`.
- Used in: `1_code/1_0_ingest/1_0_1_geocode_adhoc.R`.
- Concrete input contract: multipart form upload containing `addressFile`, `benchmark`, and `vintage`; each batch file row must provide `Unique ID, Street address, City, State, ZIP`.
- Concrete output contract: CSV rows that identify matched status and provide coordinate plus geography components sufficient to construct a tract string from state, county, and tract pieces.
- Behavioral implication: because the batch endpoint returns geography components rather than a single tract identifier, the script must assemble the 11-digit tract deterministically and validate its length.

## Completion Checklist

Before marking the ExecPlan **Complete**, verify:

- [ ] `1_code/1_0_ingest/1_0_0_ingest_adhoc.R` has been rewritten and validated.
- [ ] `1_code/1_0_ingest/1_0_1_geocode_adhoc.R` has been added and validated.
- [ ] Validation and acceptance checks passed.
- [ ] Processed artifacts are written to the correct processed-data root.
- [ ] Data contracts remain satisfied, including row preservation and 11-digit tract formatting.
- [ ] Progress log reflects the final state.
- [ ] README updates, if any, are mechanical and comply with `agent-docs/README_update_instructset.md`.
- [ ] ExecPlan Status updated to **Complete**.

---

## Change Notes

- 2026-03-22: Initial draft created after inspecting the repository, the raw workbook schema, the attached SBA geocode example, and the official Census geocoding documentation.
- 2026-03-22: Updated after user clarification that this project has one address per row and no lender data, and that the ingest rewrite should preserve `dplyr` syntax for readability. Also normalized the planned output column names to `address_latitude`, `address_longitude`, and `census_tract`.
- 2026-03-22: Updated during execution to reflect the completed ingest rewrite, the added geocoding script, the corrected four-sheet row count, the elevated-permission save requirement for the external processed-data folder, and the successful live preflight geocode run.
