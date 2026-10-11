# Shared sale sample; optionally join the verified snapshot tract lookup.
cl_price_sample <- function(with_tracts = TRUE) {
    sales <- quote_path(file.path(input, "sales", "*.parquet"))
    tract_select <- tract_join <- ""
    if (with_tracts) {
        tract_dir <- Sys.getenv("CORELOGIC_TRACTS")
        if (!nzchar(tract_dir)) stop("Set CORELOGIC_TRACTS to the verified private lookup")
        tract_manifest <- fromJSON(file.path(tract_dir, "manifest.json"))
        if (!identical(tract_manifest$status, "complete") || !identical(tract_manifest$build, input))
            stop("Tract lookup must be complete and use the same build")
        lookup <- quote_path(file.path(tract_dir, "parcel_tracts.parquet"))
        tract_select <- ", t.tractfp"
        tract_join <- sprintf("LEFT JOIN read_parquet(%s) t ON s.clip=t.clip AND s.countyfp=t.countyfp", lookup)
    }
    dt <- read_corelogic(sprintf("SELECT s.countyfp, s.clip, s.mh, s.year_constr, s.year_sale,
        s.sale_price_2000%s FROM read_parquet(%s) s %s
        WHERE s.eligible_sale AND s.countyfp IS NOT NULL AND s.year_sale BETWEEN 2000 AND 2023
        AND s.year_constr BETWEEN 1989 AND 1999 AND s.date_sale >= MAKE_DATE(s.year_constr,1,1)",
        tract_select, sales, tract_join))
    stopifnot(!anyNA(dt$mh), !anyNA(dt$sale_price_2000), all(dt$sale_price_2000 > 0))
    dt[, `:=`(log_price = log(sale_price_2000), post_mh = mh * as.integer(year_constr >= 1994),
        statefp = substr(countyfp, 1, 2))]
    if (with_tracts) {
        dt[, tract_ok := !is.na(tractfp)]
        stopifnot(all(substr(dt[tract_ok == TRUE, tractfp], 1, 5) == dt[tract_ok == TRUE, countyfp]))
        fwrite(dt[, .(sales = .N, parcels = uniqueN(clip), tract_sales = sum(tract_ok),
            tract_coverage = mean(tract_ok)), by = .(mh, year_constr)], file.path(out_dir, "tract_coverage.csv"))
    }
    dt
}
