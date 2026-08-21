# This script imports CPI data from research-database's bls_cpi dataset
# (BLS Public Data API, CPI-U U.S. city average all items, not seasonally
# adjusted). Reads the native 1982-84=100 index -- rebasing to
# DISCOUNT_YEAR is this project's own downstream step (databuild-mhs.R,
# databuild-nfip.R), not something to duplicate here.

rm(list = ls())
library(here)
library(data.table)

source(here("program", "import", "rd-client.R"))

# import ----
dt <- rd_read("bls_cpi", cols = c("year", "month", "date", "cpi_u_nsa_1982_84"))
setnames(dt, "cpi_u_nsa_1982_84", "cpi")

# clean ----
dt <- dt[!is.na(cpi)]
dt[, month := NULL]

setorder(dt, year, date)

# export ----
fwrite(dt, here("derived", "cpi-bls.csv"))
