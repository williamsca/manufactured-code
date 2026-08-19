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

source(here("program", "import", "project-params.R"))

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
    "claim_rate" = "Claims per policy",
    "repl_cost_ppol" = "Repl. cost",
    "policy_cost_ppol" = "Policy cost per policy",
    "building_policy_covg_ppol" = "Bldg covg.",
    "contents_policy_covg_ppol" = "Contents covg.",
    "elevated_share" = "Elevated",
    "sfha_share" = "SFHA",
    "water_depth" = "Water depth (ft)",
    "elevated" = "Elevated",
    "sfha" = "SFHA",
    "primary_res_share" = "Primary res.",
    "mandatory_purchase_share" = "Mandatory",
    "policies_per_1k_homes" = "Policies per 1,000 homes",
    "claims_per_1k_homes" = "Claims per 1,000 homes",
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
dt <- readRDS(here("derived", "nfip-balanced.Rds"))f
dt <- dt[between(year_constr, MIN_YEAR_CONSTR, MAX_YEAR_CONSTR)]
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
dt_cell[, policies_per_1k_homes := fifelse(
    !is.na(homes_n) & homes_n > 0, 1000 * policies_n / homes_n, NA_real_)]
dt_cell[, claims_per_1k_homes := fifelse(
    !is.na(homes_n) & homes_n > 0, 1000 * claims_n / homes_n, NA_real_)]

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

v_shares <- c("building_damage", "net_building_pmt")
v_shares_names <- paste0(v_shares, "_share")
dt_claims[, (v_shares_names) := lapply(
    .SD, function(x) 100 * x / building_value), .SDcols = v_shares]

# covariate prep for robustness specs
dt_claims[, log_repl_cost := fifelse(
    !is.na(building_repl_cost) & building_repl_cost > 0,
    log(building_repl_cost), NA_real_)]
dt_claims[, occupancy_type := factor(occupancy_type)]

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

v_alt <- c(
    "building_damage$", "net_building_pmt$", "building_damage_share",
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

est_pclaim_es <- feols(
    fmla_pclaim_es, data = dt_cell,
    weights = ~policies_n,
    lean = TRUE)
etable(est_pclaim_es, fitstat = c("n", "r2", "wr2", "my"))

iplot(est_pclaim_es[lhs = "claim_rate"])

# policy composition summary table
v_comp <- c(
    "repl_cost_ppol",
    "building_policy_covg_ppol",
    "contents_policy_covg_ppol",
    "elevated_share",
    "sfha_share"
    # "primary_res_share",
    #"mandatory_purchase_share"
)
s_comp <- paste0("c(", paste(v_comp, collapse = ", "), ")")

fmla_comp_post <- as.formula(paste0(
    s_comp, " ~ i(period_constr, mh, ref = ref_period)",
    " | geo^period_loss + mh + period_constr"
))

est_comp_post <- feols(
    fmla_comp_post, data = dt_cell,
    weights = ~policies_n,
    lean = TRUE
)
etable(est_comp_post, fitstat = c("n", "r2", "wr2", "my"))


etable(
    est_comp_post,
    tex = TRUE, se.below = FALSE,
    file = file.path(out_dir, "policy-composition.tex"),
    fitstat = c("n", "r2", "my"),
    # keep = "post_mh",
    digits = 1, digits.stats = 2, replace = TRUE
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
    weights = ~policies_n, lean = TRUE
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
    fmla_out_es, data = dt_pois
)
etable(est_pois_es)

iplot(est_pois_es)

# Take-up per housing-unit stock (Chunk E): OLS on the ratio outcomes
# themselves (policies_per_1k_homes, claims_per_1k_homes), clustered by
# county (geo == countyfp under the default agg_geo), replacing the
# policies-per-SF-permit ratio (wrong housing type, badly non-random BPS
# coverage -- see TODO.md Chunk E). Decomposes the take-up margin into claim
# frequency (claims per home, extensive/insurability margin) versus payment
# conditional on a claim (the damage-severity specs above, `est_claim_es`),
# which the review notes have different welfare interpretations.
#
# Weighted by homes_n: a handful of cells have imputed stock well under 1
# home (thin county x period x mh cells, mostly the already-flagged 1994
# bin), producing policies_per_1k_homes ratios in the tens of thousands
# that would otherwise dominate an unweighted fit. Same logic as the
# policies_n weights already used for the composition/claim-rate cell
# regressions above.
#
# Pooled across all three policy periods (2009-2023) only -- an
# earliest-period-only (2009-2013) restriction was checked and dropped:
# point estimates were extremely similar to the pooled column, so it added
# a column without adding information. See notes/specs.md for the caveat
# on the Census-2000-vs-policy-data time gap this restriction was meant to
# address.
dt_home_cell <- dt_cell[!is.na(homes_n) & homes_n > 0]

fmla_home_ols <- as.formula(paste0(
    "c(policies_per_1k_homes, claims_per_1k_homes)",
    " ~ i(period_constr, mh, ref = ref_period)",
    " | geo^period_loss + mh + period_constr"
))

est_home_ols <- feols(
    fmla_home_ols, data = dt_home_cell, cluster = ~geo,
    weights = ~homes_n, lean = TRUE
)
etable(est_home_ols, fitstat = c("n", "r2", "my"))
iplot(est_home_ols[lhs = "policies_per_1k_homes"])

etable(
    list(
        "Policies per 1,000 homes" = est_home_ols[lhs = "policies_per_1k_homes"][[1]],
        "Claims per 1,000 homes"   = est_home_ols[lhs = "claims_per_1k_homes"][[1]]
    ),
    digits = 2, digits.stats = 2, fitstat = c("n", "r2", "my"),
    tex = TRUE, replace = TRUE,
    file = file.path(out_dir, "take-up.tex"))

# ---------------------------------------------------------------------------
# covariate-controlled robustness: building damage ----
# ---------------------------------------------------------------------------
# Progressively add covariates to assess whether composition changes in the
# insured pool drive the main result. Using building_damage (not net payment)
# to avoid any confounding from deductible changes across vintages.
# FEs vary with agg_geo so the full script runs at a consistent geography.

fmla_rob_a <- building_damage ~
    i(period_constr, mh, ref = ref_period) |
    geo^period_loss + mh

fmla_rob_b <- building_damage ~
    i(period_constr, mh, ref = ref_period) +
    water_depth + elevated + sfha + water_depth |
    geo^period_loss + mh

fmla_rob_c <- building_damage ~
    i(period_constr, mh, ref = ref_period) |
    tractfp^period_loss + mh

fmla_rob_d <- building_damage ~
    i(period_constr, mh, ref = ref_period) +
    water_depth + elevated + sfha  |
    tractfp^period_loss + mh

est_rob_list <- list(
    "Baseline"          = feols(fmla_rob_a, data = dt_claims_est, lean = TRUE, cluster = ~countyfp),
    "+ Controls"     = feols(fmla_rob_b, data = dt_claims_est, lean = TRUE, cluster = ~countyfp),
    "+ Tract FE"  = feols(fmla_rob_c, data = dt_claims_est, lean = TRUE, cluster = ~countyfp),
    "+ Controls + Tract FE"    = feols(fmla_rob_d, data = dt_claims_est, lean = TRUE, cluster = ~countyfp)
)

etable(est_rob_list, tex = TRUE,
    file = here("output", "event-study", agg_geo, "robustness.tex"),
    fitstat = c("n", "r2"), digits = 2, digits.stats = 2, replace = TRUE,
    depvar = FALSE)

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
# (`derived/ecfr-windzone.csv`) rather than an independently defined
# coastal/hurricane county list, so the benefit-side split lines up with
# the cost-side treatment definition. NYC boroughs get the same Zone I
# fallback used in `databuild-nfip.R` (consolidated city-county government
# not in the eCFR crosswalk).
dt_wz <- fread(here("derived", "ecfr-windzone.csv"), keepLeadingZeros = TRUE)
dt_claims_est <- merge(dt_claims_est, dt_wz, by = "countyfp", all.x = TRUE)
dt_claims_est[is.na(wind_zone) & substr(countyfp, 1L, 2L) == "36", wind_zone := 1L]
stopifnot(nrow(dt_claims_est[is.na(wind_zone)]) == 0L)
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

plot_es_multi(
    est_rob_list,
    path = file.path(out_dir, "es-building-damage-robust.pdf"))

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

# take-up per housing-unit stock (Chunk E): OLS coefficients on the ratio
# outcomes themselves, so these are LEVEL differences in policies (or
# claims) per 1,000 homes, not log rate ratios
eff_ppl_home <- extract_post_stats(est_home_ols, "policies_per_1k_homes", 1)
eff_clm_home <- extract_post_stats(est_home_ols, "claims_per_1k_homes",   1)

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
            "policies_per_1k_homes_avg", "policies_per_1k_homes_min",
            "policies_per_1k_homes_max",
            "claims_per_1k_homes_avg",   "claims_per_1k_homes_min",
            "claims_per_1k_homes_max"
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
            eff_clm_home$avg, eff_clm_home$min, eff_clm_home$max
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
