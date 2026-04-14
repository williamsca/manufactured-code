# Build NFIP claim-level data and balanced panel, querying directly from DuckDB
#
# Inputs:  $DATA_PATH/derived/fema.duckdb
#          derived/ecfr-windzone.csv
# Outputs: derived/nfip-claims.Rds   (claim-level, filtered + renamed)
#          derived/nfip-balanced.Rds (tractfp × period_loss × mh × year_constr)
#
# period_loss: 5-year bins (1994 = 1994-1998, 1999 = 1999-2003, ...)
# year_constr: individual construction year (binning done at estimation)

rm(list = ls()); gc()
library(here)
library(DBI)
library(duckdb)
library(data.table)

source(here("program", "import", "project-params.R"))

data_path <- Sys.getenv("DATA_PATH")
if (nchar(data_path) == 0) stop("DATA_PATH environment variable is not set.")

# vintage filtering
year_min <- 1984L
year_max <- 1999L

dt_cpi <- fread(here("derived", "cpi-bls.csv"))
dt_cpi <- dt_cpi[, .(cpi = mean(cpi)), by = year]
dt_cpi[, cpi := cpi / cpi[year == DISCOUNT_YEAR]]

drv <- duckdb(file.path(data_path, "derived", "fema.duckdb"), read_only = TRUE)
con <- dbConnect(drv)
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

# ---------------------------------------------------------------------------
# 1. Claims ----
# ---------------------------------------------------------------------------

sql_claims <- "
SELECT
    countyCode                         AS countyfp,
    censusTract                        AS tractfp,
    censusBlockGroupFips               AS bgfp,
    yearOfLoss                         AS year_loss,
    YEAR(originalConstructionDate)     AS year_constr,
    CASE WHEN numberOfFloorsInTheInsuredBuilding = 5 THEN 1 ELSE 0 END AS mh,
    CAST(netBuildingPaymentAmount      AS DOUBLE) AS net_building_pmt,
    CAST(buildingDamageAmount          AS DOUBLE) AS building_damage,
    CAST(buildingPropertyValue         AS DOUBLE) AS building_value,
    CAST(contentsDamageAmount          AS DOUBLE) AS contents_damage,
    CAST(netContentsPaymentAmount      AS DOUBLE) AS net_contents_pmt,
    CAST(contentsPropertyValue         AS DOUBLE) AS contents_value,
    CAST(totalBuildingInsuranceCoverage AS DOUBLE) AS building_covg,
    CAST(totalContentsInsuranceCoverage AS DOUBLE) AS contents_covg,
    CAST(waterDepth AS DOUBLE)                     AS water_depth,
    CASE WHEN elevatedBuildingIndicator THEN 1 ELSE 0 END AS elevated,
    CAST(buildingReplacementCost AS DOUBLE)        AS building_repl_cost,
    CASE
        WHEN ratedFloodZone IS NOT NULL
            AND regexp_matches(ratedFloodZone, '^(A|V|AR)')
        THEN 1 ELSE 0
    END                                            AS sfha,
    CASE WHEN primaryResidenceIndicator THEN 1 ELSE 0 END AS primary_res,
    occupancyType                                  AS occupancy_type
FROM nfip_claims
WHERE numberOfFloorsInTheInsuredBuilding IN (1, 2, 3, 5)
    AND yearOfLoss               IS NOT NULL
    AND originalConstructionDate IS NOT NULL
    AND countyCode               IS NOT NULL
    AND censusTract              IS NOT NULL
    AND state IS NOT NULL
    AND state NOT IN ('AS', 'GU', 'VI', 'PR', 'AK', 'HI')
    AND TRY_CAST(LEFT(censusTract, 2) AS INT) <= 56
"

dt_claims <- as.data.table(dbGetQuery(con, sql_claims))

dt_claims <- merge(
    dt_claims,
    dt_cpi[, .(year_loss = year, cpi)],
    by = "year_loss",
    all.x = TRUE
)

stopifnot(!anyNA(dt_claims$cpi))

v_nom_claims <- c(
    "net_building_pmt",
    "building_damage",
    "building_value",
    "contents_damage",
    "net_contents_pmt",
    "contents_value",
    "building_covg",
    "contents_covg",
    "building_repl_cost"
)
dt_claims[, (v_nom_claims) := lapply(.SD, function(x) x / cpi), .SDcols = v_nom_claims]

message(sprintf(
    "Loaded %d claims (%d MH [floors=5], %d site-built [floors 1-3])",
    nrow(dt_claims),
    dt_claims[mh == 1L, .N],
    dt_claims[mh == 0L, .N]
))

# post-1994 shares by MH status
dt_claims[, .(
    n_claims     = .N,
    pct_post1994 = mean(year_constr >= 1994L, na.rm = TRUE)
), by = .(mh)] |> print()

saveRDS(dt_claims, here("derived", "nfip-claims.Rds"))
message(sprintf("Saved %d claims to derived/nfip-claims.Rds", nrow(dt_claims)))

# ---------------------------------------------------------------------------
# 2. Policies: expand to calendar years via DuckDB range join ----
#
#   A policy covers calendar year Y if year_eff <= Y <= year_term.
#   DuckDB's range join handles this efficiently without a Cartesian
#   intermediate in R.
# ---------------------------------------------------------------------------

sql_policies <- sprintf("
WITH filtered AS (
    SELECT
        censusTract                                                       AS tractfp,
        YEAR(originalConstructionDate)                                    AS year_constr,
        CASE WHEN numberOfFloorsInInsuredBuilding = 5 THEN 1 ELSE 0 END  AS mh,
        YEAR(policyEffectiveDate)                                         AS year_eff,
        YEAR(policyTerminationDate)                                       AS year_term,
        CAST(buildingReplacementCost AS DOUBLE)                           AS repl_cost,
        CAST(policyCost              AS DOUBLE)                           AS policy_cost,
        CAST(totalBuildingInsuranceCoverage AS DOUBLE)                    AS building_policy_covg,
        CAST(totalContentsInsuranceCoverage AS DOUBLE)                    AS contents_policy_covg,
        CASE WHEN elevatedBuildingIndicator THEN 1 ELSE 0 END             AS elevated_policy,
        CASE WHEN primaryResidenceIndicator THEN 1 ELSE 0 END             AS primary_res_policy,
        CASE WHEN mandatoryPurchaseFlag THEN 1 ELSE 0 END                 AS mandatory_purchase_policy,
        CASE
            WHEN ratedFloodZone IS NOT NULL
                AND regexp_matches(ratedFloodZone, '^(A|V|AR)')
            THEN 1 ELSE 0
        END                                                               AS sfha_policy
    FROM nfip_policies
    WHERE numberOfFloorsInInsuredBuilding IN (1, 2, 3, 5)
        AND originalConstructionDate IS NOT NULL
        AND policyEffectiveDate      IS NOT NULL
        AND policyTerminationDate    IS NOT NULL
        AND policyEffectiveDate      <  policyTerminationDate
        AND propertyState IS NOT NULL
        AND propertyState NOT IN ('AS', 'GU', 'VI', 'PR', 'AK', 'HI')
        AND countyCode  IS NOT NULL
        AND censusTract IS NOT NULL
        AND YEAR(originalConstructionDate) BETWEEN %d AND %d
)
SELECT
    p.tractfp,
    s.year,
    p.mh,
    p.year_constr,
    COUNT(*)                              AS policies_n,
    SUM(p.repl_cost)                      AS repl_cost_tot,
    SUM(p.policy_cost)                    AS policy_cost_tot,
    SUM(p.building_policy_covg)           AS building_policy_covg_tot,
    SUM(p.contents_policy_covg)           AS contents_policy_covg_tot,
    SUM(p.elevated_policy)                AS elevated_policy_n,
    SUM(p.primary_res_policy)             AS primary_res_policy_n,
    SUM(p.mandatory_purchase_policy)      AS mandatory_purchase_policy_n,
    SUM(p.sfha_policy)                    AS sfha_policy_n
FROM filtered p
JOIN generate_series(1994, 2025) AS s(year)
    ON p.year_eff <= s.year AND p.year_term >= s.year
GROUP BY p.tractfp, s.year, p.mh, p.year_constr
", year_min, year_max)

dt_pol <- as.data.table(dbGetQuery(con, sql_policies))

dt_pol <- merge(
    dt_pol,
    dt_cpi[, .(year, cpi)],
    by = "year",
    all.x = TRUE
)

stopifnot(!anyNA(dt_pol$cpi))

v_nom_policy <- c(
    "repl_cost_tot",
    "policy_cost_tot",
    "building_policy_covg_tot",
    "contents_policy_covg_tot"
)
dt_pol[, (v_nom_policy) := lapply(.SD, function(x) x / cpi), .SDcols = v_nom_policy]

message(sprintf(
    "Policy panel: %d rows (%d tracts, %d calendar years, 2 MH, %d construction years)",
    nrow(dt_pol),
    uniqueN(dt_pol$tractfp),
    uniqueN(dt_pol$year),
    uniqueN(dt_pol$year_constr)
))

# ---------------------------------------------------------------------------
# 3. Aggregate claims to panel key ----
# ---------------------------------------------------------------------------

dt_treat <- fread(here("derived", "ecfr-windzone.csv"), keepLeadingZeros = TRUE)

v_dmg <- c("net_building_pmt", "building_damage", "building_value",
           "contents_value",   "net_contents_pmt", "contents_damage",
           "building_covg",    "contents_covg")

dt_claims[, period_loss := ((year_loss - 1994L) %/% 5L) * 5L + 1994L]

dt_agg <- dt_claims[
    year_loss >= 1994L,
    c(.(claims_n = .N), lapply(.SD, sum, na.rm = TRUE)),
    by      = .(tractfp, period_loss, mh, year_constr),
    .SDcols = v_dmg
]
setnames(dt_agg, v_dmg, paste0(v_dmg, "_tot"))

# ---------------------------------------------------------------------------
# 4. Balance panel: exposed tract-periods × mh × year_constr grid ----
#    Cells with no claims get zeros.
# ---------------------------------------------------------------------------

exposed_cy <- unique(dt_agg[, .(tractfp, period_loss)])

grid <- exposed_cy[
    , CJ(mh = 0:1, year_constr = year_min:year_max),
    by = .(tractfp, period_loss)]
grid[, countyfp := substr(tractfp, 1, 5)]
grid[, statefp  := substr(tractfp, 1, 2)]

dt_balanced <- merge(
    grid, dt_agg,
    by    = c("tractfp", "period_loss", "mh", "year_constr"),
    all.x = TRUE
)
dt_balanced[, post1994 := as.integer(year_constr >= 1994L)]

# ---------------------------------------------------------------------------
# 5. Merge treatment ----
# ---------------------------------------------------------------------------

dt_balanced <- merge(dt_balanced, dt_treat, by = "countyfp", all.x = TRUE)

# NYC boroughs: consolidated city-county government not in COG crosswalk
dt_balanced[is.na(wind_zone) & statefp == "36", wind_zone := 1L]
stopifnot(nrow(dt_balanced[is.na(wind_zone)]) == 0L)

dt_balanced[, treated     := (wind_zone >= 2L)]
dt_balanced[, treated_wz3 := (wind_zone == 3L)]
dt_balanced$wind_zone <- NULL

# ---------------------------------------------------------------------------
# 6. Merge policy counts (annual → period) ----
# ---------------------------------------------------------------------------

dt_pol[, period_loss := ((year - 1994L) %/% 5L) * 5L + 1994L]
dt_pol_period <- dt_pol[, .(
    policies_n                    = sum(policies_n,                    na.rm = TRUE),
    repl_cost_tot                 = sum(repl_cost_tot,                 na.rm = TRUE),
    policy_cost_tot               = sum(policy_cost_tot,               na.rm = TRUE),
    building_policy_covg_tot      = sum(building_policy_covg_tot,      na.rm = TRUE),
    contents_policy_covg_tot      = sum(contents_policy_covg_tot,      na.rm = TRUE),
    elevated_policy_n             = sum(elevated_policy_n,             na.rm = TRUE),
    primary_res_policy_n          = sum(primary_res_policy_n,          na.rm = TRUE),
    mandatory_purchase_policy_n   = sum(mandatory_purchase_policy_n,   na.rm = TRUE),
    sfha_policy_n                 = sum(sfha_policy_n,                 na.rm = TRUE)
), by = .(tractfp, period_loss, mh, year_constr)]

dt_balanced <- merge(
    dt_balanced, dt_pol_period,
    by    = c("tractfp", "period_loss", "mh", "year_constr"),
    all.x = TRUE
)

# impute zero policies for cells in periods covered by policy data (>= 2009)
dt_balanced[is.na(policies_n) & period_loss >= 2009L, policies_n := 0L]

# ---------------------------------------------------------------------------
# 7. Derived outcomes ----
# ---------------------------------------------------------------------------

# impute zero for missing claim outcomes
v_outcomes <- grep("_tot$|claims_n$", names(dt_balanced), value = TRUE)
for (col in v_outcomes) {
    set(dt_balanced, which(is.na(dt_balanced[[col]])), col, 0)
}

# per-claim averages
v_pol_tot <- c(
    "repl_cost_tot",
    "policy_cost_tot",
    "building_policy_covg_tot",
    "contents_policy_covg_tot"
)
v_clm_tot <- setdiff(grep("_tot$", names(dt_balanced), value = TRUE), v_pol_tot)
v_clm_avg <- gsub("_tot$", "_pclaim", v_clm_tot)
dt_balanced[, (v_clm_avg) := lapply(
    .SD, function(x) fifelse(claims_n > 0L, x / claims_n, NA_real_)),
    .SDcols = v_clm_tot]

# damage shares (relative to assessed building value)
v_shares_value <- c("building_damage_tot", "net_building_pmt_tot")
v_shares <- gsub("_tot", "_share", v_shares_value)
dt_balanced[, (v_shares) := lapply(
    .SD, function(x) 100 * fifelse(
        building_value_tot > 0, x / building_value_tot, NA_real_)),
    .SDcols = v_shares_value]

# per-policy averages
v_pol_avg <- gsub("_tot$", "_ppol", v_pol_tot)
dt_balanced[, (v_pol_avg) := lapply(
    .SD, function(x) fifelse(
        !is.na(policies_n) & policies_n > 0L, x / policies_n, NA_real_)),
    .SDcols = v_pol_tot]

v_pol_ln <- gsub("_tot$", "_ln", v_pol_tot)
dt_balanced[, (v_pol_ln) := lapply(
    .SD, function(x) fifelse(
        !is.na(policies_n) & policies_n > 0L & x > 0,
        log(x / policies_n), NA_real_)),
    .SDcols = v_pol_tot]

# policy composition shares
v_pol_share_n <- c(
    "elevated_policy_n",
    "primary_res_policy_n",
    "mandatory_purchase_policy_n",
    "sfha_policy_n"
)
v_pol_share <- sub("_policy_n$", "_share", v_pol_share_n)
dt_balanced[, (v_pol_share) := lapply(
    .SD, function(x) fifelse(
        !is.na(policies_n) & policies_n > 0L, x / policies_n, NA_real_)),
    .SDcols = v_pol_share_n]

# claim rate: claims per policy in force
dt_balanced[, claim_rate := fifelse(
    !is.na(policies_n) & policies_n > 0L,
    claims_n / policies_n,
    NA_real_
)]

message(sprintf(
    "Policy merge: %.1f%% of panel cells have policy coverage",
    100 * dt_balanced[!is.na(policies_n), .N] / nrow(dt_balanced)
))

setkey(dt_balanced, tractfp, period_loss, mh, year_constr)

saveRDS(dt_balanced, here("derived", "nfip-balanced.Rds"))
message(sprintf(
    "Saved balanced panel: %d rows (%d tract-periods × 2 MH × %d construction years)",
    nrow(dt_balanced),
    uniqueN(dt_balanced[, .(tractfp, period_loss)]),
    length(unique(dt_balanced$year_constr))
))
