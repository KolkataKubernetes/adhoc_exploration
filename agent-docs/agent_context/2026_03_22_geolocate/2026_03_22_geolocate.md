# # Geocoding the MFP Data
- I'd like to geocode each row of the ad hoc MFP data, and return both a precise lat/long of the address and the 11 digit census tract associated with each address.
- We want both geographic features (lat long, census tract ID) to be saved for both borrower and lender addresses.

## Goals and Objectives
- The goal is to build a script that ingests the Ad Hoc dataframe and uses the US Census Geocoder API to identify (a) the Lat Long associated with each row's address, (b) The 11 digit census tract associated with row's address
- The 11 digit census tract should be appended as a feature to the data and saved as an artifact in 2_processed_data.
- The borrower lat and long should be similarly appended.

## Data Sources
- @0_inputs/CAS.C2602520.NA.PMTS.FINAL.DT26054.xlsx
- The US Census Geocoder API 
## Tasks to be completed
- Using a similar procedure to the one included in '/Users/indermajumdar/Research/adhoc_exploration/agent-docs/agent_context/2026_03_22_geolocate/SBA_7A_geocode.R', geocode the rows in this data with the clean data described above.
- I started typecasting in '~/Research/adhoc_exploration/1_code/1_0_ingest/1_0_0_ingest_adhoc.R'. I want you to create the features needed for the geocoding exercise in this script, in the section provided.
- A seperate script should be created for the geocode batching/API call procedure.

## Target outputs
- Output should be saved in @2_processed_data, to an RDS which does not yet exist but that you should name.

## General Guidance
- US Census Geocoder documentation can be found here: https://geocoding.geo.census.gov/geocoder/Geocoding_Services_API.html#_Toc220929672
- I value transparency and well commented code. I also prefer the use of tidyverse packages when writing code.
- The census tract ID should be 11 digits.
- Validation should include a check of how many successful address matches occured, seperately for borrower and banker.
- I have included a Census API Key in 0_inputs, stored in Markdown form.

## Execution Ambiguities
- To be populated based on any questions you have.
