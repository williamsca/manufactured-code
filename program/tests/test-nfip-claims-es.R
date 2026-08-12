# Fake-data test for the main NFIP claim-level event study (estimate-nfip.R).
#
# Simulates claim-level building-damage data with a known data-generating
# process: MH x post-1994 treatment effect, a common (MH-and-site-built)
# construction-vintage profile, and geography x loss-year shocks. Confirms
# the production spec
#   Y ~ i(period_constr, mh, ref = ref_period) | geo^year_loss + mh + period_constr
# recovers the true treatment effect, and demonstrates that dropping the
# common vintage FE (period_constr) biases the MH-vintage coefficients,
# because the common vintage trend then has nowhere else to go but into the
# MH-interacted dummies.

library(data.table)
library(fixest)
library(testthat)

set.seed(20260811)

simulate_claims_dgp <- function(
    n_geo = 20, years_loss = 2004:2018,
    vintages = 1990:1996, ref_period = 1993L,
    true_effect = -5, common_vintage_slope = 2, mh_fe = -3,
    n_per_cell = 4, noise_sd = 2
) {
    grid <- CJ(
        geo         = seq_len(n_geo),
        year_loss   = years_loss,
        mh          = c(0L, 1L),
        period_constr = vintages,
        rep         = seq_len(n_per_cell)
    )

    # geography x loss-year shocks: common storm severity, independent of mh/vintage
    geo_year <- CJ(geo = seq_len(n_geo), year_loss = years_loss)
    geo_year[, shock := rnorm(.N, sd = 5)]
    grid <- merge(grid, geo_year, by = c("geo", "year_loss"))

    # common vintage profile: same trend for MH and site-built (the thing
    # that a vintage FE must absorb to avoid contaminating the MH estimates)
    grid[, common_vintage := common_vintage_slope * (period_constr - ref_period)]

    # true, MH-specific treatment effect: zero pre-1994 (parallel trends),
    # constant true_effect post-1994
    grid[, treat_effect := ifelse(period_constr >= 1994L, true_effect, 0) * mh]

    grid[, building_damage :=
        shock + common_vintage + mh_fe * mh + treat_effect +
        rnorm(.N, sd = noise_sd)]

    grid[]
}

dt <- simulate_claims_dgp()
ref_period <- 1993L

test_that("correctly specified spec recovers the true MH x post-1994 effect", {
    est <- feols(
        building_damage ~ i(period_constr, mh, ref = ref_period) |
            geo^year_loss + mh + period_constr,
        data = dt
    )
    ct <- as.data.table(coeftable(est), keep.rownames = TRUE)
    ct <- ct[grepl(":mh$", rn)]
    ct[, period := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]

    pre  <- ct[period < 1994L]
    post <- ct[period >= 1994L]

    # pre-period coefficients recover the (zero) parallel-trends truth
    expect_true(all(abs(pre$Estimate) < 1.5))
    # post-period coefficients recover the true treatment effect (-5)
    expect_true(all(abs(post$Estimate - (-5)) < 1.5))
})

test_that("omitting the common-vintage FE biases the MH-vintage coefficients", {
    est_bad <- feols(
        building_damage ~ i(period_constr, mh, ref = ref_period) |
            geo^year_loss + mh,
        data = dt
    )
    ct <- as.data.table(coeftable(est_bad), keep.rownames = TRUE)
    ct <- ct[grepl(":mh$", rn)]
    ct[, period := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]

    post <- ct[period >= 1994L]
    # the common vintage trend (slope 2/yr, shared by both groups) leaks
    # into the mh-interacted dummies once period_constr is dropped, so the
    # average recovered "effect" is contaminated and no longer close to -5;
    # averaging over post periods cancels sampling noise so the check is
    # about the trend contamination, not a single noisy draw
    expect_true(abs(mean(post$Estimate) - (-5)) > 2)
})
