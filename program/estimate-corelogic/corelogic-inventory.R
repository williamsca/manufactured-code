# Eligible surviving dwelling inventory by county, tract and construction year.
cl_inventory_cells <- function(glob, years = 1989:1999) {
    stopifnot(identical(as.integer(years), seq.int(min(years), max(years))))
    pb_source <- Sys.getenv("CORELOGIC_PB_SOURCE")
    if (!nzchar(pb_source) || basename(pb_source) != manifest$pb_version)
        stop("Set CORELOGIC_PB_SOURCE to the pinned Property Basic version")
    meta <- fromJSON(file.path(pb_source, "_meta.json"))
    stopifnot(meta$n_rows == manifest$pb_source_rows)
    pb <- quote_path(file.path(pb_source, "*.parquet"))
    cells <- read_corelogic(sprintf("WITH eligible AS (
        SELECT clip, countyfp, year_built AS year_constr, mh FROM read_parquet(%s)
        WHERE countyfp IS NOT NULL AND clip IS NOT NULL AND year_built BETWEEN %d AND %d
        AND mh IS NOT NULL AND COALESCE(land_use_code,'') NOT IN ('135','136','454','400')
        AND COALESCE(property_indicator_code,'') IN ('','00','10')
        AND (number_of_buildings IS NULL OR number_of_buildings=1)
        AND (number_of_units IS NULL OR number_of_units=1)
    ), assigned AS (
        SELECT s.*, CASE WHEN regexp_full_match(TRIM(p.census_id),'[0-9]{10}')
            AND LEFT(TRIM(p.census_id),6)<>'000000'
            THEN s.countyfp || LEFT(TRIM(p.census_id),6) ELSE NULL END AS tractfp
        FROM eligible s LEFT JOIN read_parquet(%s) p ON s.clip=p.clip AND s.countyfp=p.countyfp
    ) SELECT countyfp, tractfp, year_constr, COUNT(*) AS homes, SUM(mh) AS mh_homes,
        COUNT(DISTINCT clip) AS parcels FROM assigned GROUP BY countyfp,tractfp,year_constr", glob, min(years), max(years), pb))
    stopifnot(all(cells$homes == cells$parcels))
    cells
}
