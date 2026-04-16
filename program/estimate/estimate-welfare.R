# Back-of-envelope cost-benefit calculation for the 1994 HUD wind standard
#
# Three scenarios for the flood-damage benefit:
#   (A) Insured MH only: uses NFIP claim rate directly (upper bound on risk)
#   (B) All MH (unconditional): scales claim rate by NFIP take-up share,
#       applying insured damage rates to the full stock (lower bound)
#   (C) Sensitivity grid: varies discount rate, home lifespan, and
#       per-claim damage reduction
#
# Main inputs:
#   derived/welfare-county.Rds
#   Point estimates from estimate-nfip.R:
#     delta_building: treatment effect on building damage per claim ($000 real 2000)
#     delta_contents: treatment effect on contents damage per claim ($000 real 2000)
#
# Output: printed tables; no file saved (results go directly into paper)

rm(list = ls())
library(here)
library(data.table)

source(here("program", "import", "project-params.R"))

# ---------------------------------------------------------------------------
# Parameters ----
# ---------------------------------------------------------------------------

# Per-claim damage reductions from main estimates (Table claims-outcomes)
# Use range to bracket uncertainty
DELTA_BUILDING_LO <- 4.0   # $000 real 2000
DELTA_BUILDING_HI <- 7.0
DELTA_CONTENTS_LO <- 1.0
DELTA_CONTENTS_HI <- 2.0

# Compliance cost from MHS price event study
COST_LO <- 4.0             # $000 real 2000
COST_HI <- 5.0

# Discount rates and home lifespan for NPV calculation
DISCOUNT_RATES <- c(0, 0.03, 0.07)
LIFESPANS      <- c(20, 30, 40)      # years

# ---------------------------------------------------------------------------
# 1. Load data ----
# ---------------------------------------------------------------------------

dt <- readRDS(here("derived", "welfare-county.Rds"))

# ---------------------------------------------------------------------------
# 2. Aggregate to national averages ----
# ---------------------------------------------------------------------------

# Weighted mean claim rate (weight = policy-years) by vintage
nat_insured <- dt[!is.na(claim_rate_insured) & !is.na(policy_years), .(
    policy_years        = sum(policy_years),
    claims_n            = sum(claims_n),
    building_damage_tot = sum(building_damage_tot),
    contents_damage_tot = sum(contents_damage_tot),
    mh_units_2000       = sum(mh_units_2000, na.rm = TRUE)
), by = post1994]

nat_insured[, claim_rate_insured := claims_n / policy_years]
nat_insured[, building_damage_pa := building_damage_tot / policy_years]
nat_insured[, contents_damage_pa := contents_damage_tot / policy_years]

cat("\n=== Insured MH: national aggregate by vintage ===\n")
print(nat_insured[, .(
    post1994, policy_years, claims_n,
    claim_rate_insured   = round(claim_rate_insured, 4),
    building_damage_pa   = round(building_damage_pa, 3),
    contents_damage_pa   = round(contents_damage_pa, 3)
)])

# ---------------------------------------------------------------------------
# 3. Estimate NFIP take-up share to recover unconditional claim rate ----
#
#   take_up = policy_years / (mh_units_2000 × years_covered)
#   years_covered: 1994-2014 (20 years of policy data in sample)
#   This overstates take-up if the Census 2000 stock does not match the
#   stock in the NFIP sample years, but serves as a reasonable approximation.
# ---------------------------------------------------------------------------

YEARS_COVERED <- 20L   # 1994-2014 (approximate range of policy panel)

nat_insured[, mh_stock_years := mh_units_2000 * YEARS_COVERED]
nat_insured[, take_up := fifelse(
    mh_stock_years > 0,
    policy_years / mh_stock_years,
    NA_real_
)]

cat("\n=== Estimated NFIP take-up by vintage ===\n")
print(nat_insured[, .(
    post1994,
    mh_units_2000,
    policy_years,
    take_up = round(take_up, 3)
)])

# unconditional claim rate: multiply insured rate by take-up
nat_insured[, claim_rate_unconditional := claim_rate_insured * take_up]

# ---------------------------------------------------------------------------
# 4. NPV calculation for a range of parameters ----
# ---------------------------------------------------------------------------

npv_annuity <- function(annual_benefit, r, T) {
    if (r == 0) return(annual_benefit * T)
    annual_benefit * (1 - (1 + r)^(-T)) / r
}

scenarios <- CJ(
    claim_rate_type   = c("insured", "unconditional"),
    delta_type        = c("low", "high"),
    discount_rate     = DISCOUNT_RATES,
    lifespan          = LIFESPANS
)

# fill in claim rate and damage reduction
pre_rate_insured       <- nat_insured[post1994 == 0L, claim_rate_insured]
pre_rate_unconditional <- nat_insured[post1994 == 0L, claim_rate_unconditional]

scenarios[, claim_rate := fcase(
    claim_rate_type == "insured",       pre_rate_insured,
    claim_rate_type == "unconditional", pre_rate_unconditional
)]

scenarios[, delta_total := fcase(
    delta_type == "low",  DELTA_BUILDING_LO + DELTA_CONTENTS_LO,
    delta_type == "high", DELTA_BUILDING_HI + DELTA_CONTENTS_HI
)]

# annual expected benefit = claim_rate × per-claim damage reduction
scenarios[, annual_benefit := claim_rate * delta_total]

# NPV over home lifespan
scenarios[, npv_benefit := mapply(npv_annuity, annual_benefit, discount_rate, lifespan)]

# ratio to compliance cost
scenarios[, bcr_lo := npv_benefit / COST_HI]   # conservative: low benefit / high cost
scenarios[, bcr_hi := npv_benefit / COST_LO]   # optimistic:   high benefit / low cost

cat("\n=== NPV of flood benefits and benefit-cost ratios ===\n")
cat(sprintf(
    "Compliance cost: $%.0f-$%.0fk (real 2000)\n",
    COST_LO * 1000, COST_HI * 1000
))
cat(sprintf(
    "Per-claim damage reduction: $%.0f-$%.0fk building + $%.0f-$%.0fk contents\n",
    DELTA_BUILDING_LO * 1000, DELTA_BUILDING_HI * 1000,
    DELTA_CONTENTS_LO * 1000, DELTA_CONTENTS_HI * 1000
))

print(scenarios[discount_rate == 0.03 | lifespan == 30, .(
    claim_rate_type, delta_type, discount_rate, lifespan,
    annual_benefit = round(annual_benefit, 4),
    npv_benefit    = round(npv_benefit, 2),
    bcr_lo         = round(bcr_lo, 2),
    bcr_hi         = round(bcr_hi, 2)
)][order(claim_rate_type, delta_type, discount_rate, lifespan)])

# ---------------------------------------------------------------------------
# 5. Aggregate fiscal spillover ----
#
#   Total NFIP savings = delta × claims filed by post-1994 MH over sample
# ---------------------------------------------------------------------------

post_claims <- nat_insured[post1994 == 1L, claims_n]

cat("\n=== Fiscal spillover (total NFIP savings from post-1994 MH claims) ===\n")
cat(sprintf(
    "Post-1994 MH claims in sample: %d\n",
    post_claims
))
cat(sprintf(
    "Estimated total NFIP savings: $%.1fM - $%.1fM\n",
    post_claims * (DELTA_BUILDING_LO + DELTA_CONTENTS_LO) / 1000,
    post_claims * (DELTA_BUILDING_HI + DELTA_CONTENTS_HI) / 1000
))
