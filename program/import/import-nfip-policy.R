# Import and aggregate NFIP policies for continental US counties
#
# Inputs:  $DATA_PATH/data/fema-nfip/FimaNfipPoliciesV2.parquet
# Outputs: derived/nfip-policies.Rds  (countyfp × year × mh × year_constr panel)

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
    "countyCode", "numberOfFloorsInInsuredBuilding", "originalConstructionDate",
    "policyCost", "policyTerminationDate", "policyEffectiveDate",
    "buildingReplacementCost", "propertyState"
)

dt_raw_pol <- pf_pol |>
    select(all_of(v_cols_pol)) |>
    filter(numberOfFloorsInInsuredBuilding %in% c(1L, 2L, 3L, 5L),
           !is.na(originalConstructionDate),
           !is.na(propertyState),
           !propertyState %in% c("AS", "GU", "VI", "PR", "AK", "HI"),
           !is.na(countyCode)
           ) |>
    collect() |>
    as.data.table()

setnames(dt_raw_pol, "countyCode", "countyfp")

dt_raw_pol[, year_constr := year(originalConstructionDate)]
dt_raw_pol[, mh := as.integer(numberOfFloorsInInsuredBuilding == 5L)]

# policyEffectiveDate is already the actual coverage start (application date
# + 30-day waiting period per FEMA data dictionary); no adjustment needed.
dt_raw_pol[, date_eff  := as.Date(policyEffectiveDate)]
dt_raw_pol[, date_term := as.Date(policyTerminationDate)]
dt_raw_pol[, year_eff  := year(date_eff)]
dt_raw_pol[, year_term := year(date_term)]

# ---------------------------------------------------------------------------
# sanity checks ----
# ---------------------------------------------------------------------------

# (1) missing dates
message(sprintf(
    "Policies: %d total | missing eff: %d (%.1f%%) | missing term: %d (%.1f%%)",
    nrow(dt_raw_pol),
    dt_raw_pol[is.na(date_eff),  .N],
    100 * dt_raw_pol[is.na(date_eff),  .N] / nrow(dt_raw_pol),
    dt_raw_pol[is.na(date_term), .N],
    100 * dt_raw_pol[is.na(date_term), .N] / nrow(dt_raw_pol)
))

# (2) effective >= termination (invalid)
dt_raw_pol[!is.na(date_eff) & !is.na(date_term), .(
    n_invalid   = sum(date_eff >= date_term),
    pct_invalid = mean(date_eff >= date_term),
    n_total     = .N
)] |> print()

# (3) duration distribution — standard NFIP annual policy should be ~365 days
dt_raw_pol[!is.na(date_eff) & !is.na(date_term),
    duration_days := as.integer(date_term - date_eff)]

dt_raw_pol[!is.na(duration_days), .(
    p1       = quantile(duration_days, .01),
    p10      = quantile(duration_days, .10),
    p50      = quantile(duration_days, .50),
    p90      = quantile(duration_days, .90),
    p99      = quantile(duration_days, .99),
    mean     = mean(duration_days),
    n_lt30   = sum(duration_days < 30L),
    n_gt400  = sum(duration_days > 400L)
)] |> print()

# (4) calendar-year coverage
message(sprintf(
    "Policy years: effective %d–%d | terminated %d–%d",
    dt_raw_pol[, min(year_eff,  na.rm = TRUE)],
    dt_raw_pol[, max(year_eff,  na.rm = TRUE)],
    dt_raw_pol[, min(year_term, na.rm = TRUE)],
    dt_raw_pol[, max(year_term, na.rm = TRUE)]
))

# (5) policies per construction decade × MH type
dt_raw_pol[!is.na(year_constr), .(n = .N),
    by = .(mh, decade = 10L * (year_constr %/% 10L))
][order(mh, decade)] |> print()

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
    year = min(dt_pol_clean$year_eff):max(dt_pol_clean$year_term))

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
), by = .(countyfp, year, mh, year_constr)]

setkey(dt_pol_agg, countyfp, year, mh, year_constr)

saveRDS(dt_pol_agg, here("derived", "nfip-policies.Rds"))
message(sprintf(
    "Constructed policy panel: %d rows (%d county-years, 2 MH types, %d vintage years)",
    nrow(dt_pol_agg),
    uniqueN(dt_pol_agg[, .(countyfp, year)]),
    uniqueN(dt_pol_agg$year_constr)
))
