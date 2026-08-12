# Fake-data test for the MHS price event study (estimate-mhs.R).
#
# Simulates a state-year panel with a known treatment effect (states with
# wind zones II/III see a level shift in price starting in 1994) and
# confirms the production spec
#   price ~ i(year, treated, ref = 1993) | statefp + year
# recovers it, with flat, ~zero pre-trends.

library(data.table)
library(fixest)
library(testthat)

set.seed(20260811)

simulate_mhs_dgp <- function(
    n_state = 30, years = 1988:1999, true_effect = 4,
    state_sd = 3, year_shock_sd = 1, noise_sd = 1.5
) {
    dt_state <- data.table(statefp = seq_len(n_state))
    dt_state[, treated := statefp <= n_state / 2]
    dt_state[, state_fe := rnorm(.N, sd = state_sd)]

    dt_year <- data.table(year = years)
    dt_year[, year_fe := rnorm(.N, sd = year_shock_sd)]

    dt <- CJ(statefp = seq_len(n_state), year = years)
    dt <- merge(dt, dt_state, by = "statefp")
    dt <- merge(dt, dt_year, by = "year")

    dt[, treat_effect := ifelse(year >= 1994L, true_effect, 0) * treated]
    dt[, avg_sales_price := 20 + state_fe + year_fe + treat_effect +
        rnorm(.N, sd = noise_sd)]
    dt[]
}

dt <- simulate_mhs_dgp()

test_that("MHS price DiD recovers the true post-1994 treatment effect", {
    est <- feols(
        avg_sales_price ~ i(year, treated, ref = 1993) | statefp + year,
        data = dt, cluster = ~statefp
    )
    ct <- as.data.table(coeftable(est), keep.rownames = TRUE)
    ct <- ct[grepl(":treated$", rn)]
    ct[, yr := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]

    pre  <- ct[yr < 1994L]
    post <- ct[yr >= 1994L]

    expect_true(all(abs(pre$Estimate) < 2))
    expect_true(all(abs(post$Estimate - 4) < 2))
})
