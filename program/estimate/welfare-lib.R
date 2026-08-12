# Pure arithmetic used by estimate-welfare.R, factored out so it can be
# unit-tested (program/tests/test-welfare-arithmetic.R) without depending on
# the estimation output files or the rest of the welfare script.

# NPV of a constant annual benefit over `lifespan` years at discount rate `r`.
npv_annuity <- function(annual_benefit, r, lifespan) {
    if (r == 0) return(annual_benefit * lifespan)
    annual_benefit * (1 - (1 + r)^(-lifespan)) / r
}
