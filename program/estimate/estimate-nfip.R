# Estimate effect of 1994 HUD wind standards on NFIP claims
#
# Three complementary pieces:
#   A. Insurability: policy/claim counts (extensive margin)
#   B. Claim intensity: claims per policy (conditional on coverage)
#   C. Damage severity: payout per claim (conditional on loss event)

rm(list = ls())
library(here)
library(data.table)
library(fixest)
library(ggplot2)

# ---------------------------------------------------------------------------
# parameters ----
# ---------------------------------------------------------------------------
# BIN_CONSTR_YEAR: width of construction-year bins.
#   1993 is always the right-end of the last pre-treatment bin, so that the
#   HUD 1994 cutoff falls cleanly at a bin boundary.
#     N=1 → annual (no binning); ref period = 1993
#     N=2 → 1992-1993, 1994-1995, ...;  ref period = 1992
#     N=3 → 1991-1993, 1994-1996, ...;  ref period = 1991
# Pass as positional arguments: Rscript estimate-nfip.R 3 countyfp
# You can also omit the bin width and pass only the geography:
#   Rscript estimate-nfip.R tractfp
args <- commandArgs(trailingOnly = TRUE)
bin_arg <- args[grepl("^[0-9]+$", args)][1L]
geo_arg <- args[args %in% c("countyfp", "tractfp")][1L]
BIN_CONSTR_YEAR <- if (!is.na(bin_arg)) as.integer(bin_arg) else 2L
agg_geo <- if (!is.na(geo_arg)) geo_arg else "countyfp"

# Winsorization cap for claim-level loss and payment outcomes, in $000 of
# 2000 dollars. The OpenFEMA loss fields carry a handful of records far outside
# any plausible single-family loss: building damage has a 99.99th percentile of
# 590 and a maximum of 1,018,489, and contents damage a 99.99th percentile of
# 2,618 against an NFIP contents limit of 100. One uniform cap is applied to
# all four claim-level damage and payment outcomes rather than a separate rule
# per outcome. It binds for a few dozen records, all of them site-built, and
# is a no-op for the two net-payment outcomes, which the NFIP statutory limits
# already bound (maximum net building payment 441). Capping rather than
# dropping keeps the estimation sample identical to the untrimmed
# specification. The headline building-damage estimate is insensitive to it
# (-5.56 uncapped vs -5.75 capped); contents damage moves more (-3.75 to
# -3.20) because its contaminated records are a larger share of a smaller
# sample.
MAX_CLAIM_LOSS <- 1000

# Calendar years per period_loss bin. The cell panel's five-year bins are
# 2009-2013, 2014-2018, 2019-2023 (policy records begin 2009; MAX_YEAR_LOSS is
# 2023), so every retained bin holds exactly this many years. Asserted against
# the data below, since the annualized take-up rates divide by it.
N_YEARS_PERIOD <- 5L

source(here("program", "import", "project-params.R"))
source(here("program", "import", "rd-client.R"))
source(here("program", "import", "geo-coverage-checks.R"))

if (!agg_geo %in% c("countyfp", "tractfp", "statefp")) {
    stop("agg_geo must be one of 'countyfp', 'tractfp', or 'statefp'.")
}
geo_label <- c(
    "statefp" = "State",
    "countyfp" = "County",
    "tractfp" = "Census tract"
)[[agg_geo]]
out_dir <- here("output", "event-study", agg_geo)

# bin construction years: bins are anchored so 1993 is always the right-end
# of the last pre-treatment bin; each bin is labeled by its left-end year.
bin_constr <- function(y, N) {
    ifelse(
        y <= 1993L,
        1994L - N  - ((1993L - y) %/% N) * N,
        1994L      + ((y - 1994L) %/% N) * N
    )
}
ref_period <- 1994L - BIN_CONSTR_YEAR

v_dict <- c(
    "claims_n" = "Claims (#)",
    "policies_n" = "Policies (#)",
    "building_damage" = "Building damage",
    "net_building_pmt" = "Net building pmt.",
    "contents_damage" = "Contents damage",
    "net_contents_pmt" = "Net contents pmt.",
    "claim_rate" = "Claims per policy-year",
    "repl_cost_ppol" = "Repl. cost",
    "policy_cost_ppol" = "Policy cost per policy",
    "building_policy_covg_ppol" = "Bldg covg.",
    "contents_policy_covg_ppol" = "Contents covg.",
    "elevated_share" = "Elevated",
    "sfha_share" = "SFHA",
    "water_depth" = "Water depth (ft)",
    "water_depth_bin" = "Water depth bin",
    "post1994" = "Post-1994",
    "elevated" = "Elevated",
    "sfha" = "SFHA",
    "primary_res_share" = "Primary res.",
    "mandatory_purchase_share" = "Mandatory",
    # policy-level composition (Chunk J: derived/nfip-policy-micro.parquet,
    # one row per policy term, replacing the cell-level averages above)
    "repl_cost" = "Repl. cost",
    "log_repl_cost_pol" = "Log repl. cost",
    "building_policy_covg" = "Bldg covg.",
    "contents_policy_covg" = "Contents covg.",
    "contents_covg_positive" = "Contents covg. $>0$",
    "contents_policy_covg_pos" = "Contents covg. (if $>0$)",
    "elevated_policy" = "Elevated",
    "sfha_policy" = "SFHA",
    "elevated_policy_pct" = "Elevated (\\%)",
    "sfha_policy_pct" = "SFHA (\\%)",
    "policies_per_1k_homes_yr" = "Policies per 1,000 homes per year",
    "claims_per_1k_homes_yr" = "Claims per 1,000 homes per year",
    "homes_n" = "Homes (stock)",
    "building_damage_share" = "Bldg. dmg. share (%)",
    "net_building_pmt_share" = "Bldg. pmt. share (%)",
    "contents_damage_share" = "Contents dmg. share (%)",
    "net_contents_pmt_share" = "Contents pmt. share (%)",
    "mh_claim_share" = "MH share of claims",
    "mh_policy_share" = "MH share of policies",
    "geo" = geo_label,
    "statefp" = "State",
    "countyfp" = "County",
    "tractfp" = "Census tract",
    # Cell panels bin calendar years into 5-year periods and assign both
    # policy records and claims to them, so "loss period" mislabels the
    # policy-composition and take-up tables (review comments 17-18).
    "period_loss" = "Calendar period",
    "year_loss" = "Loss year",
    "mh" = "MH",
    "period_constr" = "$\\nu_i$",
    "post_mh" = "$1\\{\\nu_i \\geq 1994\\} \\times$ MH",
    "capped_pmt" = "Capped payment (=1)",
    "pmt_covg_ratio" = "Payment / coverage",
    "damage_repl_ratio" = "Damage / repl. cost",
    "zero_pmt" = "Zero/small payment (=1)"
)

setFixest_dict(v_dict, reset = TRUE)
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---------------------------------------------------------------------------
# data construction ----
# ---------------------------------------------------------------------------

# --- balanced panel ---
dt <- readRDS(here("derived", "nfip-balanced.Rds"))
dt <- dt[between(year_constr, MIN_YEAR_CONSTR, MAX_YEAR_CONSTR)]

# period_loss bins must be N_YEARS_PERIOD years wide and the last one complete,
# or the annualized take-up rates below divide by the wrong denominator.
periods_obs <- sort(unique(dt$period_loss))
stopifnot(
    length(periods_obs) > 1L,
    all(diff(periods_obs) == N_YEARS_PERIOD),
    max(periods_obs) + N_YEARS_PERIOD - 1L == MAX_YEAR_LOSS
)

dt[, geo := get(agg_geo)]
dt[, period_constr := bin_constr(year_constr, BIN_CONSTR_YEAR)]

# Housing-stock take-up denominator (Chunk E). homes_n arrives on `dt` as a
# COUNTY-level value duplicated across every tract row for a given
# (countyfp, year_constr, mh) -- take a distinct county x year_constr x mh
# value before summing across year_constr into period_constr bins, or
# tract-level duplication would inflate the total. Only defined when
# agg_geo == "countyfp": the stock (derived/stock-county-vintage.Rds, from
# program/import/impute-stock.R) has no finer geographic detail, so at
# tractfp/statefp aggregation homes_n is left NA and the per-home specs
# below are skipped for that run.
dt_homes_cell <- unique(dt[, .(countyfp, year_constr, mh, homes_n)])
dt_homes_cell[, period_constr := bin_constr(year_constr, BIN_CONSTR_YEAR)]
# a period_constr bin whose year_constr members are ALL missing stock (e.g.
# the ambiguous 1994 construction year, dropped in impute-stock.R) must stay
# NA, not silently become a 0-home bin via na.rm sum over nothing
dt_homes_cell <- dt_homes_cell[
    , .(homes_n = if (all(is.na(homes_n))) NA_real_ else sum(homes_n, na.rm = TRUE)),
    by = .(countyfp, period_constr, mh)]

# MH-share panel at the requested aggregation geography
dt_share_cell <- dt[
    !is.na(policies_n) & policies_n > 0L,
    .(claims_n      = sum(claims_n,               na.rm = TRUE),
      policies_n    = sum(policies_n,             na.rm = TRUE),
      mh_claims_n   = sum(claims_n  * (mh == 1L), na.rm = TRUE),
      mh_policies_n = sum(policies_n * (mh == 1L), na.rm = TRUE)),
    by = .(geo, period_loss, period_constr, treated, post1994)]
dt_share_cell[, mh_claim_share  := mh_claims_n  / claims_n]
dt_share_cell[, mh_policy_share := mh_policies_n / policies_n]

# aggregate balanced panel to period_constr bins (cell-level ES)
v_raw <- c("claims_n", "policies_n",
           "net_building_pmt_tot", "building_damage_tot", "building_value_tot",
           "contents_value_tot", "net_contents_pmt_tot", "contents_damage_tot",
           "building_covg_tot", "contents_covg_tot",
           "repl_cost_tot", "policy_cost_tot",
           "building_policy_covg_tot", "contents_policy_covg_tot",
           "elevated_policy_n", "sfha_policy_n",
           "primary_res_policy_n", "mandatory_purchase_policy_n")

dt_cell <- dt[
    !is.na(policies_n) & policies_n > 0L,
    lapply(.SD, sum, na.rm = TRUE),
    by = .(geo, period_loss, mh, period_constr),
    .SDcols = v_raw]

dt_cell[, post1994 := as.integer(period_constr >= 1994L)]

# per-claim averages
v_clm_tot <- c("net_building_pmt_tot", "building_damage_tot",
               "building_value_tot", "contents_value_tot",
               "net_contents_pmt_tot", "contents_damage_tot",
               "building_covg_tot", "contents_covg_tot")
v_clm_avg <- gsub("_tot$", "_pclaim", v_clm_tot)
dt_cell[, (v_clm_avg) := lapply(
    .SD, function(x) fifelse(claims_n > 0L, x / claims_n, NA_real_)),
    .SDcols = v_clm_tot]

# damage shares
dt_cell[, building_damage_share := fifelse(
    building_value_tot > 0, 100 * building_damage_tot / building_value_tot,
    NA_real_)]
dt_cell[, net_building_pmt_share := fifelse(
    building_value_tot > 0, 100 * net_building_pmt_tot / building_value_tot,
    NA_real_)]

# per-policy averages
v_ppol_tot <- c(
    "repl_cost_tot", "policy_cost_tot",
    "building_policy_covg_tot", "contents_policy_covg_tot",
    "elevated_policy_n", "sfha_policy_n", "primary_res_policy_n",
    "mandatory_purchase_policy_n", "net_building_pmt_tot",
    "net_contents_pmt_tot")
v_ppol <- gsub("_tot$", "_ppol", v_ppol_tot)
v_ppol <- gsub("_policy_n$", "_share", v_ppol)
dt_cell[, (v_ppol) := lapply(
    .SD, function(x) fifelse(policies_n > 0L, x / policies_n, NA_real_)),
    .SDcols = v_ppol_tot]

# claim rate
dt_cell[, claim_rate := fifelse(
    policies_n > 0L, claims_n / policies_n, NA_real_)]

dt_cell[, post_mh := as.integer(period_constr >= 1994L) * mh]

dt_cell[, net_building_pmt_tot_ln := log(net_building_pmt_tot)]

if (agg_geo == "countyfp") {
    dt_cell <- merge(
        dt_cell, dt_homes_cell,
        by.x = c("geo", "period_constr", "mh"),
        by.y = c("countyfp", "period_constr", "mh"),
        all.x = TRUE
    )
} else {
    dt_cell[, homes_n := NA_real_]
}
# Take-up and claim-frequency rates, ANNUALIZED (Chunk I). policies_n is a
# count of policy TERMS summed over the N_YEARS_PERIOD calendar years in a
# period_loss bin (databuild-nfip.R assigns each term to one year by its
# midpoint), so it is policy-years, not a stock of distinct policies -- the
# file carries no policy identifier. Dividing by N_YEARS_PERIOD puts these on
# a per-year footing, which (a) makes them readable as take-up rates rather
# than five-year cumulative counts and (b) makes the decomposition
#
#     claims per home = policies per home x claims per policy
#
# hold in consistent units, since claim_rate above is already annual
# (claims over the period / policy-years over the period). The `_yr` suffix is
# deliberate: these replace the unsuffixed pre-Chunk-I variables, whose name
# did not disclose that they were five-year cumulative.
# These are NOT built on dt_cell: dt_cell's numerator spans every construction
# year in a period_constr bin, including years with no stock denominator, so the
# ratio would be inconsistent for any partially covered bin. They are built on
# dt_home_cell instead, where both sides are restricted to the same construction
# years -- see the take-up block below.

# Poisson panel: aggregate all cells (including zero-policy) to period_constr
dt_pois <- dt[, .(claims_n    = sum(claims_n,    na.rm = TRUE),
                  policies_n  = sum(policies_n,  na.rm = TRUE)),
    by = .(geo, period_loss, mh, period_constr)]

if (agg_geo == "countyfp") {
    dt_pois <- merge(
        dt_pois, dt_homes_cell,
        by.x = c("geo", "period_constr", "mh"),
        by.y = c("countyfp", "period_constr", "mh"),
        all.x = TRUE
    )
} else {
    dt_pois[, homes_n := NA_real_]
}

# --- claim-level data ---
dt_claims <- readRDS(here("derived", "nfip-claims.Rds"))
dt_claims <- dt_claims[
    between(year_constr, MIN_YEAR_CONSTR, MAX_YEAR_CONSTR) &
    between(year_loss, MIN_YEAR_LOSS, MAX_YEAR_LOSS)]
dt_claims[, statefp := substr(countyfp, 1L, 2L)]
dt_claims[, geo := get(agg_geo)]
dt_claims[, period_loss   := ((year_loss - 1994L) %/% 5L) * 5L + 1994L]
dt_claims[, period_constr := bin_constr(
    year_constr, BIN_CONSTR_YEAR)]
dt_claims[, post1994      := as.integer(year_constr >= 1994L)]
dt_claims[, post_mh       := post1994 * mh]

# Winsorize the claim-level loss and payment outcomes at MAX_CLAIM_LOSS before
# anything downstream is built from them, so the damage shares, the cell-level
# per-claim averages, the dependent-variable means reported in the tables, and
# the welfare inputs all use the same capped values. Counts of records the cap
# binds for are exported below for the table notes.
v_loss <- c("building_damage", "net_building_pmt",
            "contents_damage", "net_contents_pmt")
dt_winsor_n <- dt_claims[, lapply(
    .SD, function(x) sum(x > MAX_CLAIM_LOSS, na.rm = TRUE)), .SDcols = v_loss]
dt_winsor_mh <- dt_claims[, lapply(
    .SD, function(x) sum(x > MAX_CLAIM_LOSS, na.rm = TRUE)),
    by = mh, .SDcols = v_loss]
# Zero rates, for the paper's statement of why these outcomes cannot be logged.
dt_zero_share <- dt_claims[, lapply(
    .SD, function(x) mean(x == 0, na.rm = TRUE)), .SDcols = v_loss]
# Keep uncapped copies of the two damage fields so the static specification can
# be re-estimated on them below and the paper can quote how much the cap moves
# each coefficient.
dt_claims[, building_damage_unw := building_damage]
dt_claims[, contents_damage_unw := contents_damage]
dt_claims[, (v_loss) := lapply(
    .SD, function(x) pmin(x, MAX_CLAIM_LOSS)), .SDcols = v_loss]

v_shares <- c("building_damage", "net_building_pmt")
v_shares_names <- paste0(v_shares, "_share")
dt_claims[, (v_shares_names) := lapply(
    .SD, function(x) 100 * x / building_value), .SDcols = v_shares]

# covariate prep for robustness specs
dt_claims[, log_repl_cost := fifelse(
    !is.na(building_repl_cost) & building_repl_cost > 0,
    log(building_repl_cost), NA_real_)]
dt_claims[, occupancy_type := factor(occupancy_type)]

# Water-depth bins (Chunk K): a non-parametric control for flood severity,
# used in place of the linear `water_depth` control so the ~10-14% of claims
# with no recorded depth (higher, and rising, for post-1994 MH -- see the
# missingness rates exported below) enter their own bin instead of being
# dropped by listwise deletion on a continuous covariate. The top bin also
# absorbs a small number of physically implausible depths (a spike exactly at
# 99 ft, well above any plausible flood, consistent with a top-coded sentinel
# in the source field) without requiring a judgment call about which values
# are real.
wd_breaks <- c(-Inf, 0, 1, 2, 4, 8, Inf)
wd_labels <- c("<0 ft", "[0,1) ft", "[1,2) ft", "[2,4) ft", "[4,8) ft", ">=8 ft")
dt_claims[, water_depth_bin := as.character(
    cut(water_depth, breaks = wd_breaks, labels = wd_labels, right = FALSE))]
dt_claims[is.na(water_depth_bin), water_depth_bin := "Missing"]
dt_claims[, water_depth_bin := factor(
    water_depth_bin, levels = c("[0,1) ft", wd_labels[wd_labels != "[0,1) ft"], "Missing"))]

# Missingness diagnostic (text/notes, not part of any regression): the rate
# is highest, and rises most, for post-1994 MH -- the cell the composition
# concern is about -- which is why the bin approach above retains these rows
# rather than dropping them.
dt_wd_miss <- dt_claims[, .(
    water_depth_missing_rate = mean(is.na(water_depth))
), by = .(mh, post1994)]

v_shares_contents <- c("contents_damage", "net_contents_pmt")
v_shares_contents_names <- paste0(v_shares_contents, "_share")
dt_claims[, (v_shares_contents_names) := lapply(
    .SD, function(x) 100 * x / contents_value), .SDcols = v_shares_contents
]

v_claim <- c(
    "building_damage", "net_building_pmt",
    "contents_damage", "net_contents_pmt",
    "building_damage_share", "net_building_pmt_share",
    "contents_damage_share", "net_contents_pmt_share"
)
s_claim <- paste0("c(", paste0(v_claim, collapse = ", "), ")")

# outcome names for cell-level ES
v_pclaim <- grep("_share$", v_claim, invert = TRUE, value = TRUE)
v_pclaim <- paste0(v_pclaim, "_pclaim")
s_pclaim <- paste0(
    "c(", paste0(v_pclaim, collapse = ", "),
    ", claim_rate",
    ", ", paste0(v_ppol, collapse = ", "),
    ")")

# Standardized estimation sample for claim-level OLS and Poisson. Net payments
# can be negative when recoveries exceed gross payouts; Poisson does not admit
# negative outcomes, so drop these rows so both estimators run on the same set.
dt_claims_est <- dt_claims[
    (is.na(net_building_pmt) | net_building_pmt >= 0) &
    (is.na(net_contents_pmt) | net_contents_pmt >= 0)
]

# event studies ----
# claim-level event study
fmla_claim_es <- as.formula(paste0(
    s_claim, " ~ i(period_constr, mh, ref = ref_period)",
    " | geo^year_loss + mh + period_constr"
))

est_claim_es <- feols(fmla_claim_es, data = dt_claims_est, cluster = ~countyfp)
etable(est_claim_es, fitstat = c("n", "r2", "wr2", "my"))
iplot(est_claim_es[lhs = "building_pmt$"])

# Paper table columns. `building_damage_share` is still estimated (its scalars
# feed notes/apps/abstract-appam.Rmd) but is no longer a column of either paper
# table. Two reasons, in order of importance. First, its denominator
# `building_value` is the worst-behaved field in the claims data -- a 99.9th
# percentile of $1.07bn for site-built against $3.75M for MH -- so ~0.3% of the
# estimation sample carries a share above 100, which is impossible by
# construction, and those records drive the R2 from 0.52 down to 0.002. Second,
# and decisively: once the share is bounded at 100 the event study shows
# pre-1994 coefficients of +3.8, +5.4, +4.2, +1.8 against post-1994
# coefficients of +0.07, +0.18, -2.0. That is a trend across the whole vintage
# window, not a break at 1994, so parallel vintage trends fails for this
# outcome and the static -3.8 averages over a pre-trend. The share is also
# near-redundant: it is damage divided by value, and both the numerator (column
# 1) and the denominator (replacement cost, in the composition table) are
# reported separately, so the column adds only their covariance.
v_alt <- c(
    "building_damage$", "net_building_pmt$",
    "contents_damage$", "net_contents_pmt$")

etable(
    est_claim_es[lhs = v_alt], fitstat = c("n", "r2", "wr2", "my"))

etable(
    est_claim_es[lhs = v_alt],
    tex = TRUE, se.below = FALSE,
    file = file.path(out_dir, "claims-outcomes.tex"),
    fitstat = c("n", "r2", "my"),
    digits = 2, digits.stats = 2, replace = TRUE
)

# Poisson event study on damages/payments
est_claim_pois <- fepois(fmla_claim_es, data = dt_claims_est, cluster = ~countyfp)

etable(est_claim_pois)

# cell-level event study (aggregated to period_constr bins)
fmla_pclaim_es <- as.formula(paste0(
    s_pclaim, " ~ i(period_constr, mh, ref = ref_period)",
    " | geo^period_loss + mh + period_constr")
)

# Clustered by geo (county under the default agg_geo), added in Chunk I. All
# four cell-level fits below (est_pclaim_es, est_comp_post, est_share_es,
# est_pois_es) previously passed no `cluster` argument, so fixest reported IID
# standard errors while notes/specs.md 3 recorded that and the paper's Table 4
# note claimed clustering. Cluster level matches the claim-level specs.
est_pclaim_es <- feols(
    fmla_pclaim_es, data = dt_cell,
    weights = ~policies_n, cluster = ~geo,
    lean = TRUE)
etable(est_pclaim_es, fitstat = c("n", "r2", "wr2", "my"))

iplot(est_pclaim_es[lhs = "claim_rate"])

# ---------------------------------------------------------------------------
# policy-level composition table (Chunk J) ----
#
#   Replaces the cell-level policy-composition table (which averaged policy
#   characteristics within geo x period x mh x vintage cells before
#   regressing). This regresses policy characteristics directly on the
#   policy-term microdata (derived/nfip-policy-micro.parquet, built by
#   program/import/databuild-nfip-policy.R: one row per policy term, already
#   restricted to single-family residential occupancy_type -- see
#   project-params.R). Always at countyfp x period_loss, per the Chunk J
#   spec, independent of the agg_geo command-line argument.
# ---------------------------------------------------------------------------

dt_pol_micro <- as.data.table(arrow::read_parquet(
    here("derived", "nfip-policy-micro.parquet")))
dt_pol_micro <- dt_pol_micro[between(year_constr, MIN_YEAR_CONSTR, MAX_YEAR_CONSTR)]
dt_pol_micro[, period_constr := bin_constr(year_constr, BIN_CONSTR_YEAR)]

# Replacement cost enters in logs, not levels. `repl_cost` is the worst-behaved
# field on the policy file: mean 199.9 against a standard deviation of 2,269, a
# 99th percentile of 997, and a maximum of 1,371,528 -- a single-family home
# with a $1.37bn replacement cost. Building coverage on the same rows has a
# standard deviation of 45.6 because the NFIP statutory limit top-codes it,
# which is why that column fits with an R2 of 0.23 while replacement cost in
# levels fits with 0.001: essentially all of the level variance sits in records
# no fixed effect can explain, and the fitted vintage profile is correspondingly
# unstable (+32, +30, +10, -8, +31, +18, +2 across the seven bins). In logs the
# same specification has an R2 of 0.20, flat and insignificant pre-1994
# coefficients, and a stable +6 to +8% for all three post-1994 bins, which is
# the pattern the composition argument in the paper actually needs. The cost is
# the 5.6% of policy terms recording an exact zero replacement cost, which are
# dropped; a $0 replacement cost on an insured single-family home is a missing
# code rather than a fact. Winsorizing the level instead was checked and
# rejected: it fits better than the raw level (R2 0.12) but leaves a steep
# declining pre-trend, because the tail is where that pre-trend lives.
dt_pol_micro[, log_repl_cost_pol := fifelse(
    !is.na(repl_cost) & repl_cost > 0, log(repl_cost), NA_real_)]
n_repl_zero <- dt_pol_micro[, mean(!is.na(repl_cost) & repl_cost == 0)]

# Contents coverage enters unconditionally, with the zeros included, as one
# column rather than as separate extensive- and intensive-margin columns. Both
# margins are individually null after 1994 (the extensive margin is +0.004,
# -0.01, -0.02 and the conditional amount -0.30, +0.22, +0.16), so one column
# carries the whole finding, and the unconditional amount does not condition on
# a variable that itself moves across vintages -- the conditional-amount column
# was estimated on a sample selected by the outcome of the column beside it.
# The two binary outcomes enter as percentage points rather than as 0/1 shares,
# so their coefficients print at the same number of significant digits as the
# dollar columns beside them instead of as a row of leading zeros. Pure
# rescaling by 100: coefficients, standard errors, and the dependent-variable
# mean all scale, and the R2 and t-statistics are unchanged.
dt_pol_micro[, elevated_policy_pct := 100 * elevated_policy]
dt_pol_micro[, sfha_policy_pct := 100 * sfha_policy]

v_comp_pol <- c(
    "log_repl_cost_pol",
    "building_policy_covg",
    "contents_policy_covg",
    "elevated_policy_pct",
    "sfha_policy_pct"
)
s_comp_pol <- paste0("c(", paste(v_comp_pol, collapse = ", "), ")")

fmla_comp_pol <- as.formula(paste0(
    s_comp_pol, " ~ i(period_constr, mh, ref = ref_period)",
    " | countyfp^period_loss + mh + period_constr"
))

est_comp_pol <- feols(
    fmla_comp_pol, data = dt_pol_micro,
    cluster = ~countyfp, lean = TRUE
)
etable(est_comp_pol, fitstat = c("n", "r2", "wr2", "my"))

etable(
    est_comp_pol,
    tex = TRUE, se.below = FALSE,
    file = file.path(out_dir, "policy-composition.tex"),
    fitstat = c("n", "r2", "my"),
    digits = 2, digits.stats = 2, replace = TRUE
)

# MH share event study

# event study

fmla_share_es <- as.formula(paste0(
    "c(mh_claim_share, mh_policy_share)", " ~ ",
    "i(period_constr, ref = ref_period)",
    " | ", "geo^period_loss"
))

est_share_es <- feols(
    fmla_share_es, data = dt_share_cell,
    weights = ~policies_n, cluster = ~geo, lean = TRUE
)

etable(est_share_es, fitstat = c("n", "r2", "wr2", "my"))

iplot(est_share_es)

# count event study (Poisson), raw counts -- retained for comparability with
# the pre-Chunk-E table and because it is still the right model wherever
# agg_geo != "countyfp" (homes_n is undefined there, see above)
fmla_out_es <- as.formula(paste0(
    "c(policies_n, claims_n)", " ~ i(period_constr, mh, ref = ref_period)",
    " | geo^period_loss + mh + period_constr"
))

est_pois_es <- fepois(
    fmla_out_es, data = dt_pois, cluster = ~geo
)
etable(est_pois_es)

iplot(est_pois_es)

# Take-up per housing-unit stock (Chunk E): OLS on the ratio outcomes
# themselves (policies_per_1k_homes_yr, claims_per_1k_homes_yr), clustered by
# county (geo == countyfp under the default agg_geo), replacing the
# policies-per-SF-permit ratio (wrong housing type, badly non-random BPS
# coverage -- see TODO.md Chunk E).
#
# Chunk I adds the third margin, claims per policy-year (`claim_rate`), so the
# table now reports a complete decomposition of the benefit side's extensive
# margin:
#
#     claims per home = policies per home x claims per policy
#     (hazard realized      (take-up:        (claim frequency
#      per home in the       who insures)     conditional on
#      housing stock)                         holding a policy)
#
# with payment conditional on a claim -- the intensive margin -- reported
# separately in the claim-level damage tables above (`est_claim_es`,
# `est_static`), which need no stock denominator. p(claim | policy) is also the
# object `estimate-welfare.R` uses as its hazard rate, so this column says
# directly whether the reform moved the number the cost-benefit rests on.
#
# All three outcomes are annual (see the `_yr` construction above), so the
# decomposition holds in consistent units. Weights differ by column and cannot
# be pooled into one fit: the per-home columns weight by homes_n (a handful of
# thin county x period x mh cells have imputed stock well under 1 home,
# producing rates in the thousands that would otherwise dominate an unweighted
# fit), while the claim
# rate weights by policies_n, its own denominator, as the other cell-level
# specs above do. Hence two feols calls, combined in one etable.
#
# Samples also differ: the per-home columns require a defined homes_n, the
# claim rate requires policies_n > 0. Both are pooled across all three policy
# periods (2009-2023) -- an earliest-period-only (2009-2013) restriction was
# checked and dropped: point estimates were extremely similar to the pooled
# column, so it added a column without adding information. See notes/specs.md
# for the caveat on the Census-2000-vs-policy-data time gap this restriction
# was meant to address.
#
# The per-home cells are rebuilt from the row level rather than filtered out of
# dt_cell, because numerator and denominator must span the SAME construction
# years. dt_cell sums policies_n and claims_n over every year_constr in a
# period_constr bin, while homes_n is undefined for construction year 1994
# (impute-stock.R drops it as ambiguously pre/post). Filtering dt_cell would
# therefore leave the 1994 bin with a two-year numerator (1994 and 1995) over a
# one-year denominator (1995 alone), which nearly doubles that bin's measured
# take-up rate -- construction year 1994 supplies about 49% of the bin's
# site-built policy-years and 45% of its MH policy-years. Since the site-built
# take-up rate is roughly four times the MH rate, that inflation lands almost
# entirely on the comparison group, and appears as a large negative coefficient
# at exactly the treatment boundary. Restricting both sides to construction
# years with a stock denominator removes it.
home_key <- c("countyfp", "year_constr", "mh")
dt_home_ok <- unique(dt[!is.na(homes_n) & homes_n > 0, ..home_key])

dt_home_num <- merge(
    dt[!is.na(policies_n) & policies_n > 0L], dt_home_ok, by = home_key)
dt_home_cell <- dt_home_num[
    , .(claims_n   = sum(claims_n,   na.rm = TRUE),
        policies_n = sum(policies_n, na.rm = TRUE),
        mand_n     = sum(mandatory_purchase_policy_n, na.rm = TRUE)),
    by = .(geo, period_loss, mh, period_constr)]

# denominator over the same construction years; homes_n is a county-level value
# duplicated across tract rows, so dedupe on the county key before summing
dt_home_den <- unique(dt[!is.na(homes_n) & homes_n > 0,
                         .(countyfp, year_constr, mh, homes_n)])
dt_home_den[, period_constr := bin_constr(year_constr, BIN_CONSTR_YEAR)]
dt_home_den <- dt_home_den[
    , .(homes_n = sum(homes_n)), by = .(countyfp, period_constr, mh)]

dt_home_cell <- merge(
    dt_home_cell, dt_home_den,
    by.x = c("geo", "period_constr", "mh"),
    by.y = c("countyfp", "period_constr", "mh"))

dt_home_cell[, post1994 := as.integer(period_constr >= 1994L)]
dt_home_cell[, post_mh  := post1994 * mh]
dt_home_cell[, claim_rate := claims_n / policies_n]
dt_home_cell[, policies_per_1k_homes_yr :=
    1000 * policies_n / (homes_n * N_YEARS_PERIOD)]
dt_home_cell[, claims_per_1k_homes_yr :=
    1000 * claims_n / (homes_n * N_YEARS_PERIOD)]

# Take-up split by mandatory-purchase status, same denominator. The two split
# outcomes sum to policies_per_1k_homes_yr by construction, so their post_mh
# coefficients sum to the total one and say how much of the take-up response
# occurs where the homeowner was choosing rather than complying. The flag is
# reported by the insurer and is almost certainly under-recorded (it marks only
# 4-9% of policy-years, well below the SFHA share), so read the split as a lower
# bound on the mandated part, not a clean partition.
dt_home_cell[, nonmand_n := policies_n - mand_n]
stopifnot(all(dt_home_cell$nonmand_n >= 0))
dt_home_cell[, policies_mand_per_1k_homes_yr :=
    1000 * mand_n / (homes_n * N_YEARS_PERIOD)]
dt_home_cell[, policies_nonmand_per_1k_homes_yr :=
    1000 * nonmand_n / (homes_n * N_YEARS_PERIOD)]

# the 1994 bin must now be construction year 1995 alone on BOTH sides
stopifnot(
    nrow(dt_home_cell) > 0L,
    !anyNA(dt_home_cell$homes_n), all(dt_home_cell$homes_n > 0),
    dt_home_ok[, !any(year_constr == 1994L)],
    dt_home_num[, !any(year_constr == 1994L)]
)

fmla_home_ols <- as.formula(paste0(
    "c(policies_per_1k_homes_yr, claims_per_1k_homes_yr)",
    " ~ i(period_constr, mh, ref = ref_period)",
    " | geo^period_loss + mh + period_constr"
))

est_home_ols <- feols(
    fmla_home_ols, data = dt_home_cell, cluster = ~geo,
    weights = ~homes_n, lean = TRUE
)
etable(est_home_ols, fitstat = c("n", "r2", "my"))
iplot(est_home_ols[lhs = "policies_per_1k_homes_yr"])

# p(claim | policy): same FE structure and clustering, policies_n weights.
# Estimated on dt_home_cell, not dt_cell: the claim rate needs no stock
# denominator, but running it on the wider sample would make the three columns
# of the table three different samples and break the decomposition identity
# above.
est_claimrate_ols <- feols(
    claim_rate ~ i(period_constr, mh, ref = ref_period) |
        geo^period_loss + mh + period_constr,
    data = dt_home_cell, cluster = ~geo, weights = ~policies_n
)
etable(est_claimrate_ols, fitstat = c("n", "r2", "my"))

takeup_headers <- c(
    "Policies per 1,000 homes",
    "Claims per 1,000 homes",
    "Claims per policy"
)
est_takeup_list <- list(
    est_home_ols[lhs = "policies_per_1k_homes_yr"][[1]],
    est_home_ols[lhs = "claims_per_1k_homes_yr"][[1]],
    est_claimrate_ols
)

etable(
    est_takeup_list,
    digits = 3, digits.stats = 2, fitstat = c("n", "r2", "my"),
    tex = TRUE, replace = TRUE, depvar = FALSE,
    headers = list("Annual rate" = takeup_headers),
    file = file.path(out_dir, "take-up.tex"))

# Static counterpart: one post-1994 x MH coefficient per margin, same
# samples/weights/clustering, collapsing the vintage profile the way
# `est_static` does for the claim-level damage outcomes.
fmla_home_static <- as.formula(paste0(
    "c(policies_per_1k_homes_yr, claims_per_1k_homes_yr)",
    " ~ post_mh | geo^period_loss + mh + post1994"
))

est_home_static <- feols(
    fmla_home_static, data = dt_home_cell, cluster = ~geo,
    weights = ~homes_n, lean = TRUE
)

est_claimrate_static <- feols(
    claim_rate ~ post_mh | geo^period_loss + mh + post1994,
    data = dt_home_cell, cluster = ~geo, weights = ~policies_n
)

# Two diagnostics on the take-up column, reported in the text rather than the
# table. (a) The mandatory/non-mandatory split described above. (b) The same
# static contrast with the geographic fixed effects removed, which is the raw
# pre/post difference-in-differences across all counties. The two differ in
# sign: the sign of the take-up estimate rests entirely on comparing MH to
# site-built WITHIN a county and period, since MH stock is concentrated in
# counties whose overall post-1994 take-up rose least. Reporting both keeps that
# dependence visible instead of resting on the fixed effects silently.
est_home_mand_static <- feols(
    c(policies_mand_per_1k_homes_yr, policies_nonmand_per_1k_homes_yr) ~
        post_mh | geo^period_loss + mh + post1994,
    data = dt_home_cell, cluster = ~geo, weights = ~homes_n, lean = TRUE
)
etable(est_home_mand_static, fitstat = c("n", "my"))

est_home_static_nogeo <- feols(
    policies_per_1k_homes_yr ~ post_mh | mh + post1994,
    data = dt_home_cell, cluster = ~geo, weights = ~homes_n
)
etable(est_home_static_nogeo, fitstat = c("n", "my"))

est_takeup_static_list <- list(
    est_home_static[lhs = "policies_per_1k_homes_yr"][[1]],
    est_home_static[lhs = "claims_per_1k_homes_yr"][[1]],
    est_claimrate_static
)
etable(est_takeup_static_list, fitstat = c("n", "r2", "my"))

etable(
    est_takeup_static_list,
    digits = 3, digits.stats = 2, fitstat = c("n", "r2", "my"),
    tex = TRUE, replace = TRUE, depvar = FALSE, se.below = FALSE,
    headers = list("Annual rate" = takeup_headers),
    file = file.path(out_dir, "take-up-static.tex"))

# ---------------------------------------------------------------------------
# water-depth robustness: building damage (Chunk K) ----
# ---------------------------------------------------------------------------
# Does the post_mh building-damage effect survive controlling for water
# depth -- the flood-severity dimension underlying the composition concern
# of "Selection and Composition" -- and does the damage-depth relationship
# itself differ by housing type? Static post_mh spec (matching fmla_static's
# sample and FE structure below, not yet defined at this point in the script
# but built the same way) rather than the event study, so the covariate
# comparison is one coefficient per column rather than a curve per column.
# Depth enters as the non-parametric `water_depth_bin` fixed effect
# constructed above (not a linear control), with an explicit "Missing" bin,
# so N is identical across all three columns -- asserted below -- unlike a
# linear control, which would listwise-delete the ~10-14% of claims with no
# recorded depth.
fmla_rob_a <- building_damage ~ post_mh |
    geo^year_loss + mh + post1994

fmla_rob_b <- building_damage ~ post_mh |
    geo^year_loss + mh + post1994 + water_depth_bin

# Depth-bin x MH: lets the damage-depth relationship itself differ by
# housing type (on top of the common depth-bin effect already absorbed by
# the FE in fmla_rob_b), so post_mh in this column is identified off
# within-depth-bin, within-housing-type variation alone.
fmla_rob_c <- building_damage ~ post_mh +
    i(water_depth_bin, mh, ref = "[0,1) ft") |
    geo^year_loss + mh + post1994 + water_depth_bin

est_rob_list <- list(
    "Baseline"                   = feols(fmla_rob_a, data = dt_claims_est, lean = TRUE, cluster = ~countyfp),
    "+ Water depth"              = feols(fmla_rob_b, data = dt_claims_est, lean = TRUE, cluster = ~countyfp),
    "+ Water depth $\\times$ MH" = feols(fmla_rob_c, data = dt_claims_est, lean = TRUE, cluster = ~countyfp)
)

stopifnot(length(unique(vapply(est_rob_list, nobs, numeric(1)))) == 1L)

# Does the depth control have anything to work with? Adding the depth bins moves
# the R2 by about a point, which invites the reading that depth barely varies
# within a county x loss year and that the robustness check therefore has no
# power. It does not hold: the depth bins vary richly inside the fixed-effect
# cells, so the stability of post_mh across columns is informative rather than
# mechanical. The small R2 gain instead says that depth explains little of the
# claim-to-claim variance in damage once the cell is absorbed, which is a
# statement about what drives damage (home size and value), not about the
# control's variation. Reported in the appendix so a reader does not have to
# take the check on faith.
dt_wd_var <- dt_claims_est[, .(nbin = uniqueN(water_depth_bin), n = .N),
    by = .(geo, year_loss)]
wd_bins_per_cell   <- dt_wd_var[, sum(nbin * n) / sum(n)]
wd_single_bin_shr  <- dt_wd_var[nbin == 1L, sum(n)] / dt_wd_var[, sum(n)]
wd_n_bins          <- dt_claims_est[, uniqueN(water_depth_bin)]

etable(est_rob_list, tex = TRUE,
    file = here("output", "event-study", agg_geo, "robustness.tex"),
    keep_raw = "post_mh", fitstat = c("n", "r2", "my"),
    digits = 2, digits.stats = 2, replace = TRUE,
    depvar = FALSE, headers = names(est_rob_list))

# geographic robustness: state vs. county vs. tract FEs ----
# County is the baseline geography for the main results (see fmla_claim_es
# above). Compare against coarser (state) and finer (tract) alternatives.
# All columns use the same interaction specification; only the geographic
# granularity of the location × loss-period fixed effect varies.
fmla_geo_rob <- building_damage ~
    i(period_constr, mh, ref = ref_period) |
    sw(statefp^period_loss, countyfp^period_loss, tractfp^period_loss) + mh

est_geo_rob <- feols(fmla_geo_rob, data = dt_claims_est, lean = TRUE, cluster = ~countyfp)

etable(est_geo_rob)

etable(
    est_geo_rob,
    tex = TRUE,
    file = here("output", "event-study", "geo-robustness.tex"),
    fitstat = c("n", "r2", "my"),
    digits = 2, digits.stats = 2, replace = TRUE,
    depvar = FALSE
)

# static ----
# Headline ATT: single post_mh coefficient in place of the event study's
# eleven individually-noisy period_constr x mh terms. Same sample, FE
# structure, and clustering as fmla_claim_es, collapsing the vintage
# profile to a pre/post-1994 comparison.
fmla_static <- as.formula(paste0(
    s_claim, " ~ post_mh | geo^year_loss + mh + post1994"
))

est_static <- feols(fmla_static, data = dt_claims_est, cluster = ~countyfp)
etable(est_static[lhs = v_alt], fitstat = c("n", "r2", "my"))

etable(
    est_static[lhs = v_alt],
    tex = TRUE, se.below = FALSE,
    file = file.path(out_dir, "claims-outcomes-static.tex"),
    fitstat = c("n", "r2", "my"),
    digits = 2, digits.stats = 2, replace = TRUE
)

# Same static specification on the UNWINSORIZED damage fields, so the paper can
# report how much the MAX_CLAIM_LOSS cap moves each coefficient and its fit
# rather than asserting the cap is innocuous. Not a paper table.
est_static_unw <- feols(
    c(building_damage_unw, contents_damage_unw) ~ post_mh |
        geo^year_loss + mh + post1994,
    data = dt_claims_est, cluster = ~countyfp)
etable(est_static_unw, fitstat = c("n", "r2", "my"))

# ---------------------------------------------------------------------------
# mechanism decomposition (Chunk D) ----
# ---------------------------------------------------------------------------
# Same static spec as `fmla_static` (post_mh, same FE/clustering), applied
# to sample splits that speak to physical damage to the structure -- the
# project's actual object of interest. (Insurance-accounting outcomes were
# also estimated here; see "Superseded" at the end of the script -- Colin's
# call 2026-08-13 was that they're second-order to the damage question and
# not worth a paper table, but the code is kept for reference.)

# --- wind-zone exposure (coordinate with Chunk C) ---
# Reuse the same eCFR crosswalk as the Chunk C cost-side dose-response
# (`ecfr_wind_zone`, research-database) rather than an independently defined
# coastal/hurricane county list, so the benefit-side split lines up with the
# cost-side treatment definition. No NYC-borough fallback needed: verified
# 2026-08-24 that every countyfp in nfip-claims.Rds, including all five NYC
# boroughs, matches directly once ecfr_wind_zone covers geo_county's
# historical rows as well as current ones (see research-database's
# program/ecfr/wind-zones/import.R) -- the old fallback predates that fix
# and was for a gap that no longer exists.
dt_wz <- rd_read("ecfr_wind_zone", version = ECFR_WIND_ZONE_VERSION)
dt_claims_est <- merge(dt_claims_est, dt_wz, by = "countyfp", all.x = TRUE)
assert_geo_coverage(
    dt_claims_est, "wind_zone", "countyfp",
    "estimate-nfip.R: mechanism-split claims x ecfr_wind_zone")
dt_claims_est[, treated_wz3 := as.integer(wind_zone == 3L)]

# --- sample splits: elevation, SFHA, wind-zone-3 exposure ---
# Elevation (comment 15): elevated_share only rises post-1998 (see
# tab:composition), so it cannot mechanically explain the 1994-96 bins;
# splitting on elevated status checks whether the pooled effect is a
# composition shift (more elevated homes selecting in) rather than a
# resilience effect operating on non-elevated construction.
# SFHA (review target 3): splits the mandatory-purchase population from
# the voluntary-market population.
# Wind-zone-3 (coordinate with Chunk C): a benefit-side companion to the
# cost-side dose-response — Zone III MH should show a larger post-1994
# improvement than Zone I/II if the wind channel, not just general
# construction-quality upgrading, is doing the work.
fmla_mech <- building_damage ~ post_mh | geo^year_loss + mh + post1994

est_mech_split <- list(
    "Not elevated" = feols(fmla_mech,
        data = dt_claims_est[elevated == 0L], cluster = ~countyfp),
    "Elevated"     = feols(fmla_mech,
        data = dt_claims_est[elevated == 1L], cluster = ~countyfp),
    "Non-SFHA"     = feols(fmla_mech,
        data = dt_claims_est[sfha == 0L], cluster = ~countyfp),
    "SFHA"         = feols(fmla_mech,
        data = dt_claims_est[sfha == 1L], cluster = ~countyfp),
    "Zone I-II"    = feols(fmla_mech,
        data = dt_claims_est[treated_wz3 == 0L], cluster = ~countyfp),
    "Zone III"     = feols(fmla_mech,
        data = dt_claims_est[treated_wz3 == 1L], cluster = ~countyfp)
)
etable(est_mech_split, fitstat = c("n", "r2", "my"))

etable(
    est_mech_split,
    tex = TRUE, se.below = FALSE,
    file = file.path(out_dir, "mechanism-splits.tex"),
    fitstat = c("n", "r2", "my"),
    digits = 2, digits.stats = 2, replace = TRUE,
    depvar = FALSE
)

# plots ----
v_palette <- c("#0072B2", "#D55E00", "#009E73", "#F0E442")

theme_paper <- function(base_size = 14) {
    theme_classic(base_size = base_size) +
        theme(
            text = element_text(family = "serif"),
            legend.position = "right",
            panel.grid.major.y = element_line(color = "gray85", linewidth = 0.4),
            panel.grid.minor.y = element_blank()
        )
}

# Plot an event study from a fixest model estimated with i(period_constr, mh, ref = ref_period).
# Extracts interaction terms (:mh), appends a zero row at the reference period,
# and draws point estimates with 95% CI ribbon.
plot_es <- function(est, outcome = NULL, vline_x = 1992.5, path = NULL, var = "mh",
                    yscale = 1, ref = ref_period) {
    # [[]] extracts a single fixest object; [lhs=] returns fixest_multi,
    # whose coeftable() output has a different structure
    if (!is.null(outcome)) est <- est[lhs = outcome][[1]]
    ylab <- if (!is.null(outcome) && outcome %in% names(v_dict)) {
        unname(v_dict[[outcome]])
    } else {
        outcome
    }
    if (ylab %in% c("Building damage")) ylab <- paste0(ylab, " (000s)")

    ct <- as.data.table(coeftable(est), keep.rownames = TRUE)
    # i(period_constr, mh) coefficients are named "period_constr::YYYY:mh"
    # i(year_constr) main effects are named "year_constr::YYYY"
    if (is.null(var)) {
        idx <- grepl("^[a-z_]+::\\d{4}$", ct$rn)
    } else {
        idx <- grepl(paste0(":", var, "$"), ct$rn)
    }
    dt_es <- data.table(
        term    = ct$rn[idx],
        est     = ct$Estimate[idx] / yscale,
        se      = ct[["Std. Error"]][idx] / yscale
    )
    dt_es[, period  := as.integer(regmatches(term, regexpr("[0-9]{4}", term)))]
    dt_es[, ci_low  := est - 1.96 * se]
    dt_es[, ci_high := est + 1.96 * se]

    # append reference period normalized to zero
    dt_es <- rbind(
        dt_es,
        data.table(term = NA_character_, est = 0, se = 0,
                   ci_low = 0, ci_high = 0, period = ref)
    )
    setorder(dt_es, period)

    p <- ggplot(dt_es, aes(x = period, y = est)) +
        geom_ribbon(aes(ymin = ci_low, ymax = ci_high),
                    alpha = 0.2, fill = v_palette[1]) +
        geom_point(color = v_palette[1], size = 2) +
        geom_line(color = v_palette[1]) +
        geom_vline(xintercept = vline_x, linetype = "dotted", color = "black") +
        scale_x_continuous(breaks = dt_es$period) +
        labs(x = "Construction period", y = ylab) +
        theme_paper()

    if (!is.null(path)) ggsave(path, p, width = 9, height = 5)
    p
}

# Overlay event studies from a named list of single-LHS fixest objects.
# Each model must be estimated with i(period_constr, mh, ref = ref_period).
plot_es_multi <- function(est_list, vline_x = 1992.5, path = NULL,
                           yscale = 1, ref = ref_period,
                           ylab = "Building damage (000s)") {
    dt_all <- rbindlist(lapply(names(est_list), function(nm) {
        ct <- as.data.table(coeftable(est_list[[nm]]), keep.rownames = TRUE)
        idx <- grepl(":mh$", ct$rn)
        dt <- data.table(
            spec    = nm,
            term    = ct$rn[idx],
            est     = ct$Estimate[idx] / yscale,
            se      = ct[["Std. Error"]][idx] / yscale
        )
        dt[, period  := as.integer(regmatches(term, regexpr("[0-9]{4}", term)))]
        dt[, ci_low  := est - 1.96 * se]
        dt[, ci_high := est + 1.96 * se]
        rbind(dt, data.table(spec = nm, term = NA_character_,
                             est = 0, se = 0, ci_low = 0, ci_high = 0,
                             period = ref))
    }))
    setorder(dt_all, spec, period)
    dt_all[, spec := factor(spec, levels = names(est_list))]

    n <- length(est_list)
    shapes <- c(16, 17, 15, 18)[seq_len(n)]

    p <- ggplot(dt_all, aes(x = period, y = est,
                             color = spec, fill = spec, shape = spec)) +
        geom_ribbon(aes(ymin = ci_low, ymax = ci_high),
                    alpha = 0.10, color = NA) +
        geom_line() +
        geom_point(size = 2) +
        geom_vline(xintercept = vline_x, linetype = "dotted", color = "black") +
        geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
        scale_x_continuous(breaks = sort(unique(dt_all$period))) +
        scale_color_manual(values = v_palette[seq_len(n)]) +
        scale_fill_manual(values  = v_palette[seq_len(n)]) +
        scale_shape_manual(values = shapes) +
        labs(x = "Construction period", y = ylab,
             color = NULL, fill = NULL, shape = NULL) +
        theme_paper() +
        theme(legend.position = "bottom")

    if (!is.null(path)) ggsave(path, p, width = 9, height = 5)
    p
}

# Damage function (Chunk K): raw mean building damage by water-depth bin,
# by housing type, on the same estimation sample as the water-depth
# robustness table above. "Missing" is excluded here since it has no
# position on a depth axis; its rate is reported in the table notes/text
# instead. A housing-type gap that widens or narrows across depth bins is
# exactly what fmla_rob_c's depth-bin x MH interaction tests for.
dt_dmgfn <- dt_claims_est[
    water_depth_bin != "Missing",
    .(mean_damage = mean(building_damage, na.rm = TRUE),
      se_damage   = sd(building_damage, na.rm = TRUE) / sqrt(.N)),
    by = .(water_depth_bin, mh)]

# Reorder to increasing depth for the figure only -- the regressions above
# use "[0,1) ft" as the reference level, which is not depth-ordered.
dt_dmgfn[, water_depth_bin := factor(
    as.character(water_depth_bin), levels = wd_labels)]
dt_dmgfn[, housing_type := factor(
    fifelse(mh == 1L, "Manufactured", "Site-built"),
    levels = c("Site-built", "Manufactured"))]

p_dmgfn <- ggplot(
    dt_dmgfn,
    aes(x = water_depth_bin, y = mean_damage, color = housing_type,
        group = housing_type)
) +
    geom_line() +
    geom_pointrange(aes(
        ymin = mean_damage - 1.96 * se_damage,
        ymax = mean_damage + 1.96 * se_damage)) +
    scale_color_manual(values = v_palette[1:2]) +
    labs(x = "Water depth at loss", y = "Mean building damage (000s)",
         color = NULL) +
    theme_paper() +
    theme(legend.position = "bottom")

ggsave(file.path(out_dir, "damage-function.pdf"), p_dmgfn, width = 9, height = 5)

plot_es(est_claim_es, "net_building_pmt",
        path = file.path(out_dir, "es-net-building-pmt.pdf"))

plot_es(est_claim_es, "building_damage",
        path = file.path(out_dir, "es-building-damage.pdf"))

plot_es(est_claim_es, "net_contents_pmt",
        path = file.path(out_dir, "es-net-contents-pmt.pdf"))

plot_es(est_claim_es, "building_damage_share",
        path = file.path(out_dir, "es-building-damage-share.pdf"))

plot_es(est_pclaim_es, "claim_rate",
        path = file.path(out_dir, "es-claim-rate.pdf"))

plot_es(est_pois_es, "policies_n",
        path = file.path(out_dir, "es-policies.pdf"))

plot_es(est_share_es, "mh_claim_share", var = NULL, ref = ref_period,
        vline_x = 1993.5,
        path = file.path(out_dir, "es-mh-claim-share.pdf"))

plot_es(est_share_es, "mh_policy_share", var = NULL, ref = ref_period,
        vline_x = 1993.5,
        path = file.path(out_dir, "es-mh-policy-share.pdf"))

# Export key scalars ----
dir.create(here("output", "results"), showWarnings = FALSE, recursive = TRUE)

extract_post_stats <- function(est_obj, outcome, scale = 1) {
    ct <- as.data.table(coeftable(est_obj[lhs = outcome][[1]]),
                        keep.rownames = TRUE)
    ct <- ct[grepl(":mh$", rn)]
    ct[, period := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]
    post <- ct[period >= 1994L, Estimate / scale]
    list(avg = mean(post), min = min(post), max = max(post))
}

eff_bldg_dmg <- extract_post_stats(est_claim_es, "building_damage",      1)
eff_net_bldg <- extract_post_stats(est_claim_es, "net_building_pmt",     1)
eff_cont_dmg <- extract_post_stats(est_claim_es, "contents_damage",      1)
eff_net_cont <- extract_post_stats(est_claim_es, "net_contents_pmt",     1)
eff_bldg_shr <- extract_post_stats(est_claim_es, "building_damage_share",   1)
avg_bldg_dmg_all <- mean(dt_claims_est$building_damage, na.rm = TRUE)

# static ATT: single post_mh coefficient per outcome (headline number)
extract_static <- function(est_obj, outcome) {
    ct <- as.data.table(coeftable(est_obj[lhs = outcome][[1]]),
                        keep.rownames = TRUE)
    ct <- ct[rn == "post_mh"]
    list(est = ct$Estimate, se = ct[["Std. Error"]], t = ct[["t value"]])
}

stc_bldg_dmg <- extract_static(est_static, "building_damage")
stc_net_bldg <- extract_static(est_static, "net_building_pmt")
stc_cont_dmg <- extract_static(est_static, "contents_damage")
stc_net_cont <- extract_static(est_static, "net_contents_pmt")
stc_bldg_shr <- extract_static(est_static, "building_damage_share")

# water-depth robustness (Chunk K): post_mh across the three single-LHS
# columns of est_rob_list, so the text can report how the headline
# coefficient moves as the non-parametric depth control is added.
extract_postmh_single <- function(est_obj) {
    ct <- as.data.table(coeftable(est_obj), keep.rownames = TRUE)
    ct <- ct[rn == "post_mh"]
    list(est = ct$Estimate, se = ct[["Std. Error"]])
}
stc_rob_base   <- extract_postmh_single(est_rob_list[["Baseline"]])
stc_rob_depth  <- extract_postmh_single(est_rob_list[["+ Water depth"]])
stc_rob_depthx <- extract_postmh_single(est_rob_list[["+ Water depth $\\times$ MH"]])

# water-depth missingness by mh x post1994 (dt_wd_miss built during data
# construction), for the same discussion.
get_wd_miss <- function(is_mh, is_post) dt_wd_miss[
    mh == is_mh & post1994 == is_post, water_depth_missing_rate]
wd_miss_mh_pre  <- get_wd_miss(1L, 0L)
wd_miss_mh_post <- get_wd_miss(1L, 1L)
wd_miss_sb_pre  <- get_wd_miss(0L, 0L)
wd_miss_sb_post <- get_wd_miss(0L, 1L)

# take-up per housing-unit stock (Chunk E): OLS coefficients on the ratio
# outcomes themselves, so these are LEVEL differences in annual policies (or
# claims) per 1,000 homes, not log rate ratios. Chunk I adds the third margin,
# claims per policy-year, and static counterparts for all three.
eff_ppl_home <- extract_post_stats(est_home_ols, "policies_per_1k_homes_yr", 1)
eff_clm_home <- extract_post_stats(est_home_ols, "claims_per_1k_homes_yr",   1)

# earliest PRE-reform vintage bin of the take-up column. The paper cites it
# because it is large and significant, which is what disqualifies the take-up
# event study as a level-break design -- the profile trends rather than steps.
extract_bin <- function(est_obj, outcome, bin) {
    ct <- as.data.table(coeftable(est_obj[lhs = outcome][[1]]),
                        keep.rownames = TRUE)
    ct <- ct[grepl(":mh$", rn)]
    ct[, period := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]
    stopifnot(ct[period == bin, .N] == 1L)
    list(est = ct[period == bin, Estimate],
         se  = ct[period == bin][["Std. Error"]])
}
bin_ppl_first <- extract_bin(
    est_home_ols, "policies_per_1k_homes_yr", MIN_YEAR_CONSTR)

# single-LHS fits, so coeftable() applies directly rather than via [lhs = ]
extract_post_stats_single <- function(est_obj) {
    ct <- as.data.table(coeftable(est_obj), keep.rownames = TRUE)
    ct <- ct[grepl(":mh$", rn)]
    ct[, period := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]
    post <- ct[period >= 1994L, Estimate]
    list(avg = mean(post), min = min(post), max = max(post))
}
extract_static_single <- function(est_obj) {
    ct <- as.data.table(coeftable(est_obj), keep.rownames = TRUE)
    ct <- ct[rn == "post_mh"]
    list(est = ct$Estimate, se = ct[["Std. Error"]], t = ct[["t value"]])
}

eff_claim_rate <- extract_post_stats_single(est_claimrate_ols)
stc_claim_rate <- extract_static_single(est_claimrate_static)
stc_ppl_home   <- extract_static(est_home_static, "policies_per_1k_homes_yr")
stc_clm_home   <- extract_static(est_home_static, "claims_per_1k_homes_yr")
stc_ppl_mand    <- extract_static(
    est_home_mand_static, "policies_mand_per_1k_homes_yr")
stc_ppl_nonmand <- extract_static(
    est_home_mand_static, "policies_nonmand_per_1k_homes_yr")
stc_ppl_nogeo   <- extract_static_single(est_home_static_nogeo)

# Pre-1994 MH baselines for the three take-up margins, so the coefficients can
# be read against the level they move from (the paper quotes them this way).
base_ppl_home  <- dt_home_cell[
    mh == 1L & period_constr < 1994L,
    sum(policies_n) / (sum(homes_n) * N_YEARS_PERIOD) * 1000]
base_clm_home  <- dt_home_cell[
    mh == 1L & period_constr < 1994L,
    sum(claims_n) / (sum(homes_n) * N_YEARS_PERIOD) * 1000]

# Both sides of the policies-per-home comparison, in pooled levels. Weighting
# the cell ratios by homes_n makes each of these equal to the pooled ratio of
# summed policies to summed home-years. These are NOT what the fitted
# coefficient differences: the raw pre/post contrast they imply is negative
# while the fitted post_mh is positive, because the fit is within county x
# calendar period and MH stock sits disproportionately in counties whose overall
# take-up rose least across the vintage boundary. They are reported as context
# for the magnitudes, with est_home_static_nogeo above supplying the raw
# contrast the paper cites alongside the fitted one.
ppl_home_level <- function(is_mh, is_post) dt_home_cell[
    mh == is_mh & (period_constr >= 1994L) == is_post,
    sum(policies_n) / (sum(homes_n) * N_YEARS_PERIOD) * 1000]
lvl_ppl_mh_pre  <- ppl_home_level(1L, FALSE)
lvl_ppl_mh_post <- ppl_home_level(1L, TRUE)
lvl_ppl_sb_pre  <- ppl_home_level(0L, FALSE)
lvl_ppl_sb_post <- ppl_home_level(0L, TRUE)
base_claim_rate <- dt_home_cell[
    mh == 1L & period_constr < 1994L, sum(claims_n) / sum(policies_n)]

fwrite(
    data.table(
        statistic = c(
            "building_damage_avg",       "building_damage_min",
            "building_damage_max",
            "net_building_pmt_avg",      "net_building_pmt_min",
            "net_building_pmt_max",
            "contents_damage_avg",       "contents_damage_min",
            "contents_damage_max",
            "net_contents_pmt_avg",      "net_contents_pmt_min",
            "net_contents_pmt_max",
            "building_damage_share_avg", "building_damage_share_min",
            "building_damage_share_max",
            "avg_building_damage_all",
            "building_damage_static",    "building_damage_static_se",
            "building_damage_static_t",
            "net_building_pmt_static",   "net_building_pmt_static_se",
            "net_building_pmt_static_t",
            "contents_damage_static",    "contents_damage_static_se",
            "contents_damage_static_t",
            "net_contents_pmt_static",   "net_contents_pmt_static_se",
            "net_contents_pmt_static_t",
            "building_damage_share_static", "building_damage_share_static_se",
            "building_damage_share_static_t",
            "policies_per_1k_homes_yr_avg", "policies_per_1k_homes_yr_min",
            "policies_per_1k_homes_yr_max",
            "claims_per_1k_homes_yr_avg",   "claims_per_1k_homes_yr_min",
            "claims_per_1k_homes_yr_max",
            "claim_rate_avg",             "claim_rate_min",
            "claim_rate_max",
            "policies_per_1k_homes_yr_static",
            "policies_per_1k_homes_yr_static_se",
            "policies_per_1k_homes_yr_static_t",
            "claims_per_1k_homes_yr_static",
            "claims_per_1k_homes_yr_static_se",
            "claims_per_1k_homes_yr_static_t",
            "claim_rate_static",          "claim_rate_static_se",
            "claim_rate_static_t",
            "policies_per_1k_homes_yr_base_mh",
            "claims_per_1k_homes_yr_base_mh",
            "claim_rate_base_mh",
            "policies_per_1k_homes_yr_mh_pre",
            "policies_per_1k_homes_yr_mh_post",
            "policies_per_1k_homes_yr_sb_pre",
            "policies_per_1k_homes_yr_sb_post",
            "policies_mand_per_1k_homes_yr_static",
            "policies_mand_per_1k_homes_yr_static_se",
            "policies_nonmand_per_1k_homes_yr_static",
            "policies_nonmand_per_1k_homes_yr_static_se",
            "policies_per_1k_homes_yr_static_nogeo",
            "policies_per_1k_homes_yr_static_nogeo_se",
            "policies_per_1k_homes_yr_pre_first",
            "policies_per_1k_homes_yr_pre_first_se",
            "water_depth_missing_mh_pre",  "water_depth_missing_mh_post",
            "water_depth_missing_sb_pre",  "water_depth_missing_sb_post",
            "water_depth_bins_per_cell", "water_depth_single_bin_share",
            "water_depth_n_bins",
            "building_damage_static_rob_base",
            "building_damage_static_rob_base_se",
            "building_damage_static_rob_depth",
            "building_damage_static_rob_depth_se",
            "building_damage_static_rob_depthx",
            "building_damage_static_rob_depthx_se",
            "winsor_cap",
            "winsor_n_building_damage",  "winsor_n_contents_damage",
            "winsor_n_net_building_pmt", "winsor_n_net_contents_pmt",
            "winsor_n_mh_building_damage", "winsor_n_mh_contents_damage",
            "repl_cost_zero_share",
            "zero_share_net_building_pmt", "zero_share_net_contents_pmt",
            "building_damage_static_unw",  "contents_damage_static_unw",
            "building_damage_r2",          "building_damage_r2_unw",
            "contents_damage_r2",          "contents_damage_r2_unw"
        ),
        value = c(
            eff_bldg_dmg$avg, eff_bldg_dmg$min, eff_bldg_dmg$max,
            eff_net_bldg$avg, eff_net_bldg$min, eff_net_bldg$max,
            eff_cont_dmg$avg, eff_cont_dmg$min, eff_cont_dmg$max,
            eff_net_cont$avg, eff_net_cont$min, eff_net_cont$max,
            eff_bldg_shr$avg, eff_bldg_shr$min, eff_bldg_shr$max,
            avg_bldg_dmg_all,
            stc_bldg_dmg$est, stc_bldg_dmg$se, stc_bldg_dmg$t,
            stc_net_bldg$est, stc_net_bldg$se, stc_net_bldg$t,
            stc_cont_dmg$est, stc_cont_dmg$se, stc_cont_dmg$t,
            stc_net_cont$est, stc_net_cont$se, stc_net_cont$t,
            stc_bldg_shr$est, stc_bldg_shr$se, stc_bldg_shr$t,
            eff_ppl_home$avg, eff_ppl_home$min, eff_ppl_home$max,
            eff_clm_home$avg, eff_clm_home$min, eff_clm_home$max,
            eff_claim_rate$avg, eff_claim_rate$min, eff_claim_rate$max,
            stc_ppl_home$est,   stc_ppl_home$se,   stc_ppl_home$t,
            stc_clm_home$est,   stc_clm_home$se,   stc_clm_home$t,
            stc_claim_rate$est, stc_claim_rate$se, stc_claim_rate$t,
            base_ppl_home, base_clm_home, base_claim_rate,
            lvl_ppl_mh_pre, lvl_ppl_mh_post,
            lvl_ppl_sb_pre, lvl_ppl_sb_post,
            stc_ppl_mand$est,    stc_ppl_mand$se,
            stc_ppl_nonmand$est, stc_ppl_nonmand$se,
            stc_ppl_nogeo$est,   stc_ppl_nogeo$se,
            bin_ppl_first$est,   bin_ppl_first$se,
            wd_miss_mh_pre,  wd_miss_mh_post,
            wd_miss_sb_pre,  wd_miss_sb_post,
            wd_bins_per_cell, wd_single_bin_shr,
            wd_n_bins,
            stc_rob_base$est,   stc_rob_base$se,
            stc_rob_depth$est,  stc_rob_depth$se,
            stc_rob_depthx$est, stc_rob_depthx$se,
            MAX_CLAIM_LOSS,
            dt_winsor_n$building_damage,  dt_winsor_n$contents_damage,
            dt_winsor_n$net_building_pmt, dt_winsor_n$net_contents_pmt,
            dt_winsor_mh[mh == 1L, building_damage],
            dt_winsor_mh[mh == 1L, contents_damage],
            n_repl_zero,
            dt_zero_share$net_building_pmt, dt_zero_share$net_contents_pmt,
            extract_static(est_static_unw, "building_damage_unw")$est,
            extract_static(est_static_unw, "contents_damage_unw")$est,
            r2(est_static[lhs = "building_damage$"][[1]], "r2"),
            r2(est_static_unw[lhs = "building_damage_unw"][[1]], "r2"),
            r2(est_static[lhs = "contents_damage$"][[1]], "r2"),
            r2(est_static_unw[lhs = "contents_damage_unw"][[1]], "r2")
        )
    ),
    here("output", "results", "nfip-scalars.csv")
)

# ---------------------------------------------------------------------------
# Superseded ----
# ---------------------------------------------------------------------------
# Insurance-accounting outcomes (Chunk D). Checks whether payments are muted
# by coverage caps/deductibles rather than by lower physical damage.
# Colin's call (2026-08-13): second-order to the paper's actual question --
# how much MH damage itself changed -- so console-only, no .tex export.
dt_claims_est[, capped_pmt := fifelse(
    !is.na(building_covg) & building_covg > 0,
    as.integer(net_building_pmt >= building_covg), NA_integer_)]
dt_claims_est[, pmt_covg_ratio := fifelse(
    !is.na(building_covg) & building_covg > 0,
    net_building_pmt / building_covg, NA_real_)]
dt_claims_est[, damage_repl_ratio := fifelse(
    !is.na(building_repl_cost) & building_repl_cost > 0,
    building_damage / building_repl_cost, NA_real_)]
dt_claims_est[, zero_pmt := as.integer(net_building_pmt <= 0)]

s_insacct <- "c(capped_pmt, pmt_covg_ratio, damage_repl_ratio, zero_pmt)"

fmla_insacct_static <- as.formula(paste0(
    s_insacct, " ~ post_mh | geo^year_loss + mh + post1994"
))
est_insacct_static <- feols(
    fmla_insacct_static, data = dt_claims_est, cluster = ~countyfp)
etable(est_insacct_static, fitstat = c("n", "r2", "my"))

fmla_insacct_es <- as.formula(paste0(
    s_insacct, " ~ i(period_constr, mh, ref = ref_period)",
    " | geo^year_loss + mh + period_constr"
))
est_insacct_es <- feols(
    fmla_insacct_es, data = dt_claims_est, cluster = ~countyfp)
etable(est_insacct_es, fitstat = c("n", "r2", "my"))
