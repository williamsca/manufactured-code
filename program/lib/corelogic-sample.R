# SQL rules shared by the CoreLogic databuild and its fixture test.
# MH is CoreLogic's derived parcel indicator, as requested, not a land-use proxy.
cl_sql_string <- function(x) paste0("'", gsub("'", "''", x, fixed = TRUE), "'")

cl_type_sql <- function(indicator, property_code, land_use) {
    sprintf("CASE WHEN %s = 'Y' THEN 1
        WHEN %s = '10' AND COALESCE(%s, '') NOT IN ('135','136','137','138','454')
             AND COALESCE(%s, '') IN ('','N') THEN 0 ELSE NULL END",
        indicator, property_code, land_use, indicator)
}

cl_market_sql <- function(consideration = c("provisional", "strict", "ignore")) {
    # Blank parcel/interest flags are allowed but explicitly retained for audits.
    # Distressed sales stay available in transfers and a separate sales subset.
    consideration <- match.arg(consideration)
    consideration_rule <- switch(consideration,
        provisional = "(sale_type_code IS NULL OR sale_type_code IN ('F','C','V'))",
        strict = "COALESCE(sale_type_code IN ('F','C','V'), FALSE)",
        ignore = "TRUE")
    sprintf("COALESCE(primary_category_code = 'A', FALSE)
      AND COALESCE(deed_category_type_code = 'G', FALSE)
      AND %s
      AND sale_amount > 0
      AND COALESCE(multi_or_split_parcel_code, '') = ''
      AND COALESCE(partial_interest_indicator, '') IN ('','0','N')
      AND (ownership_transfer_percentage IS NULL OR ownership_transfer_percentage = 100)
      AND COALESCE(interfamily_related_indicator, 0) = 0", consideration_rule)
}

cl_dwelling_sql <- function() {
    # The parcel indicator can also flag a home on a park/commercial property.
    # Keep those in the transfer frame, but exclude them from dwelling prices.
    "mh IS NOT NULL
      AND COALESCE(land_use_code_static, '') NOT IN ('135','136','454','400')
      AND COALESCE(property_indicator_code_static, '') IN ('','00','10')
      AND (total_number_of_buildings IS NULL OR total_number_of_buildings = 1)"
}

cl_build_transfers <- function(con, year_min, year_max, sale_min, sale_max) {
    execute <- function(sql) DBI::dbExecute(con, sql)
    # pb and ot are projected input tables/views; wind_zone and cpi are small
    # reference tables. Their names make the exact production joins testable.
    execute(sprintf("CREATE OR REPLACE TEMP TABLE cohort_clips AS
        SELECT clip FROM ot WHERE clip IS NOT NULL
          AND actual_year_built_static BETWEEN %d AND %d
          AND (%s) IS NOT NULL
        UNION SELECT clip FROM pb WHERE year_built BETWEEN %d AND %d
          AND (%s) IS NOT NULL",
        year_min, year_max,
        cl_type_sql("mobile_home_indicator", "property_indicator_code_static", "land_use_code_static"),
        year_min, year_max,
        cl_type_sql("mobile_home_indicator", "property_indicator_code", "land_use_code")))

    execute(sprintf("CREATE OR REPLACE TEMP TABLE transfers AS
        WITH joined AS (
            SELECT o.*,
                %s AS mh,
                p.clip IS NOT NULL AS pb_matched,
                p.mobile_home_indicator AS pb_mobile_home_indicator,
                %s AS pb_mh,
                p.year_built AS pb_year_constr,
                p.effective_year_built AS pb_effective_year_constr,
                p.land_use_code AS pb_land_use_code,
                p.property_indicator_code AS pb_property_indicator_code,
                p.parcel_level_latitude AS latitude,
                p.parcel_level_longitude AS longitude,
                p.block_level_latitude AS block_latitude,
                p.block_level_longitude AS block_longitude,
                p.universal_building_square_feet AS pb_sqft,
                p.land_square_footage AS pb_lot_sqft,
                p.total_value_calculated AS pb_total_value,
                p.land_value_calculated AS pb_land_value,
                p.improvement_value_calculated AS pb_improvement_value,
                p.calculated_value_source_code AS pb_value_source,
                COALESCE(o.sale_derived_date, o.sale_derived_recording_date) AS date_sale,
                CASE WHEN o.sale_derived_date IS NOT NULL THEN 'derived'
                     WHEN o.sale_derived_recording_date IS NOT NULL THEN 'recording'
                     ELSE 'missing' END AS date_source,
                o.actual_year_built_static AS year_constr,
                CASE WHEN o.actual_year_built_static BETWEEN 1800 AND 2023 THEN 'transfer_original'
                     WHEN p.year_built BETWEEN 1800 AND 2023 THEN 'snapshot_only'
                     ELSE 'missing' END AS vintage_source
            FROM ot o JOIN cohort_clips k USING (clip)
            LEFT JOIN pb p USING (clip)
        ), classified AS (
            SELECT *, YEAR(date_sale)::INTEGER AS year_sale,
                COALESCE(year_constr BETWEEN %d AND %d, FALSE) AS vintage_in_window,
                CASE WHEN year_constr IS NOT NULL THEN (year_constr >= 1994)::INTEGER END AS post1994,
                COALESCE(mh = 1 AND land_use_code_static NOT IN ('137','138'), FALSE)
                    AS mh_landuse_disagrees,
                COALESCE(mh <> pb_mh, FALSE) AS snapshot_type_differs,
                COALESCE(year_constr <> pb_year_constr, FALSE) AS snapshot_vintage_differs,
                COALESCE(%s, FALSE) AS market_clean,
                COALESCE(sale_type_code IN ('F','C','V'), FALSE) AS consideration_documented,
                COALESCE(%s, FALSE) AS dwelling,
                COALESCE(short_sale_indicator = 1 OR foreclosure_reo_indicator = 1
                    OR foreclosure_reo_sale_indicator = 1, FALSE) AS distressed,
                COUNT(*) OVER (PARTITION BY clip, date_sale) AS same_day_transfers
            FROM joined
        ), screened AS (SELECT a.*, w.wind_zone, c.cpi_ratio,
            sale_amount / c.cpi_ratio AS sale_price_2000,
            COALESCE(market_clean AND dwelling AND NOT distressed AND same_day_transfers = 1
                AND vintage_in_window AND year_sale BETWEEN %d AND %d, FALSE) AS eligible_sale,
            COALESCE(market_clean AND dwelling AND NOT distressed AND same_day_transfers = 1
                AND vintage_in_window AND year_constr <> 1994
                AND year_sale BETWEEN %d AND %d AND date_sale >= MAKE_DATE(year_constr,1,1), FALSE)
                AS analysis_ready
        FROM classified a LEFT JOIN wind_zone w USING (countyfp)
        LEFT JOIN cpi c ON a.year_sale = c.year)
        SELECT *, eligible_sale AND consideration_documented AS eligible_sale_strict,
            analysis_ready AND consideration_documented AS analysis_ready_strict FROM screened",
        cl_type_sql("o.mobile_home_indicator", "o.property_indicator_code_static", "o.land_use_code_static"),
        cl_type_sql("p.mobile_home_indicator", "p.property_indicator_code", "p.land_use_code"),
        year_min, year_max, cl_market_sql(), cl_dwelling_sql(),
        sale_min, sale_max, sale_min, sale_max))
}

cl_build_pairs <- function(con, year_min, year_max, sale_min, sale_max) {
    # Keep post-sale structure changes visible. Do not restrict the later sale
    # to the treatment-vintage window or to the same housing type.
    DBI::dbExecute(con, sprintf("CREATE OR REPLACE TEMP TABLE pairs AS
        WITH ordered AS (
            SELECT clip, countyfp, wind_zone,
                owner_transfer_composite_transaction_id AS transaction_id_post,
                date_sale AS date_post, sale_amount AS price_post,
                sale_price_2000 AS real_price_post, mh AS mh_post, year_constr AS vintage_post,
                LAG(owner_transfer_composite_transaction_id) OVER q AS transaction_id_pre,
                LAG(date_sale) OVER q AS date_pre, LAG(sale_amount) OVER q AS price_pre,
                LAG(sale_price_2000) OVER q AS real_price_pre,
                LAG(mh) OVER q AS mh_pre, LAG(year_constr) OVER q AS vintage_pre,
                LAG(dwelling) OVER q AS dwelling_pre,
                dwelling AS dwelling_post,
                LAG(distressed) OVER q AS distressed_pre, distressed AS distressed_post,
                LAG(date_source) OVER q AS date_source_pre, date_source AS date_source_post
                ,LAG(consideration_documented) OVER q AS consideration_documented_pre,
                consideration_documented AS consideration_documented_post
            FROM transfers WHERE market_clean AND same_day_transfers = 1
                AND year_sale BETWEEN %d AND %d
            WINDOW q AS (PARTITION BY clip ORDER BY date_sale, owner_transfer_composite_transaction_id)
        ) SELECT *, DATE_DIFF('day', date_pre, date_post) AS holding_days,
            LN(price_post / price_pre) AS log_price_change,
            LN(real_price_post / real_price_pre) AS real_log_price_change,
            (vintage_pre >= 1994)::INTEGER AS post1994_pre,
            COALESCE(mh_pre = mh_post AND vintage_pre = vintage_post, FALSE) AS stable_structure,
            COALESCE(dwelling_pre AND dwelling_post AND NOT distressed_pre AND NOT distressed_post
                AND mh_pre = mh_post AND vintage_pre = vintage_post AND vintage_pre <> 1994, FALSE)
                AS analysis_ready
            ,COALESCE(dwelling_pre AND dwelling_post AND NOT distressed_pre AND NOT distressed_post
                AND mh_pre = mh_post AND vintage_pre = vintage_post AND vintage_pre <> 1994
                AND consideration_documented_pre AND consideration_documented_post, FALSE)
                AS analysis_ready_strict
        FROM ordered WHERE transaction_id_pre IS NOT NULL AND date_post > date_pre
            AND mh_pre IS NOT NULL AND vintage_pre BETWEEN %d AND %d
            AND date_pre >= MAKE_DATE(vintage_pre,1,1)",
        sale_min, sale_max, year_min, year_max))
}
