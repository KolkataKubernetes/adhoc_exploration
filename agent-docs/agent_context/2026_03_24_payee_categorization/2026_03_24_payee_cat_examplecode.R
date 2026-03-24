library('tidyverse')

data <- readRDS('/Users/indermajumdar/Library/CloudStorage/Box-Box/MFP/data/2_processed_data/adhoc_payments_geocoded.rds')

## Confirm categories/Program Description

data |>
  count(accounting_program_description)


## What is the count by recipient?

data |>
  filter(census_matched_address = TRUE) |>
  count(address_geocode_key, sort = TRUE)

## This seems fishy. Some addresses have almost 1,000 payments. What are the payee names?

data |>
  filter(census_matched_address = TRUE) |>
  count(formatted_payee_name, sort = TRUE) -> payee_counts

## Let's use the FSA payments as an example

data |>
  filter(formatted_payee_name == 'FARM SERVICE AGENCY/COMMODITY CRE') |>
  filter(state_fsa_name == 'North Dakota') |>
  filter(county_fsa_name == 'Cavalier') |> 
  count(address_geocode_key)

data |> 
  filter(formatted_payee_name %in% c('FARM SERVICE AGENCY/COMMODITY CRE')) |>
  group_by(state_fsa_name) |>
  summarise(n_county = n_distinct(county_fsa_name), n_address = n_distinct(address_geocode_key), .groups = "drop") |>
  mutate(diff = n_county - n_address) |>
  filter(diff < 0)

# 

data |>
  mutate(
    payee_type = case_when(
      
      # --- Government ---
      str_detect(formatted_payee_name, regex(
        "FARM SERVICE AGENCY|USDA|FSA|FARM CREDIT|COMMODITY CREDIT|CCC",
        ignore_case = TRUE
      )) ~ "government",
      
      # --- Bank / Financial Institution ---
      str_detect(formatted_payee_name, regex(
        "FINANCE|CREDIT UNION|BANK",
        ignore_case = TRUE
      )) ~ "bank_fi",
      
      # --- Farm Holding Company (only after above fail) ---
      str_detect(formatted_payee_name, regex(
        "FARMS|DAIRY|LLC",
        ignore_case = TRUE
      )) ~ "farm_holding_company",
      
      # --- Default ---
      TRUE ~ "other"
    )
  ) -> data

data |>
  filter(geocode_status == "matched") |>
  count(payee_type)
  
data |>
  filter(geocode_status == "matched") |>
  filter(payee_type == 'bank_fi') -> tempdata