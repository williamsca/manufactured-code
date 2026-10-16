# Parcel x snapshot panel from the historical CoreLogic Property Basic zips.
#
# Each zip holds one pipe-delimited text file for one state and one snapshot.
# Rows for the requested counties are streamed out of the zip (the full text
# files are never written to disk), the needed columns are kept, and every
# snapshot-state is written as a parquet part. The parts are then stacked into
# one panel keyed by (clip, snap_idx), with sanity checks written alongside.
#
# Licensed records stay in SNAPSHOT_RESULTS (private). Only the aggregate CSV
# files written next to them are exported by the Slurm wrapper.
#
# Environment:
#   SNAPSHOT_RESULTS   new private output directory (required)
#   SNAPSHOT_SOURCE    root of the historical Property Basic deliveries
#   SNAPSHOT_DELIVERY  regular expression for the delivery date in the zip names
#                      (default 2024081[45]; the 2023 delivery is 20230817)
#   SNAPSHOT_COUNTIES  comma-separated 5-digit county FIPS codes

library(data.table)
library(DBI)
library(duckdb)
library(jsonlite)
library(here)
source(here("program", "lib", "corelogic-sample.R"))

if (!nzchar(Sys.getenv("SLURM_JOB_ID")) && Sys.getenv("SNAPSHOT_ALLOW_LOCAL") != "1") {
    stop("Run on Rivanna in Slurm.")
}
env <- function(key, default) {
    value <- Sys.getenv(key)
    if (nzchar(value)) value else default
}
src_root <- env("SNAPSHOT_SOURCE", "/project/crebe_hufl_corelogic/historic_property")
# Regular expression for the delivery date: snapshot 15 was cut a day after the rest.
want_delivery <- env("SNAPSHOT_DELIVERY", "2024081[45]")
counties <- strsplit(env("SNAPSHOT_COUNTIES", "12071,12015,12005,12045,04013"), ",", fixed = TRUE)[[1]]
out_dir <- Sys.getenv("SNAPSHOT_RESULTS")
if (!nzchar(out_dir)) stop("Set SNAPSHOT_RESULTS")
if (dir.exists(out_dir)) stop("Results already exist: ", out_dir)
if (any(!grepl("^[0-9]{5}$", counties))) stop("SNAPSHOT_COUNTIES must be 5-digit FIPS codes")
threads <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", "2"))
dir.create(file.path(out_dir, "parts"), recursive = TRUE)
work_dir <- file.path(out_dir, "tmp")
dir.create(work_dir)

state_by_fips <- c(
    "01" = "AL", "04" = "AZ", "05" = "AR", "06" = "CA", "08" = "CO", "09" = "CT",
    "10" = "DE", "11" = "DC", "12" = "FL", "13" = "GA", "16" = "ID", "17" = "IL",
    "18" = "IN", "19" = "IA", "20" = "KS", "21" = "KY", "22" = "LA", "23" = "ME",
    "24" = "MD", "25" = "MA", "26" = "MI", "27" = "MN", "28" = "MS", "29" = "MO",
    "30" = "MT", "31" = "NE", "32" = "NV", "33" = "NH", "34" = "NJ", "35" = "NM",
    "36" = "NY", "37" = "NC", "38" = "ND", "39" = "OH", "40" = "OK", "41" = "OR",
    "42" = "PA", "44" = "RI", "45" = "SC", "46" = "SD", "47" = "TN", "48" = "TX",
    "49" = "UT", "50" = "VT", "51" = "VA", "53" = "WA", "54" = "WV", "55" = "WI", "56" = "WY")
county_state <- state_by_fips[substr(counties, 1, 2)]
if (anyNA(county_state)) stop("Unknown state FIPS in SNAPSHOT_COUNTIES")
states <- sort(unique(unname(county_state)))

# Source column -> panel column. Only `required` ones may be absent from no
# snapshot; every other column is NULL (and logged) where a snapshot lacks it.
col_map <- c(
    clip = "CLIP", previous_clip = "PREVIOUS CLIP", fips = "FIPS CODE",
    apn = "APN (PARCEL NUMBER UNFORMATTED)", apn_seq = "APN SEQUENCE NUMBER",
    land_use_code = "LAND USE CODE", mobile_home_indicator = "MOBILE HOME INDICATOR",
    property_indicator_code = "PROPERTY INDICATOR CODE", n_buildings = "NUMBER OF BUILDINGS",
    year_built = "YEAR BUILT", eff_year_built = "EFFECTIVE YEAR BUILT",
    land_val_calc = "LAND VALUE CALCULATED", impr_val_calc = "IMPROVEMENT VALUE CALCULATED",
    total_val_calc = "TOTAL VALUE CALCULATED", assd_land = "ASSESSED LAND VALUE",
    assd_impr = "ASSESSED IMPROVEMENT VALUE", mkt_land = "MARKET LAND VALUE",
    mkt_impr = "MARKET IMPROVEMENT VALUE", tax_year = "TAX YEAR",
    assessed_year = "ASSESSED YEAR", last_assessor_update = "LAST ASSESSOR UPDATE DATE",
    taxroll_cert_date = "TAXROLL CERTIFICATION DATE",
    univ_bldg_sqft = "UNIVERSAL BUILDING SQUARE FEET",
    lat = "PARCEL LEVEL LATITUDE", lon = "PARCEL LEVEL LONGITUDE",
    situs_address = "SITUS STREET ADDRESS")
required <- c("clip", "fips", "year_built")
text_cols <- c("clip", "previous_clip", "fips", "apn", "apn_seq", "land_use_code",
    "mobile_home_indicator", "property_indicator_code", "last_assessor_update",
    "taxroll_cert_date", "situs_address")
int_cols <- c("n_buildings", "eff_year_built", "year_built", "tax_year", "assessed_year")
num_cols <- c("land_val_calc", "impr_val_calc", "total_val_calc", "assd_land", "assd_impr",
    "mkt_land", "mkt_impr", "univ_bldg_sqft", "lat", "lon")
year_cols <- c("year_built", "eff_year_built")

if (!nzchar(Sys.which("unzip")) || !nzchar(Sys.which("awk"))) stop("unzip and awk are required")

# --- 1. Inventory of the delivery ---------------------------------------------------
name_pattern <- "dpc_[0-9]+_([0-9]{2})_([0-9]{8})_([0-9]{6})_data_([A-Z]{2})\\.zip$"
all_zips <- list.files(src_root, pattern = name_pattern, recursive = TRUE, full.names = TRUE)
parsed <- regmatches(basename(all_zips), regexec(name_pattern, basename(all_zips)))
inv <- data.table(path = all_zips,
    snap_idx = as.integer(vapply(parsed, `[`, "", 2)),
    delivery = vapply(parsed, `[`, "", 3),
    state = vapply(parsed, `[`, "", 5),
    size_gb = file.size(all_zips) / 1e9)
inv <- inv[grepl(paste0("^(", want_delivery, ")$"), delivery)]
if (!nrow(inv)) stop("No zips for delivery ", want_delivery, " under ", src_root)
if (anyDuplicated(inv[, .(snap_idx, state)])) stop("Duplicate (snapshot, state) zips in delivery")
snap_idx_all <- sort(unique(inv$snap_idx))
grid <- CJ(snap_idx = snap_idx_all, state = states)
grid <- merge(grid, inv, by = c("snap_idx", "state"), all.x = TRUE)
fwrite(inv[, .(files = .N, size_gb = sum(size_gb)), by = snap_idx][order(snap_idx)],
    file.path(out_dir, "inventory-snapshots.csv"))
fwrite(inv[, .(snap_idx, state, size_gb)][order(snap_idx, state)],
    file.path(out_dir, "inventory-files.csv"))
missing_grid <- grid[is.na(path)]
if (nrow(missing_grid)) {
    message("Missing (snapshot, state) zips:\n", paste(missing_grid$snap_idx, missing_grid$state, collapse = "; "))
}
fwrite(missing_grid[, .(snap_idx, state)], file.path(out_dir, "inventory-missing.csv"))

# --- 2. Stream each zip, filter to the counties, keep the needed columns ----------------
awk_file <- file.path(work_dir, "filter.awk")
writeLines(c(
    "{ sub(/\\r$/, \"\") }",
    "NR == 1 { for (i = 1; i <= NF; i++) if ($i == \"FIPS CODE\") c = i; if (!c) exit 3; print; next }",
    "index(want, \",\" $c \",\") > 0"), awk_file)
want <- paste0(",", paste(counties, collapse = ","), ",")

new_con <- function() {
    con <- dbConnect(duckdb())
    dbExecute(con, sprintf("SET threads=%d", threads))
    dbExecute(con, sprintf("SET memory_limit='%s'", env("SNAPSHOT_DUCKDB_MEMORY", "40GB")))
    dbExecute(con, sprintf("SET temp_directory='%s'", file.path(work_dir, "duckdb-spill")))
    con
}
con <- new_con()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

select_sql <- function(have) {
    exprs <- vapply(names(col_map), function(nm) {
        if (!col_map[[nm]] %in% have) return(sprintf("NULL AS %s", nm))
        raw <- sprintf("NULLIF(TRIM(\"%s\"), '')", col_map[[nm]])
        if (nm %in% year_cols) {
            sprintf("CASE WHEN TRY_CAST(%s AS INTEGER) BETWEEN 1700 AND 2100 THEN TRY_CAST(%s AS INTEGER) END AS %s", raw, raw, nm)
        } else if (nm %in% int_cols) {
            sprintf("TRY_CAST(%s AS INTEGER) AS %s", raw, nm)
        } else if (nm %in% num_cols) {
            sprintf("TRY_CAST(%s AS DOUBLE) AS %s", raw, nm)
        } else {
            sprintf("%s AS %s", raw, nm)
        }
    }, "")
    paste(exprs, collapse = ",\n  ")
}

log_rows <- vector("list", nrow(grid))
for (i in seq_len(nrow(grid))) {
    g <- grid[i]
    if (is.na(g$path)) next
    t0 <- Sys.time()
    txt <- file.path(work_dir, sprintf("snap%02d-%s.txt", g$snap_idx, g$state))
    cmd <- sprintf("set -o pipefail; unzip -p %s | awk -F'|' -v want=%s -f %s > %s",
        shQuote(g$path), shQuote(want), shQuote(awk_file), shQuote(txt))
    status <- system2("bash", c("-c", shQuote(cmd)))
    if (status != 0) stop("Extraction failed (", status, "): ", g$path)

    rd <- sprintf("read_csv(%s, delim='|', header=true, quote='', escape='', all_varchar=true)",
        cl_sql_string(txt))
    have <- names(dbGetQuery(con, sprintf("SELECT * FROM %s LIMIT 0", rd)))
    missing_cols <- names(col_map)[!col_map %in% have]
    if (any(required %in% missing_cols)) stop("Required column missing in ", g$path)
    part_dir <- file.path(out_dir, "parts", sprintf("snap_idx=%02d", g$snap_idx))
    dir.create(part_dir, showWarnings = FALSE)
    part <- file.path(part_dir, sprintf("%s.parquet", g$state))
    dbExecute(con, sprintf("COPY (SELECT %d AS snap_idx, '%s' AS state,\n  %s\nFROM %s) TO %s (FORMAT parquet)",
        g$snap_idx, g$state, select_sql(have), rd, cl_sql_string(part)))

    # Raw row count and year-built cleaning losses, to prove nothing silently dropped.
    chk <- dbGetQuery(con, sprintf("SELECT count(*) AS n_raw,
            count(*) FILTER (WHERE NULLIF(TRIM(\"YEAR BUILT\"), '') IS NOT NULL
                AND TRY_CAST(NULLIF(TRIM(\"YEAR BUILT\"), '') AS INTEGER) NOT BETWEEN 1700 AND 2100) AS n_yb_invalid,
            count(*) FILTER (WHERE TRY_CAST(NULLIF(TRIM(\"YEAR BUILT\"), '') AS INTEGER) = 0) AS n_yb_zero
        FROM %s", rd))
    n_part <- dbGetQuery(con, sprintf("SELECT count(*) AS n FROM read_parquet(%s)", cl_sql_string(part)))$n
    log_rows[[i]] <- data.table(snap_idx = g$snap_idx, state = g$state, n_header_cols = length(have),
        n_raw = chk$n_raw, n_part = n_part, n_yb_invalid = chk$n_yb_invalid, n_yb_zero = chk$n_yb_zero,
        missing_cols = paste(missing_cols, collapse = ";"),
        seconds = as.numeric(difftime(Sys.time(), t0, units = "secs")))
    unlink(txt)
    message(sprintf("[%s] snapshot %02d %s: %d rows (%.0fs)", format(Sys.time(), "%H:%M:%S"),
        g$snap_idx, g$state, n_part, log_rows[[i]]$seconds))
}
import_log <- rbindlist(log_rows)
stopifnot(import_log[, all(n_raw == n_part)])
fwrite(import_log, file.path(out_dir, "import-log.csv"))

# --- 3. Snapshot dating ----------------------------------------------------------------
# The zip names carry only an index; the tax and assessed years identify what each
# snapshot is. snapshot_year is the modal tax year (assessed year if tax year is empty).
parts_glob <- cl_sql_string(file.path(out_dir, "parts", "*", "*.parquet"))
.rc <- dbExecute(con, sprintf("CREATE VIEW raw_panel AS SELECT * FROM read_parquet(%s, hive_partitioning=false)", parts_glob))
year_freq <- as.data.table(dbGetQuery(con, "
    SELECT snap_idx, tax_year, assessed_year,
        TRY_CAST(substr(taxroll_cert_date, 1, 4) AS INTEGER) AS cert_year, count(*) AS n
    FROM raw_panel GROUP BY ALL"))
modal <- function(dt, col) {
    dt[!is.na(get(col)), .(n = sum(n)), by = c("snap_idx", col)][order(-n)][,
        .(value = get(col)[1], share = n[1] / sum(n)), by = snap_idx]
}
snapshots <- merge(
    merge(year_freq[, .(n_rows = sum(n)), by = snap_idx],
        modal(year_freq[tax_year > 0], "tax_year")[, .(snap_idx, mode_tax_year = value, share_mode_tax_year = share)],
        by = "snap_idx", all.x = TRUE),
    merge(modal(year_freq[assessed_year > 0], "assessed_year")[, .(snap_idx, mode_assessed_year = value)],
        modal(year_freq[cert_year > 1900], "cert_year")[, .(snap_idx, mode_cert_year = value)],
        by = "snap_idx", all = TRUE),
    by = "snap_idx", all.x = TRUE)[order(snap_idx)]
snapshots <- merge(snapshots, as.data.table(dbGetQuery(con, "
    SELECT snap_idx, max(last_assessor_update) AS max_last_update FROM raw_panel GROUP BY snap_idx")),
    by = "snap_idx")
snapshots[, snapshot_year := fifelse(!is.na(mode_tax_year), mode_tax_year, mode_assessed_year)]
fwrite(snapshots, file.path(out_dir, "snapshots.csv"))
if (anyNA(snapshots$snapshot_year)) stop("Cannot date every snapshot; see snapshots.csv")
dbWriteTable(con, "snapshots", snapshots[, .(snap_idx, snapshot_year)], overwrite = TRUE)

# --- 4. Stack into the panel ------------------------------------------------------------
# A (clip, snap_idx) with more than one row cannot identify a structure; those keys
# are dropped from the panel (and counted), never silently collapsed.
# Rows with no CLIP cannot be followed across snapshots (and would slip through the
# duplicate-key join, since NULL never matches), so they are excluded and counted.
null_clip <- as.data.table(dbGetQuery(con, "
    SELECT fips, snap_idx, count(*) AS n_null_clip FROM raw_panel WHERE clip IS NULL GROUP BY ALL ORDER BY ALL"))
fwrite(null_clip, file.path(out_dir, "check-null-clip.csv"))
.rc <- dbExecute(con, "CREATE TEMP TABLE dup_keys AS
    SELECT clip, snap_idx, count(*) AS n_rows FROM raw_panel WHERE clip IS NOT NULL
    GROUP BY clip, snap_idx HAVING count(*) > 1")
n_dup_keys <- dbGetQuery(con, "SELECT count(*) AS n, coalesce(sum(n_rows), 0) AS rows FROM dup_keys")
dup_by_county <- as.data.table(dbGetQuery(con, "
    SELECT p.fips, p.snap_idx, count(*) AS n_rows FROM raw_panel p
    JOIN dup_keys d USING (clip, snap_idx) GROUP BY ALL ORDER BY ALL"))
fwrite(dup_by_county, file.path(out_dir, "check-duplicate-keys.csv"))

mh_sql <- cl_type_sql("p.mobile_home_indicator", "p.property_indicator_code", "p.land_use_code")
panel_file <- file.path(out_dir, "panel.parquet")
.rc <- dbExecute(con, sprintf("COPY (
    SELECT p.* EXCLUDE (state), p.state, s.snapshot_year, %s AS mh
    FROM raw_panel p
    JOIN snapshots s USING (snap_idx)
    ANTI JOIN dup_keys d USING (clip, snap_idx)
    WHERE p.clip IS NOT NULL
    ORDER BY p.clip, p.snap_idx) TO %s (FORMAT parquet, COMPRESSION zstd)",
    mh_sql, cl_sql_string(panel_file)))
.rc <- dbExecute(con, sprintf("CREATE VIEW panel AS SELECT * FROM read_parquet(%s)", cl_sql_string(panel_file)))

# --- 5. Sanity checks ------------------------------------------------------------------
n_panel <- dbGetQuery(con, "SELECT count(*) AS n FROM panel")$n
checks <- list(
    delivery = want_delivery, counties = counties, snapshots = nrow(snapshots),
    rows_raw = sum(import_log$n_raw), rows_panel = n_panel,
    dup_keys = n_dup_keys$n, dup_rows = n_dup_keys$rows, null_clip_rows = sum(null_clip$n_null_clip),
    # Uniqueness on the panel key.
    panel_key_unique = dbGetQuery(con, "SELECT count(*) = count(DISTINCT (clip, snap_idx)) AS ok FROM panel")$ok,
    # Every row is in a requested county.
    fips_in_request = dbGetQuery(con, sprintf("SELECT bool_and(fips IN (%s)) AS ok FROM panel",
        paste(cl_sql_string(counties), collapse = ",")))$ok,
    missing_clip = dbGetQuery(con, "SELECT count(*) AS n FROM panel WHERE clip IS NULL")$n,
    rows_add_up = n_panel + n_dup_keys$rows + sum(null_clip$n_null_clip) == sum(import_log$n_raw))
stopifnot(isTRUE(checks$panel_key_unique), isTRUE(checks$fips_in_request),
    checks$missing_clip == 0, isTRUE(checks$rows_add_up))
write_json(checks, file.path(out_dir, "checks.json"), auto_unbox = TRUE, pretty = TRUE)

# Cross-field consistency and missing-value accounting, by county x snapshot.
consistency <- as.data.table(dbGetQuery(con, "
    SELECT fips, snap_idx, snapshot_year, count(*) AS n,
        avg((year_built IS NULL)::INTEGER) AS miss_year_built,
        avg((eff_year_built IS NULL)::INTEGER) AS miss_eff_year_built,
        avg((mobile_home_indicator IS NULL)::INTEGER) AS miss_mh_indicator,
        avg((impr_val_calc IS NULL)::INTEGER) AS miss_impr_val,
        avg((previous_clip IS NOT NULL)::INTEGER) AS share_previous_clip,
        count(*) FILTER (WHERE eff_year_built < year_built) AS n_eff_lt_yb,
        count(*) FILTER (WHERE year_built > snapshot_year) AS n_yb_after_snapshot,
        count(*) FILTER (WHERE mobile_home_indicator = 'Y' AND property_indicator_code <> '10') AS n_mh_not_sfr,
        count(*) FILTER (WHERE mh = 1) AS n_mh, count(*) FILTER (WHERE mh = 0) AS n_sb
    FROM panel GROUP BY ALL ORDER BY ALL"))
fwrite(consistency, file.path(out_dir, "check-consistency.csv"))
message("Panel rows: ", format(n_panel, big.mark = ","), "; dropped duplicate-key rows: ", n_dup_keys$rows)
unlink(work_dir, recursive = TRUE)
message("Wrote ", panel_file)
