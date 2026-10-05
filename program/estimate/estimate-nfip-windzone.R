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
# vintage x zone are free, and county x loss-year FE nest the zone. Writes
# output/results/nfip-windzone-scalars.csv.
#
# Usage: Rscript estimate-nfip-windzone.R [bin width] [countyfp|tractfp]

rm(list = ls())
library(here)
BIN_CONSTR_DEFAULT <- 1L
source(here("program", "lib", "nfip-setup.R"))
source(here("program", "lib", "nfip-claims-sample.R"))
source(here("program", "lib", "plot-es.R"))

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
fe_zone_es <- " | geo^year_loss + mh^wind_zone + period_constr^wind_zone"

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

etable(
    est_wz_did,
    tex = TRUE, se.below = FALSE,
    file = file.path(out_dir, "windzone-did.tex"),
    fitstat = c("n", "pr2"),
    digits = 3, digits.stats = 2, replace = TRUE
)
etable(
    est_wz_ddd,
    tex = TRUE, se.below = FALSE,
    file = file.path(out_dir, "windzone-ddd.tex"),
    fitstat = c("n", "pr2"),
    digits = 3, digits.stats = 2, replace = TRUE
)

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

# event studies ----
# Zone-specific profiles: each mh_z* x vintage set is that zone's own DiD
# event study, relative to its own reference bin.
est_wz_did_es <- fit(paste0(
    " ~ i(period_constr, mh_z1, ref = ref_period)",
    " + i(period_constr, mh_z2, ref = ref_period)",
    " + i(period_constr, mh_z3, ref = ref_period)", fe_zone_es))

# Triple-difference profiles: the mh x vintage set is Zone I's profile, and
# the mh_z2 / mh_z3 sets are each treated zone's profile net of Zone I's.
est_wz_ddd_es <- fit(paste0(
    " ~ i(period_constr, mh, ref = ref_period)",
    " + i(period_constr, mh_z2, ref = ref_period)",
    " + i(period_constr, mh_z3, ref = ref_period)", fe_zone_es))

est_wz_ddd_tr_es <- fit(paste0(
    " ~ i(period_constr, mh, ref = ref_period)",
    " + i(period_constr, mh_tr, ref = ref_period)",
    " | geo^year_loss + mh^treated + period_constr^treated"))

etable(est_wz_did_es[lhs = "^building_damage$"], fitstat = c("n", "pr2"))
etable(est_wz_ddd_es[lhs = "^building_damage$"],
       est_wz_ddd_tr_es[lhs = "^building_damage$"], fitstat = c("n", "pr2"))

# plots ----
es_panel <- function(est_multi, series) {
    rbindlist(lapply(v_loss, function(y) {
        e <- est_multi[lhs = paste0("^", y, "$")][[1]]
        rbindlist(lapply(names(series), function(nm) {
            es_coefs(e, series[[nm]])[, `:=`(series = nm, outcome = y)]
        }))
    }))
}

plot_es_panel <- function(dt_es, path) {
    dt_es[, series := factor(series, levels = unique(series))]
    dt_es[, outcome := factor(v_dict[outcome], levels = v_dict[v_loss])]
    n <- uniqueN(dt_es$series)
    pd <- position_dodge(width = 0.6)
    p <- ggplot(dt_es, aes(x = period, y = est, color = series,
                           shape = series)) +
        geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
        geom_vline(xintercept = vline_constr, linetype = "dotted", color = "black") +
        geom_pointrange(aes(ymin = ci_low, ymax = ci_high), position = pd,
                        size = 0.3) +
        geom_line(position = pd, alpha = 0.5) +
        facet_wrap(~outcome, ncol = 2) +
        scale_x_continuous(breaks = sort(unique(dt_es$period))) +
        scale_color_manual(values = v_palette[seq_len(n)]) +
        scale_shape_manual(values = c(16, 17, 15, 18)[seq_len(n)]) +
        labs(x = "Construction period", y = "Log points",
             color = NULL, shape = NULL) +
        theme_paper(base_size = 12) +
        theme(legend.position = "bottom",
              axis.text.x = element_text(angle = 45, hjust = 1))
    ggsave(path, p, width = 9, height = 7)
    p
}

dt_es_did <- es_panel(est_wz_did_es, c(
    "Zone I" = "mh_z1", "Zone II" = "mh_z2", "Zone III" = "mh_z3"))
plot_es_panel(dt_es_did, file.path(out_dir, "es-windzone-did.pdf"))

dt_es_ddd <- rbind(
    es_panel(est_wz_ddd_tr_es, c("Zones II-III vs. I" = "mh_tr")),
    es_panel(est_wz_ddd_es, c("Zone II vs. I" = "mh_z2",
                              "Zone III vs. I" = "mh_z3")))
plot_es_panel(dt_es_ddd, file.path(out_dir, "es-windzone-ddd.pdf"))

# Export key scalars ----
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
