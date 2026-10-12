# Fully static share comparison; the outcome is already in percentage points.
cl_share_static_formula <- function(tract = FALSE) {
    as.formula(paste("share_pp ~ post_z2 + post_z3 | countyfp + post",
        if (tract) "+ tractfp" else ""))
}

# Tract coverage on the full eligible surviving inventory, not the sale lookup.
cl_share_tract_cells <- function(glob) {
    pb_source <- Sys.getenv("CORELOGIC_PB_SOURCE")
    if (!nzchar(pb_source) || basename(pb_source) != manifest$pb_version)
        stop("Set CORELOGIC_PB_SOURCE to the pinned Property Basic version")
    meta <- fromJSON(file.path(pb_source, "_meta.json"))
    stopifnot(meta$n_rows == manifest$pb_source_rows)
    pb <- quote_path(file.path(pb_source, "*.parquet"))
    cells <- read_corelogic(sprintf("WITH eligible AS (
        SELECT clip, countyfp, year_built AS year_constr, mh FROM read_parquet(%s)
        WHERE countyfp IS NOT NULL AND clip IS NOT NULL AND year_built BETWEEN 1989 AND 1999
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
        COUNT(DISTINCT clip) AS parcels FROM assigned GROUP BY countyfp,tractfp,year_constr", glob, pb))
    stopifnot(all(cells$homes == cells$parcels))
    cells
}

cl_share_static_table <- function(models, out_dir, homes, counties) {
    fits <- models[c("baseline_static", "tract_static")]
    stopifnot(length(fits) == 2L, !any(vapply(fits, is.null, logical(1))))
    etable(fits, tex = TRUE, file = file.path(out_dir, "static_III_minus_I.tex"), replace = TRUE,
        keep = "%post_z3", digits = 4, fitstat = "n",
        style.tex = style.tex(tablefoot = FALSE),
        headers = c("Baseline", "+ Tract FE"),
        dict = c(share_pp = "MH share (percentage points)", post_z3 = "Zone III $\\times$ post",
            countyfp = "County", post = "Pre/post", tractfp = "Census tract"),
        extralines = list("Homes" = rep(format(homes, big.mark = ",", scientific = FALSE, trim = TRUE), 2),
            "Counties" = rep(as.character(counties), 2)),
        notes = NULL)
}
