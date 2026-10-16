# Aggregate tabulations of the snapshot panel: what `year_built` and
# `effective_year_built` do across adjacent snapshots, and whether the panel can
# support a destruction/replacement (survival) analysis.
#
# Reads the private panel parquet; writes aggregate CSVs only.
#   SNAPSHOT_PANEL    panel.parquet from the panel script
#   SNAPSHOT_RESULTS  new output directory (required)
#
# Unit of comparison: (clip, adjacent snapshots a -> b), where b = a + 1 in the
# snapshot index and the clip is present in both. Types are by the classification at a:
# MH (mobile-home indicator), SB (single-family, no MH flag), Other (unclassified).

library(data.table)
library(DBI)
library(duckdb)
library(here)

if (!nzchar(Sys.getenv("SLURM_JOB_ID")) && Sys.getenv("SNAPSHOT_ALLOW_LOCAL") != "1") {
    stop("Run on Rivanna in Slurm.")
}
panel_file <- Sys.getenv("SNAPSHOT_PANEL")
out_dir <- Sys.getenv("SNAPSHOT_RESULTS")
if (!nzchar(panel_file) || !file.exists(panel_file)) stop("Set SNAPSHOT_PANEL to an existing panel.parquet")
if (!nzchar(out_dir)) stop("Set SNAPSHOT_RESULTS")
if (dir.exists(out_dir)) stop("Results already exist: ", out_dir)
dir.create(out_dir, recursive = TRUE)
threads <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", "2"))

# Storm counties and the date of the event. event_time = snapshot_year(b) - storm year
# is attached to every interval, so the lag in assessor reaction is read off the table
# rather than assumed: the interval that first spans the storm has event_time 1.
county_meta <- data.table(
    fips = c("12071", "12015", "12005", "12045", "04013"),
    county = c("Lee FL", "Charlotte FL", "Bay FL", "Gulf FL", "Maricopa AZ"),
    storm = c("Ian", "Ian", "Michael", "Michael", NA),
    storm_year = c(2022L, 2022L, 2018L, 2018L, NA),
    storm_date = c("20220928", "20220928", "20181010", "20181010", NA))

con <- dbConnect(duckdb())
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)
dbExecute(con, sprintf("SET threads=%d", threads))
dbExecute(con, sprintf("SET memory_limit='%s'", Sys.getenv("SNAPSHOT_DUCKDB_MEMORY", "40GB")))
dbExecute(con, sprintf("SET temp_directory='%s'", file.path(out_dir, "duckdb-spill")))
dbWriteTable(con, "county_meta", county_meta)
dbExecute(con, sprintf("CREATE VIEW p AS
    SELECT clip, previous_clip, fips, snap_idx, snapshot_year, mh,
        year_built AS yb, eff_year_built AS eff, impr_val_calc AS impr,
        CASE mh WHEN 1 THEN 'MH' WHEN 0 THEN 'SB' ELSE 'Other' END AS type,
        last_assessor_update
    FROM read_parquet('%s')", panel_file))

query <- function(sql) as.data.table(dbGetQuery(con, sql))
save_tab <- function(dt, name) {
    # Attach county labels and event time to any table that carries fips / yr_b.
    if ("fips" %in% names(dt)) dt <- merge(dt, county_meta[, .(fips, county, storm, storm_year)], by = "fips", all.x = TRUE)
    if (all(c("yr_b", "storm_year") %in% names(dt))) dt[, event_time := yr_b - storm_year]
    fwrite(dt, file.path(out_dir, paste0(name, ".csv")))
    dt
}

dbExecute(con, "CREATE TABLE pairs AS
    SELECT a.clip, a.fips, a.snap_idx AS idx_a, b.snap_idx AS idx_b,
        a.snapshot_year AS yr_a, b.snapshot_year AS yr_b, a.type AS type_a, b.type AS type_b,
        a.yb AS yb_a, b.yb AS yb_b, a.eff AS eff_a, b.eff AS eff_b,
        a.impr AS impr_a, b.impr AS impr_b
    FROM p a JOIN p b ON a.clip = b.clip AND b.snap_idx = a.snap_idx + 1")

# --- 1. Coverage and missingness by county x snapshot -------------------------------
cover <- save_tab(query("
    SELECT fips, snap_idx, snapshot_year, count(*) AS n_parcels, count(DISTINCT clip) AS n_clips,
        count(*) FILTER (WHERE type = 'MH') AS n_mh, count(*) FILTER (WHERE type = 'SB') AS n_sb,
        avg((yb IS NOT NULL)::INTEGER) AS share_yb, avg((eff IS NOT NULL)::INTEGER) AS share_eff,
        avg((impr > 0)::INTEGER) AS share_impr_pos,
        avg((previous_clip IS NOT NULL)::INTEGER) AS share_previous_clip
    FROM p GROUP BY ALL ORDER BY ALL"), "tab-coverage")

# --- 2. Clip stability across adjacent snapshots ------------------------------------
match <- save_tab(query("
    WITH n AS (SELECT fips, snap_idx, count(*) AS n FROM p GROUP BY ALL),
    both_ AS (SELECT fips, idx_a AS snap_idx, count(*) AS n_both FROM pairs GROUP BY ALL),
    moved AS (SELECT b.fips, b.snap_idx - 1 AS snap_idx, count(*) AS n_b_new_with_prev_clip_in_a
        FROM p b WHERE NOT EXISTS (SELECT 1 FROM p a WHERE a.clip = b.clip AND a.snap_idx = b.snap_idx - 1)
          AND EXISTS (SELECT 1 FROM p a WHERE a.clip = b.previous_clip AND a.snap_idx = b.snap_idx - 1)
        GROUP BY ALL)
    SELECT a.fips, a.snap_idx AS idx_a, a.snap_idx + 1 AS idx_b, a.n AS n_a, b.n AS n_b,
        coalesce(c.n_both, 0) AS n_both, coalesce(c.n_both, 0) * 1.0 / a.n AS share_a_in_b,
        coalesce(c.n_both, 0) * 1.0 / b.n AS share_b_in_a,
        coalesce(m.n_b_new_with_prev_clip_in_a, 0) AS n_b_new_with_prev_clip_in_a
    FROM n a JOIN n b ON a.fips = b.fips AND b.snap_idx = a.snap_idx + 1
    LEFT JOIN both_ c ON a.fips = c.fips AND a.snap_idx = c.snap_idx
    LEFT JOIN moved m ON a.fips = m.fips AND a.snap_idx = m.snap_idx
    ORDER BY ALL"), "tab-clip-match")

# --- 3. year_built / type / value changes between adjacent snapshots ------------------
changes <- save_tab(query("
    SELECT fips, idx_a, idx_b, yr_a, yr_b, type_a, count(*) AS n_pairs,
        count(*) FILTER (WHERE yb_a IS NOT NULL AND yb_b IS NOT NULL) AS n_yb_both,
        count(*) FILTER (WHERE yb_a <> yb_b) AS n_yb_changed,
        count(*) FILTER (WHERE yb_a IS NOT NULL AND yb_b IS NULL) AS n_yb_to_missing,
        count(*) FILTER (WHERE yb_a IS NULL AND yb_b IS NOT NULL) AS n_yb_from_missing,
        count(*) FILTER (WHERE yb_a <> yb_b AND yb_b > yb_a) AS n_yb_later,
        count(*) FILTER (WHERE yb_a <> yb_b AND yb_b >= yr_a) AS n_yb_new_since_a,
        count(*) FILTER (WHERE type_a = 'MH' AND type_b = 'SB') AS n_mh_to_sb,
        count(*) FILTER (WHERE type_a = 'SB' AND type_b = 'MH') AS n_sb_to_mh,
        count(*) FILTER (WHERE type_a <> 'Other' AND type_b = 'Other') AS n_class_lost,
        count(*) FILTER (WHERE impr_a > 0 AND impr_b IS NULL) AS n_impr_b_missing,
        count(*) FILTER (WHERE impr_a > 0 AND impr_b < 0.2 * impr_a) AS n_impr_drop80,
        count(*) FILTER (WHERE impr_a > 0 AND impr_b IS NOT NULL) AS n_impr_both
    FROM pairs GROUP BY ALL ORDER BY ALL"), "tab-changes")

# --- 4. Distribution of the new - old year_built when it changes ---------------------
delta <- save_tab(query("
    SELECT fips, idx_a, idx_b, yr_a, yr_b, type_a,
        CASE WHEN yb_b - yb_a <= -11 THEN '1: <= -11'
             WHEN yb_b - yb_a < 0 THEN '2: -10..-1'
             WHEN yb_b - yb_a <= 2 THEN '3: 1..2'
             WHEN yb_b - yb_a <= 5 THEN '4: 3..5'
             WHEN yb_b - yb_a <= 10 THEN '5: 6..10'
             ELSE '6: > 10' END AS delta_bin,
        count(*) AS n, count(*) FILTER (WHERE yb_b >= yr_a) AS n_new_since_a
    FROM pairs WHERE yb_a <> yb_b GROUP BY ALL ORDER BY ALL"), "tab-yb-delta")

# --- 5. Improvement-value collapse and recovery: does year_built reset? -----------------
# Collapse: improvement value falls by more than 80% between adjacent snapshots.
# Recovery: at a later snapshot c, improvement value is back to >= 80% of its level at a.
# yb_c is compared with yb_a and with the start year of the collapse interval.
dbExecute(con, "CREATE TABLE collapse AS
    WITH ev AS (SELECT * FROM pairs WHERE impr_a > 0 AND impr_b < 0.2 * impr_a),
    rec AS (SELECT e.clip, e.idx_a, min(c.snap_idx) AS idx_c
        FROM ev e JOIN p c ON c.clip = e.clip AND c.snap_idx > e.idx_b AND c.impr >= 0.8 * e.impr_a
        GROUP BY ALL),
    later AS (SELECT e.clip, e.idx_a, count(*) AS n_later
        FROM ev e JOIN p c ON c.clip = e.clip AND c.snap_idx > e.idx_b GROUP BY ALL)
    SELECT e.fips, e.idx_a, e.idx_b, e.yr_a, e.yr_b, e.type_a, e.yb_a, e.yr_a AS start_year,
        coalesce(l.n_later, 0) AS n_later, r.idx_c, c.yb AS yb_c, c.type AS type_c, c.snapshot_year AS yr_c
    FROM ev e LEFT JOIN later l USING (clip, idx_a) LEFT JOIN rec r USING (clip, idx_a)
    LEFT JOIN p c ON c.clip = e.clip AND c.snap_idx = r.idx_c")
collapse <- save_tab(query("
    SELECT fips, idx_a, idx_b, yr_a, yr_b, type_a, coalesce(type_c, 'none') AS type_c,
        CASE WHEN n_later = 0 THEN '0: no later snapshot'
             WHEN idx_c IS NULL THEN '1: not recovered'
             WHEN yb_c IS NULL OR yb_a IS NULL THEN '2: year_built missing'
             WHEN yb_c = yb_a THEN '3: year_built unchanged'
             WHEN yb_c >= start_year THEN '4: reset to year >= start of interval'
             ELSE '5: changed to earlier year' END AS yb_outcome,
        count(*) AS n
    FROM collapse GROUP BY ALL ORDER BY ALL"), "tab-collapse-recovery")

# --- 6. effective_year_built against year_built ------------------------------------------
eff_static <- save_tab(query("
    SELECT fips, snap_idx, snapshot_year, type, count(*) AS n,
        count(*) FILTER (WHERE yb IS NOT NULL AND eff IS NOT NULL) AS n_both,
        count(*) FILTER (WHERE eff <> yb) AS n_eff_neq_yb,
        count(*) FILTER (WHERE eff < yb) AS n_eff_before_yb,
        count(*) FILTER (WHERE eff > yb) AS n_eff_after_yb,
        count(*) FILTER (WHERE eff IS NOT NULL AND yb IS NULL) AS n_eff_only,
        count(*) FILTER (WHERE yb IS NOT NULL AND eff IS NULL) AS n_yb_only
    FROM p GROUP BY ALL ORDER BY ALL"), "tab-eff-static")
eff_moves <- save_tab(query("
    SELECT fips, idx_a, idx_b, yr_a, yr_b, type_a,
        count(*) FILTER (WHERE eff_a IS NOT NULL AND eff_b IS NOT NULL) AS n_eff_both,
        count(*) FILTER (WHERE eff_a <> eff_b) AS n_eff_changed,
        count(*) FILTER (WHERE eff_a <> eff_b AND yb_a = yb_b) AS n_eff_changed_yb_same,
        count(*) FILTER (WHERE eff_a <> eff_b AND yb_a <> yb_b) AS n_eff_changed_yb_changed,
        count(*) FILTER (WHERE eff_a = eff_b AND yb_a <> yb_b) AS n_yb_changed_eff_same,
        count(*) FILTER (WHERE yb_a = yb_b) AS n_yb_same
    FROM pairs GROUP BY ALL ORDER BY ALL"), "tab-eff-moves")

# --- 7. Assessor update timing --------------------------------------------------------------
upd_format <- save_tab(query("
    SELECT snap_idx, length(last_assessor_update) AS nchar, count(*) AS n
    FROM p GROUP BY ALL ORDER BY ALL"), "tab-update-format")
upd <- save_tab(query("
    SELECT p.fips, p.snap_idx, p.snapshot_year, count(*) AS n,
        count(*) FILTER (WHERE last_assessor_update IS NULL) AS n_update_missing,
        count(*) FILTER (WHERE TRY_CAST(substr(last_assessor_update, 1, 4) AS INTEGER) >= p.snapshot_year) AS n_updated_in_snapshot_year,
        count(*) FILTER (WHERE m.storm_date IS NOT NULL AND last_assessor_update > m.storm_date) AS n_updated_after_storm,
        median(TRY_CAST(substr(last_assessor_update, 1, 4) AS INTEGER)) AS median_update_year
    FROM p LEFT JOIN county_meta m USING (fips) GROUP BY ALL ORDER BY ALL"), "tab-update-timing")

# --- Console digest (the job log carries the headline tables) ----------------------------
options(width = 200, datatable.print.nrows = 400)
cat("\n== Snapshot coverage ==\n"); print(cover[, .(county, snap_idx, snapshot_year, n_parcels, n_mh, n_sb,
    share_yb = round(share_yb, 3), share_eff = round(share_eff, 3))])
cat("\n== Clip match, adjacent snapshots ==\n"); print(match[, .(county, idx_a, idx_b, n_a, n_b,
    share_a_in_b = round(share_a_in_b, 3), share_b_in_a = round(share_b_in_a, 3), n_b_new_with_prev_clip_in_a)])
cat("\n== year_built change share by type, county, interval ==\n")
print(changes[type_a != "Other" & n_yb_both > 0, .(county, yr_a, yr_b, event_time, type_a, n_pairs,
    pct_yb_changed = round(100 * n_yb_changed / n_yb_both, 2),
    pct_mh_sb_flip = round(100 * (n_mh_to_sb + n_sb_to_mh) / n_pairs, 2),
    pct_impr_drop80 = round(100 * n_impr_drop80 / n_impr_both, 2))][order(county, type_a, yr_a)])
cat("\n== Collapse-and-recovery outcomes ==\n")
print(collapse[, .(n = sum(n)), by = .(county, event_time, type_a, yb_outcome)][order(county, event_time, type_a, yb_outcome)])
cat("\n== Update-date format (nchar) ==\n"); print(upd_format[, .(n = sum(n)), by = nchar])
