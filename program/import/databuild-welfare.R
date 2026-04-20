# Build county × vintage dataset for welfare/cost-benefit calculation
#
# Strategy:
#   1. From NFIP balanced panel, aggregate claims and policy-years to
#      county × vintage_census cells, where vintage bins match Census 2000
#      HCT006 intervals (1980-1989, 1990-1994, 1995-1998, 1999-2000).
#   2. Merge 2000 Census MH stock by county × vintage to get unconditional
#      exposure (insured + uninsured).
#   3. The 1990-1994 bin straddles the July 1994 HUD reform; we assign it to
#      pre-treatment throughout as a conservative choice.
#
# Inputs (in derived/):  nfip-balanced.Rds, census2000-mh-county-vintage.Rds
# Output (in derived/):  welfare-county-vintage.Rds
#
# Key columns in output:
#   countyfp, vintage_census, post1994
#   mh_units_2000         : occupied MH stock from Census 2000 HCT006
#   total_units_2000      : total occupied housing units (all types)
#   policy_years          : total policy-years (insured exposure)
#   claims_n              : total claims
#   building_damage_tot   : total building damage ($000 real 2000)
#   contents_damage_tot   : total contents damage ($000 real 2000)
#   claim_rate_insured    : claims per policy-year
#   building_damage_pa    : avg annual building damage per insured MH ($000)
#   contents_damage_pa    : avg annual contents damage per insured MH ($000)

rm(list = ls())
gc()
library(here)
library(data.table)

source(here("program", "import", "project-params.R"))

# ---------------------------------------------------------------------------
# 1. Load and prep NFIP balanced panel ----
# ---------------------------------------------------------------------------

dt_bal <- readRDS(here("derived", "nfip-balanced.Rds"))

dt_bal <- dt_bal[mh == 1L & year_constr >= 1980L & year_constr <= 1999L]
dt_bal[, countyfp := substr(tractfp, 1, 5)]

# Map year_constr to Census-compatible vintage bins.
# 1990-1994 assigned to pre-treatment (conservative; HUD reform July 1994).
dt_bal[, vintage_census := fcase(
    year_constr >= 1999L,                         "1999_2000",
    year_constr >= 1995L & year_constr <= 1998L,  "1995_1998",
    year_constr >= 1990L & year_constr <= 1994L,  "1990_1994",
    year_constr >= 1980L & year_constr <= 1989L,  "1980_1989"
)]
dt_bal <- dt_bal[!is.na(vintage_census)]
dt_bal[, post1994 := vintage_census %in% c("1995_1998", "1999_2000")]

# ---------------------------------------------------------------------------
# 2. Aggregate to county × vintage ----
#
#   policies_n counts unique active policies per 5-year loss period;
#   divide by 5 to convert to annual policy-years before summing.
# ---------------------------------------------------------------------------

dt_welfare <- dt_bal[, .(
    claims_n            = sum(claims_n,            na.rm = TRUE),
    building_damage_tot = sum(building_damage_tot, na.rm = TRUE),
    contents_damage_tot = sum(contents_damage_tot, na.rm = TRUE),
    policy_years        = sum(policies_n / 51,      na.rm = TRUE)
), by = .(countyfp, vintage_census)]

dt_welfare[, post1994 := vintage_census %in% c("1995_1998", "1999_2000")]
dt_welfare[, vintage_census := factor(
    vintage_census,
    levels = c("1980_1989", "1990_1994", "1995_1998", "1999_2000")
)]

# ---------------------------------------------------------------------------
# 3. Per-unit damage rates ----
# ---------------------------------------------------------------------------

dt_welfare[, claim_rate_insured := fifelse(
    policy_years > 0, claims_n / policy_years, NA_real_
)]
dt_welfare[, building_damage_pa := fifelse(
    policy_years > 0, building_damage_tot / policy_years, NA_real_
)]
dt_welfare[, contents_damage_pa := fifelse(
    policy_years > 0, contents_damage_tot / policy_years, NA_real_
)]

# ---------------------------------------------------------------------------
# 4. Merge 2000 Census MH stock by county × vintage ----
# ---------------------------------------------------------------------------

dt_census <- readRDS(here("derived", "census2000-mh-county-vintage.Rds"))

dt_welfare <- merge(
    dt_welfare,
    dt_census[, .(
        countyfp,
        vintage_census = as.character(vintage_census),
        mh_units_2000    = mh_units,
        total_units_2000 = total_units
    )],
    by  = c("countyfp", "vintage_census"),
    all.x = TRUE
)
dt_welfare[, vintage_census := factor(
    vintage_census,
    levels = c("1980_1989", "1990_1994", "1995_1998", "1999_2000")
)]

message(sprintf(
    "County × vintage cells missing Census MH counts: %d of %d",
    dt_welfare[is.na(mh_units_2000), .N],
    nrow(dt_welfare)
))

setcolorder(dt_welfare, c(
    "countyfp", "vintage_census", "post1994",
    "mh_units_2000", "total_units_2000",
    "policy_years", "claims_n",
    "building_damage_tot", "contents_damage_tot",
    "claim_rate_insured",
    "building_damage_pa", "contents_damage_pa"
))
setorder(dt_welfare, countyfp, vintage_census)

saveRDS(dt_welfare, here("derived", "welfare-county-vintage.Rds"))
message(sprintf(
    "Saved welfare-county-vintage.Rds: %d county × vintage cells",
    nrow(dt_welfare)
))
