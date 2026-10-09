# All licensed records stay on a Rivanna compute node. Export only aggregates.
cl_price_formula <- function(fe, controls = "", dynamic_fit = TRUE) {
    rhs <- if (dynamic_fit) "i(year_constr, mh, ref = c(1992,1993))" else "post_mh + mh_1994"
    as.formula(paste("log_price ~", rhs, controls, "|", fe))
}
main <- function() {
    if (!nzchar(Sys.getenv("SLURM_JOB_ID"))) stop("Run on Rivanna in Slurm.")
    library(DBI); library(duckdb); library(data.table); library(fixest)
    library(ggplot2); library(jsonlite)
    input <- Sys.getenv("CORELOGIC_BUILD")
    out <- Sys.getenv("CORELOGIC_RESULTS")
    if (!nzchar(input) || !nzchar(out)) stop("Set CORELOGIC_BUILD and CORELOGIC_RESULTS")
    manifest <- fromJSON(file.path(input, "manifest.json"))
    if (!identical(manifest$status, "complete")) stop("Incomplete build")
    verification <- fromJSON(file.path(input, "audit", "verification.json"))
    if (!isTRUE(verification$ok)) stop("Build verification has not passed")
    if (dir.exists(out)) stop("Results already exist: ", out)
    dir.create(out, recursive = TRUE)
    write_json(list(status = "running", input = input), file.path(out, "manifest.json"))
    threads <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", "8"))
    setFixest_nthreads(threads)
    con <- dbConnect(duckdb())
    on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)
    dbExecute(con, sprintf("SET threads=%d", threads))
    dbExecute(con, "SET memory_limit='16GB'")
    glob <- gsub("'", "''", file.path(input, "sales", "*.parquet"), fixed = TRUE)
    d <- as.data.table(dbGetQuery(con, sprintf("SELECT countyfp, clip, mh, year_constr,
        year_sale, date_sale, sale_amount, sale_price_2000, eligible_sale,
        analysis_ready AS analysis_ready_legacy,
        consideration_documented, pb_sqft, pb_lot_sqft, latitude, longitude,
        pb_matched, snapshot_type_differs, snapshot_vintage_differs
        FROM read_parquet('%s') WHERE countyfp IS NOT NULL
        AND date_sale >= MAKE_DATE(year_constr,1,1)", glob)))
    stopifnot(!anyNA(d$mh), all(d$sale_price_2000 > 0), !anyNA(d$sale_price_2000))
    stopifnot(all(d$eligible_sale))
    # The persisted legacy flag excludes 1994; eligibility plus the date guard
    # keeps the transition cohort while retaining every other production screen.
    d[, `:=`(analysis_ready = eligible_sale, log_price = log(sale_price_2000),
             post_mh = mh * as.integer(year_constr >= 1995), mh_1994 = mh * (year_constr == 1994),
             statefp = substr(countyfp, 1, 2),
             sizes_ok = pb_sqft >= 200 & pb_sqft <= 10000 & pb_lot_sqft >= 100 & pb_lot_sqft <= 4356000)]
    d[is.na(sizes_ok), sizes_ok := FALSE]
    d[, `:=`(log_sqft = log(pmax(pb_sqft, 1)), log_lot = log(pmax(pb_lot_sqft, 1)))]
    fwrite(d[, .(sales = .N, parcels = uniqueN(clip), counties = uniqueN(countyfp),
        median_price_2000 = median(sale_price_2000), size_coverage = mean(sizes_ok),
        coordinate_coverage = mean(!is.na(latitude) & !is.na(longitude)),
        snapshot_match = mean(pb_matched)), by = .(mh, year_constr, analysis_ready)],
        file.path(out, "sample_by_vintage.csv"))
    fwrite(d[analysis_ready == TRUE, .(sales = .N), by = .(mh, year_sale)],
        file.path(out, "sample_by_sale_year.csv"))
    dynamic <- list(); static <- list(); models <- list()
    fit <- function(id, rows, fe, controls = "", dynamic_fit = TRUE) {
        x <- d[which(rows)]
        cat("Estimating", id, "N=", nrow(x), "\n")
        f <- cl_price_formula(fe, controls, dynamic_fit)
        m <- feols(f, data = x, vcov = ~countyfp, mem.clean = TRUE, lean = TRUE)
        tab <- as.data.table(coeftable(m), keep.rownames = "term")
        setnames(tab, names(tab)[2:5], c("estimate", "se", "t", "p"))
        ci <- confint(m)
        tab[, `:=`(ci_low = ci[term, 1], ci_high = ci[term, 2], specification = id,
            n = nobs(m), mh_input = sum(x$mh), counties_input = uniqueN(x$countyfp))]
        tab[, `:=`(pct = 100 * expm1(estimate), pct_low = 100 * expm1(ci_low), pct_high = 100 * expm1(ci_high))]
        if (dynamic_fit) dynamic[[id]] <<- tab else static[[id]] <<- tab[term %in% c("post_mh","mh_1994")]
        models[[paste(id, if (dynamic_fit) "dynamic" else "static", sep = "_")]] <<- m
        # Check that every non-reference cohort is identified (never silently plot dropped cohorts).
        if (dynamic_fit) {
            expected <- setdiff(sort(unique(x$year_constr)), c(1992,1993))
            found <- as.integer(sub("year_constr::([0-9]+):mh", "\\1", tab[grepl("^year_constr::", term), term]))
            stopifnot(setequal(expected, found))
        }
        fwrite(rbindlist(dynamic, fill = TRUE), file.path(out, "vintage_coefficients.csv"))
        if (length(static)) fwrite(rbindlist(static, fill = TRUE), file.path(out, "post_coefficients.csv"))
    }
    baseline <- "countyfp^year_sale + mh + year_constr"
    local <- "countyfp^year_sale + countyfp^mh + year_constr"
    ready <- d$analysis_ready
    later <- ready & d$year_sale >= 2000
    specs <- list(pooled = list(ready, baseline), county_type = list(ready, local),
        sales_2000 = list(later, baseline), county_type_2000 = list(later, local),
        strict_2000 = list(later & d$consideration_documented, local),
        no_florida_2000 = list(later & d$statefp != "12", local),
        size_sample_2000 = list(later & d$sizes_ok, local),
        size_controls_2000 = list(later & d$sizes_ok, local, "+ log_sqft + I(log_sqft^2) + log_lot + I(log_lot^2)"),
        narrow_2000 = list(later & d$year_constr >= 1990 & d$year_constr <= 1997, local))
    for (id in names(specs)) {
        s <- specs[[id]]; controls <- if (length(s) == 3) s[[3]] else ""
        fit(id, s[[1]], s[[2]], controls)
        fit(id, s[[1]], s[[2]], controls, dynamic_fit = FALSE)
    }
    # Snapshot size balance: use the same complete-case sample and specification.
    balance <- rbindlist(lapply(c("log_sqft", "log_lot"), function(y) {
        m <- feols(as.formula(paste(y, "~ post_mh + mh_1994 |", local)),
            data = d[which(later & d$sizes_ok)], vcov = ~countyfp, lean = TRUE, mem.clean = TRUE)
        ci <- confint(m, "post_mh")
        data.table(outcome = y, estimate = coef(m)[["post_mh"]], se = se(m)[["post_mh"]],
            ci_low = ci[1,1], ci_high = ci[1,2], n = nobs(m))
    }))
    fwrite(balance, file.path(out, "snapshot_size_balance.csv"))
    saveRDS(models, file.path(out, "models-private.rds"))
    source("program/estimate/plot-corelogic-prices.R")
    cl_plot_prices(out)
    dir.create(file.path(out,"source"))
    file.copy(c("program/estimate/estimate-corelogic-prices.R","program/estimate/plot-corelogic-prices.R"),file.path(out,"source"))
    write_json(list(status = "complete", build = input, slurm_job = Sys.getenv("SLURM_JOB_ID"),
        sale_rows = nrow(d), preferred_rows = sum(ready), specification_ids = names(specs),
        outcome = "Log land-inclusive sale price, annual CPI-U in 2000 dollars",
        vintage_1994 = "Retained as own annual coefficient; static model has separate MH x 1994 term",
        source_build_manifest_md5 = unname(tools::md5sum(file.path(input, "manifest.json"))),
        code_md5 = unname(tools::md5sum("program/estimate/estimate-corelogic-prices.R")),
        wind_zone = "Not used; legacy crosswalk awaits reconciliation",
        session = capture.output(sessionInfo())), file.path(out, "manifest.json"), pretty = TRUE, auto_unbox = TRUE)
    cat("COMPLETE", out, "\n")
}
if (sys.nframe() == 0L) main()
