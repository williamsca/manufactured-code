# Fake-data test for the housing-stock take-up denominator (Chunk E,
# estimate-nfip.R's homes_n-weighted OLS take-up spec).
#
# Simulates a geo x period_constr x mh panel where `policies_n` is drawn
# from a Poisson process with a known per-home RATE (flat pre-1994, a
# known MH x post-1994 level shift) applied to a `homes_n` stock -- and
# where a small share of cells have a near-zero imputed stock (as some
# real county x period x mh cells do, mostly in the flagged 1994
# construction-year bin), producing extreme `policies_per_home` ratios.
# Confirms the production spec
#   policies_per_home ~ i(period_constr, mh, ref = ref_period) |
#       geo^period + mh + period_constr,
#   weights = homes_n, cluster = geo
# recovers the true level effect despite those outlier cells, and
# demonstrates that dropping the homes_n weights lets a handful of
# near-zero-stock cells dominate the fit -- the reason the take-up spec is
# weighted (TODO.md Chunk E).

library(data.table)
library(fixest)
library(testthat)

set.seed(20260813)

simulate_takeup_dgp <- function(
    n_geo = 60, periods = seq(1984, 1998, 2), ref_period = 1992L,
    true_effect = 0.05, base_rate = 0.3, thin_share = 0.02,
    homes_lo = 150, homes_hi = 400, thin_lo = 0.05, thin_hi = 0.5
) {
    grid <- CJ(geo = seq_len(n_geo), period_constr = periods, mh = c(0L, 1L))

    grid[, thin := runif(.N) < thin_share]
    grid[, homes_n := fifelse(
        thin, runif(.N, thin_lo, thin_hi), runif(.N, homes_lo, homes_hi))]

    grid[, true_rate := base_rate + ifelse(period_constr >= 1994L, true_effect, 0) * mh]
    grid[, policies_n := rpois(.N, homes_n * true_rate)]
    grid[, policies_per_home := policies_n / homes_n]
    grid[]
}

dt <- simulate_takeup_dgp()
ref_period <- 1992L

test_that("homes_n-weighted OLS recovers the true post-1994 policies-per-home level effect", {
    est <- feols(
        policies_per_home ~ i(period_constr, mh, ref = ref_period) |
            geo^period_constr + mh + period_constr,
        data = dt, weights = ~homes_n, cluster = ~geo
    )
    ct <- as.data.table(coeftable(est), keep.rownames = TRUE)
    ct <- ct[grepl(":mh$", rn)]
    ct[, period := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]

    pre  <- ct[period < 1994L]
    post <- ct[period >= 1994L]

    # averaging over periods cancels sampling noise so the check is about
    # whether the thin-stock outliers are neutralized, not a single draw
    expect_true(abs(mean(pre$Estimate)) < 0.02)
    expect_true(abs(mean(post$Estimate) - 0.05) < 0.02)
})

test_that("unweighted OLS is distorted by near-zero-stock outlier cells", {
    est_unw <- feols(
        policies_per_home ~ i(period_constr, mh, ref = ref_period) |
            geo^period_constr + mh + period_constr,
        data = dt, cluster = ~geo
    )
    ct <- as.data.table(coeftable(est_unw), keep.rownames = TRUE)
    ct <- ct[grepl(":mh$", rn)]
    ct[, period := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]

    pre <- ct[period < 1994L]
    # thin cells (homes_n well under 1) can produce policies_per_home
    # ratios in the tens even though the true rate is ~0.3; with equal
    # weight per cell, this pulls the (true zero) pre-period dummies away
    # from zero -- the same failure mode as the take-up table before it
    # was weighted by homes_n
    expect_true(abs(mean(pre$Estimate)) > 0.02)
})
