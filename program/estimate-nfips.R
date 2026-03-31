# Estimate effect of 1994 HUD wind standards on NFIP claims
# Uses balanced county × mh × post1994 × year_loss panel

rm(list = ls())
library(here)
library(data.table)
library(fixest)

# import ----
dt <- readRDS(here("derived", "nfip-balanced.Rds"))

dt[, treated_mh := (mh == 1) & treated == TRUE]

dt_claims <- dt[
    claims_n > 0 & building_damage_tot > 0 & !is.na(policies_n)]
# dt_claims <- readRDS(here("derived", "nfip-claims.Rds"))

# estimate ----

# claim-level outcomes
v_claim <- c(
    "building_damage", # "building_value",
    "net_building_pmt",
    "contents_damage", "net_contents_pmt"
    # "contents_value"
    # "building_covg_pclaim", "contents_covg_pclaim"
)
v_pclaim <- paste0(v_claim, "_pclaim")
s_pclaim <- paste0(
    "c(", paste0(v_pclaim, collapse = ", "), ", claim_rate", ")")

fmla_pclaim <- as.formula(paste0(
    s_pclaim, " ~ i(year_constr, mh, ref = 1994)",
    " | countyfp^year_loss + mh")
)

est_pclaim <- feols(fmla_pclaim, data = dt_claims, weights = ~claims_n)

etable(est_pclaim, fitstat = c("n", "r2", "wr2", "my"))

# on count outcomes

v_out <- c("claims_n", "policies_n")
s_out <- paste0("c(", paste0(v_out, collapse = ", "), ")")

fmla_out <- as.formula(paste0(
    s_out, " ~ i(year_constr, mh, ref = 1994)",
    " | countyfp^year_loss + mh"
))


est_pois <- fepois(
    fmla_out, data = dt,
    weights = ~claims_n
)

etable(est_pois)

# triple-diff: add treated interaction
est_ddd <- feols(
    c(building_damage_pclaim, net_building_pmt_pclaim) ~
        post1994 * mh * treated | countyfp^year_loss + mh,
    data = dt_claims
)

etable(est_ddd)
