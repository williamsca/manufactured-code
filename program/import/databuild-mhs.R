# This script constructs a panel of state-year observations
# of MH prices and shipments

rm(list = ls())
library(here)
library(data.table)
library(stringr)

source(here("program", "import", "project-params.R"))

data_path <- Sys.getenv("DATA_PATH")

year_min <- 1985L
year_max <- 2003L

# import ----

# wind zone classification
dt_treat <- fread(
    here("derived", "ecfr-windzone.csv"),
    keepLeadingZeros = TRUE
)

dt_treat[, statefp := substr(countyfp, 1, 2)]

dt_treat <- dt_treat[, .(wind_zone = max(wind_zone)), by = .(statefp)]

# state crosswalk
dt_state <- fread(
    file.path(data_path, "crosswalk", "states.txt"),
    keepLeadingZeros = TRUE
)

# CPI
dt_cpi <- fread(here("derived", "cpi-bls.csv"))
dt_cpi <- dt_cpi[, .(cpi = mean(cpi)), by = year]

dt_cpi[, cpi := cpi / cpi[year == DISCOUNT_YEAR]]

# MHS sample
dt <- readRDS(here("derived", "mhs-state-year.Rds"))
dt <- dt[
    !state_name %in% c("Alaska", "Hawaii") &
    year %between% c(year_min, year_max)]

# merge ----

# treatment status
dt[, statefp := str_pad(statefp, width = 2, pad = "0")]
dt <- merge(dt, dt_treat, by = "statefp", all.x = TRUE)

stopifnot(!anyNA(dt$wind_zone))

dt[, treated := (wind_zone >= 2)]
dt[, treated_wz3 := (wind_zone == 3)]

# CPI
dt <- merge(dt, dt_cpi[, .(year, cpi)], by = "year", all.x = TRUE)

stopifnot(!anyNA(dt$cpi))

# define outcomes ----
v_price <- grep("avg_sales_price", names(dt), value = TRUE)
dt[, (v_price) := lapply(.SD, function(x) x / cpi), .SDcols = v_price]

v_price_ln <- paste0(v_price, "_ln")
dt[, (v_price_ln) := lapply(.SD, log), .SDcols = v_price]

v_ship <- grep("placements", names(dt), value = TRUE)
v_ship_ln <- paste0(v_ship, "_ln")
dt[, (v_ship_ln) := lapply(.SD, log), .SDcols = v_ship]

# export ----
saveRDS(dt, here("derived", "sample-mhs.Rds"))
