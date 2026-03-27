# Build NFIP claims panel for HUD 1994 wind-standard DiD
#
# Inputs:  data/FimaNfipClaimsV2.parquet
# Outputs: derived/nfip-claims.Rds   (claim-level, filtered + labelled)
#          derived/nfip-county.Rds   (county × event × MH × vintage aggregates)

rm(list = ls())
library(here)
library(arrow)
library(dplyr)   # arrow lazy-eval uses dplyr verbs
library(data.table)
library(lubridate)

# ---------------------------------------------------------------------------
# Treatment geography (from estimate.R)
# ---------------------------------------------------------------------------
v_treated_primary <- c(
    "FL", "SC", "NC", "GA", "AL", "MS", "LA", "TX"
)
# FIPS two-digit codes for the same states (for countyCode matching if needed)
v_treated_fringe <- c(
    "VA", "MD", "DE", "NJ", "CT", "RI", "MA", "NY", "ME", "NH", "HI"
)

# ---------------------------------------------------------------------------
# Load & filter parquet with arrow
#  - numberOfFloorsInTheInsuredBuilding 5   = manufactured/mobile home (MH group)
#  - numberOfFloorsInTheInsuredBuilding 1-3 = site-built single-family (comparison)
#  - occupancyType 14 used only post-2022 (RR2.0 reclassification); floors==5
#    is the consistent MH identifier across the full claims history (back to 1978)
#  - drop records missing yearOfLoss or state
# ---------------------------------------------------------------------------
pf <- open_dataset(here("data", "FimaNfipClaimsV2.parquet"))

keep_cols <- c(
    # identifiers / geography
    "state", "countyCode", "censusTract", "censusBlockGroupFips",
    "latitude", "longitude",
    # storm / event
    "yearOfLoss", "dateOfLoss", "eventDesignationNumber", "ficoNumber",
    # property
    "occupancyType", "originalConstructionDate",
    "numberOfFloorsInTheInsuredBuilding",   # 5 = MH; 1-3 = site-built
    "postFIRMConstructionIndicator",
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
           !is.na(state)) |>
    collect() |>
    as.data.table()

message(sprintf("Loaded %d claims (%d MH [floors==5], %d site-built [floors 1-3])",
    nrow(dt_raw),
    dt_raw[numberOfFloorsInTheInsuredBuilding == 5L, .N],
    dt_raw[numberOfFloorsInTheInsuredBuilding %in% c(1L, 2L, 3L), .N]))

# ---------------------------------------------------------------------------
# Core classification variables
# ---------------------------------------------------------------------------
# MH indicator (floors==5 is the consistent NFIP categorical code for MH)
dt_raw[, mh := as.integer(numberOfFloorsInTheInsuredBuilding == 5L)]

dt_raw[, countyfp := as.numeric(countyCode)]

# Vintage year and exact date
dt_raw[, year_constr := year(originalConstructionDate)]

# HUD wind-standard effective date: July 13, 1994
# post1994 = 1 for homes built on/after that date (compliant vintage)
dt_raw[, post1994 := as.integer(
    year_constr > 1994L
)]

# Event-study time relative to the rule change
dt_raw[, event_time := year_constr - 1994L]

# Treatment geography (primary treated states)
dt_raw[, treated       := as.integer(state %in% v_treated_primary)]
dt_raw[, treated_broad := as.integer(state %in% c(v_treated_primary, v_treated_fringe))]

# Triple-difference indicator: compliant MH in treated state
dt_raw[, ddd_indicator := mh * post1994 * treated]

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------
stopifnot(dt_raw[, all(numberOfFloorsInTheInsuredBuilding %in% c(1L, 2L, 3L, 5L))])
stopifnot(dt_raw[, all(mh %in% c(0L, 1L))])
stopifnot(dt_raw[, all(post1994 %in% c(0L, 1L, NA_integer_))])

# Flag if construction date missing
dt_raw[, missing_construction := as.integer(is.na(originalConstructionDate))]
message(sprintf(
    "Missing originalConstructionDate: %d of %d claims (%.1f%%)",
    dt_raw[missing_construction == 1L, .N],
    nrow(dt_raw),
    100 * dt_raw[missing_construction == 1L, .N] / nrow(dt_raw)
))

# Check consistency: post1994 shares by MH status
dt_raw[, .(
    n_claims      = .N,
    pct_post1994  = mean(post1994, na.rm = TRUE),
    pct_missing   = mean(missing_construction)
), by = .(mh)] |> print()

# ---------------------------------------------------------------------
# County × event × MH × vintage aggregate
#   Group on: state, countyCode, yearOfLoss, eventDesignationNumber,
#             ficoNumber, mh, post1994
#   (censusTract / block-group kept in claim-level file; too sparse here)
# ---------------------------------------------------------------------------
damage_cols <- c(
    "netBuildingPaymentAmount", "buildingDamageAmount",
    "buildingPropertyValue",
    "contentsDamageAmount",     "netContentsPaymentAmount",
    "contentsPropertyValue"
)

# Convert decimal128 columns to numeric
for (col in damage_cols) {
    if (col %in% names(dt_raw)) {
        dt_raw[[col]] <- as.numeric(dt_raw[[col]])
    }
}

dt_county <- dt_raw[
    !is.na(post1994),   # drop claims with unknown vintage
    .(
        n_claims                    = .N,
        # totals
        total_net_building_pmt      = sum(netBuildingPaymentAmount, na.rm = TRUE),
        total_building_damage       = sum(buildingDamageAmount,      na.rm = TRUE),
        total_building_value        = sum(buildingPropertyValue,     na.rm = TRUE),
        total_net_contents_pmt      = sum(netContentsPaymentAmount,  na.rm = TRUE),
        total_contents_damage       = sum(contentsDamageAmount,      na.rm = TRUE),
        total_contents_value        = sum(contentsPropertyValue,     na.rm = TRUE),
        # per-claim averages
        avg_net_building_pmt        = mean(netBuildingPaymentAmount, na.rm = TRUE),
        avg_building_damage         = mean(buildingDamageAmount,     na.rm = TRUE),
        avg_net_contents_pmt        = mean(netContentsPaymentAmount, na.rm = TRUE),
        avg_contents_damage         = mean(contentsDamageAmount,     na.rm = TRUE),
        # claim rate proxies
        any_building_claim          = mean(netBuildingPaymentAmount > 0, na.rm = TRUE),
        any_contents_claim          = mean(netContentsPaymentAmount > 0, na.rm = TRUE)
    ),
    by = .(state, countyfp, year_loss = yearOfLoss,
           eventDesignationNumber, ficoNumber,
           year_constr,
           mh, post1994, treated, treated_broad, event_time)
]

# Add triple-diff indicator at aggregate level
dt_county[, ddd_indicator := mh * post1994 * treated]

setkey(dt_county, countyfp, year_constr, year_loss, mh)

saveRDS(dt_county, here("derived", "nfip-county.Rds"))
message("Saved county aggregate: derived/nfip-county.Rds")

# Quick cross-tab: claims by MH × post1994 × treated
dt_county[, .(
    n_cell_obs  = .N,
    total_claims = sum(n_claims),
    avg_bldg_damage = mean(avg_building_damage, na.rm = TRUE)
), by = .(mh, post1994, treated)] |>
    (\(x) x[order(treated, mh, post1994)])() |>
    print()

# ---------------------------------------------------------------------------
# Balanced panel: county × mh × post1994 × year_loss
#   Aggregate from claim-level (collapsing event/fico/year_constr),
#   then expand so every exposed county-year has all 4 mh × post1994 cells.
#   Cells with no claims get zeros.
# ---------------------------------------------------------------------------
dt_agg <- dt_raw[
    !is.na(post1994) & !is.na(countyfp) & !is.na(yearOfLoss),
    .(
        n_claims               = .N,
        total_net_building_pmt = sum(netBuildingPaymentAmount, na.rm = TRUE),
        total_building_damage  = sum(buildingDamageAmount, na.rm = TRUE),
        total_building_value   = sum(buildingPropertyValue, na.rm = TRUE),
        total_net_contents_pmt = sum(netContentsPaymentAmount, na.rm = TRUE),
        total_contents_damage  = sum(contentsDamageAmount, na.rm = TRUE)
    ),
    by = .(
        state, countyfp, year_loss = yearOfLoss, mh, year_constr, post1994,
        treated, treated_broad)
]

# County attributes (1:1 mapping from countyfp → state, treated, treated_broad)
county_attrs <- unique(dt_agg[, .(countyfp, state, treated, treated_broad)])
stopifnot(county_attrs[, .N, by = countyfp][N > 1, .N] == 0)

# Exposed county-years: any county-year with at least one claim
exposed_cy <- unique(dt_agg[, .(countyfp, year_loss)])

# Cross with all mh × post1994 cells
grid <- exposed_cy[
    , CJ(mh = 0:1, year_constr = 1985:2005),
    by = .(countyfp, year_loss)]
grid <- county_attrs[grid, on = "countyfp"]

# Merge observed aggregates onto full grid
dt_balanced <- merge(
    grid, dt_agg,
    by = c("countyfp", "year_loss", "mh", "year_constr", "state", "treated", "treated_broad"),
    all.x = TRUE
)
dt_balanced[, post1994 := as.integer(year_constr > 1994L)]

# Fill missing outcomes with zero
v_outcomes <- c(
    "n_claims", "total_net_building_pmt", "total_building_damage",
    "total_building_value", "total_net_contents_pmt", "total_contents_damage")
for (col in v_outcomes) {
    set(dt_balanced, which(is.na(dt_balanced[[col]])), col, 0)
}

dt_balanced[, ddd_indicator := mh * post1994 * treated]
setkey(dt_balanced, countyfp, mh, post1994, year_loss)

saveRDS(dt_balanced, here("derived", "nfip-balanced.Rds"))
message(sprintf("Saved balanced panel: %d rows (%d county-years x 4 cells)",
                nrow(dt_balanced), uniqueN(dt_balanced[, .(countyfp, year_loss)])))
