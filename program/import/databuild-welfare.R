# Build county-level dataset for welfare/cost-benefit calculation
#
# Strategy:
#   1. From NFIP claims, compute average annual damage per *insured* MH
#      by county and vintage (pre/post 1994). "Annual" = total damage over
#      the sample period / total policy-years in the same cells.
#   2. Merge 2000 Census MH counts to get total (insured + uninsured) stock.
#   3. Compute unconditional damage rate by applying the insured damage rate
#      to the full stock -- a lower bound since uninsured MH are likely in
#      lower-risk areas.
#
# Inputs:  derived/nfip-balanced.Rds
#          derived/census2000-mh-county.Rds
# Output:  derived/welfare-county.Rds
#
# Key columns in output:
#   countyfp, post1994
#   mh_units_2000         : MH stock from 2000 Census
#   total_units_2000      : total housing units from 2000 Census
#   policy_years          : total policy-years (insured exposure)
#   claims_n              : total claims
#   building_damage_tot   : total building damage ($000 real 2000)
#   contents_damage_tot   : total contents damage ($000 real 2000)
#   claim_rate_insured    : claims per policy-year (conditional on coverage)
#   building_damage_pa    : avg annual building damage per insured MH ($000)
#   contents_damage_pa    : avg annual contents damage per insured MH ($000)

rm(list = ls()); gc()
library(here)
library(data.table)

source(here("program", "import", "project-params.R"))

# ---------------------------------------------------------------------------
# 1. Load claims and policy panel ----
# ---------------------------------------------------------------------------

dt_bal <- readRDS(here("derived", "nfip-balanced.Rds"))

# restrict to MH, sample window matching main analysis
dt_bal <- dt_bal[mh == 1L & year_constr >= 1986L & year_constr <= 1999L]
dt_bal[, post1994 := as.integer(year_constr >= 1994L)]
dt_bal[, countyfp := substr(tractfp, 1, 5)]

# ---------------------------------------------------------------------------
# 2. Aggregate claims and policy-years to county × vintage ----
#
#   policies_n is the count of unique policies active in a 5-year period,
#   so divide by 5 to convert to annual policy-years before summing.
# ---------------------------------------------------------------------------

dt_welfare <- dt_bal[, .(
    claims_n            = sum(claims_n,            na.rm = TRUE),
    building_damage_tot = sum(building_damage_tot, na.rm = TRUE),
    contents_damage_tot = sum(contents_damage_tot, na.rm = TRUE),
    policy_years        = sum(policies_n / 5,      na.rm = TRUE)
), by = .(countyfp, post1994)]

# ---------------------------------------------------------------------------
# 5. Per-unit damage rates ----
# ---------------------------------------------------------------------------

# claim rate: claims per policy-year
dt_welfare[, claim_rate_insured := fifelse(
    !is.na(policy_years) & policy_years > 0,
    claims_n / policy_years,
    NA_real_
)]

# average annual damage per insured MH (total damage / total policy-years)
dt_welfare[, building_damage_pa := fifelse(
    !is.na(policy_years) & policy_years > 0,
    building_damage_tot / policy_years,
    NA_real_
)]
dt_welfare[, contents_damage_pa := fifelse(
    !is.na(policy_years) & policy_years > 0,
    contents_damage_tot / policy_years,
    NA_real_
)]

# ---------------------------------------------------------------------------
# 6. Merge 2000 Census MH stock ----
# ---------------------------------------------------------------------------

dt_census <- readRDS(here("derived", "census2000-mh-county.Rds"))

dt_welfare <- merge(
    dt_welfare,
    dt_census[, .(countyfp, mh_units_2000 = mh_units, total_units_2000 = total_units)],
    by  = "countyfp",
    all.x = TRUE
)

message(sprintf(
    "Counties missing Census MH counts: %d",
    dt_welfare[is.na(mh_units_2000), uniqueN(countyfp)]
))

setcolorder(dt_welfare, c(
    "countyfp", "post1994",
    "mh_units_2000", "total_units_2000",
    "policy_years", "claims_n",
    "building_damage_tot", "contents_damage_tot",
    "claim_rate_insured",
    "building_damage_pa", "contents_damage_pa"
))
setorder(dt_welfare, countyfp, post1994)

saveRDS(dt_welfare, here("derived", "welfare-county.Rds"))
message(sprintf(
    "Saved welfare-county.Rds: %d county × vintage cells",
    nrow(dt_welfare)
))
