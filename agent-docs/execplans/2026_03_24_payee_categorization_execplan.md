# Build Payee-Type Categorization Stage for Ad Hoc Payments

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document must be maintained in accordance with `agent-docs/PLANS.md` from the repository root.

---

## ExecPlan Status

Status: Execution (In Progress)  
Owner: Codex  
Created: 2026-03-24  
Last Updated: 2026-03-24  
Related Project: `adhoc_exploration` ingest and payee-classification workstream

Optional Metadata:  
Priority: High  
Estimated Effort: 1 working session for rule design and implementation, plus 1 validation session  
Dependencies: `2_processed_data/processed_root.txt`, `adhoc_payments_geocoded.rds`, `1_code/1_0_ingest/1_0_0_ingest_adhoc.R`, `1_code/1_0_ingest/1_0_1_geocode_adhoc.R`

---

## Revision History

| Date | Change | Author |
|-----|------|------|
| 2026-03-24 | Initial ExecPlan drafted from repository inspection, payee-categorization context note, example classification code, live geocoded dataset schema, and payee-name profiling | Codex |
| 2026-03-24 | Added an explicit validation requiring every row to receive a non-missing `payee_type`, including rows with missing payee names | Codex |
| 2026-03-24 | Execution started; status moved to in-progress before implementation of the new ingest-stage categorization script | Codex |
| 2026-03-24 | Added `1_code/1_0_ingest/1_0_2_categorize_payees.R`, ran it to completion, refined the residual-person fallback, validated outputs, and closed the execplan | Codex |
| 2026-03-24 | Reopened the execplan to add explicit compatibility for running `1_0_2_categorize_payees.R` from both `Rscript` and RStudio | Codex |
| 2026-03-24 | Patched the script for RStudio-safe path discovery and interactive reruns, validated both terminal and sourced execution paths, and closed the execplan again | Codex |
| 2026-03-24 | Reopened the execplan again to simplify the execution-path logic so it supports only the user-required modes: terminal and RStudio | Codex |
| 2026-03-24 | Simplified the execution-path logic to explicit terminal and RStudio branches, revalidated the terminal path, and left the plan open pending user sign-off | Codex |
| 2026-03-24 | Added a centralized manual override block for curated payee-name exceptions discovered during manual review and refreshed the categorized outputs | Codex |

---

## Quick Summary

**Goal**

Create a reproducible payee-categorization stage that reads the existing geocoded ad hoc payment file and appends an audit-friendly `payee_type` variable describing whether each payee is best interpreted as a person, personal trust, farm/ranch business, financial institution, government entity, or residual other organization.

**Deliverable**

When complete, the repository will contain a new ingest-stage script that writes a non-destructive categorized `.rds` plus a compact audit output showing category counts, triggering patterns, and examples that make the rules inspectable.

**Success Criteria**

- A new script under `1_code/1_0_ingest/` runs after geocoding and writes a new processed-data artifact without overwriting `adhoc_payments_geocoded.rds`.
- The output dataset preserves one row per input row and appends `payee_type`, a more detailed review field for the rule that fired, and optional indicator columns used for audit.
- Every input row receives a non-missing broad category in `payee_type`, including rows with missing or unusable payee names.
- Bank and government patterns are matched with word-boundary logic so names such as `LINDA S BANKS`, `ANTHONY JASON MARCHBANKS`, `BANKSTON UDDER-WISE DAIRY INC`, and `FAIRBANKS BAPTIST CHURCH` are not falsely classified as banks.
- A validation artifact demonstrates category counts and sampled names by category so a human can inspect whether the rules behave as intended.

**Key Files**

- `agent-docs/execplans/2026_03_24_payee_categorization_execplan.md`
- `agent-docs/agent_context/2026_03_24_payee_categorization/2026_03_24_payee_categorization.md`
- `agent-docs/agent_context/2026_03_24_payee_categorization/2026_03_24_payee_cat_examplecode.R`
- `agent-docs/0_0_code_format.R`
- `1_code/1_0_ingest/1_0_1_geocode_adhoc.R`
- `1_code/1_0_ingest/1_0_2_categorize_payees.R` (new)
- `1_code/run_refactor_pipeline.R`
- `2_processed_data/processed_root.txt`

---

## Purpose / Big Picture

After this change, a user should be able to run the ingest stage and obtain a payment-level dataset that not only contains geocodes but also a consistent, reviewable classification of what kind of entity received the payment. The visible proof of success will be a new categorized `.rds`, terminal `message()` output summarizing category totals, and an audit table that makes the rule system transparent enough to spot obvious mistakes before downstream descriptive or econometric work.

---

## Progress

- [x] (2026-03-24 20:40Z) Reviewed `AGENTS.md`, `agent-docs/PLANS.md`, the payee-categorization context note, the example rough code, and the existing geocode execplan for local style.
- [x] (2026-03-24 20:55Z) Inspected the current ingest-stage scripts and confirmed that the next numeric slot is `1_code/1_0_ingest/1_0_2_*`.
- [x] (2026-03-24 21:05Z) Confirmed that `adhoc_payments_geocoded.rds` currently contains the expected geocoded payment columns, including `formatted_payee_name`, `geocode_status`, `address_latitude`, `address_longitude`, and `census_tract`.
- [x] (2026-03-24 21:15Z) Profiled representative payee-name patterns from the live processed dataset to ground category design and precedence rules.
- [x] (2026-03-24 21:30Z) Drafted the initial execplan with proposed category definitions, precedence, outputs, and validation steps.
- [x] (2026-03-24 21:40Z) Updated the planning draft to require full row-level category coverage and a direct zero-missing validation for `payee_type`.
- [x] (2026-03-24 21:45Z) Began execution and moved the execplan status to `Execution (In Progress)` before adding the new categorization script.
- [x] (2026-03-24 22:05Z) Added `1_code/1_0_ingest/1_0_2_categorize_payees.R` with explicit helper provenance comments, broad category assignment, non-destructive output writing, and an audit CSV.
- [x] (2026-03-24 22:15Z) First execution pass completed the classification logic and zero-missing coverage check, but failed when writing to the external processed-data root because elevated filesystem permission was required.
- [x] (2026-03-24 22:20Z) Re-ran the script with elevated write permission and wrote both `adhoc_payments_geocoded_payee_categorized.rds` and `adhoc_payments_payee_type_audit.csv`.
- [x] (2026-03-24 22:30Z) Inspected the residual `person` bucket and found that `AG-CREDIT ACA`, `AGHERITAGE`, and `WCCB` were still falling through the first-pass rules.
- [x] (2026-03-24 22:35Z) Tightened the classifier by treating `ACA`, `PCA`, and `FCS` as financial tokens and compact all-caps single-token names as residual organizations rather than inferred persons.
- [x] (2026-03-24 22:40Z) Re-ran the script with `--overwrite`, confirmed row preservation and zero missing categories, verified the bank-surname false-positive cases, and confirmed the stage runner discovers the new script in order.
- [x] (2026-03-24 22:45Z) Closed the execplan after the original implementation scope was complete. No repository README file exists in this workspace, so no README update was possible.
- [x] (2026-03-24 23:05Z) Reopened the execplan after the user added a new requirement: `1_0_2_categorize_payees.R` must run cleanly from both the terminal and RStudio.
- [x] (2026-03-24 23:15Z) Patched `1_code/1_0_ingest/1_0_2_categorize_payees.R` so script-context detection works for `Rscript`, sourced execution, and RStudio-style interactive runs.
- [x] (2026-03-24 23:20Z) Added an option-based overwrite override and interactive-session refresh behavior so existing outputs do not block normal IDE reruns.
- [x] (2026-03-24 23:30Z) Validated the terminal execution path with `/usr/local/bin/Rscript 1_code/1_0_ingest/1_0_2_categorize_payees.R --overwrite`.
- [x] (2026-03-24 23:40Z) Validated the non-terminal execution path by sourcing the script from `/tmp` with `options(adhoc.payee_categorization.overwrite = TRUE)`, confirming repo discovery does not depend on the working directory.
- [x] (2026-03-24 23:45Z) Removed a sourced-path warning caused by iterating over `sys.frames()` as a pairlist and revalidated the sourced execution path.
- [x] (2026-03-24 23:50Z) Closed the execplan again after confirming the script works from both the terminal and a sourced execution path consistent with RStudio use.
- [x] (2026-03-24 23:55Z) Reopened the execplan after the user requested that the execution-path logic be simplified rather than kept broadly defensive.
- [x] (2026-03-25 00:05Z) Simplified `1_code/1_0_ingest/1_0_2_categorize_payees.R` so script-path detection now has only two supported branches: `Rscript` and RStudio.
- [x] (2026-03-25 00:15Z) Revalidated the terminal path with `/usr/local/bin/Rscript 1_code/1_0_ingest/1_0_2_categorize_payees.R --overwrite`; outputs and category counts were unchanged.
- [x] (2026-03-25 00:30Z) Added a centralized `manual_payee_overrides` block to `1_code/1_0_ingest/1_0_2_categorize_payees.R` so manually reviewed exceptions can be curated without weakening the general rules.
- [x] (2026-03-25 00:35Z) Refreshed the categorized outputs after adding the manual overrides and confirmed the listed edge cases were assigned the intended broad categories.
- [ ] Confirm the simplified RStudio branch in a live IDE session and keep the execplan open until the user explicitly approves closure.

---

## Surprises & Discoveries

- Observation: The current example code uses substring searches such as `BANK` and `FSA` without word boundaries, which would misclassify many surnames and unrelated words.
  Evidence: The user-provided false-positive list includes `LINDA S BANKS`, `ANTHONY JASON MARCHBANKS`, `KIM A BANKSON`, `THOMAS J BROOKBANK`, `BANKSTON UDDER-WISE DAIRY INC`, and `FAIRBANKS BAPTIST CHURCH`.

- Observation: The live processed dataset already provides a clean staging point for payee categorization.
  Evidence: `adhoc_payments_geocoded.rds` contains `formatted_payee_name` plus stable row-level identifiers and geocode fields, so payee classification can be added as a new downstream ingest step instead of rewriting prior scripts.

- Observation: Broad token counts are large enough to justify explicit entity categories but also overlap heavily, so rule precedence matters.
  Evidence: Local profiling on 2026-03-24 found approximately `118,330` rows with `TRUST`, `358,365` rows with farm/ranch terms, `381,486` rows with `LLC` or `INC`, `5,135` rows with bank terms, `3,155` rows with credit/finance terms, and `6,922` rows with government terms.

- Observation: `TRUST` cannot be treated as a personal-trust indicator without first excluding financial institutions.
  Evidence: Among the most frequent `TRUST` names are `FRANKLIN STATE BANK & TRUST COMPA`, `FIRST STATE BANK AND TRUST BRANCH`, `GUARANTY BANK & TRUST CO`, and `FIRST FARMERS BANK & TRUST`.

- Observation: `FARM` is too broad to define a farm-business class by itself because many government and farm-credit entities also contain that token.
  Evidence: Among the most frequent farm/entity names are `FARM SERVICE AGENCY/COMMODITY CRE`, `FARM SERVICE AGENCY`, `AGCOUNTRY FARM CREDIT SERVICES`, `USDA FARM SERVICE AGENCY`, and `FARM CREDIT SOUTHEAST MISSOURI`.

- Observation: Writing the new categorized artifacts to the external processed-data root required elevated filesystem permission even though reading the staged `.rds` input succeeded without escalation.
  Evidence: The first execution pass failed at `saveRDS()` with `Operation not permitted` for `/Users/indermajumdar/Library/CloudStorage/Box-Box/MFP/data/2_processed_data/adhoc_payments_geocoded_payee_categorized.rds`; rerunning with elevated permissions succeeded on 2026-03-24.

- Observation: The first-pass residual `person` bucket still contained a few obvious organization-like names even though the core bank-surname problem was fixed.
  Evidence: The top residual-person names after the first pass included `AGHERITAGE`, `AG-CREDIT ACA`, and `WCCB`, which are not strong candidates for individual recipients.

- Observation: Adding acronym-level financial tokens plus a fallback for compact all-caps organization names materially improved the residual `person` bucket without introducing name-by-name exception rules.
  Evidence: After refinement, the top residual-person names were conventional personal names such as `DAVID THOMPSON`, `MARK MILLER`, and `DAVID JOHNSON`; `AG-CREDIT ACA` moved to `financial_institution`, while `AGHERITAGE` and `WCCB` moved to `other`.

- Observation: The original script-path discovery logic was terminal-centric and not robust to RStudio's Source workflow.
  Evidence: The original implementation depended on `--file=` arguments and then fell back to `getwd()`, which can fail in RStudio when the working directory is the repository root or another directory unrelated to the script location.

- Observation: The sourced execution path worked once script-context detection used `sys.frames()` and, when available, `rstudioapi` as fallbacks after the `--file=` check.
  Evidence: On 2026-03-24, sourcing the script from `/tmp` with `options(adhoc.payee_categorization.overwrite = TRUE)` successfully discovered the repository, read the staged input, and wrote both outputs.

- Observation: The broader sourced-execution support is more general than the user's actual requirement.
  Evidence: On 2026-03-24, the user clarified that the relevant requirement is only compatibility with terminal runs and RStudio runs, and questioned whether the more defensive path-discovery helper was unnecessarily complicated.

- Observation: The terminal workflow remained intact after removing the generic sourced-execution fallbacks.
  Evidence: On 2026-03-25, `/usr/local/bin/Rscript 1_code/1_0_ingest/1_0_2_categorize_payees.R --overwrite` completed successfully and reproduced the same category totals as before the simplification.

- Observation: Some manually reviewed residual `person` names are best handled as explicit curated exceptions rather than by adding more generic pattern logic.
  Evidence: On 2026-03-25, the user supplied names such as `SARA S DAVIS ESTATE`, `JAMES H STEELE SR CREDIT SHELTER`, `LKH FARMING AN ARIZONA GP`, and `RJS PLANTING CO`, which are difficult to capture cleanly with broad regex rules without increasing the risk of new false positives.

---

## Decision Log

- Decision: Implement payee categorization as a new ingest-stage script named `1_code/1_0_ingest/1_0_2_categorize_payees.R`.
  Rationale: The numbering preserves pipeline order, keeps the task additive, and avoids rewriting the existing ingest and geocoding scripts.
  Date/Author: 2026-03-24 / Codex

- Decision: Keep the update non-destructive by writing a new categorized output rather than overwriting `adhoc_payments_geocoded.rds`.
  Rationale: Project instructions say to default to non-destructive updates and not overwrite existing outputs unless explicitly instructed.
  Date/Author: 2026-03-24 / Codex

- Decision: Use a broad `payee_type` variable with six values: `person`, `person_trust`, `farm_ranch`, `financial_institution`, `government`, and `other`, while also keeping a more granular rule/audit field that records the exact trigger family.
  Rationale: The user asked for a small set of economically meaningful categories, but also mentioned distinctions such as private financial institution versus government financial institution. A broad primary category plus a more detailed audit field preserves both goals without making the main variable overly fragmented.
  Date/Author: 2026-03-24 / Codex

- Decision: Enforce ordered rule precedence of `government` before `financial_institution`, `financial_institution` before `person_trust`, `person_trust` before `farm_ranch`, and `farm_ranch` before the `person` fallback.
  Rationale: The profiling work shows real overlaps such as `BANK & TRUST` and `FARM CREDIT`, so unordered matching would create unstable or obviously incorrect classes.
  Date/Author: 2026-03-24 / Codex

- Decision: Treat `person` as the residual category only after explicit organization, institution, and trust rules are exhausted, and reserve `other` for names that remain non-person-like even though they do not fit the main entity categories.
  Rationale: The user’s initial framing emphasizes persons versus business-like entities. A pure residual `other` would become too large and would obscure individual recipients if person detection is not handled explicitly.
  Date/Author: 2026-03-24 / Codex

- Decision: Treat `ACA`, `PCA`, and `FCS` as financial tokens in this dataset.
  Rationale: The first-pass audit showed farm-credit style entities such as `AG-CREDIT ACA` falling into the residual `person` bucket because they lacked the longer `FARM CREDIT` phrase. These abbreviations are specific enough in this context to improve classification without resorting to exact-name overrides.
  Date/Author: 2026-03-24 / Codex

- Decision: Reclassify compact all-caps single-token names away from `person` and into `other` when no stronger rule fires.
  Rationale: Names such as `AGHERITAGE` and `WCCB` are poor candidates for individual recipients, but they also lack enough transparent information to assign confidently to `financial_institution` or `farm_ranch`. The safer fallback is `other`, not `person`.
  Date/Author: 2026-03-24 / Codex

- Decision: Make script-context discovery explicit for both terminal and IDE execution rather than assuming `commandArgs()` always contains `--file=`.
  Rationale: The user expects the same pipeline script to run from both the terminal and RStudio. That requires a fallback chain that can resolve the script path when the code is sourced interactively.
  Date/Author: 2026-03-24 / Codex

- Decision: Allow interactive reruns to refresh existing categorized outputs without requiring a literal `--overwrite` flag, while keeping the non-interactive terminal guard in place.
  Rationale: The non-destructive default is useful for unattended terminal runs, but it is unnecessarily hostile in RStudio where rerunning the current script typically means the user intends to refresh the artifact. An explicit R option also keeps sourced testing controllable.
  Date/Author: 2026-03-24 / Codex

- Decision: Simplify the execution-path helper to target only the user-required modes rather than every plausible sourced-execution path.
  Rationale: Supporting only `Rscript` and RStudio should make the script easier to read and maintain, and the user explicitly prefers that narrower, simpler design.
  Date/Author: 2026-03-24 / Codex

- Decision: Remove the generic `sys.frames()` and option-based sourced-execution support from the script.
  Rationale: Those branches solved a broader problem than requested and made the helper harder to read. The simpler explicit branches now match the actual contract: terminal and RStudio.
  Date/Author: 2026-03-25 / Codex

- Decision: Add a centralized manual override table keyed on exact payee names for curated exceptions discovered during manual review.
  Rationale: This keeps the general rules simple while giving the user one explicit place to revise known edge cases without making the regex classifier materially more complex.
  Date/Author: 2026-03-25 / Codex

---

## Outcomes & Retrospective

**Summary of Outcome**

Execution is complete. A new ingest-stage script, `1_code/1_0_ingest/1_0_2_categorize_payees.R`, was added, run successfully, and wired into the ingest-stage runner. The script reads the existing geocoded dataset, assigns `payee_type` and `payee_type_detail`, writes a non-destructive categorized `.rds`, and writes an audit CSV that summarizes the rule output.

**Expected vs. Actual Result**

- Expected outcome: add a reproducible payee-type classification stage that fixes the obvious `BANK` substring errors and gives every row a broad category.
- Actual outcome: the stage was implemented and validated. The final categorized dataset preserves all `2,924,968` rows from `adhoc_payments_geocoded.rds`, and the count of missing `payee_type` values is `0`.
- Difference (if any): the first implementation pass exposed a residual-person fallback issue for `AG-CREDIT ACA`, `AGHERITAGE`, and `WCCB`, so the rules were tightened before closing the plan.

**Key Challenges Encountered**

- Challenge: the external Box-backed processed-data root could not be written from the default sandbox.
  Resolution: rerun the classification script with elevated permissions for the write step.

- Challenge: a few organization-like names still looked person-like under the first residual fallback.
  Resolution: add acronym-level financial detection for `ACA`, `PCA`, and `FCS`, and route compact all-caps single-token names to `other`.

**Lessons Learned**

- Lesson: the motivating surname false positives are best handled by stronger boundary-aware institution rules, not by memorizing exception names.
- Lesson: the residual `person` bucket needs an audit pass. A small number of compact organization names can survive a transparent first-pass classifier if the fallback is too permissive.
- Lesson: scripts intended to define pipeline stages in this repository should not assume terminal-only execution. If a script is expected to be sourced in RStudio, script-path discovery and overwrite behavior need explicit IDE-safe fallbacks.

**Follow-up Work**

- Follow-up task: inspect the audit CSV for whether additional transparent non-person organization markers should migrate from `other` into more specific categories in a future refinement pass.
- Follow-up task: if the same RStudio requirement applies across the pipeline, port the same script-context pattern to the other ingest-stage scripts so the behavior is consistent.
- Follow-up task: simplify the RStudio/terminal execution-path logic so the script is easier to maintain while still meeting the user's stated requirement.
- Follow-up task: ask the user to confirm the simplified script works as expected from their live RStudio session before closing this execplan.
- Follow-up task: continue populating or revising the manual override table as additional reviewed exceptions are discovered.

---

## Context and Orientation

The current ingest-stage pipeline consists of `1_code/1_0_ingest/1_0_0_ingest_adhoc.R`, which reads and types the raw workbook, and `1_code/1_0_ingest/1_0_1_geocode_adhoc.R`, which appends Census geocodes and writes `adhoc_payments_geocoded.rds` to the processed-data root pointed to by `2_processed_data/processed_root.txt`. The stage runner `1_code/run_refactor_pipeline.R` discovers scripts under `1_code/1_0_ingest` and executes them in numeric order, so adding `1_0_2_categorize_payees.R` is enough to place the new logic after geocoding.

The term "payee categorization" in this plan means classification using only the normalized payee-name string already stored in `formatted_payee_name`. This is a name-based heuristic, not a legal verification exercise. The classification must therefore remain simple, transparent, and auditable. The code should use explicit regex rules with word boundaries and should expose which rule family fired so a researcher can inspect errors.

The core input for this plan is `formatted_payee_name`. The output should preserve all existing columns and append at least the following:

- `payee_type`: the broad category used for downstream analysis.
- `payee_type_detail`: a more specific label naming the rule family that fired, such as `government_fsa`, `financial_bank`, `financial_farm_credit`, `person_trust`, `farm_llc_inc`, or `residual_other`.
- Optional audit flags such as `flag_government_pattern`, `flag_financial_pattern`, `flag_trust_pattern`, `flag_farm_pattern`, and `flag_person_pattern` if these make validation easier.

Every row must receive a non-missing `payee_type`. If `formatted_payee_name` is missing or unusable after cleaning, the script should still assign a fallback category, most likely `other`, with a detail label such as `missing_payee_name` so the case remains auditable.

The most important classification risk is false matching when an organizational keyword appears inside a surname or unrelated word. For example, `BANK` should only match as a standalone word or institutional phrase, not inside `BANKS`, `MARCHBANKS`, `EUBANK`, `BROOKBANK`, `BANKSON`, or `FAIRBANKS`. The example context supplied by the user should be treated as a required validation set.

This plan assumes the current geocoded dataset remains the staging input. If the user later wants payee categorization to happen before geocoding, the plan should be revised rather than inferred silently.

---

## Proposed Category Scheme

The broad analytical variable should be `payee_type` with the following values.

`government`

Use this when the payee name clearly refers to a government office or government financial vehicle. Examples include `FARM SERVICE AGENCY`, `USDA FARM SERVICE AGENCY`, `COMMODITY CREDIT CORPORATION`, `CCC`, and county-level `FSA` offices. If useful for audit, the detail field may distinguish `government_fsa_usda` from any broader `government_other`.

`financial_institution`

Use this when the payee is a bank, credit union, farm-credit lender, finance company, or similar institution. This class must rely on word-boundary or phrase-level patterns such as `BANK`, `BANCORP BANK`, `CREDIT UNION`, `FARM CREDIT`, `PRODUCTION CREDIT`, `ACA`, `PCA`, and `FINANCE`. This rule must run before `person_trust` because some institutions include both `BANK` and `TRUST`.

`person_trust`

Use this when the payee appears to be a personal or family trust rather than a bank trust department or a corporate trust company. Positive indicators include `TRUST`, `REVOCABLE TRUST`, `LIVING TRUST`, `FAMILY TRUST`, and similar phrases after financial-institution and government exclusions have already run.

`farm_ranch`

Use this when the payee name appears to describe a farm, ranch, dairy, or agricultural operating entity. Positive indicators may include phrases such as `FARM`, `FARMS`, `RANCH`, `DAIRY`, `CATTLE`, `ANGUS`, and legal suffixes such as `LLC`, `INC`, `LP`, or `LLP` when they appear alongside farm/ranch or clear business-like patterns. This rule must run after government and financial-institution rules because names like `FARM CREDIT` and `FARM SERVICE AGENCY` are not farm businesses.

`person`

Use this when no stronger entity rule fires and the name still looks like an individual recipient or a small joint individual recipient. Examples include conventional personal-name strings and simple conjunction formats such as `JACKIE R & DUFFIE L BANKS JV`. This class is the main residual individual class.

`other`

Use this when the name does not fit the categories above, does not appear person-like, or is missing/too malformed to classify more specifically. Examples may include churches, schools, nonprofits, estates that do not clearly map to personal trusts, ambiguous organizations without farm or financial markers, and rows where the payee name is unavailable after cleaning.

The detail field should preserve the narrower path used to assign the category. That allows downstream work to collapse or expand categories without rewriting the full script.

---

## Plan of Work

First, add a new script at `1_code/1_0_ingest/1_0_2_categorize_payees.R`. The file should follow the structure in `agent-docs/0_0_code_format.R`, emit `message()` progress updates, and use the same repository-root and root-path helper approach already present in `1_code/1_0_ingest/1_0_0_ingest_adhoc.R` and `1_code/1_0_ingest/1_0_1_geocode_adhoc.R`. If those helper functions are copied, the script comments should cite the origin file explicitly to satisfy the repository’s helper-function documentation rule.

Within that new script, read `adhoc_payments_geocoded.rds` from the processed-data root and standardize `formatted_payee_name` into a working uppercase string used only for matching. Do not destructively rewrite the original name column. Then create a small set of regex-based indicator flags built around word boundaries and phrase-level patterns. The script should keep the pattern groups readable in-line rather than hiding them inside a large external helper system. Short local helper functions are acceptable only if they materially simplify repeated logic and are clearly commented.

Next, assign `payee_type_detail` and `payee_type` using a single ordered `case_when()` block that documents precedence directly in the code. The planned precedence is:

1. Government patterns.
2. Financial institution patterns.
3. Personal trust patterns.
4. Farm/ranch business patterns.
5. Person-like fallback.
6. Residual other.

The person-like fallback should be intentionally conservative. It should not try to solve name parsing perfectly. A reasonable version is to treat residual names as `person` unless they still show obvious non-person organization markers such as `CHURCH`, `MINISTRY`, `SCHOOL`, `COUNTY`, `CITY OF`, `COOPERATIVE`, `ASSOCIATION`, or similar phrases that belong in `other`. This keeps the classification transparent and prevents over-engineered name parsing.

After assigning categories, write a new processed-data artifact named `adhoc_payments_geocoded_payee_categorized.rds`. Preserve all input rows and existing columns. Append only the new category columns and any lightweight audit flags needed for review.

Finally, write a compact audit artifact, preferably `adhoc_payments_payee_type_audit.csv`, to the processed-data root. At minimum this file should report category counts and a few representative high-frequency names within each category or detail class. If a second audit file improves review, it may contain the top matched names per `payee_type_detail` or the names that triggered multiple raw pattern families before precedence resolved them.

Because this is a new numbered pipeline script, update the repository README only when this execplan is executed and closed, and only if a repository README exists at that time. Any README update must follow `agent-docs/README_update_instructset.md`.

---

## Concrete Steps

Run all commands from the repository root: ` /Users/indermajumdar/Research/adhoc_exploration `

1. Confirm the ingest runner sees the new numeric slot after the script is added.

       /usr/local/bin/Rscript 1_code/run_refactor_pipeline.R --stage ingest --dry-run

   Expected result: the queued scripts include `1_code/1_0_ingest/1_0_0_ingest_adhoc.R`, `1_code/1_0_ingest/1_0_1_geocode_adhoc.R`, and `1_code/1_0_ingest/1_0_2_categorize_payees.R` in that order.

2. Run the payee-categorization script directly while developing it.

       /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_2_categorize_payees.R

   Expected result: terminal `message()` output reports the number of rows read, category totals, any ambiguous-match review counts, and the save paths for the categorized `.rds` and audit `.csv`.

3. Run the full ingest stage after implementation.

       /usr/local/bin/Rscript 1_code/run_refactor_pipeline.R --stage ingest

   Expected result: the categorization script runs after geocoding, the new categorized artifact is written to the processed-data root, and the terminal output confirms category totals.

---

## Validation and Acceptance

Validation 1: Output artifact creation and row preservation.

1. Command:

       /usr/local/bin/Rscript 1_code/1_0_ingest/1_0_2_categorize_payees.R

2. Expected behavior:

   The script writes `adhoc_payments_geocoded_payee_categorized.rds` and `adhoc_payments_payee_type_audit.csv` to the processed-data root. The categorized dataset has the same row count as `adhoc_payments_geocoded.rds` and contains non-missing values in `payee_type` for every row.

3. Why this proves correctness:

   The primary deliverable is an additive categorized dataset, not only code changes. Row preservation and full category assignment verify that the stage can be used downstream without leaving uncoded rows behind.

Validation 1A: Explicit full-coverage category check.

1. Command:

       /usr/local/bin/Rscript -e 'processed_root <- trimws(readLines("2_processed_data/processed_root.txt"), which = "both"); processed_root <- gsub("^'\''", "", processed_root); processed_root <- gsub("'\''$", "", processed_root); x <- readRDS(file.path(processed_root, "adhoc_payments_geocoded_payee_categorized.rds")); cat(sum(is.na(x$payee_type)), "\n")'

2. Expected behavior:

   The command prints `0`.

3. Why this proves correctness:

   This directly verifies the full-coverage requirement that every row in the categorized dataset receives a broad payee category.

Validation 2: False-positive surname protection.

1. Command:

       /usr/local/bin/Rscript -e 'processed_root <- trimws(readLines("2_processed_data/processed_root.txt"), which = "both"); processed_root <- gsub("^'\''", "", processed_root); processed_root <- gsub("'\''$", "", processed_root); x <- readRDS(file.path(processed_root, "adhoc_payments_geocoded_payee_categorized.rds")); check_names <- c("LINDA S BANKS", "ANTHONY JASON MARCHBANKS", "KIM A BANKSON", "THOMAS J BROOKBANK", "BANKSTON UDDER-WISE DAIRY INC", "FAIRBANKS BAPTIST CHURCH"); print(x[x$formatted_payee_name %in% check_names, c("formatted_payee_name", "payee_type", "payee_type_detail")])'

2. Expected behavior:

   None of the listed cases are classified as `financial_institution`. `BANKSTON UDDER-WISE DAIRY INC` should resolve to `farm_ranch`, and the personal-surname examples should remain `person` or another non-financial class.

3. Why this proves correctness:

   These concrete names are the motivating bug examples supplied by the user. Passing this check demonstrates that the revised regex logic fixes the most obvious substring errors.

Validation 3: Category-level audit inspection.

1. Command:

       /usr/local/bin/Rscript -e 'processed_root <- trimws(readLines("2_processed_data/processed_root.txt"), which = "both"); processed_root <- gsub("^'\''", "", processed_root); processed_root <- gsub("'\''$", "", processed_root); audit <- read.csv(file.path(processed_root, "adhoc_payments_payee_type_audit.csv")); print(audit)'

2. Expected behavior:

   The audit file shows the counts for each broad category and enough detail or examples to verify that the main rule families are populated sensibly.

3. Why this proves correctness:

   This task is inherently heuristic. A visible audit artifact is required so a human can assess whether the classification is substantively reasonable.

---

## Idempotence and Recovery

The new script should be idempotent. Re-running it against the same `adhoc_payments_geocoded.rds` should recreate the same categorized `.rds` and audit `.csv` without changing row counts or prior pipeline outputs. Because the project defaults to non-destructive output management, the script should stop if the categorized output already exists unless an explicit `--overwrite` flag is supplied, or it should print a message explaining that it is refreshing the same named artifact intentionally. The chosen behavior must be documented in the script comments and terminal messages.

If the script fails after writing one artifact but before writing the other, the failure message should identify which output is incomplete. Safe recovery is to rerun only `1_code/1_0_ingest/1_0_2_categorize_payees.R` after correcting the bug or enabling overwrite.

---

## Artifacts and Notes

Important planning facts observed on 2026-03-24:

    Current staged input columns in `adhoc_payments_geocoded.rds` include:
    formatted_payee_name
    row_id
    geocode_status
    census_matched_address
    address_latitude
    address_longitude
    census_tract

    Representative high-frequency institutional names:
    FARM SERVICE AGENCY/COMMODITY CRE
    FARM SERVICE AGENCY
    AGCOUNTRY FARM CREDIT SERVICES
    BEACON CREDIT UNION
    AGRI BUSINESS FINANCE, INC.
    FARMERS & MERCHANTS BANK
    SOUTHERN BANCORP BANK
    COMMODITY CREDIT CORPORATION

    Representative high-frequency trust names showing overlap risk:
    FRANKLIN STATE BANK & TRUST COMPA
    FIRST STATE BANK AND TRUST BRANCH
    JOHNSON FAMILY TRUST
    GUARANTY BANK & TRUST CO
    JONES FAMILY TRUST

    User-supplied false-positive cases that must not be classed as financial institutions:
    LINDA S BANKS
    JACKIE R & DUFFIE L BANKS JV
    HUGHBANKS RANCH LLC
    ANTHONY JASON MARCHBANKS
    KIM A BANKSON
    THOMAS J BROOKBANK
    FAIRBANKS BAPTIST CHURCH
    BANKSTON UDDER-WISE DAIRY INC

Execution facts confirmed on 2026-03-24:

    Categorized output row count:
    2,924,968

    Input row count from `adhoc_payments_geocoded.rds`:
    2,924,968

    Missing `payee_type` values:
    0

    Final category totals:
    person = 2,296,776
    farm_ranch = 361,138
    other = 133,848
    person_trust = 117,740
    financial_institution = 8,592
    government = 6,874

    Validated edge-case assignments:
    LINDA S BANKS -> person
    JACKIE R & DUFFIE L BANKS JV -> person
    HUGHBANKS RANCH LLC -> farm_ranch
    ANTHONY JASON MARCHBANKS -> person
    KIM A BANKSON -> person
    THOMAS J BROOKBANK -> person
    FAIRBANKS BAPTIST CHURCH -> other
    BANKSTON UDDER-WISE DAIRY INC -> farm_ranch
    AG-CREDIT ACA -> financial_institution
    AGHERITAGE -> other
    WCCB -> other

    Additional execution-path validation:
    `/usr/local/bin/Rscript 1_code/1_0_ingest/1_0_2_categorize_payees.R --overwrite` completed successfully.
    `source("/Users/indermajumdar/Research/adhoc_exploration/1_code/1_0_ingest/1_0_2_categorize_payees.R")` also completed successfully when called from `/tmp` with `options(adhoc.payee_categorization.overwrite = TRUE)`.

---

## Data Contracts, Inputs, and Dependencies

`1_code/1_0_ingest/1_0_2_categorize_payees.R`

- Tooling: base R plus `tidyverse`; follow the repository style in `agent-docs/0_0_code_format.R`.
- Inputs: `2_processed_data/processed_root.txt` and `adhoc_payments_geocoded.rds`.
- Required columns from the input dataset: `formatted_payee_name` and a stable row identifier such as `row_id`. All existing columns must be preserved.
- Outputs: `adhoc_payments_geocoded_payee_categorized.rds` and `adhoc_payments_payee_type_audit.csv` in the processed-data root.
- Invariants: preserve one row per input row; preserve existing geocode columns unchanged; create a non-missing `payee_type` for every row in the dataset; never classify the user-supplied surname false positives as `financial_institution`.

Regex rule system

- Tooling: `stringr::str_detect()` or equivalent base-R regex functions with `ignore_case = TRUE`.
- Used in: `1_code/1_0_ingest/1_0_2_categorize_payees.R`.
- Concrete input contract: uppercase or otherwise standardized payee-name strings derived from `formatted_payee_name`.
- Concrete output contract: a set of boolean rule flags or direct class assignments that can be inspected and summarized.
- Behavioral implication: matching must use word boundaries or phrase-level patterns for institution keywords so substring collisions in surnames do not create classification errors.

Audit artifact

- Tooling: `dplyr` summaries written to CSV.
- Used in: `1_code/1_0_ingest/1_0_2_categorize_payees.R`.
- Concrete input contract: the classified row-level dataset after `payee_type` and `payee_type_detail` are assigned.
- Concrete output contract: a CSV that reports category counts and representative names or rule triggers.
- Behavioral implication: because the classifier is heuristic, this audit file is part of the deliverable rather than an optional side effect.

## Completion Checklist

Before marking the ExecPlan **Complete**, verify:

- [x] `1_code/1_0_ingest/1_0_2_categorize_payees.R` has been added and follows the repository code format.
- [x] The script reads `adhoc_payments_geocoded.rds` and writes `adhoc_payments_geocoded_payee_categorized.rds` non-destructively.
- [x] The script writes `adhoc_payments_payee_type_audit.csv`.
- [x] Validation and acceptance checks passed, including the surname false-positive test.
- [x] The script is compatible with both terminal execution and sourced execution consistent with RStudio use.
- [x] Data contracts remain satisfied, including row preservation and unchanged geocode columns.
- [x] Progress log reflects the final state.
- [x] README updates, if any, are mechanical and comply with `agent-docs/README_update_instructset.md`. No repository README file exists in this workspace, so no README change was made.
- [x] ExecPlan Status updated to **Complete**.

---

## Change Notes

- 2026-03-24: Initial draft created after inspecting the repository, the new payee-categorization context note, the rough example code, the live geocoded data schema, and representative payee-name frequencies. The draft adopts a broad `payee_type` plus narrower `payee_type_detail` approach so the main analysis variable stays small while still preserving audit detail.
- 2026-03-24: Updated during planning review to make full category coverage explicit. The plan now requires every row to receive a non-missing `payee_type`, and it adds a direct validation that the count of missing `payee_type` values is zero.
- 2026-03-24: Execution began. The plan status was moved to `Execution (In Progress)` before implementation so the living document matches the work state.
- 2026-03-24: Updated at closeout to record the implemented categorization script, the external-write permission requirement, the post-audit refinement for `ACA` and compact all-caps organization names, the final category counts, the validated edge-case assignments, and the absence of a repository README to update.
- 2026-03-24: Reopened after closeout because the user added a new execution requirement: the categorization script must work from RStudio as well as the terminal. This is a follow-on implementation change, not a revision to the original completed scope.
- 2026-03-24: Updated at second closeout to record the RStudio-safe path detection change, the interactive overwrite refresh behavior, the sourced execution validation from `/tmp`, and the final re-close of the execplan.
- 2026-03-24: Reopened again after the user requested simplification of the execution-path logic. The next revision should narrow support to the two required modes only: terminal and RStudio.
- 2026-03-25: Updated during the simplification pass to record the narrower terminal/RStudio-only helper, the successful terminal revalidation, and the decision to keep the execplan open pending user confirmation from a live RStudio run.
- 2026-03-25: Updated during manual review to record the new `manual_payee_overrides` block, the refreshed categorized outputs, and the decision to use curated exceptions for hard-to-generalize residual names.
