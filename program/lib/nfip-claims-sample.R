# Claim-level estimation sample shared by the estimate-nfip-*.R scripts.
# Expects program/lib/nfip-setup.R to have been sourced. Builds `dt_claims`
# (every in-window claim) and `dt_claims_est` (the PPML/OLS estimation sample),
# both carrying the county's HUD wind zone.

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
# MAX_CLAIM_LOSS is defined in project-params.R so that
# estimate-hud-comparison.R winsorizes at the same cap.

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

# Log building damage (Chunk M). A proportional counterpart to the levels
# outcome above, added because the levels specification's identifying
# assumption does not hold in the units it is estimated in.
#
# Equation (2)'s parallel-vintage-trends assumption is that the common
# vintage effect lambda_nu is the same for both housing types. In a levels
# regression that requires the vintage profile to be common *in dollars*.
# The data reject that and support the proportional version instead: across
# the 1994 boundary, median recorded replacement cost rises 15.4% for
# site-built (143.6 -> 165.8) and 16.7% for MH (39.9 -> 46.6), so the DiD on
# LOG replacement cost is -0.031 (SE 0.027), indistinguishable from zero,
# while the same DiD on the LEVEL of replacement cost is -20.58 (SE 2.89).
# Newer homes of both types are larger and more valuable, and dollar damage
# scales with what is at risk.
#
# A common proportional vintage gradient applied to bases that differ by a
# factor of 2.4 (mean pre-1994 building damage 28.95 site-built vs 11.86 MH)
# mechanically produces a negative level DiD with no resilience effect at
# all: 11.86 * 0.156 - 28.95 * 0.156 = -2.67, against a raw level DiD of
# -3.00 and a fixed-effects estimate of -5.75. Verified in simulation but NOT
# yet added to program/tests/: on fake claims with a TRUE post_mh effect of
# zero and a common proportional vintage gradient, the levels specification
# returns roughly -5.3 (t = -5.4) while Poisson recovers zero. Worth adding
# to the fake-data harness before the levels headline is defended in print.
#
# Logs remove the base-scale term by construction, so the coefficients are
# comparable across two housing types of very different value. The cost is
# the zero claims, which are dropped: exact zeros are
# `dt_zero_share$building_damage` of records (about 1.6%), exported as a
# scalar below. This is a diagnostic outcome, not a replacement for the
# levels headline -- the cost-benefit calculation needs a change in expected
# dollars, which a log coefficient does not deliver without a
# retransformation assumption. Poisson (`est_claim_es_pois`) is the estimator
# that gives both, and Chunk L's levels-vs-logs discussion should be read
# alongside this. Winsorization at MAX_CLAIM_LOSS is retained so the log
# outcome sits on the same underlying values as every other claim-level
# outcome; it binds for 8 records and is immaterial in logs.
dt_claims[, log_building_damage := fifelse(
    building_damage > 0, log(building_damage), NA_real_)]

# Log counterparts of the other three baseline claim outcomes. Zeros are
# dropped as above; the net payments and contents damage have far more exact
# zeros than building damage (see `dt_zero_share`), so each log fit has its own
# sample and N is reported by column.
v_log <- c("net_building_pmt", "contents_damage", "net_contents_pmt")
dt_claims[, (paste0("log_", v_log)) := lapply(
    .SD, function(x) fifelse(x > 0, log(x), NA_real_)), .SDcols = v_log]

v_shares <- c("building_damage", "net_building_pmt")
v_shares_names <- paste0(v_shares, "_share")
dt_claims[, (v_shares_names) := lapply(
    .SD, function(x) 100 * x / building_value), .SDcols = v_shares]

# Log of the damage share. Zero damage and non-positive or missing
# building_value give a non-finite share and are dropped.
dt_claims[, log_building_damage_share := fifelse(
    is.finite(building_damage_share) & building_damage_share > 0,
    log(building_damage_share), NA_real_)]

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

# --- wind-zone exposure ---
# Reuse the same eCFR crosswalk as the cost-side wind-zone treatment
# (`ecfr_wind_zone`, research-database) rather than an independently defined
# coastal/hurricane county list, so the benefit-side split lines up with the
# cost-side treatment definition. No NYC-borough fallback needed: verified
# 2026-08-24 that every countyfp in nfip-claims.Rds, including all five NYC
# boroughs, matches directly once ecfr_wind_zone covers geo_county's
# historical rows as well as current ones (see research-database's
# program/ecfr/wind-zones/import.R) -- the old fallback predates that fix
# and was for a gap that no longer exists.
dt_wz <- rd_read("ecfr_wind_zone", version = ECFR_WIND_ZONE_VERSION)
# Update join rather than merge() so the claim row order is unchanged.
dt_claims[dt_wz, wind_zone := i.wind_zone, on = "countyfp"]
assert_geo_coverage(
    dt_claims, "wind_zone", "countyfp",
    "nfip-claims-sample.R: claims x ecfr_wind_zone")
dt_claims[, treated_wz3 := as.integer(wind_zone == 3L)]

# Standardized estimation sample for claim-level OLS and Poisson. Net payments
# can be negative when recoveries exceed gross payouts; Poisson does not admit
# negative outcomes, so drop these rows so both estimators run on the same set.
dt_claims_est <- dt_claims[
    (is.na(net_building_pmt) | net_building_pmt >= 0) &
    (is.na(net_contents_pmt) | net_contents_pmt >= 0)
]
