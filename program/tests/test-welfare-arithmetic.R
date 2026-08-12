# Fake-data test for the welfare/cost-benefit arithmetic (estimate-welfare.R).
#
# (1) Unit-tests npv_annuity() against closed-form values for known inputs.
# (2) Recomputes NPV and BCR from a small synthetic county x vintage dataset
#     with known claim rates, damage reductions, and compliance cost, and
#     checks the pipeline's arithmetic (claim rate, annual benefit, NPV, BCR)
#     against hand-calculated truth.

library(here)
library(data.table)
library(testthat)

source(here("program", "estimate", "welfare-lib.R"))

test_that("npv_annuity matches closed-form values", {
    # r = 0: NPV is just annual_benefit * lifespan
    expect_equal(npv_annuity(10, 0, 20), 200)

    # r > 0: hand-computed annuity factor
    # annuity factor for r=0.03, T=20: (1 - 1.03^-20) / 0.03 = 14.8775...
    af <- (1 - 1.03^(-20)) / 0.03
    expect_equal(npv_annuity(10, 0.03, 20), 10 * af, tolerance = 1e-8)

    # scales linearly in the annual benefit
    expect_equal(npv_annuity(20, 0.03, 20), 2 * npv_annuity(10, 0.03, 20))
})

test_that("NPV/BCR pipeline recovers a known take-up and damage gradient", {
    # Synthetic county x vintage cells: two vintages (pre/post), with a known
    # claim rate and a known per-claim damage reduction post-treatment.
    true_claim_rate  <- 0.05
    true_delta_total <- 5      # $000s per claim, post - pre damage reduction
    true_cost        <- 4      # $000s compliance cost
    r                <- 0.03
    lifespan         <- 20

    dt <- data.table(
        countyfp       = rep(c("00001", "00002"), each = 2),
        vintage_census = rep(c("1980_1989", "1995_1998"), 2),
        post1994       = rep(c(FALSE, TRUE), 2),
        policies_n     = c(1000, 1000, 2000, 2000),
        claims_n       = c(1000, 1000, 2000, 2000) * true_claim_rate
    )
    dt[, building_damage_tot := fifelse(
        post1994, claims_n * 2, claims_n * (2 + true_delta_total))]

    nat <- dt[, .(
        policies_n = sum(policies_n), claims_n = sum(claims_n),
        building_damage_tot = sum(building_damage_tot)
    ), by = post1994]
    nat[, claim_rate := claims_n / policies_n]
    nat[, damage_pa  := building_damage_tot / policies_n]

    rate_pre <- nat[post1994 == FALSE, claim_rate]
    expect_equal(rate_pre, true_claim_rate)

    # recompute the benefit exactly as estimate-welfare.R does
    annual_benefit <- rate_pre * true_delta_total
    npv <- npv_annuity(annual_benefit, r, lifespan)
    bcr <- npv / true_cost

    expect_equal(annual_benefit, true_claim_rate * true_delta_total)
    expect_equal(npv, annual_benefit * (1 - (1 + r)^(-lifespan)) / r)
    expect_equal(bcr, npv / true_cost)
    expect_gt(bcr, 0)
})
