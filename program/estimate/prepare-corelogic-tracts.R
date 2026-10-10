# Private snapshot tract lookup for the 2000-2023 vintage price sample.
rm(list = ls())
library(here)
source(here("program", "lib", "corelogic-setup.R"))
pb_source <- Sys.getenv("CORELOGIC_PB_SOURCE")
if (!nzchar(pb_source) || basename(pb_source) != manifest$pb_version) stop("Set CORELOGIC_PB_SOURCE to pinned Property Basic version")
meta <- fromJSON(file.path(pb_source, "_meta.json"))
stopifnot(meta$n_rows == manifest$pb_source_rows)
sales <- quote_path(file.path(input, "sales", "*.parquet"))
pb <- quote_path(file.path(pb_source, "*.parquet"))
con <- dbConnect(duckdb())
dbExecute(con, sprintf("SET threads=%d", threads))
dbExecute(con, "SET memory_limit='16GB'")
dbExecute(con, paste("SET temp_directory =", quote_path(file.path(out_dir, "duckdb-tmp"))))
dbExecute(con, sprintf("CREATE TEMP TABLE clips AS SELECT DISTINCT clip, countyfp FROM read_parquet(%s)
    WHERE eligible_sale AND countyfp IS NOT NULL AND year_sale BETWEEN 2000 AND 2023
    AND year_constr BETWEEN 1989 AND 1999 AND date_sale >= MAKE_DATE(year_constr,1,1)", sales))
dbExecute(con, sprintf("CREATE TEMP TABLE lookup AS SELECT s.clip, s.countyfp, p.countyfp AS pb_countyfp,
    TRIM(p.census_id) AS census_id FROM clips s LEFT JOIN read_parquet(%s) p ON s.clip=p.clip", pb))
checks <- dbGetQuery(con, "SELECT COUNT(*) AS rows, COUNT(DISTINCT clip) AS clips FROM lookup")
stopifnot(checks$rows == checks$clips)
# CoreLogic's 10-character census identifier contains six tract digits then block digits.
# Never pad malformed IDs or combine a snapshot tract with a different historical county.
formats <- dbGetQuery(con, "SELECT LENGTH(census_id) AS census_id_length,
    regexp_full_match(census_id,'[0-9]{10}') AS numeric_ten,
    countyfp=pb_countyfp AS same_county, COUNT(*) AS parcels FROM lookup GROUP BY ALL")
fwrite(formats, file.path(out_dir, "census_id_formats.csv"))
dbExecute(con, paste("COPY (SELECT clip, countyfp, CASE WHEN countyfp=pb_countyfp
    AND regexp_full_match(census_id,'[0-9]{10}') AND LEFT(census_id,6)<>'000000'
    THEN countyfp || LEFT(census_id,6) ELSE NULL END AS tractfp FROM lookup) TO",
    quote_path(file.path(out_dir, "parcel_tracts.parquet")), "(FORMAT PARQUET, COMPRESSION ZSTD)"))
audit <- dbGetQuery(con, paste("SELECT COUNT(*) AS parcels, COUNT(tractfp) AS tract_parcels,
    COUNT(DISTINCT tractfp) AS tracts FROM read_parquet(", quote_path(file.path(out_dir, "parcel_tracts.parquet")), ")"))
fwrite(audit, file.path(out_dir, "tract_lookup_support.csv"))
dbDisconnect(con, shutdown = TRUE)
files <- c(here("program", "estimate", "prepare-corelogic-tracts.R"), here("program", "lib", "corelogic-setup.R"))
dir.create(file.path(out_dir, "source")); file.copy(files, file.path(out_dir, "source"))
write_json(list(status = "complete", build = input, source = pb_source, job = Sys.getenv("SLURM_JOB_ID"),
    census_id_rule = "County FIPS + first six digits of numeric ten-character snapshot census_id, same county only",
    tract_boundary_vintage = "Not specified by CoreLogic dictionary; snapshot geographic assignment",
    support = audit, pb_source_manifest_md5 = unname(tools::md5sum(file.path(pb_source, "_meta.json"))),
    code_md5 = as.list(tools::md5sum(files))), file.path(out_dir, "manifest.json"), pretty = TRUE, auto_unbox = TRUE)
cat("COMPLETE", out_dir, "\n")
