# Small host-side diagnostic pass over a completed private build. Outputs only
# aggregate tables, particularly the effect of missing consideration codes.
if (!nzchar(Sys.getenv("SLURM_JOB_ID"))) stop("Run CoreLogic diagnostics on Rivanna in Slurm.")
library(DBI)
library(duckdb)
library(data.table)
library(here)
source(here("program", "lib", "corelogic-sample.R"))
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) stop("Supply one private completed build directory")
run <- args[1]
meta <- jsonlite::fromJSON(file.path(run, "manifest.json"))
if (meta$status != "complete") stop("Build is incomplete")
con <- dbConnect(duckdb())
on.exit(dbDisconnect(con, shutdown = TRUE))
dbExecute(con, "SET threads=4")
dbExecute(con, "SET memory_limit='6GB'")
dbExecute(con, sprintf("CREATE VIEW transfers AS SELECT * FROM read_parquet(%s)",
    cl_sql_string(file.path(run, "transfers", "*.parquet"))))
rules <- cl_market_sql(consideration = "ignore")
sql <- sprintf("SELECT mh, sale_type_code, YEAR(date_sale) AS year_sale,
    COUNT(*) AS transfers,
    COUNT(*) FILTER (WHERE sale_amount > 0) AS positive_price,
    COUNT(*) FILTER (WHERE primary_category_code = 'A' AND deed_category_type_code = 'G'
        AND sale_amount > 0) AS positive_arms_length_deeds,
    COUNT(*) FILTER (WHERE %s AND dwelling AND NOT distressed AND same_day_transfers = 1
        AND vintage_in_window AND year_constr <> 1994 AND year_sale BETWEEN %d AND %d
        AND date_sale >= MAKE_DATE(year_constr,1,1)) AS otherwise_analysis_ready,
    COUNT(*) FILTER (WHERE analysis_ready) AS analysis_ready
    FROM transfers GROUP BY ALL", rules, meta$min_sale_year, meta$max_sale_year)
dt <- as.data.table(dbGetQuery(con, sql))
setorder(dt, mh, sale_type_code, year_sale)
fwrite(dt, file.path(run, "audit", "consideration_by_year.csv"))
summary <- dt[, lapply(.SD, sum), by = .(mh, sale_type_code),
    .SDcols = c("transfers", "positive_price", "positive_arms_length_deeds", "otherwise_analysis_ready", "analysis_ready")]
setorder(summary, mh, sale_type_code)
fwrite(summary, file.path(run, "audit", "consideration_summary.csv"))
print(summary)
