# Shared setup for CoreLogic price estimation. Licensed sales are read only
# inside a Rivanna Slurm allocation. Each run writes to a new private directory.

library(here)
library(DBI)
library(duckdb)
library(data.table)
library(fixest)
library(ggplot2)
library(jsonlite)

if (!nzchar(Sys.getenv("SLURM_JOB_ID"))) stop("Run on Rivanna in Slurm.")
input <- Sys.getenv("CORELOGIC_BUILD")
out_dir <- Sys.getenv("CORELOGIC_RESULTS")
if (!nzchar(input) || !nzchar(out_dir)) {
    stop("Set CORELOGIC_BUILD and CORELOGIC_RESULTS")
}
manifest <- fromJSON(file.path(input, "manifest.json"))
verification <- fromJSON(file.path(input, "audit", "verification.json"))
if (!identical(manifest$status, "complete") || !isTRUE(verification$ok)) {
    stop("Run requires a complete, verified build")
}
if (dir.exists(out_dir)) stop("Results already exist: ", out_dir)
dir.create(out_dir, recursive = TRUE)
write_json(list(status = "running", build = input), file.path(out_dir, "manifest.json"))

threads <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", "8"))
setFixest_nthreads(threads)

# Keep the connection local to each read, including cleanup on failure.
read_corelogic <- function(sql) {
    con <- dbConnect(duckdb())
    on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)
    dbExecute(con, sprintf("SET threads=%d", threads))
    dbExecute(con, "SET memory_limit='16GB'")
    as.data.table(dbGetQuery(con, sql))
}
quote_path <- function(path) {
    paste0("'", gsub("'", "''", path, fixed = TRUE), "'")
}

# Coefficients and county/state-clustered intervals on the plotted scale.
cl_coeftable <- function(model, specification) {
    tab <- as.data.table(coeftable(model), keep.rownames = "term")
    setnames(tab, names(tab)[2:5], c("estimate", "se", "t", "p"))
    ci <- confint(model)
    tab[, `:=`(
        ci_low = ci[term, 1], ci_high = ci[term, 2],
        specification = specification, n = nobs(model)
    )]
    tab[, `:=`(
        pct = 100 * expm1(estimate), pct_low = 100 * expm1(ci_low),
        pct_high = 100 * expm1(ci_high)
    )]
    tab
}
