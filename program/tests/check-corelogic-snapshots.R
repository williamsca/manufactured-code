# Run both snapshot scripts on a synthetic delivery of zipped pipe-delimited files
# and check the panel and tabulations against known answers: a replacement where
# year_built resets, a replacement where it does not, an SB -> MH flip, a clip that
# changes (PREVIOUS CLIP), a duplicated key, effective year before year built, a CRLF
# file, and a county that must be filtered out.
library(data.table)
library(DBI)
library(duckdb)
library(here)

if (!nzchar(Sys.which("zip")) || !nzchar(Sys.which("unzip"))) {
    cat("SKIP: zip/unzip not available\n")
    quit(save = "no", status = 0)
}

root <- tempfile("snapshots-fixture-")
dir.create(root)
src <- file.path(root, "src")
cols <- c("CLIP", "PREVIOUS CLIP", "FIPS CODE", "APN (PARCEL NUMBER UNFORMATTED)", "APN SEQUENCE NUMBER",
    "LAND USE CODE", "MOBILE HOME INDICATOR", "PROPERTY INDICATOR CODE", "NUMBER OF BUILDINGS",
    "SOMETHING UNUSED", "YEAR BUILT", "EFFECTIVE YEAR BUILT", "LAND VALUE CALCULATED",
    "IMPROVEMENT VALUE CALCULATED", "TOTAL VALUE CALCULATED", "TAX YEAR", "ASSESSED YEAR",
    "LAST ASSESSOR UPDATE DATE", "TAXROLL CERTIFICATION DATE")
row <- function(clip, snap, yb, impr, mh = "", prev = "", fips = "12071", eff = yb, prop = "10", lu = "100") {
    data.table(`CLIP` = clip, `PREVIOUS CLIP` = prev, `FIPS CODE` = fips,
        `APN (PARCEL NUMBER UNFORMATTED)` = paste0("apn-", clip), `APN SEQUENCE NUMBER` = "1",
        `LAND USE CODE` = lu, `MOBILE HOME INDICATOR` = mh, `PROPERTY INDICATOR CODE` = prop,
        `NUMBER OF BUILDINGS` = "1", `SOMETHING UNUSED` = "x", `YEAR BUILT` = yb,
        `EFFECTIVE YEAR BUILT` = eff, `LAND VALUE CALCULATED` = 10000,
        `IMPROVEMENT VALUE CALCULATED` = impr, `TOTAL VALUE CALCULATED` = 10000 + impr,
        `TAX YEAR` = 2020 + snap, `ASSESSED YEAR` = 2020 + snap,
        `LAST ASSESSOR UPDATE DATE` = sprintf("%d0601", 2020 + snap),
        `TAXROLL CERTIFICATION DATE` = sprintf("%d0901", 2020 + snap))
}
snap_rows <- function(s) {
    rbindlist(list(
        row("A", s, 1990, 50000, mh = "Y", lu = "137"),
        # B: destroyed in snapshot 3, rebuilt with a new year_built in snapshot 4
        row("B", s, c(1985, 1985, 1985, 2023)[s], c(50000, 50000, 2000, 60000)[s], mh = "Y", lu = "137"),
        # C: same collapse and recovery, year_built never changes
        row("C", s, 1990, c(40000, 40000, 1000, 45000)[s], mh = "Y", lu = "137"),
        # D: site-built until snapshot 3, then flagged MH
        row("D", s, 2000, 90000, mh = if (s >= 3) "Y" else "", lu = if (s >= 3) "137" else "100"),
        if (s <= 2) row("E", s, 1999, 80000),
        # F succeeds E under a new clip
        if (s >= 3) row("F", s, 1999, 80000, prev = "E"),
        # G has two rows in snapshot 2, so its key is dropped there
        row("G", s, 1990, 70000), if (s == 2) row("G", s, 1990, 70000),
        # I: year_built moves by one year in snapshot 3
        row("I", s, if (s >= 3) 1996 else 1995, 85000),
        # J: effective year built precedes year built (data error)
        row("J", s, 2005, 75000, eff = 2000),
        # L: no CLIP in snapshots 3 and 4 (cannot be tracked, must be excluded and counted)
        if (s >= 3) rbind(row("", s, 1990, 50000), row("", s, 1991, 51000)),
        # K: outside the requested counties
        row("K", s, 1990, 50000, fips = "99999")))
}
# Zip numbering is not chronological: the first three snapshots are numbered newest-first
# (03, 02, 01) and the newest snapshot is a late extra (15) with a different date and a
# space in its file name, as in the real delivery.
zip_idx <- c(3, 2, 1, 15)
for (s in 1:4) {
    k <- zip_idx[s]
    d <- file.path(src, "20240814", sprintf("14%02d00", k))
    dir.create(d, recursive = TRUE)
    txt <- file.path(root, sprintf("fixture_%02d_FL.txt", s))
    tmp <- tempfile()
    fwrite(snap_rows(s)[, ..cols], tmp, sep = "|", quote = FALSE)
    lines <- readLines(tmp)
    eol <- if (s == 2) "\r\n" else "\n"   # snapshot 2 carries CRLF line endings
    writeBin(charToRaw(paste0(paste(lines, collapse = eol), eol)), txt)
    stem <- if (k == 15) {
        "University of Virginia_hist_property_basic1_dpc_01468305_15_20240815_151041_data_FL"
    } else {
        sprintf("university_of_virginia_hist_property_basic1_dpc_01468305_%02d_20240814_14%02d00_data_FL", k, k)
    }
    file.copy(txt, file.path(d, paste0(stem, ".txt")))
    owd <- setwd(d)
    system2("zip", c("-q", shQuote(paste0(stem, ".zip")), shQuote(paste0(stem, ".txt"))))
    unlink(paste0(stem, ".txt"))
    setwd(owd)
    stopifnot(file.exists(file.path(d, paste0(stem, ".zip"))))
}

run <- function(script, ...) {
    out <- system2("Rscript", here("program", "import-corelogic-snapshots", script),
        env = c("SNAPSHOT_ALLOW_LOCAL=1", sprintf("SNAPSHOT_SOURCE=%s", src), "SNAPSHOT_COUNTIES=12071",
            "SNAPSHOT_DELIVERY=2024081[45]", ...), stdout = TRUE, stderr = TRUE)
    status <- attr(out, "status")
    if (!is.null(status) && status != 0) stop(paste(c("Script failed:", script, tail(out, 25)), collapse = "\n"))
    invisible(out)
}
panel_dir <- file.path(root, "panel")
run("import-corelogic-snapshots-panel.R", sprintf("SNAPSHOT_RESULTS=%s", panel_dir))
tab_dir <- file.path(root, "tab")
run("import-corelogic-snapshots-tabulate.R", sprintf("SNAPSHOT_RESULTS=%s", tab_dir),
    sprintf("SNAPSHOT_PANEL=%s", file.path(panel_dir, "panel.parquet")))

con <- dbConnect(duckdb())
on.exit(dbDisconnect(con, shutdown = TRUE))
panel <- as.data.table(dbGetQuery(con, sprintf("SELECT * FROM read_parquet('%s')", file.path(panel_dir, "panel.parquet"))))
snapshots <- fread(file.path(panel_dir, "snapshots.csv"))
stopifnot(identical(snapshots$snapshot_year, c(2023L, 2022L, 2021L, 2024L)))
# Row accounting: 9 parcels in the county per snapshot (A,B,C,D,G,I,J + E or F) plus G's duplicate in 2.
stopifnot(!"K" %in% panel$clip, all(panel$fips == "12071"))
stopifnot(nrow(panel[clip == "G"]) == 3, nrow(panel[clip == "E"]) == 2, nrow(panel[clip == "F"]) == 2)
stopifnot(!anyDuplicated(panel[, .(clip, snap_idx)]))
stopifnot(panel[clip == "B" & snapshot_year == 2024L, year_built] == 2023L)
stopifnot(panel[clip == "A", unique(mh)] == 1L, panel[clip == "I" & snapshot_year == 2021L, mh] == 0L)

tab <- function(name) fread(file.path(tab_dir, paste0(name, ".csv")), colClasses = c(fips = "character"))
cr <- tab("tab-collapse-recovery")
# B and C collapse in interval 2 -> 3; both recover at snapshot 4 (D's flip is not a collapse).
stopifnot(cr[type_a == "MH" & grepl("^4", yb_outcome), sum(n)] == 1,
    cr[type_a == "MH" & grepl("^3", yb_outcome), sum(n)] == 1, cr[, sum(n)] == 2,
    all(cr$event_time == 1))

ch <- tab("tab-changes")
# I (SB) is the only parcel whose year_built changes, between snapshots 2 and 3, by +1.
stopifnot(ch[, sum(n_yb_changed)] == 2, ch[idx_a == 2 & type_a == "SB", sum(n_yb_changed)] == 1)
# B's year_built also changes (snapshot 3 -> 4), type MH.
stopifnot(ch[idx_a == 3 & type_a == "MH", sum(n_yb_changed)] == 1)
stopifnot(ch[idx_a == 2, sum(n_sb_to_mh)] == 1, ch[, sum(n_mh_to_sb)] == 0)
stopifnot(ch[idx_a == 2 & type_a %in% c("MH", "SB"), sum(n_impr_drop80)] == 2)

dl <- tab("tab-yb-delta")
stopifnot(dl[delta_bin == "3: 1..2", sum(n)] == 1, dl[delta_bin == "6: > 10", sum(n)] == 1)

mt <- tab("tab-clip-match")
# Between snapshots 2 and 3, E leaves and F arrives carrying PREVIOUS CLIP = E; G is absent from
# the snapshot-2 panel (duplicate key), so six clips are in both.
stopifnot(mt[idx_a == 2, n_b_new_with_prev_clip_in_a] == 1, mt[idx_a == 2, n_both] == 6)

ef <- tab("tab-eff-static")
stopifnot(ef[, sum(n_eff_before_yb)] == 4, ef[, sum(n_eff_after_yb)] == 0)
em <- tab("tab-eff-moves")
# Effective year built moves only together with year built here (B and I).
stopifnot(em[, sum(n_eff_changed)] == 2, em[, sum(n_eff_changed_yb_changed)] == 2,
    em[, sum(n_eff_changed_yb_same)] == 0)

up <- tab("tab-update-timing")
stopifnot(all(up$n_update_missing == 0), all(up$n_updated_in_snapshot_year == up$n))
chk <- jsonlite::fromJSON(file.path(panel_dir, "checks.json"))
stopifnot(chk$dup_keys == 1, chk$dup_rows == 2, chk$null_clip_rows == 4, isTRUE(chk$panel_key_unique))
cat("check-corelogic-snapshots: all assertions passed\n")
unlink(root, recursive = TRUE)
