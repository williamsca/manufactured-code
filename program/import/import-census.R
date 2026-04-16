# Import manufactured home counts from the 2000 Decennial Census by county
# using the censusapi package.
#
# Table H030 ("Units in Structure") reports housing unit counts by structure
# type, including "Mobile home". H034 ("Year Structure Built") is available
# at the county level but does not cross-tabulate with structure type, so we
# pull H030 for MH counts and H034 for the vintage distribution of all units.
#
# Outputs: derived/census2000-mh-county.Rds
#   countyfp: 5-digit FIPS
#   mh_units: total MH units in county (from H030)
#   total_units: total housing units (from H030)

rm(list = ls()); gc()
library(here)
library(data.table)
library(censusapi)

# censusapi requires CENSUS_KEY in environment or .Renviron
readRenviron(here(".Renviron"))

# ---------------------------------------------------------------------------
# H030: Units in Structure (county level)
# ---------------------------------------------------------------------------
# Code H030009 = "Mobile home"; H030001 = total housing units

raw_h030 <- getCensus(
    name    = "dec/sf3",
    vintage = 2000,
    vars    = c("GEO_ID", "H030001", "H030009"),
    region  = "county:*",
    regionin = "state:*"
)

dt <- as.data.table(raw_h030)
setnames(dt, c(
    "geo_id", "statefp", "countyfp_short", "total_units", "mh_units"))

# construct 5-digit FIPS
dt[, countyfp := paste0(
    formatC(as.integer(statefp), width = 2, flag = "0"),
    formatC(as.integer(countyfp_short), width = 3, flag = "0")
)]

dt[, total_units := as.integer(total_units)]
dt[, mh_units    := as.integer(mh_units)]

# drop territories
dt <- dt[as.integer(statefp) <= 56]
dt[, c("geo_id", "statefp", "countyfp_short") := NULL]

stopifnot(uniqueN(dt$countyfp) == nrow(dt))
message(sprintf(
    "2000 Census MH counts: %d counties, %.0f total MH units",
    nrow(dt),
    sum(dt$mh_units, na.rm = TRUE)
))

setcolorder(dt, c("countyfp", "mh_units", "total_units"))
setorder(dt, countyfp)

saveRDS(dt, here("derived", "census2000-mh-county.Rds"))
message("Saved derived/census2000-mh-county.Rds")
