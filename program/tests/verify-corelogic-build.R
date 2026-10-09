# Verify persisted private artifacts on their host; return aggregate checks only.
main <- function() {
    if (!nzchar(Sys.getenv("SLURM_JOB_ID"))) stop("Verify CoreLogic builds on Rivanna in Slurm.")
    library(DBI)
    library(duckdb)
    library(data.table)
    library(here)
    source(here("program", "lib", "corelogic-sample.R"))
    args <- commandArgs(trailingOnly = TRUE)
    if (length(args) != 1) stop("Supply one completed private run directory")
    run <- args[1]
    meta <- jsonlite::fromJSON(file.path(run, "manifest.json"))
    stopifnot(meta$status == "complete")
    for (kind in c("properties", "transfers", "sales", "pairs")) {
        files <- list.files(file.path(run, kind), pattern = "\\.parquet$")
        stopifnot(setequal(files, paste0(meta$states, ".parquet")))
    }
    con <- dbConnect(duckdb())
    on.exit(dbDisconnect(con, shutdown = TRUE))
    dbExecute(con, "SET threads=4")
    dbExecute(con, "SET memory_limit='8GB'")
    for (kind in c("transfers", "sales", "pairs")) {
        dbExecute(con, sprintf("CREATE VIEW %s AS SELECT * FROM read_parquet(%s)",
            kind, cl_sql_string(file.path(run, kind, "*.parquet"))))
    }
    tr <- as.data.table(dbGetQuery(con, "SELECT mh, COUNT(*) AS transfers,
        COUNT(*) FILTER (WHERE eligible_sale) AS eligible_sales,
        COUNT(*) FILTER (WHERE analysis_ready) AS analysis_sales,
        COUNT(*) FILTER (WHERE analysis_ready_strict) AS analysis_sales_strict
        FROM transfers GROUP BY mh ORDER BY mh NULLS FIRST"))
    expected <- fread(file.path(run, "audit", "summary_by_type.csv"),
        select = c("mh", "transfers", "eligible_sales", "analysis_sales", "analysis_sales_strict"))
    setorder(expected, mh)
    stopifnot(isTRUE(all.equal(as.data.frame(tr), as.data.frame(expected), check.attributes = FALSE)))
    violations <- dbGetQuery(con, sprintf("SELECT COUNT(*) AS violations FROM transfers
        WHERE (mh = 1 AND COALESCE(mobile_home_indicator, '') <> 'Y')
           OR (analysis_ready_strict AND NOT analysis_ready)
           OR (analysis_ready AND (year_constr = 1994 OR year_constr NOT BETWEEN %d AND %d
               OR date_sale < MAKE_DATE(year_constr,1,1)
               OR year_sale NOT BETWEEN %d AND %d))",
        meta$min_vintage, meta$max_vintage, meta$min_sale_year, meta$max_sale_year))$violations
    stopifnot(violations == 0)
    sl <- dbGetQuery(con, "SELECT COUNT(*) AS sales,
        COUNT(*) FILTER (WHERE NOT eligible_sale OR sale_amount <= 0
            OR sale_price_2000 IS NULL OR NOT ISFINITE(sale_price_2000)) AS violations FROM sales")
    stopifnot(sl$violations == 0, sl$sales == sum(tr$eligible_sales))
    pr <- as.data.table(dbGetQuery(con, "SELECT mh_pre, COUNT(*) AS pairs,
        COUNT(*) FILTER (WHERE stable_structure) AS stable_pairs,
        COUNT(*) FILTER (WHERE analysis_ready) AS analysis_pairs,
        COUNT(*) FILTER (WHERE analysis_ready_strict) AS analysis_pairs_strict
        FROM pairs GROUP BY mh_pre ORDER BY mh_pre"))
    expected_pairs <- fread(file.path(run, "audit", "summary_pairs.csv"))
    setorder(expected_pairs, mh_pre)
    stopifnot(isTRUE(all.equal(as.data.frame(pr), as.data.frame(expected_pairs), check.attributes = FALSE)))
    pair_violations <- dbGetQuery(con, sprintf("SELECT COUNT(*) AS violations FROM pairs
        WHERE date_post <= date_pre OR vintage_pre NOT BETWEEN %d AND %d
            OR post1994_pre <> (vintage_pre >= 1994)::INTEGER
            OR (analysis_ready AND (NOT stable_structure OR vintage_pre = 1994))
            OR (analysis_ready_strict AND (NOT analysis_ready
                OR NOT consideration_documented_pre OR NOT consideration_documented_post))",
        meta$min_vintage, meta$max_vintage))$violations
    stopifnot(pair_violations == 0)
    verification <- list(ok = TRUE, run_id = meta$run_id, states = length(meta$states),
        transfer_rows = sum(tr$transfers), sale_rows = sl$sales, pair_rows = sum(pr$pairs),
        transfer_rule_violations = violations, sale_rule_violations = sl$violations,
        pair_rule_violations = pair_violations,
        verified_at = format(Sys.time(), tz = "UTC"))
    jsonlite::write_json(verification, file.path(run, "audit", "verification.json"),
        pretty = TRUE, auto_unbox = TRUE)
    print(verification)
}
main()
