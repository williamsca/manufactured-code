# Estimate effect of 1994 HUD wind standards on NFIP claims
# Uses balanced county × mh × post1994 × year_loss panel

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
    "claims_rate" = "Claims per policy"
)

setFixest_dict(v_dict, reset = TRUE)

# import ----
dt <- readRDS(here("derived", "nfip-balanced.Rds"))

dt[, treated_mh := (mh == 1) & treated == TRUE]

dt_claims_cell <- dt[
    claims_n > 0 & building_damage_tot > 0 & !is.na(policies_n) &
    between(year_constr, 1988L, 2002L)]

dt_claims <- readRDS(here("derived", "nfip-claims.Rds"))
dt_claims <- dt_claims[between(year_constr, 1988, 2002) & year_loss >= 1994]
dt_claims[, building_damage_ln := log(building_damage)]
dt_claims[, net_building_pmt_ln := log(net_building_pmt)]

# estimate ----

# claim-level outcomes
# conditional on making a claim, damage and payment amounts decline
# for MH built after 1994, though the effect grows gradually,
# consistent with some delay between manufacturing and installation,
# plus the fact that window and door debris impact-testing requirements
# only applied after Jan. 1995.
v_claim <- c(
    "building_damage", # "building_damage_ln", # "building_value",
    "net_building_pmt", # "net_building_pmt_ln",
    "contents_damage", "net_contents_pmt"
    # "contents_value"
    # "building_covg_pclaim", "contents_covg_pclaim"
)
s_claim <- paste0("c(", paste0(v_claim, collapse = ", "), ")")

fmla_claim <- as.formula(paste0(
    s_claim, " ~ i(year_constr, mh, ref = 1994)",
    " | tractfp^year_loss + mh"
))

est_claim <- feols(fmla_claim, data = dt_claims, lean = TRUE)

etable(est_claim, fitstat = c("n", "r2", "wr2", "my"))

iplot(est_claim[lhs = "building_pmt$"])

# cell-level averages
# claims per active policy declines sharply for MH built after 1994,
# by 0.05 against a baseline of 0.13

v_pclaim <- paste0(v_claim, "_pclaim")
s_pclaim <- paste0(
    "c(", paste0(v_pclaim, collapse = ", "), ", claim_rate", ")")

fmla_pclaim <- as.formula(paste0(
    s_pclaim, " ~ i(year_constr, mh, ref = 1994)",
    " | tractfp^year_loss + mh")
)

est_pclaim <- feols(
    fmla_pclaim, data = dt_claims_cell, weights = ~claims_n,
    lean = TRUE)

etable(est_pclaim, fitstat = c("n", "r2", "wr2", "my"))

iplot(est_pclaim[lhs = "claim_rate"])

# count outcomes (claims and policies)
# both increase sharply for MH built after 1994.
# Supported by anecdote from the NYT:
# "Those over-roof anchors were added to mobile home regulations after
# Hurricane Andrew. At the time, most homes were only secured by connecting
# the frame to rods buried in the ground.
# Not all older homes have been upgraded. Generally, homeowners said, the
# additional anchors have to be installed in order to obtain insurance. But
# many people do not buy insurance, as premiums are relatively high and
 #coverage is usually below the home’s full cost."

v_out <- c("claims_n", "policies_n")
s_out <- paste0("c(", paste0(v_out, collapse = ", "), ")")

fmla_out <- as.formula(paste0(
    s_out, " ~ i(year_constr, mh, ref = 1994)",
    " | countyfp^year_loss + mh"
))


est_pois <- fepois(
    fmla_out, data = dt,
    weights = ~claims_n, lean = TRUE
)

etable(est_pois)

# triple-diff: add treated interaction
est_ddd <- feols(
    c(building_damage_pclaim, net_building_pmt_pclaim) ~
        post1994 * mh * treated | countyfp^year_loss + mh,
    data = dt_claims
)

etable(est_ddd)
