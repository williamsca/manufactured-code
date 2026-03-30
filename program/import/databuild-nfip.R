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

# fema claims
pf <- open_dataset(file.path(fema_dir, "FimaNfipClaimsV2.parquet"))

keep_cols <- c(
    # identifiers / geography
    "state", "countyCode", # "censusTract", "censusBlockGroupFips",
    # "latitude", "longitude",
    # storm / event
    "yearOfLoss", "dateOfLoss", # "eventDesignationNumber", "ficoNumber",
    # property
    "occupancyType", "originalConstructionDate",
    "numberOfFloorsInTheInsuredBuilding",   # 5 = MH; 1-3 = site-built
    # "locationOfContents",
    # damage / payment amounts
    "netBuildingPaymentAmount", "buildingDamageAmount",
    "totalBuildingInsuranceCoverage",
    "buildingDeductibleCode",  "buildingPropertyValue",
    "contentsDamageAmount",    "netContentsPaymentAmount",
    "contentsPropertyValue", "totalContentsInsuranceCoverage",
    # claim flags
    # "causeOfDamage", "floodZoneCurrent", "primaryResidenceIndicator"
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

# fema policies
pf_pol <- open_dataset(file.path(fema_dir, "FimaNfipPoliciesV2.parquet"))

v_cols_pol <- c(
    "countyCode", "numberOfFloorsInInsuredBuilding", "originalConstructionDate",
    "policyCost", "policyTerminationDate", "policyEffectiveDate",
    "buildingReplacementCost", "propertyState"
)

dt_raw_pol <- pf_pol |>
    select(all_of(v_cols_pol)) |>
    filter(numberOfFloorsInInsuredBuilding %in% c(1L, 2L, 3L, 5L),
           !is.na(originalConstructionDate),
           !is.na(propertyState),
           !propertyState %in% c("AS", "GU", "VI", "PR", "AK", "HI"),
           !is.na(countyCode)
           ) |>
    collect() |>
    as.data.table()

setnames(dt_raw_pol, c("countyCode"), c("countyfp"))

dt_raw_pol[, year_constr := year(originalConstructionDate)]
dt_raw_pol[, mh := as.integer(numberOfFloorsInInsuredBuilding == 5L)]

# policyEffectiveDate is already the actual coverage start (application date
# + 30-day waiting period per FEMA data dictionary); no adjustment needed.
dt_raw_pol[, date_eff  := as.Date(policyEffectiveDate)]
dt_raw_pol[, date_term := as.Date(policyTerminationDate)]
dt_raw_pol[, year_eff  := year(date_eff)]
dt_raw_pol[, year_term := year(date_term)]

# ---------------------------------------------------------------------------
# policy date sanity checks ----
# ---------------------------------------------------------------------------

# (1) missing dates
message(sprintf(
    "Policies: %d total | missing eff: %d (%.1f%%) | missing term: %d (%.1f%%)",
    nrow(dt_raw_pol),
    dt_raw_pol[is.na(date_eff),  .N],
    100 * dt_raw_pol[is.na(date_eff),  .N] / nrow(dt_raw_pol),
    dt_raw_pol[is.na(date_term), .N],
    100 * dt_raw_pol[is.na(date_term), .N] / nrow(dt_raw_pol)
))

# (2) effective >= termination (invalid)
dt_raw_pol[!is.na(date_eff) & !is.na(date_term), .(
    n_invalid   = sum(date_eff >= date_term),
    pct_invalid = mean(date_eff >= date_term),
    n_total     = .N
)] |> print()

# (3) duration distribution — standard NFIP annual policy should be ~365 days
dt_raw_pol[!is.na(date_eff) & !is.na(date_term),
    duration_days := as.integer(date_term - date_eff)]

dt_raw_pol[!is.na(duration_days), .(
    p1       = quantile(duration_days, .01),
    p10      = quantile(duration_days, .10),
    p50      = quantile(duration_days, .50),
    p90      = quantile(duration_days, .90),
    p99      = quantile(duration_days, .99),
    mean     = mean(duration_days),
    n_lt30   = sum(duration_days < 30L),
    n_gt400  = sum(duration_days > 400L)
)] |> print()

# (4) calendar-year coverage
message(sprintf(
    "Policy years: effective %d–%d | terminated %d–%d",
    dt_raw_pol[, min(year_eff,  na.rm = TRUE)],
    dt_raw_pol[, max(year_eff,  na.rm = TRUE)],
    dt_raw_pol[, min(year_term, na.rm = TRUE)],
    dt_raw_pol[, max(year_term, na.rm = TRUE)]
))

# (5) policies per construction decade × MH type
dt_raw_pol[!is.na(year_constr), .(n = .N),
    by = .(mh, decade = 10L * (year_constr %/% 10L))
][order(mh, decade)] |> print()

# ---------------------------------------------------------------------------
# aggregate policies: countyfp × calendar year × mh × year_constr ----
#
#   A policy is "in force" during calendar year Y if:
#       year_eff <= Y  AND  year_term >= Y          (closed interval)
#   The right endpoint is closed because a policy terminating mid-year
#   (e.g., a May-to-May annual policy) genuinely covers part of the
#   termination calendar year.  Using > would drop those policy-years.
#
#   policyEffectiveDate is already post-waiting-period (coverage start),
#   so no date offset is needed.
# ---------------------------------------------------------------------------

pol_yr_lo <- year_min          # 1984 — matches claims panel vintage range
pol_yr_hi <- year_max + 10L   # 2015 — covers storm years beyond year_max

dt_pol_clean <- dt_raw_pol[
    !is.na(date_eff) & !is.na(date_term) &
    date_eff < date_term &
    year_constr >= year_min &
    year_constr <= year_max
]

message(sprintf(
    "Policies after date/vintage filter: %d of %d (%.1f%%)",
    nrow(dt_pol_clean), nrow(dt_raw_pol),
    100 * nrow(dt_pol_clean) / nrow(dt_raw_pol)
))

# non-equi join: expand each policy to every calendar year it was active
# data.table overwrites the LHS key columns with the matched i-column values,
# so year_eff → matched spine year; rename immediately.
years_spine <- data.table(year = pol_yr_lo:pol_yr_hi)

dt_pol_exp <- dt_pol_clean[
    years_spine,
    on      = .(year_eff <= year, year_term >= year),
    allow.cartesian = TRUE,
    nomatch = 0L
]
setnames(dt_pol_exp, c("year_eff", "year_term"), c("year", "year_drop"))
dt_pol_exp[, year_drop := NULL]

# aggregate to panel key
dt_pol_agg <- dt_pol_exp[, .(
    policies_n      = .N,
    repl_cost_tot   = sum(as.numeric(buildingReplacementCost), na.rm = TRUE),
    policy_cost_tot = sum(as.numeric(policyCost),              na.rm = TRUE)
), by = .(countyfp, year, mh, year_constr)]

setkey(dt_pol_agg, countyfp, year, mh, year_constr)

saveRDS(dt_pol_agg, here("derived", "nfip-policies.Rds"))
message(sprintf(
    "Saved policy panel: %d rows (%d county-years, 2 MH types, %d vintage years)",
    nrow(dt_pol_agg),
    uniqueN(dt_pol_agg[, .(countyfp, year)]),
    uniqueN(dt_pol_agg$year_constr)
))

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
    "contentsPropertyValue", "totalBuildingInsuranceCoverage",
    "totalContentsInsuranceCoverage"
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
        claims_n               = .N,
        net_building_pmt_tot = sum(netBuildingPaymentAmount, na.rm = TRUE),
        building_damage_tot  = sum(buildingDamageAmount, na.rm = TRUE),
        building_value_tot   = sum(buildingPropertyValue, na.rm = TRUE),
        contents_value_tot   = sum(contentsPropertyValue, na.rm = TRUE),
        net_contents_pmt_tot = sum(netContentsPaymentAmount, na.rm = TRUE),
        contents_damage_tot  = sum(contentsDamageAmount, na.rm = TRUE),
        building_covg_tot    = sum(totalBuildingInsuranceCoverage, na.rm = TRUE),
        contents_covg_tot    = sum(totalContentsInsuranceCoverage, na.rm = TRUE)
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
v_outcomes <- grep("_tot$|_n$", names(dt_balanced), value = TRUE)
for (col in v_outcomes) {
    set(dt_balanced, which(is.na(dt_balanced[[col]])), col, 0)
}

# compute averages
v_tot <- grep("_tot$", names(dt_balanced), value = TRUE)
v_avg <- gsub("_tot$", "_pclaim", v_tot)
dt_balanced[, (v_avg) := lapply(
    .SD, function(x) fifelse(claims_n > 0, x / claims_n, NA_real_)),
    .SDcols = v_tot]

setkey(dt_balanced, countyfp, year_loss, mh, year_constr)

dt_pol_agg <- readRDS(here("derived", "nfip-policies.Rds"))

dt_balanced <- merge(
    dt_balanced,
    dt_pol_agg[, .(
        countyfp, year_loss = year, mh, year_constr,
        policies_n, repl_cost_tot, policy_cost_tot)],
    by    = c("countyfp", "year_loss", "mh", "year_constr"),
    all.x = TRUE
)

# claim rate: claims per policy in force that year
# NA where the county × year × cell has no policy records (coverage gap)
dt_balanced[, claim_rate := fifelse(
    !is.na(policies_n) & policies_n > 0L,
    claims_n / policies_n,
    NA_real_
)]

message(sprintf(
    "Policy merge: %.1f%% of panel cells have policy coverage",
    100 * dt_balanced[!is.na(policies_n), .N] / nrow(dt_balanced)
))

saveRDS(dt_balanced, here("derived", "nfip-balanced.Rds"))
message(sprintf(
    "Saved balanced panel: %d rows (%d county-years x 2 MH x %d vintage years)",
    nrow(dt_balanced), uniqueN(dt_balanced[, .(countyfp, year_loss)]),
    length(unique(dt_balanced$year_constr))))
