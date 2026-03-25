# Project Title

Project Description

## Folder Structure

```
adhoc_exploration/
├── 0_inputs/
│   ├── input_root.txt                    # Pointer to the external raw-data root
│   └── census_apikey.md                  # Census API key reference notes
├── 1_code/
│   ├── 1_0_ingest/
│   │   ├── 1_0_0_ingest_adhoc.R          # Workbook ingest and address preparation
│   │   ├── 1_0_1_geocode_adhoc.R         # Census batch geocoding and geocode audit
│   │   └── 1_0_2_categorize_payees.R     # Payee categorization and payee audit
│   ├── 1_1_descriptives/                 # Reserved for descriptive-analysis scripts
│   ├── scratch/                          # Non-pipeline exploratory code
│   └── run_refactor_pipeline.R           # Stage runner for numbered pipeline scripts
├── 2_processed_data/
│   └── processed_root.txt                # Pointer to the external processed-data root
├── 3_outputs/
│   └── 3_0_tables/                       # Repository-local output directory scaffold
├── agent-docs/
│   ├── agent_context/                    # Task-specific context notes and examples
│   ├── execplans/                        # Living execution plans
│   ├── PLANS.md                          # Execplan template and maintenance rules
│   └── README_update_instructset.md      # README governance rules
└── README.md
```

## Data Sources

| Dataset | Source | Notes |
|---------|--------|-------|
| Ad hoc MFP payment workbook | External raw-data root referenced by `0_inputs/input_root.txt` | Current workbook: `CAS.C2602520.NA.PMTS.FINAL.DT26054.xlsx` |
| External processed-data root | External path referenced by `2_processed_data/processed_root.txt` | Stores generated `.rds` and audit `.csv` artifacts written by the ingest-stage scripts |
| Census batch geocoder | U.S. Census geocoding service used by `1_code/1_0_ingest/1_0_1_geocode_adhoc.R` | Used to append row-level coordinates and census tracts before downstream categorization |

## Data Definitions, Location and Pathing

- The repository stores pointer files to external data locations rather than checking raw or processed payment data into git.
- `0_inputs/input_root.txt` points to the Box-backed raw-data directory that currently contains `CAS.C2602520.NA.PMTS.FINAL.DT26054.xlsx`.
- `2_processed_data/processed_root.txt` points to the Box-backed processed-data directory where ingest-stage scripts currently write:
  - `adhoc_payments_ingested.rds`
  - `adhoc_payments_geocoded.rds`
  - `adhoc_payments_geocode_audit.csv`
  - `adhoc_payments_geocode_preflight.csv`
  - `adhoc_payments_geocoded_payee_categorized.rds`
  - `adhoc_payments_payee_type_audit.csv`
- `3_outputs/` is the repository-local destination for tables, figures, and other presentation-ready outputs. The current scaffold includes `3_outputs/3_0_tables/`.

## Pipeline Summary

### Pipeline Order (High-Level)

1. `1_code/1_0_ingest/1_0_0_ingest_adhoc.R` reads the external workbook, combines sheets, types fields explicitly, and writes `adhoc_payments_ingested.rds`.
2. `1_code/1_0_ingest/1_0_1_geocode_adhoc.R` reads `adhoc_payments_ingested.rds`, geocodes row-level addresses, and writes `adhoc_payments_geocoded.rds` plus geocoding audit files.
3. `1_code/1_0_ingest/1_0_2_categorize_payees.R` reads `adhoc_payments_geocoded.rds`, assigns broad payee categories, and writes `adhoc_payments_geocoded_payee_categorized.rds` plus a payee audit file.

### Running the Current Pipeline

From the repository root:

```bash
Rscript 1_code/run_refactor_pipeline.R --stage ingest
```

To inspect the queued ingest scripts without executing them:

```bash
Rscript 1_code/run_refactor_pipeline.R --stage ingest --dry-run
```

## Scripts and Outputs

### Ingest Scripts

| Script | Inputs | Outputs | Role |
|--------|--------|---------|------|
| `1_code/1_0_ingest/1_0_0_ingest_adhoc.R` | `0_inputs/input_root.txt`; `2_processed_data/processed_root.txt`; `CAS.C2602520.NA.PMTS.FINAL.DT26054.xlsx` | `adhoc_payments_ingested.rds` | Builds the typed ingest-stage dataset and address-preparation fields |
| `1_code/1_0_ingest/1_0_1_geocode_adhoc.R` | `2_processed_data/processed_root.txt`; `adhoc_payments_ingested.rds` | `adhoc_payments_geocoded.rds`; `adhoc_payments_geocode_audit.csv`; `adhoc_payments_geocode_preflight.csv` (optional) | Adds Census geocodes and writes geocoding audit artifacts |
| `1_code/1_0_ingest/1_0_2_categorize_payees.R` | `2_processed_data/processed_root.txt`; `adhoc_payments_geocoded.rds` | `adhoc_payments_geocoded_payee_categorized.rds`; `adhoc_payments_payee_type_audit.csv` | Adds broad payee categories and writes a payee audit artifact |
| `1_code/run_refactor_pipeline.R` | Numbered stage scripts under `1_code/` | Terminal execution of queued scripts in numeric order | Stage runner for `ingest`, `descriptives`, `reduced_form`, or `all` |

### Output Files and Directories

| File or Directory | Location | Notes |
|-------------------|----------|-------|
| `adhoc_payments_ingested.rds` | External processed-data root | Ingest-stage typed dataset created by `1_0_0_ingest_adhoc.R` |
| `adhoc_payments_geocoded.rds` | External processed-data root | Geocoded payment dataset created by `1_0_1_geocode_adhoc.R` |
| `adhoc_payments_geocode_audit.csv` | External processed-data root | Geocoding audit summary created by `1_0_1_geocode_adhoc.R` |
| `adhoc_payments_geocode_preflight.csv` | External processed-data root | Optional preflight artifact created by `1_0_1_geocode_adhoc.R` |
| `adhoc_payments_geocoded_payee_categorized.rds` | External processed-data root | Payee-categorized dataset created by `1_0_2_categorize_payees.R` |
| `adhoc_payments_payee_type_audit.csv` | External processed-data root | Payee categorization audit created by `1_0_2_categorize_payees.R` |
| `3_outputs/3_0_tables/` | Repository-local output directory | Current table-output scaffold used by the stage runner |

### TEMP/TEST Outputs

No repository-local TEMP/TEST output files are currently checked in.

## Change Log

| Date | Change | Type |
|------|--------|------|
| 2026-03-24 | Replaced the placeholder README template with repository-specific folder structure, data-source/pathing notes, pipeline order, ingest script inventory, output inventory, and a mechanical change log entry | Mechanical |
