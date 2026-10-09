# Vintage price formulas, shared with the synthetic identification checks.
cl_price_formula <- function(fe, controls = "", dynamic_fit = TRUE) {
    rhs <- if (dynamic_fit) "i(year_constr, mh, ref = c(1992,1993))" else "post_mh + mh_1994"
    as.formula(paste("log_price ~", rhs, controls, "|", fe))
}
