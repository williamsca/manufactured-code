# Wind-zone heterogeneity in the claim-level damage estimates. The 1994 HUD
# standard raised wind requirements for homes sited in Zones II and III only;
# Zone I homes built after 1994 were not subject to it.
#
#   (a) Zone-specific DiDs: the headline MH x post-1994 contrast estimated
#       within each wind zone (the dose-response reading).
#   (b) Triple differences: each treated zone's DiD net of Zone I's, which
#       removes any MH-specific vintage change common to all zones.
#
# (a) and (b) are two parameterizations of one saturated model: MH x zone and
# vintage x zone are free, and county x loss-year FE nest the zone. Writes the
# building-damage triple-difference table and
# output/nfip/nfip-windzone-scalars.csv.

rm(list = ls())
library(here)
BIN_CONSTR_DEFAULT <- 1L
source(here("program", "estimate-nfip", "nfip-setup.R"))
source(here("program", "estimate-nfip", "nfip-claims-sample.R"))

dt <- dt_claims_est
dt[, treated    := as.integer(wind_zone >= 2L)]
dt[, mh_z1      := mh * (wind_zone == 1L)]
dt[, mh_z2      := mh * (wind_zone == 2L)]
dt[, mh_z3      := mh * (wind_zone == 3L)]
dt[, mh_tr      := mh * treated]
dt[, post_mh_z2 := post_mh * (wind_zone == 2L)]
dt[, post_mh_z3 := post_mh * (wind_zone == 3L)]
dt[, post_mh_tr := post_mh * treated]

# Zone III is 25 counties in three states (FL, LA, NC), so county-clustered
# inference treats observations within a few coastal states as independent.
dt_wz_n <- dt[, .(claims = .N, counties = uniqueN(countyfp),
                  states = uniqueN(statefp)),
              keyby = .(wind_zone, mh, post1994)]
print(dt_wz_n)

v_loss <- c("building_damage", "net_building_pmt",
            "contents_damage", "net_contents_pmt")
s_loss <- paste0("c(", paste(v_loss, collapse = ", "), ")")
fe_zone <- " | geo^year_loss + mh^wind_zone + post1994^wind_zone"

fit <- function(rhs) {
    fepois(as.formula(paste0(s_loss, rhs)), data = dt, cluster = ~countyfp)
}

# static ----
est_wz_did <- fit(paste0(" ~ i(wind_zone, post_mh)", fe_zone))
est_wz_ddd <- fit(paste0(" ~ post_mh + post_mh_z2 + post_mh_z3", fe_zone))
est_wz_ddd_tr <- fit(paste0(" ~ post_mh + post_mh_tr",
    " | geo^year_loss + mh^treated + post1994^treated"))

# the two parameterizations of the saturated model must agree
local({
    for (y in v_loss) {
        a <- coef(est_wz_did[lhs = paste0("^", y, "$")][[1]])
        b <- coef(est_wz_ddd[lhs = paste0("^", y, "$")][[1]])
        stopifnot(abs(a[[3]] - a[[1]] - b[["post_mh_z3"]]) < 1e-6,
                  abs(a[[1]] - b[["post_mh"]]) < 1e-6)
    }
})

etable(est_wz_did, fitstat = c("n", "pr2"))
etable(est_wz_ddd, est_wz_ddd_tr, fitstat = c("n", "pr2"))
etable(summary(est_wz_ddd, cluster = ~statefp), fitstat = "n")

# Paper robustness table, building damage only: the baseline DiD on all
# counties beside the binary and zone-by-zone triple differences.
est_bd_static <- list(
    fepois(building_damage ~ post_mh | geo^year_loss + mh + post1994,
           data = dt, cluster = ~countyfp),
    est_wz_ddd_tr[lhs = "^building_damage$"][[1]],
    est_wz_ddd[lhs = "^building_damage$"][[1]])
etable(
    est_bd_static,
    tex = TRUE, se.below = FALSE, depvar = FALSE,
    headers = c("Baseline", "Triple diff.", "Triple diff., by zone"),
    order = c("^post_mh$", "post_mh_tr", "post_mh_z2", "post_mh_z3"),
    file = file.path(out_dir, "windzone-ddd-building.tex"),
    fitstat = c("n", "pr2", "my"),
    digits = 3, digits.stats = 2, replace = TRUE
)

get_coef <- function(est_multi, y, term, cluster = NULL) {
    e <- est_multi[lhs = paste0("^", y, "$")][[1]]
    if (!is.null(cluster)) e <- summary(e, cluster = cluster)
    ct <- coeftable(e)
    c(est = ct[term, 1L], se = ct[term, 2L])
}

sc <- list()
for (y in c("building_damage", "net_building_pmt")) {
    terms <- list(
        did_z1 = list(est_wz_did, "wind_zone::1:post_mh"),
        did_z2 = list(est_wz_did, "wind_zone::2:post_mh"),
        did_z3 = list(est_wz_did, "wind_zone::3:post_mh"),
        ddd_z2 = list(est_wz_ddd, "post_mh_z2"),
        ddd_z3 = list(est_wz_ddd, "post_mh_z3"),
        ddd_tr = list(est_wz_ddd_tr, "post_mh_tr"))
    for (nm in names(terms)) {
        b  <- get_coef(terms[[nm]][[1]], y, terms[[nm]][[2]])
        bs <- get_coef(terms[[nm]][[1]], y, terms[[nm]][[2]], ~statefp)
        key <- paste0("wz_", y, "_", nm)
        sc[[key]] <- b[["est"]]
        sc[[paste0(key, "_se")]] <- b[["se"]]
        sc[[paste0(key, "_se_state")]] <- bs[["se"]]
    }
}
for (z in 1:3) {
    sc[[paste0("wz_n_mh_claims_z", z)]] <- dt[mh == 1L & wind_zone == z, .N]
    sc[[paste0("wz_n_counties_z", z)]] <- dt[wind_zone == z, uniqueN(countyfp)]
    sc[[paste0("wz_n_states_z", z)]] <- dt[wind_zone == z, uniqueN(statefp)]
}
write_nfip_scalars(sc, "windzone")
