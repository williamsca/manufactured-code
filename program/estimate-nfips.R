# Estimate effect of 1994 HUD wind standards on NFIP claims
# Uses balanced county × mh × post1994 × year_loss panel

rm(list = ls())
library(here)
library(data.table)
library(fixest)

# import ----
dt <- readRDS(here("derived", "nfip-balanced.Rds"))

# Main spec: event × housing-type FE, county FE
# post1994 captures general vintage improvement (both MH and site-built)
# post1994 × mh captures the MH-specific effect of the HUD code change
est_main <- feols(
    c(n_claims, total_building_damage, total_net_building_pmt) ~
        i(year_constr, mh, ref = 1994) | countyfp + year_loss^mh,
    data = dt, cluster = ~countyfp
)

etable(est_main, se = "cluster")

# Triple-diff: add treated interaction
est_ddd <- feols(
    c(n_claims, total_building_damage, total_net_building_pmt) ~
        post1994 * mh * treated | countyfp + year_loss^mh,
    data = dt, cluster = ~countyfp
)

etable(est_ddd, se = "cluster")
