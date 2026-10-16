# Fake-data test for the Census 2000 quantity design (Chunk Q2).
# Counts are Poisson with a known MH x post x Zone III effect, a shock common
# to both housing types in Zone III counties after the reform, and county sizes
# that differ by orders of magnitude. Columns 3-4 (MH relative to site-built,
# county x bin absorbing the common shock) must recover the truth; column 1
# (MH only) is biased by the common shock, which is why the ladder reports both.

library(data.table)
library(fixest)
library(testthat)
library(here)
source(here("program", "estimate-census", "census-lib.R"))

simulate_census <- function(true_mh = -0.5, common = -0.3, n_county = 600, seed = 20261015) {
    set.seed(seed)
    bins <- c("1980_1989", "1990_1994", "1995_1998", "1999_2000")
    cty <- data.table(countyfp = sprintf("%05d", seq_len(n_county)),
                      statefp = sprintf("%02d", rep(1:20, length.out = n_county)),
                      size = exp(rnorm(n_county, 5, 1.5)))
    cty[, `:=`(z3 = as.integer(runif(.N) < .1), z2 = 0L)]
    x <- CJ(countyfp = cty$countyfp, bin = bins, mh = 0:1)
    x <- merge(x, cty, by = "countyfp")
    x[, post := as.integer(bin %in% c("1995_1998", "1999_2000"))]
    x[, mu := size * fifelse(mh == 1, .4, 1) * exp(common * post * z3 + true_mh * post * z3 * mh)]
    x[, homes := rpois(.N, mu)]
    x[, `:=`(post_z2 = 0L, post_z3 = post * z3, post_mh_z2 = 0L, post_mh_z3 = post * z3 * mh,
             z2_mh = 0L, z3_mh = z3 * mh)]
    x
}
z3_post <- function(k, x) {
    d <- if (k <= 2) x[mh == 1L] else x
    # No simulated Zone II county, so the Zone II regressor is dropped as collinear.
    unname(coef(fepois(ladder_formula(k), d, vcov = ~countyfp))[if (k <= 2) "post_z3" else "post_mh_z3"])
}

test_that("MH-relative-to-site-built columns recover the known effect", {
    x <- simulate_census()
    expect_equal(z3_post(3, x), -0.5, tolerance = 0.1)
    expect_equal(z3_post(4, x), -0.5, tolerance = 0.12)
})

test_that("MH-only columns absorb the common shock, as documented", {
    x <- simulate_census()
    expect_equal(z3_post(1, x), -0.8, tolerance = 0.1)
})

test_that("zero-effect placebo returns zero in the type-relative columns", {
    x <- simulate_census(true_mh = 0)
    expect_lt(abs(z3_post(3, x)), 0.1)
})

test_that("dynamic formula uses the requested reference bin", {
    f <- dynamic_formula(1, "1990_1994")
    expect_match(deparse(f, width.cutoff = 500), 'ref = "1990_1994"', fixed = TRUE)
})
