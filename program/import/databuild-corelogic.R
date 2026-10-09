# Hosted CoreLogic property/transfer build, including repeat-sale readiness.
# Run on a Rivanna compute node. Example:
# Rscript program/import/databuild-corelogic.R --states=FL,NC --run-id=pilot
# CORELOGIC_OUTPUT_ROOT must name a private artifact directory (default derived/corelogic).
# Existing run directories are refused, so pilot/full builds cannot overwrite one another.

main <- function() {
    if (!nzchar(Sys.getenv("SLURM_JOB_ID")))
        stop("Run this workstream in a Slurm job on Rivanna; no local CoreLogic extracts.")
    library(DBI)
    library(duckdb)
    library(data.table)
    library(jsonlite)
    library(here)
    source(here("program", "import", "project-params.R"))
    source(here("program", "lib", "corelogic-sample.R"))
    rd_home <- Sys.getenv("RD_HOME")
    if (!nzchar(rd_home)) stop("Set RD_HOME to the research-database checkout on this machine.")
    source(file.path(rd_home, "client", "r", "load_all.R"))
    rd_load_client(file.path(rd_home, "client", "r"))

    args <- commandArgs(trailingOnly = TRUE)
    if (any(!grepl("^--(states|run-id|reference-dir)=", args)))
        stop("Options: --states=FL,NC --run-id=<unique-name> --reference-dir=<public-reference-bundle>")
    option <- function(key, default) {
        x <- args[startsWith(args, paste0("--", key, "="))]
        if (length(x) > 1) stop("Repeated option: ", key)
        if (length(x)) sub("^[^=]+=", "", x) else default
    }
    run_id <- option("run-id", format(Sys.time(), "%Y%m%dT%H%M%S"))
    if (!grepl("^[A-Za-z0-9_-]+$", run_id)) stop("Invalid run-id")
    output_root <- Sys.getenv("CORELOGIC_OUTPUT_ROOT", here("derived", "corelogic"))
    out <- file.path(output_root, run_id)
    if (dir.exists(out)) stop("Run already exists: ", out, "; choose a new run-id.")

    pb_glob <- rd_path("cl_property_basic", version = CORELOGIC_PB_VERSION, tier = "licensed")
    ot_glob <- rd_path("cl_owner_transfer", version = CORELOGIC_OT_VERSION, tier = "licensed")
    read_manifest <- function(glob, expected) {
        meta <- file.path(dirname(glob), "_meta.json")
        if (!file.exists(meta)) stop("No full source manifest: ", meta)
        m <- fromJSON(meta)
        if (m$n_rows != expected || any(!file.exists(file.path(dirname(glob), m$parts$file))))
            stop("Incomplete/unexpected pinned source: ", meta)
        m
    }
    pb_meta <- read_manifest(pb_glob, 114032245)
    ot_meta <- read_manifest(ot_glob, 271394803)
    reference_dir <- option("reference-dir", "")
    # An explicit public reference bundle permits a source/sample audit without
    # S3 credentials on the host. It never impersonates a pinned curated version.
    if (nzchar(reference_dir)) {
        reference_files <- file.path(reference_dir, c("geo_state.parquet", "ecfr-windzone.csv", "cpi-bls.csv"))
        if (any(!file.exists(reference_files))) stop("Incomplete public reference bundle")
        ref_con <- rd_con()
        geo <- as.data.table(dbGetQuery(ref_con, sprintf("SELECT statefp, stusab FROM read_parquet(%s)",
            cl_sql_string(reference_files[1]))))
        dbDisconnect(ref_con, shutdown = TRUE)
        reference_metadata <- list(mode = "explicit_project_files",
            files = as.list(tools::md5sum(reference_files)),
            wind_zone_version = NULL, cpi_version = NULL,
            note = "Legacy project reference files used for databuild audit; refresh curated wind-zone reference before estimation.")
    } else {
        geo <- rd_read("geo_state", cols = c("statefp", "stusab"))
        reference_metadata <- list(mode = "curated", wind_zone_version = ECFR_WIND_ZONE_VERSION)
    }
    geo <- geo[!statefp %in% c("02", "15") & as.integer(statefp) <= 56]
    states <- strsplit(option("states", paste(sort(geo$stusab), collapse = ",")), ",", fixed = TRUE)[[1]]
    states <- sort(unique(states))
    if (!length(states) || any(!states %in% geo$stusab)) stop("states must be continental US state abbreviations (or DC)")
    if (any(!states %in% pb_meta$parts$part) || any(!states %in% ot_meta$parts$part))
        stop("Requested state missing from a source manifest")

    if (nzchar(reference_dir)) {
        wz <- fread(reference_files[2], colClasses = c(countyfp = "character"))[, .(countyfp, wind_zone)]
        cpi <- fread(reference_files[3])[, .(year, cpi_u_nsa_1982_84 = cpi)]
        cpi_version <- NA_character_
    } else {
        wz <- rd_read("ecfr_wind_zone", version = ECFR_WIND_ZONE_VERSION,
                      cols = c("countyfp", "wind_zone"))
        cpi_version <- rd_latest_version("bls_cpi")
        cpi <- rd_read("bls_cpi", version = cpi_version, cols = c("year", "cpi_u_nsa_1982_84"))
        reference_metadata$cpi_version <- cpi_version
    }
    if (anyDuplicated(wz$countyfp)) stop("Duplicate county in wind-zone crosswalk")
    cpi <- cpi[!is.na(cpi_u_nsa_1982_84), .(cpi = mean(cpi_u_nsa_1982_84)), by = year]
    cpi[, cpi_ratio := cpi / cpi[year == DISCOUNT_YEAR]]
    if (length(cpi$cpi[cpi$year == DISCOUNT_YEAR]) != 1 || anyNA(cpi$cpi_ratio)) stop("Invalid CPI base")

    dir.create(out, recursive = TRUE)
    for (d in c("properties", "transfers", "sales", "pairs", "audit")) dir.create(file.path(out, d))
    temp_dir <- file.path(out, "duckdb-tmp")
    dir.create(temp_dir)
    con <- rd_con()
    on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)
    threads <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", "4"))
    dbExecute(con, sprintf("SET threads=%d", threads))
    dbExecute(con, paste0("SET memory_limit=", cl_sql_string(Sys.getenv("CORELOGIC_DUCKDB_MEMORY", "16GB"))))
    dbExecute(con, paste0("SET temp_directory=", cl_sql_string(temp_dir)))
    dbExecute(con, "SET preserve_insertion_order=false")
    dbWriteTable(con, "wind_zone", as.data.frame(wz))
    dbWriteTable(con, "cpi", as.data.frame(cpi[, .(year, cpi_ratio)]))

    manifest <- list(status = "running", run_id = run_id, started = format(Sys.time(), tz = "UTC"),
        states = states, full_continental = setequal(states, geo$stusab),
        pb_version = CORELOGIC_PB_VERSION, ot_version = CORELOGIC_OT_VERSION,
        delivery = "20230817", pb_source_rows = pb_meta$n_rows, ot_source_rows = ot_meta$n_rows,
        references = reference_metadata, cpi_base_year = DISCOUNT_YEAR,
        min_vintage = MIN_YEAR_CONSTR, max_vintage = MAX_YEAR_CONSTR,
        min_sale_year = CORELOGIC_MIN_SALE_YEAR, max_sale_year = CORELOGIC_MAX_SALE_YEAR,
        mh_definition = "mobile_home_indicator = Y (transfer-time for historical records)",
        current_snapshot_is_historical_fallback = FALSE,
        sale_screen = cl_market_sql(), dwelling_screen = cl_dwelling_sql(),
        code_md5 = as.list(tools::md5sum(c(here("program", "lib", "corelogic-sample.R"),
            here("program", "import", "databuild-corelogic.R"), here("program", "import", "project-params.R")))),
        source_manifests = list(property_basic = pb_meta, owner_transfer = ot_meta))
    write_json(manifest, file.path(out, "manifest.json"), pretty = TRUE, auto_unbox = TRUE)
    audits <- list()
    audit <- function(name, sql, state) {
        dt <- as.data.table(dbGetQuery(con, sql))
        dt[, source_state := state]
        audits[[name]] <<- rbindlist(list(audits[[name]], dt), fill = TRUE)
        fwrite(audits[[name]], file.path(out, "audit", paste0(name, ".csv")))
        dt
    }
    copy <- function(sql, kind, state) {
        path <- file.path(out, kind, paste0(state, ".parquet"))
        dbExecute(con, sprintf("COPY (%s) TO %s (FORMAT PARQUET, COMPRESSION ZSTD)", sql, cl_sql_string(path)))
    }
    pb_fields <- c("clip", "previous_clip", "countyfp", "mobile_home_indicator", "land_use_code",
        "property_indicator_code", "year_built", "effective_year_built", "number_of_buildings", "number_of_units",
        "parcel_level_latitude", "parcel_level_longitude", "block_level_latitude", "block_level_longitude",
        "universal_building_square_feet", "land_square_footage", "total_value_calculated",
        "land_value_calculated", "improvement_value_calculated",
        "calculated_value_source_indicator AS calculated_value_source_code", "assessed_year")
    ot_fields <- c("clip", "previous_clip", "countyfp", "source_file_state",
        "owner_transfer_composite_transaction_id", "land_use_code_static", "mobile_home_indicator",
        "property_indicator_code_static", "actual_year_built_static", "effective_year_built_static",
        "total_number_of_buildings", "primary_category_code", "deed_category_type_code", "sale_type_code",
        "sale_amount", "sale_derived_date", "sale_derived_date_raw", "sale_derived_recording_date",
        "sale_derived_recording_date_raw", "multi_or_split_parcel_code", "partial_interest_indicator",
        "ownership_transfer_percentage", "interfamily_related_indicator", "new_construction_indicator",
        "resale_indicator", "short_sale_indicator", "foreclosure_reo_indicator", "foreclosure_reo_sale_indicator")
    pb_scan <- function(path) sprintf("read_parquet(%s)", cl_sql_string(path))
    ot_null <- file.path(dirname(ot_glob), ot_meta$parts$file[ot_meta$parts$part == "NULL"])
    if (length(ot_null) != 1) stop("Expected the unassigned-state transfer archive")

    for (state in states) {
        message(format(Sys.time()), " starting ", state)
        fips <- geo[stusab == state, statefp]
        pb_file <- file.path(dirname(pb_glob), pb_meta$parts$file[pb_meta$parts$part == state])
        ot_file <- file.path(dirname(ot_glob), ot_meta$parts$file[ot_meta$parts$part == state])
        dbExecute(con, sprintf("CREATE OR REPLACE TEMP VIEW pb AS SELECT %s FROM %s",
            paste(pb_fields, collapse = ","), pb_scan(pb_file)))
        # The NULL archive can contain usable mainland county IDs. Include those
        # by county, while auditing cross-state/missing county IDs in regular files.
        dbExecute(con, sprintf("CREATE OR REPLACE TEMP VIEW ot AS
            SELECT %s FROM %s WHERE LEFT(countyfp,2) = %s
            UNION ALL SELECT %s FROM %s WHERE LEFT(countyfp,2) = %s",
            paste(ot_fields, collapse = ","), pb_scan(ot_file), cl_sql_string(fips),
            paste(ot_fields, collapse = ","), pb_scan(ot_null), cl_sql_string(fips)))
        audit("source_geography", sprintf("SELECT COUNT(*) AS records,
            COUNT(*) FILTER (WHERE countyfp IS NULL) AS missing_county,
            COUNT(*) FILTER (WHERE countyfp IS NOT NULL AND LEFT(countyfp,2) <> %s) AS different_state_county
            FROM %s", cl_sql_string(fips), pb_scan(ot_file)), state)
        audit("property_indicator", "SELECT mobile_home_indicator, land_use_code, property_indicator_code,
            COUNT(*) AS properties, COUNT(*) FILTER (WHERE year_built BETWEEN 1984 AND 1999) AS vintage_properties
            FROM pb GROUP BY ALL", state)
        audit("transfer_indicator", "SELECT mobile_home_indicator, land_use_code_static, property_indicator_code_static,
            COUNT(*) AS transfers, COUNT(*) FILTER (WHERE actual_year_built_static BETWEEN 1984 AND 1999) AS vintage_transfers
            FROM ot GROUP BY ALL", state)
        audit("original_vintage", "SELECT mobile_home_indicator, actual_year_built_static,
            COUNT(*) AS transfers FROM ot WHERE mobile_home_indicator = 'Y'
            OR property_indicator_code_static = '10' GROUP BY ALL", state)
        cl_build_transfers(con, MIN_YEAR_CONSTR, MAX_YEAR_CONSTR, CORELOGIC_MIN_SALE_YEAR, CORELOGIC_MAX_SALE_YEAR)
        n <- dbGetQuery(con, "SELECT COUNT(*) AS n, COUNT(DISTINCT owner_transfer_composite_transaction_id) AS ids FROM transfers")
        if (n$n != n$ids) stop("Transfer key duplicated in ", state)
        invalid <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM transfers
            WHERE eligible_sale AND cpi_ratio IS NULL")$n
        if (invalid) stop("Missing CPI on eligible sales: ", invalid)
        cl_build_pairs(con, MIN_YEAR_CONSTR, MAX_YEAR_CONSTR, CORELOGIC_MIN_SALE_YEAR, CORELOGIC_MAX_SALE_YEAR)
        copy(sprintf("SELECT p.*, %s AS mh, w.wind_zone FROM pb p LEFT JOIN wind_zone w USING (countyfp)
            WHERE mobile_home_indicator = 'Y' OR property_indicator_code = '10'",
            cl_type_sql("mobile_home_indicator", "property_indicator_code", "land_use_code")), "properties", state)
        copy("SELECT * FROM transfers", "transfers", state)
        copy("SELECT * FROM transfers WHERE eligible_sale", "sales", state)
        copy("SELECT * FROM pairs", "pairs", state)
        audit("sample_counts", "SELECT mh, COUNT(*) AS transfers, COUNT(DISTINCT clip) AS properties,
            COUNT(*) FILTER (WHERE NOT pb_matched) AS unmatched_snapshot,
            COUNT(*) FILTER (WHERE snapshot_type_differs) AS snapshot_type_differs,
            COUNT(*) FILTER (WHERE snapshot_vintage_differs) AS snapshot_vintage_differs,
            COUNT(*) FILTER (WHERE eligible_sale) AS eligible_sales,
            COUNT(*) FILTER (WHERE analysis_ready) AS analysis_sales,
            COUNT(*) FILTER (WHERE analysis_ready_strict) AS analysis_sales_strict,
            COUNT(*) FILTER (WHERE date_source = 'recording') AS recording_date_fallback,
            COUNT(*) FILTER (WHERE date_source = 'missing') AS missing_date
            FROM transfers GROUP BY mh", state)
        audit("exclusions", "SELECT mh, COUNT(*) AS transfers,
            COUNT(*) FILTER (WHERE NOT market_clean) AS not_market_clean,
            COUNT(*) FILTER (WHERE NOT dwelling) AS not_dwelling,
            COUNT(*) FILTER (WHERE distressed) AS distressed,
            COUNT(*) FILTER (WHERE same_day_transfers > 1 AND date_sale IS NOT NULL) AS same_day_ambiguous,
            COUNT(*) FILTER (WHERE NOT vintage_in_window) AS outside_or_missing_original_vintage,
            COUNT(*) FILTER (WHERE year_constr = 1994) AS transition_1994,
            COUNT(*) FILTER (WHERE wind_zone IS NULL) AS missing_wind_zone,
            COUNT(*) FILTER (WHERE multi_or_split_parcel_code IS NULL) AS blank_parcel_flag,
            COUNT(*) FILTER (WHERE ownership_transfer_percentage IS NULL) AS missing_ownership_percentage
            FROM transfers GROUP BY mh", state)
        audit("transaction_codes", "SELECT mh, primary_category_code, deed_category_type_code, sale_type_code,
            COUNT(*) AS transfers FROM transfers GROUP BY ALL", state)
        audit("dwelling_codes", "SELECT mh, land_use_code_static, property_indicator_code_static,
            total_number_of_buildings, COUNT(*) AS transfers FROM transfers GROUP BY ALL", state)
        audit("market_flags", "SELECT mh, multi_or_split_parcel_code, partial_interest_indicator,
            ownership_transfer_percentage, interfamily_related_indicator,
            COUNT(*) AS transfers FROM transfers GROUP BY ALL", state)
        audit("price_distribution", "SELECT mh, COUNT(*) AS sales,
            MIN(sale_price_2000) AS min_price_2000,
            QUANTILE_CONT(sale_price_2000,0.01) AS p01_price_2000,
            MEDIAN(sale_price_2000) AS median_price_2000,
            QUANTILE_CONT(sale_price_2000,0.99) AS p99_price_2000,
            QUANTILE_CONT(sale_price_2000,0.999) AS p999_price_2000,
            MAX(sale_price_2000) AS max_price_2000
            FROM transfers WHERE eligible_sale GROUP BY mh", state)
        audit("sale_support", "SELECT countyfp, year_sale, year_constr, mh, wind_zone,
            COUNT(*) AS sales, COUNT(DISTINCT clip) AS properties, AVG(sale_price_2000) AS mean_price_2000,
            MEDIAN(sale_price_2000) AS median_price_2000,
            COUNT(*) FILTER (WHERE analysis_ready) AS analysis_sales
            FROM transfers WHERE eligible_sale GROUP BY ALL", state)
        audit("pair_support", "SELECT countyfp, mh_pre, vintage_pre, wind_zone,
            COUNT(*) AS pairs, COUNT(DISTINCT clip) AS properties,
            COUNT(*) FILTER (WHERE stable_structure) AS stable_pairs,
            COUNT(*) FILTER (WHERE analysis_ready) AS analysis_pairs,
            COUNT(*) FILTER (WHERE analysis_ready_strict) AS analysis_pairs_strict,
            MEDIAN(holding_days) AS median_holding_days FROM pairs GROUP BY ALL", state)
        audit("pair_changes", "SELECT mh_pre, mh_post, stable_structure, distressed_pre, distressed_post,
            COUNT(*) AS pairs FROM pairs GROUP BY ALL", state)
        for (table in c("pairs", "transfers", "cohort_clips")) dbExecute(con, paste("DROP TABLE", table))
        message(format(Sys.time()), " completed ", state)
        gc()
    }
    manifest$status <- "complete"
    manifest$finished <- format(Sys.time(), tz = "UTC")
    summary_fields <- c("transfers", "unmatched_snapshot", "snapshot_type_differs",
        "snapshot_vintage_differs", "eligible_sales", "analysis_sales",
        "recording_date_fallback", "missing_date", "analysis_sales_strict")
    fwrite(audits$sample_counts[, lapply(.SD, sum), by = mh, .SDcols = summary_fields],
        file.path(out, "audit", "summary_by_type.csv"))
    fwrite(audits$pair_support[, lapply(.SD, sum), by = mh_pre,
        .SDcols = c("pairs", "stable_pairs", "analysis_pairs", "analysis_pairs_strict")],
        file.path(out, "audit", "summary_pairs.csv"))
    manifest$rows <- as.list(audits$sample_counts[, lapply(.SD, sum),
        .SDcols = c("transfers", "properties", "eligible_sales", "analysis_sales")])
    # properties summed across type groups are not globally distinct counts.
    manifest$rows$properties <- NULL
    write_json(manifest, file.path(out, "manifest.json"), pretty = TRUE, auto_unbox = TRUE)
    message("Completed build: ", out)
}

main()
