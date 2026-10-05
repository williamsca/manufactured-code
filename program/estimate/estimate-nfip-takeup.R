# Cell-level NFIP estimates: take-up per housing unit, claim frequency, per-claim
# cell averages, and the MH share of claims and policies, on the balanced
# tract x calendar-period x housing-type x vintage panel.
# Writes output/results/nfip-takeup-scalars.csv.
#
# Usage: Rscript estimate-nfip-takeup.R [bin width] [countyfp|tractfp]

rm(list = ls())
library(here)
source(here("program", "lib", "nfip-setup.R"))
source(here("program", "lib", "nfip-claims-sample.R"))
source(here("program", "lib", "plot-es.R"))

# Calendar years per period_loss bin. The cell panel's five-year bins are
# 2009-2013, 2014-2018, 2019-2023 (policy records begin 2009; MAX_YEAR_LOSS is
# 2023), so every retained bin holds exactly this many years. Asserted against
# the data below, since the annualized take-up rates divide by it.
N_YEARS_PERIOD <- 5L

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
#
# Read the current stock independently of the policy panel. This also avoids
# requiring a large NFIP rebuild when only the Census denominator changes.
dt_stock <- readRDS(here("derived", "stock-county-vintage.Rds"))
dt_stock <- dt_stock[between(year_constr, MIN_YEAR_CONSTR, MAX_YEAR_CONSTR)]
dt[, intersect(c("homes_n", "homes_flat_n", "homes_occupied_n"), names(dt)) := NULL]
dt <- merge(dt, dt_stock, by = c("countyfp", "year_constr", "mh"), all.x = TRUE)

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

# outcome names for cell-level ES
v_pclaim <- grep("_share$", v_claim, invert = TRUE, value = TRUE)
v_pclaim <- paste0(v_pclaim, "_pclaim")
s_pclaim <- paste0(
    "c(", paste0(v_pclaim, collapse = ", "),
    ", claim_rate",
    ", ", paste0(v_ppol, collapse = ", "),
    ")")

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

# Take-up per housing-unit stock (Chunk E; Chunk N moves it to PPML). The three
# margins are counts of policy-years and claims relative to an exposure
# denominator, so they are estimated as Poisson counts with the log denominator
# as an offset:
#
#     claims per home = policies per home x claims per policy
#     (hazard realized      (take-up:        (claim frequency
#      per home in the       who insures)     conditional on
#      housing stock)                         holding a policy)
#
# with payment conditional on a claim -- the intensive margin -- reported
# separately in the claim-level damage tables above (`est_claim_es`,
# `est_static`), which need no stock denominator. p(claim | policy) is also the
# object `estimate-welfare.R` uses as its hazard rate, so that column says
# directly whether the reform moved the number the cost-benefit rests on.
#
# WHY COUNTS RATHER THAN OLS ON THE RATIO (Chunk N). These columns previously
# ran OLS on the ratio itself, weighted by the denominator, so the coefficients
# were level differences in policies per 1,000 homes. That specification is not
# identified in its own units, for the same reason the levels damage spec is not
# (Chunk M): the MH/site-built take-up gap is proportional, not additive.
# Weighted take-up runs from about 4 annual policies per 1,000 homes in the
# bottom third of counties to about 108 in the top third, so a single additive
# `mh` fixed effect cannot fit both ends, and `post_mh` absorbs the misfit. The
# diagnostics below (`est_home_diag_*`) quantify it: the pooled level estimate
# is +4.65, but it is NEGATIVE in each of the three take-up terciles estimated
# separately, and flips to about -5.5 as soon as the `mh` and `post1994` main
# effects are allowed to vary by tercile, to about -1.5 with a county-specific
# `mh` effect, and to about +0.4 at five-year construction bins. The PPML
# coefficient moves from 0.007 to 0.170 across the same perturbations -- small
# and sign-stable throughout. Poisson also takes the zeros natively and needs no
# weighting rule, which retires the thin-cell weighting the level fit required.
#
# WHY STATE CLUSTERING (Chunk N). The stock denominator's within-bin annual
# allocation is a STATE-year series (MHS placements) broadcast to every county
# in the state, and county permit shares within a state move together. Its error
# is therefore close to a single draw per state x vintage x housing type, not
# 2,866 independent county draws, and county clustering credits it with
# precision it does not have. Regressing log(homes_n) on the same interaction
# and fixed effects returns a vintage profile with county-clustered t-statistics
# of 5 to 11 on a quantity that contains no policy data at all. Every column
# here clusters by state; the county-clustered standard errors are exported as
# scalars so the appendix can report both. Column (3) uses no imputed input and
# so is not exposed to this, which is why the appendix reports it as the one
# result that does not rest on the imputation.
#
# The exact rate identity above holds cell by cell in the data but NOT in the
# fitted coefficients: each column solves its own Poisson score equation against
# its own offset, so (1) + (3) need not equal (2). The appendix says so rather
# than claiming a decomposition the estimator does not deliver.
#
# Construct the denominator from every eligible Census stock cell, then join
# counts. Match numerator construction years to positive stock, excluding 1994.
# The shared helper also builds five-year vintage bins for the diagnostic.
source(here("program", "lib", "takeup-panel.R"))
# Claims are aggregated directly so tracts without policies are not silently
# lost from the claims-per-home numerator. The policy panel already contains
# every observed policy; zero-policy county/vintage/type cells come from stock.
takeup_claims <- dt_claims[period_loss %in% periods_obs,
    .(claims_n = .N), by = .(countyfp, period_loss, year_constr, mh)]
build_home_cell <- function(binw) {
    build_takeup_panel(dt, takeup_claims, dt_stock, periods_obs, binw,
                       N_YEARS_PERIOD)
}

dt_home_cell <- build_home_cell(BIN_CONSTR_YEAR)

CLUSTER_TAKEUP <- ~statefp

# --- dynamic: vintage profile, three margins ------------------------------
takeup_es_rhs <- paste0(
    " ~ i(period_constr, mh, ref = ref_period)",
    " | geo^period_loss + mh + period_constr")

fit_takeup <- function(lhs, offset_var, rhs, data = dt_home_cell,
                       cluster = CLUSTER_TAKEUP) {
    if (offset_var == "log_policy_yrs") data <- data[policies_n > 0]
    fepois(as.formula(paste0(lhs, rhs)), data = data,
           offset = as.formula(paste0("~", offset_var)), cluster = cluster)
}

est_ppl_home_es <- fit_takeup("policies_n", "log_home_yrs",   takeup_es_rhs)
est_clm_home_es <- fit_takeup("claims_n",   "log_home_yrs",   takeup_es_rhs)
est_claimrate_es <- fit_takeup("claims_n",  "log_policy_yrs", takeup_es_rhs)

source(here("program", "lib", "plot-takeup.R"))
plot_takeup_event_study(
    list("Policies per home" = est_ppl_home_es,
         "Claims per policy" = est_claimrate_es),
    ref_period, file.path(out_dir, "es-takeup-claim-frequency.pdf"))


takeup_headers <- c(
    "Policies per home",
    "Claims per home",
    "Claims per policy"
)
est_takeup_list <- list(est_ppl_home_es, est_clm_home_es, est_claimrate_es)
etable(est_takeup_list, fitstat = c("n", "pr2"))
iplot(est_ppl_home_es)

etable(
    est_takeup_list,
    digits = 3, digits.stats = 2, fitstat = c("n", "pr2"),
    tex = TRUE, replace = TRUE, depvar = FALSE,
    headers = list("Log annual rate" = takeup_headers),
    file = file.path(out_dir, "take-up.tex"))

# --- static: one post-1994 x MH coefficient per margin --------------------
takeup_static_rhs <- " ~ post_mh | geo^period_loss + mh + post1994"

est_ppl_home_static <- fit_takeup("policies_n", "log_home_yrs",   takeup_static_rhs)
est_clm_home_static <- fit_takeup("claims_n",   "log_home_yrs",   takeup_static_rhs)
est_claimrate_static <- fit_takeup("claims_n",  "log_policy_yrs", takeup_static_rhs)

est_takeup_static_list <- list(
    est_ppl_home_static, est_clm_home_static, est_claimrate_static)
etable(est_takeup_static_list, fitstat = c("n", "pr2"))

etable(
    est_takeup_static_list,
    digits = 3, digits.stats = 2, fitstat = c("n", "pr2"),
    tex = TRUE, replace = TRUE, depvar = FALSE, se.below = FALSE,
    headers = list("Log annual rate" = takeup_headers),
    file = file.path(out_dir, "take-up-static.tex"))

# Column (1) re-estimated on the two claims columns' sample. Poisson drops
# fixed-effect groups whose outcome is zero throughout, and a county x calendar
# period with no claims at all is such a group for the claims columns but not
# for the policy column, so the three columns of the table do not share a
# sample. Those cells carry take-up information and are not dropped from column
# (1) for that reason; this fit says what column (1) would be if they were, so
# the appendix can state that the sample difference does not drive the contrast
# between the columns.
est_ppl_home_static_clm <- fit_takeup(
    "policies_n", "log_home_yrs", takeup_static_rhs,
    data = dt_home_cell[obs(est_clm_home_static)])

# County-clustered counterparts of the same three static fits, so the appendix
# can report how much of the old table's significance was the clustering choice
# rather than the estimates.
est_ppl_home_static_cty <- fit_takeup(
    "policies_n", "log_home_yrs", takeup_static_rhs, cluster = ~geo)
est_clm_home_static_cty <- fit_takeup(
    "claims_n", "log_home_yrs", takeup_static_rhs, cluster = ~geo)
est_claimrate_static_cty <- fit_takeup(
    "claims_n", "log_policy_yrs", takeup_static_rhs, cluster = ~geo)

# --- robustness: switch the annual imputation off -------------------------
# Same specification, same cells, same numerator; only the offset changes, from
# the placement- and permit-allocated stock to the equal within-bin split
# (impute-stock.R section 4). What moves between the two columns is what the
# annual sources supply. The claim-rate column has no such counterpart because
# its offset is observed policy-years, which is the point of including it.
est_ppl_home_es_flat <- fit_takeup(
    "policies_n", "log_home_yrs_flat", takeup_es_rhs)
est_clm_home_es_flat <- fit_takeup(
    "claims_n", "log_home_yrs_flat", takeup_es_rhs)
est_ppl_home_static_flat <- fit_takeup(
    "policies_n", "log_home_yrs_flat", takeup_static_rhs)
est_clm_home_static_flat <- fit_takeup(
    "claims_n", "log_home_yrs_flat", takeup_static_rhs)

est_takeup_flat_list <- list(
    est_ppl_home_es, est_ppl_home_es_flat,
    est_clm_home_es, est_clm_home_es_flat)
etable(est_takeup_flat_list, fitstat = c("n", "pr2"))

etable(
    est_takeup_flat_list,
    digits = 3, digits.stats = 2, fitstat = c("n", "pr2"),
    tex = TRUE, replace = TRUE, depvar = FALSE,
    headers = list(
        "Log annual rate" = rep(c("Policies per home", "Claims per home"),
                                each = 2),
        "Stock denominator" = rep(c("Imputed", "Flat"), 2)),
    file = file.path(out_dir, "take-up-robust.tex"))

# How far the swap moves the imputed denominator itself, by vintage bin and
# housing type, so the appendix can say which bins the annual sources are doing
# the work in rather than only that some of them are.
dt_flat_gap <- dt_home_cell[
    , .(imputed = sum(homes_n), flat = sum(homes_flat_n)),
    by = .(mh, period_constr)]
dt_flat_gap[, log_gap := log(flat / imputed)]
dt_flat_gap <- dcast(dt_flat_gap, period_constr ~ mh, value.var = "log_gap")
setnames(dt_flat_gap, c("0", "1"), c("gap_sb", "gap_mh"))
dt_flat_gap[, gap_diff := gap_mh - gap_sb]
print(dt_flat_gap)

# --- diagnostics reported in the appendix text, not tabled ----------------
# (a) The level specification this block used to run, plus the three
#     perturbations that show it is not identified in its own units. Each is the
#     same static contrast; only the fixed effects (or the bin width) change.
est_home_diag_lvl <- feols(
    policies_per_1k_homes_yr ~ post_mh | geo^period_loss + mh + post1994,
    data = dt_home_cell, cluster = CLUSTER_TAKEUP, weights = ~homes_n)

# take-up tercile of the county, on its own pooled all-vintage rate
dt_cty_rate <- dt_home_cell[
    , .(rate = 1000 * sum(policies_n) / (sum(homes_n) * N_YEARS_PERIOD)),
    by = geo]
dt_cty_rate[, tercile := cut(
    rate, quantile(rate, 0:3 / 3), include.lowest = TRUE,
    labels = c("low", "mid", "high"))]
dt_home_cell <- merge(dt_home_cell, dt_cty_rate[, .(geo, tercile)], by = "geo")

est_home_diag_tercile <- feols(
    policies_per_1k_homes_yr ~ post_mh | geo^period_loss + mh^tercile +
        post1994^tercile,
    data = dt_home_cell, cluster = CLUSTER_TAKEUP, weights = ~homes_n)
est_home_diag_ctymh <- feols(
    policies_per_1k_homes_yr ~ post_mh | geo^period_loss + geo^mh + post1994,
    data = dt_home_cell, cluster = CLUSTER_TAKEUP, weights = ~homes_n)
est_home_diag_ppml_ctymh <- fit_takeup(
    "policies_n", "log_home_yrs",
    " ~ post_mh | geo^period_loss + geo^mh + post1994")

# five-year construction bins, panel rebuilt from the row level
dt_home_cell5 <- build_home_cell(5L)
est_home_diag_bin5 <- feols(
    policies_per_1k_homes_yr ~ post_mh | geo^period_loss + mh + post1994,
    data = dt_home_cell5, cluster = CLUSTER_TAKEUP, weights = ~homes_n)
est_home_diag_bin5_ppml <- fit_takeup(
    "policies_n", "log_home_yrs", takeup_static_rhs, data = dt_home_cell5)

# the same level contrast estimated separately within each tercile
diag_tercile_by <- rbindlist(lapply(c("low", "mid", "high"), function(t) {
    s <- dt_home_cell[tercile == t]
    m <- feols(policies_per_1k_homes_yr ~ post_mh |
                   geo^period_loss + mh + post1994,
               data = s, cluster = CLUSTER_TAKEUP, weights = ~homes_n)
    data.table(tercile = t,
               mean_rate = weighted.mean(s$policies_per_1k_homes_yr, s$homes_n),
               est = coef(m)[["post_mh"]], se = se(m)[["post_mh"]])
}))
print(diag_tercile_by)

# (b) The imputed denominator's own vintage profile, run through the identical
#     interaction and fixed effects as the outcome. It contains no policy data,
#     so every coefficient here is imputation; the county-clustered t-statistics
#     are what the state-clustering paragraph above refers to.
est_home_den_profile <- feols(
    log(homes_n) ~ i(period_constr, mh, ref = ref_period) |
        geo^period_loss + mh + period_constr,
    data = dt_home_cell, cluster = ~geo)
etable(est_home_den_profile, fitstat = c("n", "r2"))

# (c) The same static contrast with the geographic fixed effects removed, which
#     is the raw pre/post difference-in-differences across all counties. MH
#     stock is concentrated in counties whose overall post-1994 take-up rose
#     least, so the two differ; reporting both keeps that dependence visible
#     instead of resting on the fixed effects silently.
est_home_static_nogeo <- fit_takeup(
    "policies_n", "log_home_yrs", " ~ post_mh | mh + post1994")

# (d) Mandatory vs non-mandatory purchase, as described above.
est_home_mand_static <- fit_takeup(
    "mand_n", "log_home_yrs", takeup_static_rhs)
est_home_nonmand_static <- fit_takeup(
    "nonmand_n", "log_home_yrs", takeup_static_rhs)
etable(list(est_home_mand_static, est_home_nonmand_static), fitstat = c("n"))

# plots ----
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
# Take-up per housing-unit stock (Chunk E; PPML from Chunk N). Every take-up
# coefficient below is now a LOG rate ratio -- a proportional change in the
# annual rate -- not the level difference in policies per 1,000 homes the
# earlier OLS-on-the-ratio version produced. The `_ppml` suffix marks that, so a
# stale scalar name cannot silently be read on the old scale. The level rates
# themselves are still exported (unsuffixed, as `*_base_mh` and the four
# `*_mh_pre`/`_sb_post` quantities) because they are descriptive statistics, not
# estimates, and the appendix quotes them to give the log effects a magnitude.

# single-coefficient PPML fits, so coeftable() applies directly
extract_static_single <- function(est_obj) {
    ct <- as.data.table(coeftable(est_obj), keep.rownames = TRUE)
    ct <- ct[rn == "post_mh"]
    stopifnot(nrow(ct) == 1L)
    list(est = ct$Estimate, se = ct[[3L]], t = ct[[4L]])
}
extract_post_stats_single <- function(est_obj) {
    ct <- as.data.table(coeftable(est_obj), keep.rownames = TRUE)
    ct <- ct[grepl(":mh$", rn)]
    ct[, period := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]
    post <- ct[period >= 1994L, Estimate]
    list(avg = mean(post), min = min(post), max = max(post))
}
# one named vintage bin, with its standard error. The appendix cites the
# earliest PRE-reform bin because a large coefficient there is what disqualifies
# the event study as a level-break design -- the profile trends rather than
# steps.
extract_bin_single <- function(est_obj, bin) {
    ct <- as.data.table(coeftable(est_obj), keep.rownames = TRUE)
    ct <- ct[grepl(":mh$", rn)]
    ct[, period := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]
    stopifnot(ct[period == bin, .N] == 1L)
    list(est = ct[period == bin, Estimate], se = ct[period == bin][[3L]])
}

eff_ppl_home   <- extract_post_stats_single(est_ppl_home_es)
eff_clm_home   <- extract_post_stats_single(est_clm_home_es)
eff_claim_rate <- extract_post_stats_single(est_claimrate_es)

stc_ppl_home   <- extract_static_single(est_ppl_home_static)
stc_clm_home   <- extract_static_single(est_clm_home_static)
stc_claim_rate <- extract_static_single(est_claimrate_static)

# county-clustered counterparts: same point estimates, so only the SEs differ
stc_ppl_home_cty   <- extract_static_single(est_ppl_home_static_cty)
stc_clm_home_cty   <- extract_static_single(est_clm_home_static_cty)
stc_claim_rate_cty <- extract_static_single(est_claimrate_static_cty)
stopifnot(all(abs(c(
    stc_ppl_home$est   - stc_ppl_home_cty$est,
    stc_clm_home$est   - stc_clm_home_cty$est,
    stc_claim_rate$est - stc_claim_rate_cty$est)) < 1e-12))

# largest pre-1994 bin of column (1) in absolute value, with the vintage bin it
# sits in. The appendix cites it because a coefficient this size before the
# reform is what rules the profile out as a level break at 1994.
extract_pre_max_single <- function(est_obj) {
    ct <- as.data.table(coeftable(est_obj), keep.rownames = TRUE)
    ct <- ct[grepl(":mh$", rn)]
    ct[, period := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]
    ct <- ct[period < 1994L]
    stopifnot(nrow(ct) > 0L)
    r <- ct[which.max(abs(Estimate))]
    list(est = r$Estimate, se = r[[3L]], period = r$period)
}
pre_max_ppl <- extract_pre_max_single(est_ppl_home_es)

bin_ppl_first      <- extract_bin_single(est_ppl_home_es, MIN_YEAR_CONSTR)
bin_ppl_first_flat <- extract_bin_single(est_ppl_home_es_flat, MIN_YEAR_CONSTR)

stc_ppl_home_clm  <- extract_static_single(est_ppl_home_static_clm)
stc_ppl_home_flat <- extract_static_single(est_ppl_home_static_flat)
stc_clm_home_flat <- extract_static_single(est_clm_home_static_flat)
stc_ppl_nogeo     <- extract_static_single(est_home_static_nogeo)
stc_ppl_mand      <- extract_static_single(est_home_mand_static)
stc_ppl_nonmand   <- extract_static_single(est_home_nonmand_static)

# Largest movement between the imputed and flat denominators anywhere in the
# pre-1994 vintage profile of column (1), which is the single number the
# appendix uses to say the pre-period profile is the imputation's.
gap_pre_max <- local({
    b <- as.data.table(coeftable(est_ppl_home_es), keep.rownames = TRUE)
    f <- as.data.table(coeftable(est_ppl_home_es_flat), keep.rownames = TRUE)
    m <- merge(b[, .(rn, base = Estimate)], f[, .(rn, flat = Estimate)], by = "rn")
    m[, period := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]
    m[period < 1994L, max(abs(base - flat))]
})

# Specification diagnostics for the levels-vs-counts paragraph. The level fits
# are in policies per 1,000 homes; the PPML ones in log points.
stc_diag_lvl      <- extract_static_single(est_home_diag_lvl)
stc_diag_tercile  <- extract_static_single(est_home_diag_tercile)
stc_diag_ctymh    <- extract_static_single(est_home_diag_ctymh)
stc_diag_bin5     <- extract_static_single(est_home_diag_bin5)
stc_diag_ppml_ctymh <- extract_static_single(est_home_diag_ppml_ctymh)
stc_diag_ppml_bin5  <- extract_static_single(est_home_diag_bin5_ppml)

# The three within-tercile level estimates, and the take-up rates they are
# estimated against, which is the spread a single additive `mh` effect has to
# span.
diag_terc <- function(t, col) diag_tercile_by[tercile == t][[col]]
# Largest county-clustered |t| anywhere in the imputed denominator's own vintage
# profile: a quantity with no policy content in it at all.
den_profile_max_t <- max(abs(coeftable(est_home_den_profile)[, 3L]))

# Pre-1994 MH baselines for the three take-up margins, so the coefficients can
# be read against the level they move from (the appendix quotes them this way).
base_ppl_home  <- dt_home_cell[
    mh == 1L & period_constr < 1994L,
    sum(policies_n) / (sum(homes_n) * N_YEARS_PERIOD) * 1000]
base_clm_home  <- dt_home_cell[
    mh == 1L & period_constr < 1994L,
    sum(claims_n) / (sum(homes_n) * N_YEARS_PERIOD) * 1000]
base_claim_rate <- dt_home_cell[
    mh == 1L & period_constr < 1994L, sum(claims_n) / sum(policies_n)]
# pre-1994 mandated share of MH policy-years, used to weight the two components
# of the mandatory/non-mandatory split into a contribution to the total
base_mand_share <- dt_home_cell[
    mh == 1L & period_constr < 1994L, sum(mand_n) / sum(policies_n)]

# Both sides of the policies-per-home comparison, in pooled levels. These are
# NOT what the fitted coefficients difference: the fit is within county x
# calendar period, and MH stock sits disproportionately in counties whose
# overall take-up rose least across the vintage boundary, which is what
# est_home_static_nogeo above quantifies.
ppl_home_level <- function(is_mh, is_post) dt_home_cell[
    mh == is_mh & (period_constr >= 1994L) == is_post,
    sum(policies_n) / (sum(homes_n) * N_YEARS_PERIOD) * 1000]
lvl_ppl_mh_pre  <- ppl_home_level(1L, FALSE)
lvl_ppl_mh_post <- ppl_home_level(1L, TRUE)
lvl_ppl_sb_pre  <- ppl_home_level(0L, FALSE)
lvl_ppl_sb_post <- ppl_home_level(0L, TRUE)

write_nfip_scalars(list(
    takeup_ppml_avg                  = eff_ppl_home$avg,
    takeup_ppml_min                  = eff_ppl_home$min,
    takeup_ppml_max                  = eff_ppl_home$max,
    claims_home_ppml_avg             = eff_clm_home$avg,
    claims_home_ppml_min             = eff_clm_home$min,
    claims_home_ppml_max             = eff_clm_home$max,
    claim_rate_ppml_avg              = eff_claim_rate$avg,
    claim_rate_ppml_min              = eff_claim_rate$min,
    claim_rate_ppml_max              = eff_claim_rate$max,
    takeup_ppml_static               = stc_ppl_home$est,
    takeup_ppml_static_se            = stc_ppl_home$se,
    takeup_ppml_static_t             = stc_ppl_home$t,
    takeup_ppml_static_cty_se        = stc_ppl_home_cty$se,
    claims_home_ppml_static          = stc_clm_home$est,
    claims_home_ppml_static_se       = stc_clm_home$se,
    claims_home_ppml_static_t        = stc_clm_home$t,
    claims_home_ppml_static_cty_se   = stc_clm_home_cty$se,
    claim_rate_ppml_static           = stc_claim_rate$est,
    claim_rate_ppml_static_se        = stc_claim_rate$se,
    claim_rate_ppml_static_t         = stc_claim_rate$t,
    claim_rate_ppml_static_cty_se    = stc_claim_rate_cty$se,
    policies_per_1k_homes_yr_base_mh = base_ppl_home,
    claims_per_1k_homes_yr_base_mh   = base_clm_home,
    claim_rate_base_mh               = base_claim_rate,
    policies_per_1k_homes_yr_mh_pre  = lvl_ppl_mh_pre,
    policies_per_1k_homes_yr_mh_post = lvl_ppl_mh_post,
    policies_per_1k_homes_yr_sb_pre  = lvl_ppl_sb_pre,
    policies_per_1k_homes_yr_sb_post = lvl_ppl_sb_post,
    takeup_ppml_mand_static          = stc_ppl_mand$est,
    takeup_ppml_mand_static_se       = stc_ppl_mand$se,
    takeup_ppml_nonmand_static       = stc_ppl_nonmand$est,
    takeup_ppml_nonmand_static_se    = stc_ppl_nonmand$se,
    takeup_mand_share_pre_mh         = base_mand_share,
    takeup_ppml_static_nogeo         = stc_ppl_nogeo$est,
    takeup_ppml_static_nogeo_se      = stc_ppl_nogeo$se,
    takeup_ppml_pre_first            = bin_ppl_first$est,
    takeup_ppml_pre_first_se         = bin_ppl_first$se,
    takeup_ppml_pre_max              = pre_max_ppl$est,
    takeup_ppml_pre_max_se           = pre_max_ppl$se,
    takeup_ppml_pre_max_bin          = pre_max_ppl$period,
    takeup_ppml_static_flat          = stc_ppl_home_flat$est,
    takeup_ppml_static_flat_se       = stc_ppl_home_flat$se,
    claims_home_ppml_static_flat     = stc_clm_home_flat$est,
    claims_home_ppml_static_flat_se  = stc_clm_home_flat$se,
    takeup_ppml_pre_first_flat       = bin_ppl_first_flat$est,
    takeup_ppml_pre_first_flat_se    = bin_ppl_first_flat$se,
    takeup_flat_pre_max_gap          = gap_pre_max,
    takeup_ppml_static_clmsample     = stc_ppl_home_clm$est,
    takeup_ppml_static_clmsample_se  = stc_ppl_home_clm$se,
    takeup_lvl_static                = stc_diag_lvl$est,
    takeup_lvl_static_se             = stc_diag_lvl$se,
    takeup_lvl_static_tercile        = stc_diag_tercile$est,
    takeup_lvl_static_tercile_se     = stc_diag_tercile$se,
    takeup_lvl_static_ctymh          = stc_diag_ctymh$est,
    takeup_lvl_static_ctymh_se       = stc_diag_ctymh$se,
    takeup_lvl_static_bin5           = stc_diag_bin5$est,
    takeup_lvl_static_bin5_se        = stc_diag_bin5$se,
    takeup_ppml_static_ctymh         = stc_diag_ppml_ctymh$est,
    takeup_ppml_static_bin5          = stc_diag_ppml_bin5$est,
    takeup_lvl_static_terc_low       = diag_terc("low", "est"),
    takeup_lvl_static_terc_mid       = diag_terc("mid", "est"),
    takeup_lvl_static_terc_high      = diag_terc("high", "est"),
    takeup_rate_terc_low             = diag_terc("low", "mean_rate"),
    takeup_rate_terc_high            = diag_terc("high", "mean_rate"),
    takeup_den_profile_max_t         = den_profile_max_t
), "takeup")
