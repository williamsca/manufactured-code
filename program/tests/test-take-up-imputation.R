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
