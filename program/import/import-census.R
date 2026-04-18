# Import manufactured home counts from the 2000 Decennial Census by county.
#
# Table H030 ("Units in Structure") reports total MH units by county.
# Table HCT006 ("Tenure by Year Structure Built by Units in Structure")
# cross-tabulates occupied housing units by tenure, vintage, and structure
# type, including mobile homes -- used for the vintage-level welfare calc.
#
# Outputs (in derived/):
#   census2000-mh-county.Rds        county-level MH totals (H030)
#   census2000-mh-county-vintage.Rds county x vintage MH counts (HCT006)

rm(list = ls())
gc()
library(here)
library(data.table)
library(censusapi)

readRenviron(here(".Renviron"))

# ---------------------------------------------------------------------------
# H030: Units in Structure -- county-level MH totals
# ---------------------------------------------------------------------------
# H030010 = "Mobile home"; H030001 = total housing units

raw_h030 <- getCensus(
    name     = "dec/sf3",
    vintage  = 2000,
    vars     = c("H030001", "H030010"),
    region   = "county:*",
    regionin = "state:*"
)

dt <- as.data.table(raw_h030)
setnames(dt,
    c("state", "county", "H030001", "H030010"),
    c("statefp", "countyfp_short", "total_units", "mh_units"))

dt[, sfp := formatC(as.integer(statefp),        width = 2, flag = "0")]
dt[, cfp := formatC(as.integer(countyfp_short), width = 3, flag = "0")]
dt[, countyfp := paste0(sfp, cfp)]
dt[, total_units := as.integer(total_units)]
dt[, mh_units    := as.integer(mh_units)]
dt <- dt[as.integer(statefp) <= 56, .(countyfp, mh_units, total_units)]

stopifnot(uniqueN(dt$countyfp) == nrow(dt))
message(sprintf(
    "H030: %d counties, %.0f total MH units",
    nrow(dt), sum(dt$mh_units, na.rm = TRUE)
))
setorder(dt, countyfp)
saveRDS(dt, here("derived", "census2000-mh-county.Rds"))
message("Saved derived/census2000-mh-county.Rds")


# ---------------------------------------------------------------------------
# HCT006: Tenure × Year Built × Units in Structure
#
# For each vintage we pull:
#   - owner MH count  (HCT006009/017/025/033)
#   - renter MH count (HCT006082/090/098/106)
#   - owner total occupied units per vintage: HCT006003, 011, 019, 027
#   - renter total occupied units per vintage: HCT006076, 084, 092, 100
#
# Vintages: 1999-2000, 1995-1998, 1990-1994, 1980-1989
# "total_units" is occupied units only (owner + renter), not including vacant.
# ---------------------------------------------------------------------------

VTG_VARS <- c(
    # owner MH
    "HCT006009", "HCT006017", "HCT006025", "HCT006033",
    # renter MH
    "HCT006082", "HCT006090", "HCT006098", "HCT006106",
    # owner total (all structure types) per vintage
    "HCT006003", "HCT006011", "HCT006019", "HCT006027",
    # renter total (all structure types) per vintage
    "HCT006076", "HCT006084", "HCT006092", "HCT006100"
)

raw_hct006 <- getCensus(
    name     = "dec/sf3",
    vintage  = 2000,
    vars     = VTG_VARS,
    region   = "county:*",
    regionin = "state:*"
)

dv <- as.data.table(raw_hct006)

# parse FIPS
dv[, countyfp := paste0(
    formatC(as.integer(state),  width = 2, flag = "0"),
    formatC(as.integer(county), width = 3, flag = "0")
)]
dv <- dv[as.integer(state) <= 56]

# coerce all HCT006 cols to integer
hct_cols <- names(dv)[names(dv) %like% "^HCT006"]
dv[, (hct_cols) := lapply(.SD, as.integer), .SDcols = hct_cols]

# compute mh_units and total_units for each vintage bin, then reshape long
vtg_labels <- c("1999_2000", "1995_1998", "1990_1994", "1980_1989")

dv[, mh_1999_2000 := HCT006009 + HCT006082]
dv[, mh_1995_1998 := HCT006017 + HCT006090]
dv[, mh_1990_1994 := HCT006025 + HCT006098]
dv[, mh_1980_1989 := HCT006033 + HCT006106]

dv[, tot_1999_2000 := HCT006003 + HCT006076]
dv[, tot_1995_1998 := HCT006011 + HCT006084]
dv[, tot_1990_1994 := HCT006019 + HCT006092]
dv[, tot_1980_1989 := HCT006027 + HCT006100]

# reshape to long
dv_long <- rbindlist(lapply(vtg_labels, function(v) {
    data.table(
        countyfp       = dv$countyfp,
        vintage_census = v,
        mh_units       = dv[[paste0("mh_",  v)]],
        total_units    = dv[[paste0("tot_", v)]]
    )
}))

dv_long[, vintage_census := factor(
    vintage_census,
    levels = c("1980_1989", "1990_1994", "1995_1998", "1999_2000")
)]
setorder(dv_long, countyfp, vintage_census)

stopifnot(
    uniqueN(dv_long[, .(countyfp, vintage_census)]) == nrow(dv_long)
)
message(sprintf(
    "HCT006: %d county × vintage cells, %.0f MH units (occupied, 4 vintages)",
    nrow(dv_long),
    sum(dv_long$mh_units, na.rm = TRUE)
))

saveRDS(dv_long, here("derived", "census2000-mh-county-vintage.Rds"))
message("Saved derived/census2000-mh-county-vintage.Rds")
