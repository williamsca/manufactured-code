# Shared sale sample: eligible 2000-2023 sales of homes built 1989-1999.
cl_price_sample <- function() {
    sales <- quote_path(file.path(input, "sales", "*.parquet"))
    dt <- read_corelogic(sprintf("SELECT s.countyfp, s.clip, s.mh, s.year_constr, s.year_sale,
        s.sale_price_2000 FROM read_parquet(%s) s
        WHERE s.eligible_sale AND s.countyfp IS NOT NULL AND s.year_sale BETWEEN 2000 AND 2023
        AND s.year_constr BETWEEN 1989 AND 1999 AND s.date_sale >= MAKE_DATE(s.year_constr,1,1)",
        sales))
    stopifnot(!anyNA(dt$mh), !anyNA(dt$sale_price_2000), all(dt$sale_price_2000 > 0))
    dt[, `:=`(log_price = log(sale_price_2000), post_mh = mh * as.integer(year_constr >= 1994),
        statefp = substr(countyfp, 1, 2))]
    dt
}
