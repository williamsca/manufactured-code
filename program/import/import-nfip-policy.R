# Import and aggregate NFIP policies for continental US census block groups
#
# Inputs:  $DATA_PATH/data/fema-nfip/FimaNfipPoliciesV2.parquet
# Outputs: derived/nfip-policies.Rds  (bgfp × year × mh × year_constr panel)

rm(list = ls())
library(here)
library(arrow)
library(dplyr)   # arrow lazy-eval uses dplyr verbs
library(data.table)
library(lubridate)

data_path <- Sys.getenv("DATA_PATH")
if (nchar(data_path) == 0) stop("DATA_PATH environment variable is not set.")
fema_dir  <- file.path(data_path, "data", "fema-nfip")

year_min <- 1984L
year_max <- 2005L

# ---------------------------------------------------------------------------
# import ----
# ---------------------------------------------------------------------------

pf_pol <- open_dataset(file.path(fema_dir, "FimaNfipPoliciesV2.parquet"))

v_cols_pol <- c(
    "countyCode", "censusBlockGroupFips", "censusTract",
    "numberOfFloorsInInsuredBuilding", "originalConstructionDate",
    "policyCost", "policyTerminationDate", "policyEffectiveDate",
    "buildingReplacementCost", "propertyState"
)

dt_raw_pol <- pf_pol |>
    select(all_of(v_cols_pol)) |>
    filter(numberOfFloorsInInsuredBuilding %in% c(1L, 2L, 3L, 5L),
           !is.na(originalConstructionDate),
           !is.na(propertyState),
           !propertyState %in% c("AS", "GU", "VI", "PR", "AK", "HI"),
           !is.na(countyCode),
           !is.na(censusTract)
           ) |>
    collect() |>
    as.data.table()

setnames(dt_raw_pol, "countyCode",            "countyfp")
setnames(dt_raw_pol, "censusBlockGroupFips", "bgfp")
setnames(dt_raw_pol, "censusTract",         "tractfp")

dt_raw_pol[, year_constr := year(originalConstructionDate)]
dt_raw_pol[, mh := as.integer(numberOfFloorsInInsuredBuilding == 5L)]

# 3-year construction vintage bins — must match databuild-nfip.R formula
bin_base <- 1988L
dt_raw_pol[, period_constr := ((year_constr - bin_base) %/% 3L) * 3L + bin_base]

# policyEffectiveDate is already the actual coverage start (application date
# + 30-day waiting period per FEMA data dictionary); no adjustment needed.
dt_raw_pol[, date_eff  := as.Date(policyEffectiveDate)]
dt_raw_pol[, date_term := as.Date(policyTerminationDate)]
dt_raw_pol[, year_eff  := year(date_eff)]
dt_raw_pol[, year_term := year(date_term)]

# ---------------------------------------------------------------------------
# aggregate policies: countyfp × calendar year × mh × year_constr ----
#
#   A policy is "in force" during calendar year Y if:
#       year_eff <= Y  AND  year_term >= Y          (closed interval)
#   The right endpoint is closed because a policy terminating mid-year
#   (e.g., a May-to-May annual policy) genuinely covers part of the
#   termination calendar year.  Using > would drop those policy-years.
#
#   policyEffectiveDate is already post-waiting-period (coverage start),
#   so no date offset is needed.
# ---------------------------------------------------------------------------

pol_yr_lo <- year_min          # 1984 — matches claims panel vintage range
pol_yr_hi <- year_max + 10L   # 2015 — covers storm years beyond year_max

dt_pol_clean <- dt_raw_pol[
    !is.na(date_eff) & !is.na(date_term) &
    date_eff < date_term &
    year_constr >= year_min &
    year_constr <= year_max
]

message(sprintf(
    "Policies after date/vintage filter: %d of %d (%.1f%%)",
    nrow(dt_pol_clean), nrow(dt_raw_pol),
    100 * nrow(dt_pol_clean) / nrow(dt_raw_pol)
))

# non-equi join: expand each policy to every calendar year it was active
# data.table overwrites the LHS key columns with the matched i-column values,
# so year_eff → matched spine year; rename immediately.
years_spine <- data.table(
    year = 1994:max(dt_pol_clean$year_term))

dt_pol_exp <- dt_pol_clean[
    years_spine,
    on      = .(year_eff <= year, year_term >= year),
    allow.cartesian = TRUE,
    nomatch = 0L
]
setnames(dt_pol_exp, c("year_eff", "year_term"), c("year", "year_drop"))
dt_pol_exp[, year_drop := NULL]

# aggregate to panel key
dt_pol_agg <- dt_pol_exp[, .(
    policies_n      = .N,
    repl_cost_tot   = sum(as.numeric(buildingReplacementCost), na.rm = TRUE),
    policy_cost_tot = sum(as.numeric(policyCost),              na.rm = TRUE)
), by = .(tractfp, year, mh, period_constr)]

setkey(dt_pol_agg, tractfp, year, mh, period_constr)

fwrite(dt_pol_agg, here("derived", "nfip-policies.csv"))
message(sprintf(
    "Constructed policy panel: %d rows (%d BG-years, 2 MH, %d vintage bins)",
    nrow(dt_pol_agg),
    uniqueN(dt_pol_agg[, .(tractfp, year)]),
    uniqueN(dt_pol_agg$period_constr)
))
