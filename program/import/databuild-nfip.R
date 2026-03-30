# Build NFIP claims panel for continental US counties
#
# Inputs:  $DATA_PATH/data/fema-nfip/FimaNfipClaimsV2.parquet
#          $DATA_PATH/data/fema-nfip/FimaNfipPoliciesV2.parquet
# Outputs: derived/nfip-claims.Rds   (claim-level, filtered + labelled)
#          derived/nfip-county.Rds   (county × event × MH × vintage aggregates)

rm(list = ls())
library(here)
library(arrow)
library(dplyr)   # arrow lazy-eval uses dplyr verbs
library(data.table)
library(lubridate)

data_path <- Sys.getenv("DATA_PATH")
if (nchar(data_path) == 0) stop("DATA_PATH environment variable is not set.")
fema_dir  <- file.path(data_path, "data", "fema-nfip")

year_min <- 1984L
year_max <- 2005L

# ---------------------------------------------------------------------------
# import ----
# ---------------------------------------------------------------------------

# county wind zone designations
dt_treat <- fread(
    here("derived", "ecfr-windzone.csv"), keepLeadingZeros = TRUE)

# state crosswalk
dt_state <- fread(
    file.path(data_path, "crosswalk", "states.txt"), keepLeadingZeros = TRUE)

# fema claims and policies
pf <- open_dataset(file.path(fema_dir, "FimaNfipClaimsV2.parquet"))
# pf_pol <- open_dataset(file.path(fema_dir, "FimaNfipPoliciesV2.parquet"))

keep_cols <- c(
    # identifiers / geography
    "state", "countyCode", "censusTract", "censusBlockGroupFips",
    "latitude", "longitude",
    # storm / event
    "yearOfLoss", "dateOfLoss", "eventDesignationNumber", "ficoNumber",
    # property
    "occupancyType", "originalConstructionDate",
    "numberOfFloorsInTheInsuredBuilding",   # 5 = MH; 1-3 = site-built
    "locationOfContents",
    # damage / payment amounts
    "netBuildingPaymentAmount", "buildingDamageAmount",
    "buildingDeductibleCode",  "buildingPropertyValue",
    "contentsDamageAmount",    "netContentsPaymentAmount",
    "contentsPropertyValue",
    # claim flags
    "causeOfDamage", "floodZoneCurrent", "primaryResidenceIndicator"
)

dt_raw <- pf |>
    select(all_of(keep_cols)) |>
    filter(numberOfFloorsInTheInsuredBuilding %in% c(1L, 2L, 3L, 5L),
           !is.na(yearOfLoss),
           !is.na(state),
           !state %in% c("AS", "GU", "VI", "PR", "AK", "HI"),
           !is.na(countyCode)) |>
    collect() |>
    as.data.table()

message(sprintf(
    "Loaded %d claims (%d MH [floors==5], %d site-built [floors 1-3])",
    nrow(dt_raw),
    dt_raw[numberOfFloorsInTheInsuredBuilding == 5L, .N],
    dt_raw[numberOfFloorsInTheInsuredBuilding %in% c(1L, 2L, 3L), .N]))

# ---------------------------------------------------------------------------
# merge ----
# ---------------------------------------------------------------------------
setnames(dt_raw, c("countyCode"), c("countyfp"))
dt_raw[, statefp := substr(countyfp, 1, 2)]

# conflicts between 'state' and 'countyCode' in NFIP; take countyCode
# as ground truth
dt_raw$state <- NULL
dt_raw <- merge(
    dt_raw, dt_state[, .(state, statefp)], all.x = TRUE, by = "statefp")

stopifnot(nrow(dt_raw[is.na(state)]) == 0L)

# ---------------------------------------------------------------------------
# define event study variables ----
# ---------------------------------------------------------------------------

# MH indicator
dt_raw[, mh := as.integer(numberOfFloorsInTheInsuredBuilding == 5L)]

# vintage year
dt_raw[, year_constr := year(originalConstructionDate)]

# homes built on/after HUD wind-standard change date (July 13, 1994)
dt_raw[, post1994 := as.integer(
    year_constr > 1994L
)]

# ---------------------------------------------------------------------------
# sanity checks ----
# ---------------------------------------------------------------------------

# missing construction year
dt_raw[, missing_construction := as.integer(is.na(originalConstructionDate))]
message(sprintf(
    "Missing originalConstructionDate: %d of %d claims (%.1f%%)",
    dt_raw[missing_construction == 1L, .N],
    nrow(dt_raw),
    100 * dt_raw[missing_construction == 1L, .N] / nrow(dt_raw)
))

# post1994 shares by MH status
dt_raw[, .(
    n_claims      = .N,
    pct_post1994  = mean(post1994, na.rm = TRUE),
    pct_missing   = mean(missing_construction)
), by = .(mh)] |> print()

dt_raw <- dt_raw[missing_construction == 0L]

damage_cols <- c(
    "netBuildingPaymentAmount", "buildingDamageAmount",
    "buildingPropertyValue",
    "contentsDamageAmount",     "netContentsPaymentAmount",
    "contentsPropertyValue"
)

# convert decimal128 columns to numeric
for (col in damage_cols) {
    if (col %in% names(dt_raw)) {
        dt_raw[[col]] <- as.numeric(dt_raw[[col]])
    }
}

# ---------------------------------------------------------------------------
# balance panel: ----
#   start with all exposed county-years (> 0 claims)
#   then balance over mh × construction vintage \in (year_min, year_max)
#   cells with no claims get zeros
# ---------------------------------------------------------------------------
dt_agg <- dt_raw[,
    .(
        n_claims               = .N,
        total_net_building_pmt = sum(netBuildingPaymentAmount, na.rm = TRUE),
        total_building_damage  = sum(buildingDamageAmount, na.rm = TRUE),
        total_building_value   = sum(buildingPropertyValue, na.rm = TRUE),
        total_net_contents_pmt = sum(netContentsPaymentAmount, na.rm = TRUE),
        total_contents_damage  = sum(contentsDamageAmount, na.rm = TRUE)
    ),
    by = .(
        countyfp, year_loss = yearOfLoss, mh, year_constr)
]

# exposed county-years: any county-year with at least one claim
# *after* 1994
exposed_cy <- unique(dt_agg[, .(countyfp, year_loss)])
exposed_cy <- exposed_cy[year_loss > 1994L]

# cross with all mh × year_constr cells
grid <- exposed_cy[
    , CJ(mh = 0:1, year_constr = year_min:year_max),
    by = .(countyfp, year_loss)]
grid[, statefp := substr(countyfp, 1, 2)]

# merge on observed aggregates
dt_balanced <- merge(
    grid, dt_agg,
    by = c(
        "countyfp", "year_loss", "mh", "year_constr"),
    all.x = TRUE
)
dt_balanced[, post1994 := as.integer(year_constr > 1994L)]

# merge on treatment status
dt_balanced <- merge(dt_balanced, dt_treat, by = "countyfp", all.x = TRUE)

# the NYC boroughs have a consolidated city-county government, so
# they do *not* appear in the COG crosswalk
dt_balanced[is.na(wind_zone) & statefp == "36", wind_zone := 1]

stopifnot(nrow(dt_balanced[is.na(wind_zone)]) == 0L)

# treatment geography by county
dt_balanced[, treated := (wind_zone >= 2)]
dt_balanced[, treated_wz3 := (wind_zone == 3)]
dt_balanced$wind_zone <- NULL

# impute missing outcomes with zeros
v_outcomes <- c(
    "n_claims", "total_net_building_pmt", "total_building_damage",
    "total_building_value", "total_net_contents_pmt", "total_contents_damage")
for (col in v_outcomes) {
    set(dt_balanced, which(is.na(dt_balanced[[col]])), col, 0)
}

setkey(dt_balanced, countyfp, year_loss, mh, year_constr)

saveRDS(dt_balanced, here("derived", "nfip-balanced.Rds"))
message(sprintf(
    "Saved balanced panel: %d rows (%d county-years x 2 MH x %d vintage years)",
    nrow(dt_balanced), uniqueN(dt_balanced[, .(countyfp, year_loss)]),
    length(unique(dt_balanced$year_constr))))
