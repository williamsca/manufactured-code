# This script imports policy data for 1980-2007 from Gallagher (2014).

rm(list = ls())
library(here)
library(data.table)
library(haven)
library(stringr)

data_path <- Sys.getenv("DATA_PATH")

# import ----
dt <- as.data.table(read_dta(
    file.path(data_path, "data", "fema-nfip", "gallagher_aer_2014",
    "panel_1980_2007.dta")))

# data are keyed by community-year
uniqueN(dt[, .(com_state, year)]) == nrow(dt)

# aggregate ----
dt[is.na(claim_cnt), claim_cnt := 0]
dt[, countyfp := str_pad(cnty_fips, 5, pad = "0")]
dt <- dt[, .(policies_n = sum(holders), claims_n = sum(claim_cnt)),
    by = .(countyfp, year)]

# export ----
fwrite(dt, here("derived", "fema-nfip-gallagher.csv"))