# Native fixest LaTeX table for the three static price III-minus-I models.
cl_price_static_table <- function(models, out_dir) {
    ids <- c("baseline_static", "tract_static", "tract_size_static")
    fits <- models[ids]
    stopifnot(length(fits) == 3L, !any(vapply(fits, is.null, logical(1))))
    etable(fits, tex = TRUE, file = file.path(out_dir, "static_III_minus_I.tex"), replace = TRUE,
        keep = "%post_mh_z3", digits = 4, fitstat = "n",
        style.tex = style.tex(tablefoot = FALSE),
        headers = c("Baseline", "+ Tract FE", "+ Size controls"),
        dict = c(log_price = "Log sale price", post_mh_z3 = "Zone III $\\times$ MH $\\times$ post",
            "countyfp^year_sale" = "County $\\times$ sale year", "countyfp^mh" = "County $\\times$ housing type",
            "post^wind_zone" = "Zone $\\times$ pre/post", tractfp = "Census tract"),
        group = list("Log lot size and living area" = "%log_lot|log_living"),
        notes = NULL)
}
