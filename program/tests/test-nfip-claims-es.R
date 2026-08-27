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

# ---------------------------------------------------------------------------
# Scale placebo (Chunk M diagnosis, Chunk O headline change).
#
# The paper states in "Why the estimates are proportional" that a dollar
# specification returns a large significant negative coefficient on data built
# with a treatment effect of exactly zero, while Poisson returns zero. That
# claim is load-bearing -- it is the reason the headline is proportional -- so
# it is verified here rather than asserted from a one-off diagnostic.
#
# The DGP has no treatment effect at all. What it does have is the two features
# of the real data that break the dollar specification: damage is MULTIPLICATIVE
# in a housing-type factor (site-built homes are worth about 2.4x manufactured
# ones), and the common vintage gradient is proportional rather than additive,
# so it moves the two housing types by different dollar amounts. A single
# additive MH fixed effect cannot absorb a gap that is proportional, and the
# treatment coefficient takes up the residual.
# ---------------------------------------------------------------------------

simulate_scale_dgp <- function(
    n_geo = 40, years_loss = 2004:2018, vintages = 1990:1996,
    ref_period = 1993L, n_per_cell = 8,
    base_damage = 12, mh_ratio = 1 / 2.4, vintage_gradient = 0.04,
    true_effect = 0
) {
    grid <- CJ(geo = seq_len(n_geo), year_loss = years_loss, mh = c(0L, 1L),
               period_constr = vintages, rep = seq_len(n_per_cell))

    geo_year <- CJ(geo = seq_len(n_geo), year_loss = years_loss)
    geo_year[, shock := exp(rnorm(.N, sd = 0.4))]
    grid <- merge(grid, geo_year, by = c("geo", "year_loss"))

    # every component is multiplicative, which is the point: the vintage
    # gradient is a PERCENTAGE common to both housing types, so in dollars it
    # is a much larger number for site-built homes than for manufactured ones
    grid[, mean_damage := base_damage * shock *
             ifelse(mh == 1L, mh_ratio, 1) *
             exp(vintage_gradient * (period_constr - ref_period)) *
             exp(true_effect * mh * (period_constr >= 1994L))]
    grid[, damage := rgamma(.N, shape = 2, scale = mean_damage / 2)]
    grid[, post1994 := as.integer(period_constr >= 1994L)]
    grid[, post_mh := post1994 * mh]
    grid[]
}

test_that("with a true effect of zero, the dollar spec is biased and Poisson is not", {
    dt <- simulate_scale_dgp(true_effect = 0)

    m_lvl <- feols(damage ~ post_mh | geo^year_loss + mh + post1994,
                   data = dt, cluster = ~geo)
    m_pois <- fepois(damage ~ post_mh | geo^year_loss + mh + post1994,
                     data = dt, cluster = ~geo)

    # the dollar coefficient is large, negative, and significant despite there
    # being no effect whatsoever -- stated relative to the MH mean so the
    # threshold does not depend on base_damage
    mh_mean <- dt[mh == 1L, mean(damage)]
    expect_lt(coef(m_lvl)[["post_mh"]], 0)
    expect_gt(abs(coef(m_lvl)[["post_mh"]]) / mh_mean, 0.05)
    expect_gt(abs(coef(m_lvl)[["post_mh"]] / se(m_lvl)[["post_mh"]]), 2)

    # Poisson recovers the truth
    expect_lt(abs(coef(m_pois)[["post_mh"]]), 0.02)
})

test_that("Poisson recovers a known proportional effect that the dollar spec misstates", {
    truth <- log(0.85)
    dt <- simulate_scale_dgp(true_effect = truth)

    m_pois <- fepois(damage ~ post_mh | geo^year_loss + mh + post1994,
                     data = dt, cluster = ~geo)
    expect_lt(abs(coef(m_pois)[["post_mh"]] - truth), 0.03)

    # The dollar estimate does not correspond to the true proportional effect
    # applied to the MH mean: it inherits the same bias the zero-effect case
    # isolates, and overstates the reduction.
    mh_pre_mean <- dt[mh == 1L & post1994 == 0L, mean(damage)]
    implied_true_dollars <- mh_pre_mean * (1 - exp(truth))
    m_lvl <- feols(damage ~ post_mh | geo^year_loss + mh + post1994,
                   data = dt, cluster = ~geo)
    expect_gt(abs(coef(m_lvl)[["post_mh"]]), implied_true_dollars)

    # and the conversion the paper uses -- Poisson coefficient times the
    # pre-period MH mean -- does recover the truth in dollars
    expect_lt(
        abs(mh_pre_mean * (1 - exp(coef(m_pois)[["post_mh"]])) -
            implied_true_dollars) / implied_true_dollars,
        0.10)
})
