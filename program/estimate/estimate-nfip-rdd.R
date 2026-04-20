# RDD-DiD: effect of 1994 HUD wind standard on building damage
#
# Running variable: construction year centered at 1994 (rc = year_constr - 1994)
# Separate linear trends in rc on each side of cutoff and for each housing type.
# Key coefficients: mh, post1994, mh x post1994.

rm(list = ls())
library(here)
library(data.table)
library(fixest)
library(rdrobust)

source(here("program", "import", "project-params.R"))

out_dir <- here("output", "event-study", "rdd")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

v_dict <- c(
    mh = "MH",
    post1994 = "Post-1994 vintage",
    year_loss = "Year of loss",
    statefp = "State",
    countyfp = "County",
    tractfp = "Tract",
    building_damage = "Building damage",
    net_building_pmt = "Net building pmt.",
    building_damage_share = "Bldg. dmg. share (\\%)",
    contents_damage = "Contents damage",
    net_contents_pmt = "Net contents pmt.",
    repl_cost_ppol = "Repl. cost",
    building_policy_covg_ppol = "Bldg. covg.",
    contents_policy_covg_ppol = "Contents covg.",
    elevated_share = "Elevated",
    sfha_share = "SFHA",
    primary_res_share = "Primary res.",
    mandatory_purchase_share = "Mandatory"
)

setFixest_dict(v_dict, reset = TRUE)

# ---------------------------------------------------------------------------
# data ----
# ---------------------------------------------------------------------------
dt_claims <- readRDS(here("derived", "nfip-claims.Rds"))
dt_claims <- dt_claims[
    between(year_constr, 1985, 2005) &
    between(year_loss, MIN_YEAR_LOSS, MAX_YEAR_LOSS)]

dt_claims[, period_loss := ((year_loss - 1994L) %/% 5L) * 5L + 1994L]
dt_claims[, post1994    := as.integer(year_constr >= 1994L)]
dt_claims[, rc          := year_constr - 1994L]   # centered running variable
dt_claims[, rc_post     := rc * post1994]          # slope allowed to differ post-cutoff
dt_claims[, statefp     := substr(countyfp, 1L, 2L)]

dt_claims[, building_damage_share := fifelse(
    !is.na(building_value) & building_value > 0,
    100 * building_damage / building_value, NA_real_)]

v_outcomes <- c(
    "building_damage", "net_building_pmt", "building_damage_share",
    "contents_damage", "net_contents_pmt"
)
dt_claims <- dt_claims[rowSums(is.na(.SD)) == 0L, .SDcols = v_outcomes]

# ---------------------------------------------------------------------------
# RDD-DiD specifications ----
# ---------------------------------------------------------------------------

# Linear RDD-DiD: separate slope on each side of the cutoff via rc + rc_post
fmla_rdd <- building_damage ~
    mh * post1994 + mh * rc + mh * rc_post |
    sw(statefp^year_loss, countyfp^year_loss, tractfp^year_loss)

est_rdd <- feols(fmla_rdd, data = dt_claims)

etable(est_rdd, fitstat = c("n", "r2"),
    digits = 2, digits.stats = 2, drop = "rc")

etable(est_rdd,
    fitstat   = c("n", "r2", "my"),
    drop      = "rc",
    digits    = 2, digits.stats = 2,
    tex       = TRUE, replace = TRUE,
    file      = file.path(out_dir, "rdd-building-damage.tex"))

# ---------------------------------------------------------------------------
# RDD-DiD: baseline (county x loss-year FEs), all claim-level outcomes ----
# ---------------------------------------------------------------------------

s_outcomes <- paste0("c(", paste(v_outcomes, collapse = ", "), ")")

fmla_rdd_outcomes <- as.formula(paste0(
    s_outcomes, " ~ mh * post1994 + mh * rc + mh * rc_post",
    " | countyfp^year_loss"
))

est_rdd_outcomes <- feols(
    fmla_rdd_outcomes, data = dt_claims)

etable(est_rdd_outcomes, fitstat = c("n", "r2", "my"),
    digits = 2, digits.stats = 2, drop = "rc")

etable(est_rdd_outcomes,
    fitstat   = c("n", "r2", "my"),
    digits    = 2, digits.stats = 2,
    tex       = TRUE, replace = TRUE,
    file      = file.path(out_dir, "rdd-outcomes.tex"))

# ---------------------------------------------------------------------------
# RDD-DiD: policy composition ----
# ---------------------------------------------------------------------------

dt_pol <- readRDS(here("derived", "nfip-balanced.Rds"))
dt_pol <- dt_pol[between(year_constr, 1985L, 2005L)]
dt_pol[, countyfp := substr(tractfp, 1L, 5L)]

v_pol_raw <- c(
    "policies_n", "repl_cost_tot", "policy_cost_tot",
    "building_policy_covg_tot", "contents_policy_covg_tot",
    "elevated_policy_n", "sfha_policy_n",
    "primary_res_policy_n", "mandatory_purchase_policy_n"
)

dt_pol_cell <- dt_pol[
    !is.na(policies_n) & policies_n > 0L,
    lapply(.SD, sum, na.rm = TRUE),
    by = .(countyfp, period_loss, mh, year_constr),
    .SDcols = v_pol_raw]

dt_pol_cell[, elevated_share            := elevated_policy_n           / policies_n]
dt_pol_cell[, sfha_share                := sfha_policy_n               / policies_n]
dt_pol_cell[, primary_res_share         := primary_res_policy_n        / policies_n]
dt_pol_cell[, mandatory_purchase_share  := mandatory_purchase_policy_n / policies_n]
dt_pol_cell[, repl_cost_ppol            := repl_cost_tot               / policies_n]
dt_pol_cell[, building_policy_covg_ppol := building_policy_covg_tot    / policies_n]
dt_pol_cell[, contents_policy_covg_ppol := contents_policy_covg_tot    / policies_n]

dt_pol_cell[, post1994 := as.integer(year_constr >= 1994L)]
dt_pol_cell[, rc       := year_constr - 1994L]
dt_pol_cell[, rc_post  := rc * post1994]

v_comp <- c(
    "repl_cost_ppol",
    "building_policy_covg_ppol",
    "contents_policy_covg_ppol",
    "elevated_share",
    "sfha_share",
    "primary_res_share",
    "mandatory_purchase_share"
)
s_comp <- paste0("c(", paste(v_comp, collapse = ", "), ")")

fmla_rdd_comp <- as.formula(paste0(
    s_comp, " ~ mh * post1994 + mh * rc + mh * rc_post",
    " | countyfp^period_loss"
))

est_rdd_comp <- feols(
    fmla_rdd_comp, data = dt_pol_cell,
    weights = ~policies_n)

etable(est_rdd_comp, fitstat = c("n", "r2", "my"),
    digits = 1, digits.stats = 2, drop = "rc")

etable(est_rdd_comp,
    fitstat      = c("n", "r2", "my"),
    drop         = "rc",
    digits       = 1, digits.stats = 2,
    tex          = TRUE, replace = TRUE,
    file         = file.path(out_dir, "rdd-policy-composition.tex"))
