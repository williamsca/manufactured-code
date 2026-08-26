# Build policy-level (not tract/period-cell-aggregated) NFIP policy microdata
# for the policy-composition design, querying directly from DuckDB against
# research-database's curated parquet.
#
# Inputs:  fema_nfip_policies (research-database, pinned to NFIP_VERSION in
#          project-params.R)
# Outputs: derived/nfip-policy-micro.parquet (one row per policy term)
#
# Chunk J (TODO.md, 2026-08-26): the cell-level policy-composition table
# (`est_comp_post` in estimate-nfip.R, Table tab:composition) averages
# policy characteristics within geo x period x mh x vintage cells before
# regressing, which is a weaker design than regressing the policy-level
# indicators/amounts directly. This script keeps one row per policy term so
# estimate-nfip.R can run the composition spec at the policy level:
#   i(period_constr, mh, ref = 1992) | countyfp^period_loss + mh + period_constr
# Same sample restrictions as databuild-nfip.R's policy query (floors,
# occupancy_type, state exclusions, construction-year window), so the two
# NFIP policy extracts cannot drift apart -- see project-params.R for the
# occupancy_type code list and rationale.
# year_constr: individual construction year (binning done at estimation, as
# in databuild-nfip.R) -- period_constr is NOT computed here.

rm(list = ls()); gc()
library(here)
library(DBI)
library(duckdb)
library(data.table)
library(arrow)

source(here("program", "import", "project-params.R"))
source(here("program", "import", "rd-client.R"))

year_min <- MIN_YEAR_CONSTR
year_max <- MAX_YEAR_CONSTR
occ_sf   <- paste(OCCUPANCY_TYPE_SF, collapse = ", ")

dt_cpi <- fread(here("derived", "cpi-bls.csv"))
dt_cpi <- dt_cpi[, .(cpi = mean(cpi)), by = year]
dt_cpi[, cpi := cpi / cpi[year == DISCOUNT_YEAR]]

con <- rd_con()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

glob_policies <- rd_path("fema_nfip_policies", version = NFIP_VERSION)

# ---------------------------------------------------------------------------
# Policies: one row per term, assigned to a single calendar year by midpoint
# (same approximation and reasoning as databuild-nfip.R section 2).
# ---------------------------------------------------------------------------

sql_policy_micro <- sprintf("
SELECT
    id,
    countyfp,
    tractfp,
    YEAR(original_construction_date)                                 AS year_constr,
    CASE WHEN number_of_floors_in_insured_building = 5 THEN 1 ELSE 0 END AS mh,
    YEAR(policy_effective_date
         + CAST((policy_termination_date - policy_effective_date) / 2 AS INTEGER)) AS year,
    CAST(building_replacement_cost AS DOUBLE)                         AS repl_cost,
    CAST(policy_cost               AS DOUBLE)                         AS policy_cost,
    CAST(total_building_insurance_coverage AS DOUBLE)                 AS building_policy_covg,
    CAST(total_contents_insurance_coverage AS DOUBLE)                 AS contents_policy_covg,
    CASE WHEN elevated_building_indicator THEN 1 ELSE 0 END           AS elevated_policy,
    CASE WHEN primary_residence_indicator THEN 1 ELSE 0 END           AS primary_res_policy,
    CASE WHEN mandatory_purchase_flag THEN 1 ELSE 0 END               AS mandatory_purchase_policy,
    CASE
        WHEN rated_flood_zone IS NOT NULL
            AND regexp_matches(rated_flood_zone, '^(A|V|AR)')
        THEN 1 ELSE 0
    END                                                               AS sfha_policy
FROM read_parquet('%s')
WHERE number_of_floors_in_insured_building IN (1, 2, 3, 5)
    AND occupancy_type              IN (%s)
    AND original_construction_date IS NOT NULL
    AND policy_effective_date      IS NOT NULL
    AND policy_termination_date    IS NOT NULL
    AND policy_effective_date      <  policy_termination_date
    AND property_state IS NOT NULL
    AND property_state NOT IN ('AS', 'GU', 'MP', 'VI', 'PR', 'AK', 'HI')
    AND countyfp IS NOT NULL
    AND tractfp  IS NOT NULL
    AND TRY_CAST(LEFT(tractfp, 2) AS INT) <= 56
    AND YEAR(original_construction_date) BETWEEN %d AND %d
", glob_policies, occ_sf, year_min, year_max)

dt_pol <- as.data.table(dbGetQuery(con, sql_policy_micro))

# uniqueness on the intended key: one row per policy term
stopifnot(uniqueN(dt_pol$id) == nrow(dt_pol))

# policy records begin in 2009 (databuild-nfip.R section 2); restrict to the
# same calendar-year window as the balanced panel so the two NFIP policy
# extracts describe the same population of policy terms
dt_pol <- dt_pol[year >= 2009L & year <= MAX_YEAR_LOSS]

dt_pol <- merge(dt_pol, dt_cpi[, .(year, cpi)], by = "year", all.x = TRUE)
stopifnot(!anyNA(dt_pol$cpi))

v_nom <- c("repl_cost", "policy_cost", "building_policy_covg", "contents_policy_covg")
dt_pol[, (v_nom) := lapply(.SD, function(x) x / (cpi * 1000)), .SDcols = v_nom]

# five-year calendar-period bin, same anchor as databuild-nfip.R
dt_pol[, period_loss := ((year - 1994L) %/% 5L) * 5L + 1994L]

# contents-coverage choice margin (Chunk J): most interesting when built from
# the raw per-policy value, not a cell average
dt_pol[, contents_covg_positive := as.integer(contents_policy_covg > 0)]

message(sprintf(
    "Loaded %d policy terms (%d MH, %d site-built), %d distinct counties",
    nrow(dt_pol),
    dt_pol[mh == 1L, .N],
    dt_pol[mh == 0L, .N],
    uniqueN(dt_pol$countyfp)
))
message(sprintf(
    "Contents coverage: %.1f%% MH policies carry none, %.1f%% site-built",
    100 * dt_pol[mh == 1L, mean(contents_covg_positive == 0L)],
    100 * dt_pol[mh == 0L, mean(contents_covg_positive == 0L)]
))

# a filtered parquet scan returns rows in an arbitrary (row-group-parallel)
# order; pin one so the output is stable across reruns (UPDATE.md §2.2)
setorder(dt_pol, year, countyfp, tractfp, year_constr, id)

write_parquet(dt_pol, here("derived", "nfip-policy-micro.parquet"))
message(sprintf(
    "Saved %d policy terms to derived/nfip-policy-micro.parquet", nrow(dt_pol)))
