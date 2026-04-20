# Back-of-envelope cost-benefit calculation for the 1994 HUD wind standard
#
# Uses county × vintage data from databuild-welfare.R, with vintage bins
# matching Census 2000 HCT006 (1980-1989, 1990-1994, 1995-1998, 1999-2000).
# 1990-1994 treated as pre-treatment throughout (conservative).
#
# Outputs four calculations:
#   1. Per-unit NPV for the purchaser of a post-1994 MH (private cost-benefit)
#   2. Total NFIP fiscal savings from post-1994 MH (insured claims in sample)
#   3. Total NFIP fiscal savings scaled to Census stock (all post-1994 MH)
#   4. Sensitivity grid over discount rate, lifespan, claim rate assumption
#
# Main input:   derived/welfare-county-vintage.Rds
# Point estimates from estimate-nfip.R (Table claims-outcomes):
#   delta_building: building damage reduction per claim ($000 real 2000)
#   delta_contents: contents damage reduction per claim ($000 real 2000)

rm(list = ls())
library(here)
library(data.table)

source(here("program", "import", "project-params.R"))

# ---------------------------------------------------------------------------
# Parameters ----
# ---------------------------------------------------------------------------

# Per-claim damage reductions from main regression (Table claims-outcomes)
DELTA_BUILDING <- 5  # $000 real 2000
DELTA_CONTENTS <- 2.0  # $000 real 2000

# Per-claim payment reductions for NFIP fiscal savings (section 5)
DELTA_BUILDING_PAYMENT <- 4.0  # $000 real 2000
DELTA_CONTENTS_PAYMENT <- .7  # $000 real 2000

# Compliance cost from MHS price event study
COST <- 5.0            # $000 real 2000

# Discount rates and home lifespan for NPV calculation
DISCOUNT_RATES <- c(0, 0.03, 0.07)
LIFESPANS      <- c(20, 30, 40)

# Census 2000 is used as MH stock denominator for unconditional rates.
# Policy panel spans roughly 1994-2014 (20 years) for pre-1994 vintages,
# shorter for post-1994 vintages as construction ramps up post-reform.
YEARS_COVERED <- 20L

# ---------------------------------------------------------------------------
# 1. Load and aggregate to national vintage-level totals ----
# ---------------------------------------------------------------------------

dt <- readRDS(here("derived", "welfare-county-vintage.Rds"))

nat <- dt[!is.na(claim_rate_insured) & !is.na(policies_n), .(
    policies_n        = sum(policies_n),
    claims_n            = sum(claims_n),
    building_damage_tot = sum(building_damage_tot),
    contents_damage_tot = sum(contents_damage_tot),
    mh_units_2000       = sum(mh_units_2000, na.rm = TRUE)
), by = .(vintage_census, post1994)]

nat[, claim_rate_insured := claims_n / policies_n]
nat[, building_damage_pa := building_damage_tot / policies_n]
nat[, contents_damage_pa := contents_damage_tot / policies_n]

cat("\n=== National aggregate by vintage ===\n")
print(nat[order(vintage_census), .(
    vintage_census,
    post1994,
    policies_n        = round(policies_n),
    claims_n,
    mh_units_2000,
    claim_rate_insured  = round(claim_rate_insured,  4),
    building_damage_pa  = round(building_damage_pa,  3),
    contents_damage_pa  = round(contents_damage_pa,  3)
)])

# ---------------------------------------------------------------------------
# 2. NFIP take-up by vintage ----
# ---------------------------------------------------------------------------

nat[, mh_stock_years := mh_units_2000 * YEARS_COVERED]
nat[, take_up := fifelse(
    mh_stock_years > 0,
    policies_n / mh_stock_years,
    NA_real_
)]

cat("\n=== NFIP take-up by vintage ===\n")
print(nat[order(vintage_census), .(
    vintage_census, post1994,
    mh_units_2000,
    policies_n = round(policies_n),
    take_up      = round(take_up, 3)
)])

# ---------------------------------------------------------------------------
# 3. Counterfactual claim rate for NPV calculation ----
#
#   Use the pre-1994 pooled insured claim rate (1980-1989 + 1990-1994) as the
#   counterfactual risk faced by a post-1994 MH absent the HUD standard.
#   This is conservative: older vintages may face somewhat higher hazard due
#   to siting in lower-lying areas. We also report 1990-1994 alone as an
#   alternative counterfactual (more similar construction vintage).
# ---------------------------------------------------------------------------

rate_pre_pooled <- nat[post1994 == FALSE, sum(claims_n) / sum(policies_n)]
rate_pre_9094   <- nat[vintage_census == "1990_1994", claim_rate_insured]

cat(sprintf(
    "\nCounterfactual claim rates (per policy-year):\n"
))
cat(sprintf("  Pre-1994 pooled: %.4f\n", rate_pre_pooled))
cat(sprintf("  1990-1994 only:  %.4f\n", rate_pre_9094))

# ---------------------------------------------------------------------------
# 4. Per-unit NPV for a post-1994 MH purchaser ----
# ---------------------------------------------------------------------------

npv_annuity <- function(annual_benefit, r, lifespan) {
    if (r == 0) return(annual_benefit * lifespan)
    annual_benefit * (1 - (1 + r)^(-lifespan)) / r
}

scenarios <- CJ(
    counterfactual = c("pooled_pre", "vintage_9094"),
    discount_rate  = DISCOUNT_RATES,
    lifespan       = LIFESPANS
)

scenarios[, claim_rate := fcase(
    counterfactual == "pooled_pre",   rate_pre_pooled,
    counterfactual == "vintage_9094", rate_pre_9094
)]
scenarios[, delta_total    := DELTA_BUILDING + DELTA_CONTENTS]
scenarios[, annual_benefit := claim_rate * delta_total]
scenarios[, npv_benefit    := mapply(npv_annuity, annual_benefit,
                                     discount_rate, lifespan)]
scenarios[, bcr := npv_benefit / COST]

cat("\n=== Per-unit NPV and benefit-cost ratio (r=0.03, T=30) ===\n")
cat(sprintf("Compliance cost: $%.0fk (real 2000)\n", COST * 1e3))
cat(sprintf(
    "Per-claim damage reduction: $%.0fk building, $%.0fk contents\n",
    DELTA_BUILDING * 1e3, DELTA_CONTENTS * 1e3
))
print(scenarios[discount_rate == 0.03 & lifespan == 20, .(
    counterfactual,
    claim_rate     = round(claim_rate,     4),
    annual_benefit = round(annual_benefit, 4),
    npv_benefit    = round(npv_benefit,    2),
    bcr            = round(bcr,            2)
)][order(counterfactual)])

cat("\n=== Full sensitivity grid ===\n")
print(scenarios[, .(
    counterfactual, discount_rate, lifespan,
    npv_benefit = round(npv_benefit, 2),
    bcr         = round(bcr,         2)
)][order(counterfactual, discount_rate, lifespan)])

# ---------------------------------------------------------------------------
# 5. NFIP fiscal savings from post-1994 MH claims in sample ----
#
#   Observed claims × per-claim reduction. Captures only insured MH claims
#   that actually occurred in the NFIP data; lower bound on NFIP savings.
# ---------------------------------------------------------------------------

post_claims_bldg <- nat[post1994 == TRUE, sum(claims_n)]

cat("\n=== NFIP fiscal savings: observed claims in sample ===\n")
cat(sprintf("Post-1994 MH claims in sample: %d\n", post_claims_bldg))
cat(sprintf("Building savings:  $%.1fM\n",
    post_claims_bldg * DELTA_BUILDING_PAYMENT / 1e3))
cat(sprintf("Contents savings:  $%.1fM\n",
    post_claims_bldg * DELTA_CONTENTS_PAYMENT / 1e3))
cat(sprintf("Total NFIP savings: $%.1fM\n",
    post_claims_bldg * (DELTA_BUILDING_PAYMENT + DELTA_CONTENTS_PAYMENT) / 1e3))

# ---------------------------------------------------------------------------
# 6. Total NFIP fiscal savings scaled to Census stock ----
#
#   Uses the Census 2000 count of post-1994 MH as the stock denominator and
#   the pre-1994 insured claim rate as counterfactual frequency. This assumes
#   post-1994 MH face the same underlying flood hazard as pre-1994 MH -- the
#   composition checks suggest post-1994 MH are *more* exposed (higher SFHA
#   share), so this is conservative. Damage reduction per claim is the
#   regression estimate applied to the pre-1994 claim frequency.
#
#   Note: this estimates savings to *all* MH (insured and uninsured), not
#   only NFIP payments. Uninsured MH owners bear losses privately; FEMA IA
#   and SBA programs partially cover them. The NFIP-specific share equals
#   the take-up-weighted portion.
# ---------------------------------------------------------------------------

mh_stock_post94 <- nat[post1994 == TRUE, sum(mh_units_2000, na.rm = TRUE)]
take_up_post94  <- nat[post1994 == TRUE,
    sum(policies_n) / sum(mh_stock_years, na.rm = TRUE)]

expected_claims_per_yr_pooled <- rate_pre_pooled * mh_stock_post94
expected_claims_per_yr_9094   <- rate_pre_9094   * mh_stock_post94

cat(sprintf("\n=== Total savings scaled to Census post-1994 MH stock ===\n"))
cat(sprintf("Post-1994 MH stock (Census 2000, occupied): %.0f units\n",
            mh_stock_post94))
cat(sprintf("Estimated NFIP take-up (post-1994 vintages): %.1f%%\n",
            take_up_post94 * 100))
cat(sprintf(
    "Expected flood claims/yr (pooled pre rate): %.0f\n",
    expected_claims_per_yr_pooled
))
cat(sprintf(
    "Expected flood claims/yr (1990-1994 rate):  %.0f\n",
    expected_claims_per_yr_9094
))

delta             <- DELTA_BUILDING + DELTA_CONTENTS
ann_saving_pooled <- expected_claims_per_yr_pooled * delta
ann_saving_9094   <- expected_claims_per_yr_9094   * delta
cat(sprintf(
    "Annual total savings (delta=$%.0fk): pooled=$%.2fM, 1990-94=$%.2fM\n",
    delta * 1e3,
    ann_saving_pooled / 1e3,
    ann_saving_9094   / 1e3
))
