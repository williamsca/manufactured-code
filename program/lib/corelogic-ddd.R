# County x type absorbs MH x zone; county x sale-year absorbs zone/time effects.
# Zone x vintage FE retain every zone/vintage lower-order term, including in static DDD.
cl_ddd_formula <- function(by_zone = FALSE, dynamic = FALSE, controls = "", county_type = TRUE) {
    modifier <- if (by_zone) c("mh_z2", "mh_z3") else "mh_tr"
    rhs <- if (dynamic) paste(c("i(year_constr, mh, ref=c(1992,1993))",
        paste0("i(year_constr, ", modifier, ", ref=c(1992,1993))")), collapse = " + ") else
        paste(c("post_mh", paste0("post_", modifier), "mh_1994",
            sub("^mh", "mh_1994", modifier)), collapse = " + ")
    fe <- paste("countyfp^year_sale + year_constr^wind_zone +",
        if (county_type) "countyfp^mh" else "mh^wind_zone")
    as.formula(paste("log_price ~", rhs, controls, "|", fe))
}
