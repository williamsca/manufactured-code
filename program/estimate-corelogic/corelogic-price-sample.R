# Shared sale sample: existing homes only, every eligible sale in a year after
# the parcel's own construction year. Sale years overlap the vintage window, so
# early sale years contain only older vintages.
CL_SALE_YEARS <- 1990L:2023L
cl_price_sample <- function() {
    if (manifest$min_sale_year > min(CL_SALE_YEARS) || manifest$max_sale_year < max(CL_SALE_YEARS))
        stop("Build sale years ", manifest$min_sale_year, "-", manifest$max_sale_year,
             " do not cover CL_SALE_YEARS")
    if (manifest$min_vintage > min(CL_VINTAGES) || manifest$max_vintage < max(CL_VINTAGES))
        stop("Build vintages ", manifest$min_vintage, "-", manifest$max_vintage,
             " do not cover CL_VINTAGES")
    sales <- quote_path(file.path(input, "sales", "*.parquet"))
    dt <- read_corelogic(sprintf("SELECT s.countyfp, s.clip, s.mh, s.year_constr, s.year_sale,
        s.sale_price_2000 FROM read_parquet(%s) s
        WHERE s.eligible_sale AND s.countyfp IS NOT NULL AND s.year_sale BETWEEN %d AND %d
        AND s.year_constr BETWEEN %d AND %d AND s.year_sale > s.year_constr",
        sales, min(CL_SALE_YEARS), max(CL_SALE_YEARS), min(CL_VINTAGES), max(CL_VINTAGES)))
    stopifnot(setequal(unique(dt$year_constr), CL_VINTAGES))
    stopifnot(!anyNA(dt$mh), !anyNA(dt$sale_price_2000), all(dt$sale_price_2000 > 0))
    stopifnot(all(dt$year_sale > dt$year_constr),
        all(dt$year_sale %in% CL_SALE_YEARS))
    dt[, `:=`(log_price = log(sale_price_2000), post_mh = mh * as.integer(year_constr >= 1994),
        statefp = substr(countyfp, 1, 2))]
    dt
}

# Real price in levels, winsorized at the 1st and 99th percentiles within each
# housing type; used only by the levels table. Returns the caps for export.
cl_price_level_winsor <- function(dt, probs = c(.01, .99)) {
    caps <- dt[, .(sales = .N, p_low = quantile(sale_price_2000, probs[1], names = FALSE),
        p_high = quantile(sale_price_2000, probs[2], names = FALSE)), by = mh]
    stopifnot(!anyDuplicated(caps$mh), nrow(caps) == 2L, all(caps$p_low < caps$p_high))
    dt[caps, price_level_w := pmin(pmax(sale_price_2000, i.p_low), i.p_high), on = "mh"]
    stopifnot(!anyNA(dt$price_level_w))
    caps[dt[, .(capped_low = sum(price_level_w > sale_price_2000), capped_high = sum(price_level_w < sale_price_2000),
        mean_raw = mean(sale_price_2000), mean_w = mean(price_level_w)), by = mh], on = "mh"]
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
    x[, valid_living := is.finite(log_living_area)]
    x[, valid_size := valid_living & is.finite(log_lot_size)]
    x
}
