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

v_dict <- c(
    "claims_n" = "Claims (#)",
    "policies_n" = "Policies (#)",
    "building_damage" = "Building damage ($)",
    "net_building_pmt" = "Net building payment ($)",
    "contents_damage" = "Contents damage ($)",
    "net_contents_pmt" = "Net contents payment ($)",
    "claim_rate" = "Claims per policy"
)

setFixest_dict(v_dict, reset = TRUE)

# import ----
dt <- readRDS(here("derived", "nfip-balanced.Rds"))

dt[, treated_mh := (mh == 1) & treated == TRUE]
dt[, post_mh := post1994 * mh]

dt_treated <- unique(dt[, .(countyfp, treated)])

# claim-level data
dt_claims <- readRDS(here("derived", "nfip-claims.Rds"))
dt_claims <- dt_claims[between(year_constr, 1985, 2002) & year_loss >= 1994]
dt_claims[, period_loss := ((year_loss - 1994L) %/% 5L) * 5L + 1994L]
dt_claims[, period_constr := ((year_constr - 1985L) %/% 3L) * 3L + 1985L]
dt_claims[, post1994 := as.integer(year_constr > 1994L)]

# A. Insurability (extensive margin) ----
# Post-1994 MH met structural requirements for insurance eligibility,
# expanding coverage. Supported by NYT anecdote: "the additional anchors
# have to be installed in order to obtain insurance."

est_extensive <- fepois(
    c(policies_n, claims_n) ~ post_mh + post1994 + mh
        | countyfp^loss_period,
    data = dt[between(year_constr, 1988L, 2002L)],
    lean = TRUE
)

etable(est_extensive, fitstat = c("n", "r2", "my"))

# B. Claim intensity (conditional on coverage) ----
# Among cells with active policies, did claim rates change?

dt_rate <- dt[
    !is.na(policies_n) & policies_n > 0 &
    between(year_constr, 1988L, 2002L)]

est_rate <- feols(
    claim_rate ~ post1994*mh | countyfp^loss_period,
    data = dt_rate, weights = ~policies_n, lean = TRUE
)

etable(est_rate, fitstat = c("n", "r2", "wr2", "my"))

# C. Damage severity (conditional on claim) ----
# Among those who filed a claim, did post-1994 MH have lower payouts?

v_claim <- c(
    "building_damage", "net_building_pmt",
    "contents_damage", "net_contents_pmt")
s_claim <- paste0("c(", paste0(v_claim, collapse = ", "), ")")

fmla_sev <- as.formula(paste0(
    s_claim, " ~ post_mh + post1994 + mh | countyfp^loss_period"
))

est_severity <- feols(fmla_sev, data = dt_claims, lean = TRUE)

etable(est_severity, fitstat = c("n", "r2", "wr2", "my"))

# superseded ----
# Event study specifications below.
# These spread limited MH variation across many year_constr bins;
# underpowered at tract level and triple-diff shows bad pre-trends.

# claim-level event study
dt_claims[, treated_mh := (mh == 1) & treated]

fmla_claim_es <- as.formula(paste0(
    s_claim, " ~ i(period_constr, mh, ref = 1991)",
    " | tractfp^period_loss + mh"
))

est_claim_es <- feols(fmla_claim_es, data = dt_claims, lean = TRUE)
etable(est_claim_es, fitstat = c("n", "r2", "wr2", "my"))
iplot(est_claim_es[lhs = "building_pmt$"])

# cell-level event study
dt_claims_cell <- dt[
    claims_n > 0 & building_damage_tot > 0 & !is.na(policies_n) &
    between(period_constr, 1985L, 2002L)]
dt_claims_cell[, treated_mh := (mh == 1) & treated == TRUE]

v_pclaim <- paste0(v_claim, "_pclaim")
s_pclaim <- paste0(
    "c(", paste0(v_pclaim, collapse = ", "), ", claim_rate", ")")

fmla_pclaim_es <- as.formula(paste0(
    s_pclaim, " ~ i(period_constr, mh, ref = 1991)",
    " | countyfp^period_loss + mh")
)

est_pclaim_es <- feols(
    fmla_pclaim_es, data = dt_claims_cell, weights = ~claims_n,
    lean = TRUE)
etable(est_pclaim_es, fitstat = c("n", "r2", "wr2", "my"))
iplot(est_pclaim_es[lhs = "claim_rate"])

# count event study (Poisson)
v_out <- c("claims_n", "policies_n")
s_out <- paste0("c(", paste0(v_out, collapse = ", "), ")")

fmla_out_es <- as.formula(paste0(
    s_out, " ~ i(period_constr, mh, ref = 1991)",
    " | tractfp^period_loss + mh"
))

est_pois_es <- fepois(
    fmla_out_es, data = dt,
    weights = ~claims_n, lean = TRUE
)
etable(est_pois_es)
