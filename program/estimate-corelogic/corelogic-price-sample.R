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

# Dedicated living area and lot area from the pinned snapshot, not universal
# building area. Join only the sale keys, with county agreement and no expansion.
cl_price_size_controls <- function(dt) {
    pb_source <- Sys.getenv("CORELOGIC_PB_SOURCE")
    if (!nzchar(pb_source) || basename(pb_source) != manifest$pb_version)
        stop("Set CORELOGIC_PB_SOURCE to the pinned Property Basic version")
    meta <- fromJSON(file.path(pb_source, "_meta.json"))
    stopifnot(meta$n_rows == manifest$pb_source_rows)
    con <- dbConnect(duckdb())
    on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)
    dbExecute(con, sprintf("SET threads=%d", threads))
    dbExecute(con, "SET memory_limit='16GB'")
    dbWriteTable(con, "sale_keys", unique(dt[, .(clip, countyfp)]))
    sizes <- as.data.table(dbGetQuery(con, sprintf("SELECT k.clip, k.countyfp,
        p.living_square_feet_all_buildings AS living_area,
        p.land_square_footage AS lot_size
        FROM sale_keys k LEFT JOIN read_parquet(%s) p
        ON k.clip=p.clip AND k.countyfp=p.countyfp",
        quote_path(file.path(pb_source, "*.parquet")))))
    stopifnot(!anyDuplicated(sizes, by = c("clip", "countyfp")))
    n_before <- nrow(dt)
    x <- merge(dt, sizes, by = c("clip", "countyfp"), all.x = TRUE, sort = FALSE)
    stopifnot(nrow(x) == n_before)
    x[, `:=`(log_living_area = log(fifelse(is.finite(living_area) & living_area > 0,
        living_area, NA_real_)), log_lot_size = log(fifelse(is.finite(lot_size) & lot_size > 0,
        lot_size, NA_real_)))]
    x[, valid_size := is.finite(log_living_area) & is.finite(log_lot_size)]
    x
}
