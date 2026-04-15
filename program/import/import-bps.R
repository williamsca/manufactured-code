# This script imports annual building permit data from the Census
# Building Permits Survey, downloaded on July 2024 from
# https://socds.huduser.gov/permits/help

# Users may also query the data directly from the HUD User website:
# https://socds.huduser.gov/permits/index.html

rm(list = ls())
library(here)
library(data.table)

data_path <- Sys.getenv("DATA_PATH")

# import ----
dt <- fread(
  file.path(data_path, "data", "census-bps", "BPS_Compiled_File.csv"))

# clean ----
dt[, countyfp := 1000 * state + county]

# * filter
# drop PR and VI and aggregate rows
dt <- dt[series %in% c(1, 6) & !state %in% c(43, 52)]

# * aggregate by county and year
dt <- dt[, .(permits = sum(permits)), by = .(state, countyfp, year, sertxt)]

# * reshape
dt <- dcast(dt, state + countyfp + year ~ sertxt, value.var = "permits",
  fun.aggregate = sum, fill = 0L)

setnames(dt, c("All Permits", "Single Family", "state"),
  c("permits_tot", "permits_sf", "statefp"))

setkey(dt, countyfp, year)

# export
saveRDS(dt, here("derived", "permits-co.Rds"))