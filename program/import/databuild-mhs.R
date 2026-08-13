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
dt_wz <- fread(
    here("derived", "ecfr-windzone.csv"),
    keepLeadingZeros = TRUE
)

dt_treat <- copy(dt_wz)
dt_treat[, statefp := substr(countyfp, 1, 2)]

dt_treat <- dt_treat[, .(wind_zone = max(wind_zone)), by = .(statefp)]

# continuous treatment intensity: MH-stock-weighted share of a state's
# 1980-2000 MH stock sitting in a Zone II/III county. Binary `treated`
# above is diluted (e.g. GA has one WZ2/3 county but is coded fully
# treated); this recovers within-treated-group variation in how much of
# the state's MH stock the reform actually bound on. A handful of
# counties (AK, HI, NYC boroughs, renamed/consolidated FIPS codes) have
# no eCFR match; following the `statefp == 36` fallback in
# databuild-nfip.R, unmatched counties default to Zone I.
dt_stock <- readRDS(here("derived", "census2000-mh-county-vintage.Rds"))
dt_stock <- dt_stock[, .(mh_stock = sum(mh_units)), by = countyfp]

dt_intensity <- merge(dt_stock, dt_wz, by = "countyfp", all.x = TRUE)
dt_intensity[is.na(wind_zone), wind_zone := 1L]
dt_intensity[, statefp := substr(countyfp, 1, 2)]

dt_intensity <- dt_intensity[, .(
    mh_stock      = sum(mh_stock),
    mh_stock_wz23 = sum(mh_stock * (wind_zone >= 2L))
), by = statefp]
dt_intensity[, treated_intensity := mh_stock_wz23 / mh_stock]

saveRDS(dt_intensity, here("derived", "mhs-windzone-intensity.Rds"))

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

dt <- merge(
    dt, dt_intensity[, .(statefp, treated_intensity)],
    by = "statefp", all.x = TRUE)
dt[is.na(treated_intensity), treated_intensity := 0]

# high-intensity treated states only: FL, LA, MA (see notes/specs.md
# Chunk C for the state table with all intensities)
dt[, high_intensity := statefp %in% c("12", "22", "25")]

# CPI
dt <- merge(dt, dt_cpi[, .(year, cpi)], by = "year", all.x = TRUE)

stopifnot(!anyNA(dt$cpi))

# BPS single-family permits aggregated to state-year
dt_perm <- readRDS(here("derived", "permits-co.Rds"))
dt_perm[, statefp := formatC(as.integer(statefp), width = 2, flag = "0")]
dt_perm_state <- dt_perm[,
    .(permits_sf = sum(permits_sf, na.rm = TRUE)),
    by = .(statefp, year)
]
dt <- merge(dt, dt_perm_state, by = c("statefp", "year"), all.x = TRUE)

# define outcomes ----
v_price <- grep("avg_sales_price", names(dt), value = TRUE)
dt[, (v_price) := lapply(.SD, function(x) x / cpi), .SDcols = v_price]

v_price_ln <- paste0(v_price, "_ln")
dt[, (v_price_ln) := lapply(.SD, log), .SDcols = v_price]

v_ship <- grep("placements", names(dt), value = TRUE)
v_ship_ln <- paste0(v_ship, "_ln")
dt[, (v_ship_ln) := lapply(.SD, log), .SDcols = v_ship]

dt[, placements_permits_ratio    := fifelse(
    !is.na(permits_sf) & permits_sf > 0, placements / permits_sf, NA_real_)]
dt[, placements_permits_ratio_ln := log(placements_permits_ratio)]

# export ----
saveRDS(dt, here("derived", "sample-mhs.Rds"))
