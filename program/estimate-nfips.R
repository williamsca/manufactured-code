# Estimate effect of 1994 HUD wind standards on NFIP claims
# Uses balanced county × mh × post1994 × year_loss panel

rm(list = ls())
library(here)
library(data.table)
library(fixest)

# import ----
dt <- readRDS(here("derived", "nfip-balanced.Rds"))

dt[, damage_building_pvalue := building_damage_tot / building_value_tot]
dt[, damage_contents_pvalue := contents_damage_tot / contents_value_tot]

dt[, net_building_pmts_pdamage := net_building_pmt_tot / building_damage_tot]

dt_claims <- dt[claims_n > 0 & building_damage_tot > 0]

# estimate ----

# main specification: event study with treated × year_constr effects,
# controlling for type x year_loss x county FEs
v_pclaim <- c(
    "building_value_pclaim", "building_damage_pclaim",
    "net_building_pmt_pclaim",
    "contents_damage_pclaim", "net_contents_pmt_pclaim",
    "contents_value_pclaim",
    "building_covg_pclaim", "contents_covg_pclaim",
    "damage_building_pvalue", "damage_contents_pvalue",
    "net_building_pmts_pdamage")
s_pclaim <- paste0("c(", paste0(v_pclaim, collapse = ", "), ")")

v_out <- c("claims_n")
s_out <- paste0("c(", paste0(v_out, collapse = ", "), ")")

fmla_pclaim <- as.formula(paste0(
    s_pclaim, " ~ i(year_constr, mh, ref = 1994) | countyfp^year_loss + mh"))
fmla_out    <- as.formula(paste0(
    s_out, " ~ i(year_constr, mh, ref = 1994) | countyfp^year_loss + mh^year_loss"))

est_pclaim <- feols(
    fmla_pclaim, weights = ~claims_n,
    data = dt_claims
)

etable(est_pclaim, fitstat = c("n", "r2", "wr2", "my"))


est_pois <- fepois(
    fmla_out, data = dt,
    weights = ~claims_n
)

etable(est_pois)

# triple-diff: add treated interaction
est_ddd <- feols(
    c(building_damage_pclaim, net_building_pmt_pclaim) ~
        post1994 * mh * treated | countyfp^year_loss + mh,
    data = dt_claims, cluster = ~countyfp
)

etable(est_ddd, se = "cluster")
