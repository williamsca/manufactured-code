# Estimate effect of 1994 HUD wind standards on NFIP claims
# Uses balanced county × mh × post1994 × year_loss panel

rm(list = ls())
library(here)
library(data.table)
library(fixest)

# import ----
dt <- readRDS(here("derived", "nfip-balanced.Rds"))

# Per-claim averages (conditional on at least one claim in the cell)
dt[, avg_building_damage    := fifelse(n_claims > 0, total_building_damage    / n_claims, NA_real_)]
dt[, avg_net_building_pmt   := fifelse(n_claims > 0, total_net_building_pmt   / n_claims, NA_real_)]

dt_claims <- dt[n_claims > 0]

# estimate ----

# main specification: event study with treated × year_constr effects,
# controlling for type x year_loss x county FEs
v_pclaim <- c("avg_building_damage", "avg_net_building_pmt")
s_pclaim <- paste0("c(", paste0(v_pclaim, collapse = ", "), ")")

v_out <- c("n_claims", "total_building_damage", "total_net_building_pmt")
s_out <- paste0("c(", paste0(v_out, collapse = ", "), ")")

fmla_pclaim <- as.formula(paste0(
    s_pclaim, " ~ i(year_constr, treated, ref = 1994) | countyfp^year_loss^mh"))
fmla_out    <- as.formula(paste0(
    s_out, " ~ i(year_constr, treated, ref = 1994) | countyfp^year_loss^mh"))


est_pclaim <- feols(
    fmla_pclaim, weights = ~n_claims,
    data = dt_claims
)

etable(est_pclaim)

est_main <- feols(
    fmla_out, data = dt
)

etable(est_main)

est_pois <- fepois(
    fmla_out, data = dt[total_net_building_pmt >= 0], weights = ~n_claims
)

etable(est_pois, est_main)

# Triple-diff: add treated interaction
est_ddd <- feols(
    c(avg_building_damage, avg_net_building_pmt) ~
        post1994 * mh * treated | countyfp + year_loss^mh,
    data = dt_claims, cluster = ~countyfp
)

etable(est_ddd, se = "cluster")
