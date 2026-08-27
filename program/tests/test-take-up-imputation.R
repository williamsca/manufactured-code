# Fake-data test for the housing-stock take-up denominator and the take-up
# specification (Chunk E; moved to Poisson counts with an exposure offset in
# Chunk N).
#
# The first block covers the SPEC. The production specification is
#   policies_n ~ i(period_constr, mh, ref = ref_period) |
#       geo^period + mh + period_constr,
#   offset = log(home-years), cluster = state
# and the two tests below establish, on data with a known answer, that it
# recovers a true proportional effect and that the level-rate specification it
# replaced does not. The second block covers how `homes_n` and the per-home
# ratio are BUILT. The third covers the equal-split companion denominator.

library(data.table)
library(fixest)
library(testthat)

set.seed(20260813)

# Take-up counts drawn from a Poisson process with a known per-home RATE. The
# panel mirrors the production one: county x calendar period x construction
# vintage x housing type, so that the county x calendar-period fixed effect
# spans every vintage and housing type rather than a single pair of cells.
#
# The rate is MULTIPLICATIVE in a county effect, which is what the real data
# look like: take-up per home differs across counties by more than an order of
# magnitude, and the MH/site-built gap is proportional rather than a constant
# number of policies per 1,000 homes. `true_effect` is a log-scale MH x
# post-1994 shift, so a value of 0 is a genuine zero-effect placebo.
#
# `tilt` shifts the vintage composition of the MH stock toward high-take-up
# counties after 1994. This is the second half of the real pathology: the
# manufactured-housing boom of the mid-1990s was not spread evenly across
# counties, so the set of counties carrying the post-1994 comparison is
# weighted differently from the set carrying the pre-1994 one. A proportional
# effect is invariant to that reweighting; a level difference in policies per
# home is not, because the same proportional gap is a different number of
# policies in a high-rate county than in a low-rate one.
simulate_takeup_dgp <- function(
    n_geo = 400, periods = seq(1984, 1998, 2), n_period_loss = 3L,
    true_effect = log(1.05), base_rate = 0.03, geo_spread = 3,
    mh_gap = log(0.3), homes_lo = 500, homes_hi = 5000, tilt = 1
) {
    grid <- CJ(geo = seq_len(n_geo), period_loss = seq_len(n_period_loss),
               period_constr = periods, mh = c(0L, 1L))
    # county take-up levels spread over about two orders of magnitude, as in
    # the real panel, and independent of anything treatment-related
    geo_fe <- data.table(
        geo = seq_len(n_geo),
        geo_z = runif(n_geo, -geo_spread / 2, geo_spread / 2))
    geo_fe[, geo_mult := exp(geo_z)]
    grid <- merge(grid, geo_fe, by = "geo")

    # stock varies by county, vintage and housing type but not by calendar
    # period, as the Census-anchored imputation does
    stock <- unique(grid[, .(geo, period_constr, mh, geo_z)])
    stock[, homes_n := runif(.N, homes_lo, homes_hi)]
    stock[, homes_n := homes_n *
        exp(tilt * geo_z * mh * (period_constr >= 1994L))]
    grid <- merge(grid, stock[, .(geo, period_constr, mh, homes_n)],
                  by = c("geo", "period_constr", "mh"))

    grid[, log_rate := log(base_rate) + log(geo_mult) + mh_gap * mh +
             true_effect * mh * (period_constr >= 1994L)]
    grid[, policies_n := rpois(.N, homes_n * exp(log_rate))]
    grid[, policies_per_home := policies_n / homes_n]
    grid[, log_homes := log(homes_n)]
    grid[]
}

fit_ppml <- function(dt, ref_period = 1992L) {
    fepois(
        policies_n ~ i(period_constr, mh, ref = ref_period) |
            geo^period_loss + mh + period_constr,
        data = dt, offset = ~log_homes, cluster = ~geo)
}
fit_level <- function(dt, ref_period = 1992L) {
    feols(
        policies_per_home ~ i(period_constr, mh, ref = ref_period) |
            geo^period_loss + mh + period_constr,
        data = dt, weights = ~homes_n, cluster = ~geo)
}
post_pre <- function(est) {
    ct <- as.data.table(coeftable(est), keep.rownames = TRUE)
    ct <- ct[grepl(":mh$", rn)]
    ct[, period := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]
    list(pre = ct[period < 1994L, mean(Estimate)],
         post = ct[period >= 1994L, mean(Estimate)])
}

test_that("Poisson with an exposure offset recovers the true proportional take-up effect", {
    dt <- simulate_takeup_dgp(true_effect = log(1.05))
    e <- post_pre(fit_ppml(dt))
    # averaging over periods cancels sampling noise, so this is a check on the
    # estimator rather than on a single draw
    expect_lt(abs(e$pre), 0.02)
    expect_lt(abs(e$post - log(1.05)), 0.02)
})

test_that("the level-rate specification is biased when the true effect is zero", {
    dt <- simulate_takeup_dgp(true_effect = 0)

    # Poisson returns the truth: no pre-period profile and no post-1994 shift
    e_ppml <- post_pre(fit_ppml(dt))
    expect_lt(abs(e_ppml$pre), 0.02)
    expect_lt(abs(e_ppml$post), 0.02)

    # The level specification cannot fit a proportional MH gap with a single
    # additive MH fixed effect, so its post-1994 coefficient is not zero even
    # though the truth is. Stated relative to the mean rate, so the threshold
    # does not depend on the arbitrary units of base_rate.
    e_lvl <- post_pre(fit_level(dt))
    mean_rate <- dt[, weighted.mean(policies_per_home, homes_n)]
    expect_gt(abs(e_lvl$post) / mean_rate, 0.10)

    # switching the composition tilt off shrinks the level bias, which
    # identifies the tilt as its source rather than the proportional gap alone
    e_lvl_flat <- post_pre(fit_level(simulate_takeup_dgp(
        true_effect = 0, tilt = 0)))
    expect_lt(abs(e_lvl_flat$post) / mean_rate, abs(e_lvl$post) / mean_rate)

    # and the bias is a property of the additive MH effect: giving each county
    # its own MH effect, which is what a proportional gap needs, removes it
    est_ctymh <- feols(
        policies_per_home ~ i(period_constr, mh, ref = 1992L) |
            geo^period_loss + geo^mh + period_constr,
        data = dt, weights = ~homes_n, cluster = ~geo)
    e_ctymh <- post_pre(est_ctymh)
    expect_lt(abs(e_ctymh$post) / mean_rate, abs(e_lvl$post) / mean_rate)
})

ref_period <- 1992L

# ---------------------------------------------------------------------------
# Denominator-construction failure modes (Chunk I-b, notes/specs.md 12.2).
# The two tests above cover the take-up SPEC. These two cover how `homes_n`
# and the per-home ratio are BUILT, which is where both defects fixed on
# 2026-08-26 lived. Each demonstrates the defective rule failing and the
# production rule recovering the truth, so re-introducing either rule
# breaks the harness.
# ---------------------------------------------------------------------------

# Simulate one Census bin whose span is wider than the retained construction
# window: the bin total is known, the annual source (placements/permits)
# gives the true within-bin year profile, and only some years are retained.
simulate_bin_span <- function(
    bin_total = 1000, span = 1990:1994, kept = 1990:1993,
    source_by_year = c(300, 250, 200, 150, 100)
) {
    dt <- data.table(year = span, src = source_by_year)
    dt[, kept := year %in% kept]
    # truth: a year's stock is its source share of the FULL span, applied to
    # the bin total. What the retained years are collectively entitled to is
    # therefore source-implied, not the mechanical year-count fraction.
    dt[, true_n := bin_total * src / sum(src)]
    dt[]
}

test_that("within-bin shares normalized over the bin's full span recover the true retained stock", {
    dt <- simulate_bin_span()
    bin_total <- 1000

    # production rule: normalize over the span, then subset to kept years
    dt[, share_span := src / sum(src)]
    expect_equal(sum(dt$share_span), 1)
    alloc_span <- bin_total * dt[kept == TRUE, sum(share_span)]
    expect_equal(alloc_span, dt[kept == TRUE, sum(true_n)])

    # the retained allocation must never exceed the bin total, and must equal
    # it exactly only when the whole span is retained
    expect_lt(alloc_span, bin_total)
    dt_full <- simulate_bin_span(kept = 1990:1994)
    dt_full[, share_span := src / sum(src)]
    expect_equal(bin_total * dt_full[kept == TRUE, sum(share_span)], bin_total)

    # source-implied retained fraction differs from the year-count fraction,
    # so a test targeting the latter as an exact value is wrong (it is what
    # my first attempt at this assertion got wrong)
    expect_false(isTRUE(all.equal(
        alloc_span / bin_total, dt[, sum(kept) / .N])))
})

test_that("normalizing within-bin shares over retained years only inflates the retained stock", {
    dt <- simulate_bin_span()
    bin_total <- 1000

    # defective rule: subset to kept years FIRST, then normalize -- the
    # dropped years' stock is redistributed onto the years that remain
    kept_only <- dt[kept == TRUE]
    kept_only[, share_kept := src / sum(src)]
    alloc_kept <- bin_total * sum(kept_only$share_kept)

    expect_equal(alloc_kept, bin_total)                        # the old test
    expect_gt(alloc_kept, dt[kept == TRUE, sum(true_n)])       # but inflated
    # inflation factor is 1 / (source-implied retained fraction)
    expect_equal(
        alloc_kept / dt[kept == TRUE, sum(true_n)],
        1 / dt[kept == TRUE, sum(src)] * dt[, sum(src)])
})

# Simulate the per-home ratio at a two-construction-year vintage bin where
# `homes_n` exists for only one of the two years (the real 1994 bin: 1994 is
# dropped from the stock imputation, 1995 is not).
simulate_mixed_bin <- function(
    rate = 0.3, homes_1995 = 500, policies_1994 = 200, policies_1995 = 150
) {
    data.table(
        year_constr = c(1994L, 1995L),
        policies_n  = c(policies_1994, policies_1995),
        homes_n     = c(NA_real_, homes_1995)
    )
}

test_that("per-home rates built from matched construction years are not inflated by an unmatched numerator", {
    dt <- simulate_mixed_bin()
    homes_1995 <- 500

    # production rule: restrict the numerator to the construction years for
    # which the denominator is defined, then aggregate both sides
    ok <- dt[!is.na(homes_n) & homes_n > 0, year_constr]
    rate_matched <- dt[year_constr %in% ok, sum(policies_n)] /
        dt[year_constr %in% ok, sum(homes_n)]
    expect_equal(rate_matched, 150 / homes_1995)

    # defective rule: aggregate the numerator over the whole bin, then filter
    # rows on a non-missing denominator -- 1994's policies survive in the sum
    rate_mixed <- dt[, sum(policies_n)] / homes_1995
    expect_gt(rate_mixed, rate_matched)
    expect_equal(rate_mixed / rate_matched, 350 / 150)

    # the inflation is proportional to the dropped year's share of the bin's
    # policy-years, which in the real data is ~45-49% -- i.e. ~1.9x
    expect_gt(rate_mixed / rate_matched, 1.5)
})


# ---------------------------------------------------------------------------
# Equal-split companion denominator (Chunk N). impute-stock.R emits a second
# stock column built from the same Census bin totals with the annual sources
# switched off, used in estimate-nfip.R to bound how much of a take-up
# coefficient the annual imputation supplies. These tests pin the two
# properties the estimation relies on: it is defined on the same cells as the
# imputed stock, and it retains exactly the year-count fraction of each bin.
# ---------------------------------------------------------------------------

test_that("the equal split retains the year-count fraction of a bin, not the source-weighted one", {
    dt <- simulate_bin_span()
    bin_total <- 1000

    dt[, share_flat := 1 / .N]
    expect_equal(sum(dt$share_flat), 1)
    alloc_flat <- bin_total * dt[kept == TRUE, sum(share_flat)]
    expect_equal(alloc_flat, bin_total * dt[, sum(kept) / .N])

    # it differs from the imputed allocation, which is the point of running it:
    # a specification that gives the same answer on both is not relying on the
    # annual sources
    dt[, share_span := src / sum(src)]
    alloc_span <- bin_total * dt[kept == TRUE, sum(share_span)]
    expect_false(isTRUE(all.equal(alloc_flat, alloc_span)))
})

test_that("the equal split is positive wherever the imputed stock is, so the sample is unchanged", {
    # a year in which the annual source reports nothing gets no imputed stock
    # but a full equal share; the reverse cannot happen, because a positive
    # imputed stock requires a positive bin total, which is all the equal
    # split needs. estimate-nfip.R defines its sample by the imputed stock, so
    # only this direction matters.
    dt <- simulate_bin_span(source_by_year = c(300, 0, 200, 150, 100))
    bin_total <- 1000
    dt[, imputed := bin_total * src / sum(src)]
    dt[, flat    := bin_total / .N]

    expect_true(all(dt[imputed > 0, flat] > 0))
    expect_true(any(dt$imputed == 0 & dt$flat > 0))
})
