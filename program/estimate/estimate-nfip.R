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

# ---------------------------------------------------------------------------
# parameters ----
# ---------------------------------------------------------------------------
# BIN_CONSTR_YEAR: width of construction-year bins.
#   1993 is always the right-end of the last pre-treatment bin, so that the
#   HUD 1994 cutoff falls cleanly at a bin boundary.
#     N=1 → annual (no binning); ref period = 1993
#     N=2 → 1992-1993, 1994-1995, ...;  ref period = 1992
#     N=3 → 1991-1993, 1994-1996, ...;  ref period = 1991
# Pass as positional arguments: Rscript estimate-nfip.R 3 countyfp
# You can also omit the bin width and pass only the geography:
#   Rscript estimate-nfip.R tractfp
args <- commandArgs(trailingOnly = TRUE)
bin_arg <- args[grepl("^[0-9]+$", args)][1L]
geo_arg <- args[args %in% c("countyfp", "tractfp")][1L]
BIN_CONSTR_YEAR <- if (!is.na(bin_arg)) as.integer(bin_arg) else 2L
agg_geo <- if (!is.na(geo_arg)) geo_arg else "countyfp"

MIN_YEAR <- 1986L
MAX_YEAR <- 1999L

if (!agg_geo %in% c("countyfp", "tractfp")) {
    stop("agg_geo must be one of 'countyfp' or 'tractfp'.")
}
geo_label <- c(
    "countyfp" = "County",
    "tractfp" = "Census tract"
)[[agg_geo]]
out_dir <- here("output", "event-study", agg_geo)

# bin construction years: bins are anchored so 1993 is always the right-end
# of the last pre-treatment bin; each bin is labeled by its left-end year.
bin_constr <- function(y, N) {
    ifelse(
        y <= 1993L,
        1994L - N  - ((1993L - y) %/% N) * N,
        1994L      + ((y - 1994L) %/% N) * N
    )
}
ref_period <- 1994L - BIN_CONSTR_YEAR

v_dict <- c(
    "claims_n" = "Claims (#)",
    "policies_n" = "Policies (#)",
    "building_damage" = "Building damage",
    "net_building_pmt" = "Net building pmt.",
    "contents_damage" = "Contents damage",
    "net_contents_pmt" = "Net contents pmt.",
    "claim_rate" = "Claims per policy",
    "repl_cost_ppol" = "Repl. cost",
    "policy_cost_ppol" = "Policy cost per policy",
    "building_policy_covg_ppol" = "Bldg covg.",
    "contents_policy_covg_ppol" = "Contents covg.",
    "elevated_share" = "Elevated",
    "sfha_share" = "SFHA",
    "primary_res_share" = "Primary res.",
    "mandatory_purchase_share" = "Mandatory",
    "policies_ppermit" = "Policies per SF permit",
    "building_damage_share" = "Bldg. dmg. share (%)",
    "net_building_pmt_share" = "Bldg. pmt. share (%)",
    "contents_damage_share" = "Contents dmg. share (%)",
    "net_contents_pmt_share" = "Contents pmt. share (%)",
    "mh_claim_share" = "MH share of claims",
    "mh_policy_share" = "MH share of policies",
    "geo" = geo_label,
    "countyfp" = "County",
    "tractfp" = "Census tract",
    "period_loss" = "Loss period",
    "mh" = "MH",
    "period_constr" = "$\\nu_i$"
)

setFixest_dict(v_dict, reset = TRUE)
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---------------------------------------------------------------------------
# data construction ----
# ---------------------------------------------------------------------------

# --- balanced panel ---
dt <- readRDS(here("derived", "nfip-balanced.Rds"))
dt <- dt[between(year_constr, MIN_YEAR, MAX_YEAR)]
dt[, geo := get(agg_geo)]
dt[, period_constr := bin_constr(year_constr, BIN_CONSTR_YEAR)]

# MH-share panel at the requested aggregation geography
dt_share_cell <- dt[
    !is.na(policies_n) & policies_n > 0L,
    .(claims_n      = sum(claims_n,               na.rm = TRUE),
      policies_n    = sum(policies_n,             na.rm = TRUE),
      mh_claims_n   = sum(claims_n  * (mh == 1L), na.rm = TRUE),
      mh_policies_n = sum(policies_n * (mh == 1L), na.rm = TRUE)),
    by = .(geo, period_loss, period_constr, treated, post1994)]
dt_share_cell[, mh_claim_share  := mh_claims_n  / claims_n]
dt_share_cell[, mh_policy_share := mh_policies_n / policies_n]

# aggregate balanced panel to period_constr bins (cell-level ES)
v_raw <- c("claims_n", "policies_n",
           "net_building_pmt_tot", "building_damage_tot", "building_value_tot",
           "contents_value_tot", "net_contents_pmt_tot", "contents_damage_tot",
           "building_covg_tot", "contents_covg_tot",
           "repl_cost_tot", "policy_cost_tot",
           "building_policy_covg_tot", "contents_policy_covg_tot",
           "elevated_policy_n", "sfha_policy_n",
           "primary_res_policy_n", "mandatory_purchase_policy_n",
           "permits_sf_n")

dt_cell <- dt[
    !is.na(policies_n) & policies_n > 0L,
    lapply(.SD, sum, na.rm = TRUE),
    by = .(geo, period_loss, mh, period_constr),
    .SDcols = v_raw]

dt_cell[, post1994 := as.integer(period_constr >= 1994L)]

# per-claim averages
v_clm_tot <- c("net_building_pmt_tot", "building_damage_tot",
               "building_value_tot", "contents_value_tot",
               "net_contents_pmt_tot", "contents_damage_tot",
               "building_covg_tot", "contents_covg_tot")
v_clm_avg <- gsub("_tot$", "_pclaim", v_clm_tot)
dt_cell[, (v_clm_avg) := lapply(
    .SD, function(x) fifelse(claims_n > 0L, x / claims_n, NA_real_)),
    .SDcols = v_clm_tot]

# damage shares
dt_cell[, building_damage_share := fifelse(
    building_value_tot > 0, 100 * building_damage_tot / building_value_tot,
    NA_real_)]
dt_cell[, net_building_pmt_share := fifelse(
    building_value_tot > 0, 100 * net_building_pmt_tot / building_value_tot,
    NA_real_)]

# per-policy averages
v_ppol_tot <- c(
    "repl_cost_tot", "policy_cost_tot",
    "building_policy_covg_tot", "contents_policy_covg_tot",
    "elevated_policy_n", "sfha_policy_n", "primary_res_policy_n",
    "mandatory_purchase_policy_n", "net_building_pmt_tot",
    "net_contents_pmt_tot")
v_ppol <- gsub("_tot$", "_ppol", v_ppol_tot)
v_ppol <- gsub("_policy_n$", "_share", v_ppol)
dt_cell[, (v_ppol) := lapply(
    .SD, function(x) fifelse(policies_n > 0L, x / policies_n, NA_real_)),
    .SDcols = v_ppol_tot]

# claim rate
dt_cell[, claim_rate := fifelse(
    policies_n > 0L, claims_n / policies_n, NA_real_)]

# policies per SF permit
dt_cell[, policies_ppermit := fifelse(
    !is.na(permits_sf_n) & permits_sf_n > 0, policies_n /
    permits_sf_n, NA_real_)]
dt_cell[, post_mh := as.integer(period_constr >= 1994L) * mh]

dt_cell[, net_building_pmt_tot_ln := log(net_building_pmt_tot)]

# Poisson panel: aggregate all cells (including zero-policy) to period_constr
dt_pois <- dt[, .(claims_n   = sum(claims_n,   na.rm = TRUE),
                  policies_n = sum(policies_n, na.rm = TRUE)),
    by = .(geo, period_loss, mh, period_constr)]

# --- claim-level data ---
dt_claims <- readRDS(here("derived", "nfip-claims.Rds"))
dt_claims <- dt_claims[
    between(year_constr, MIN_YEAR, MAX_YEAR) & year_loss >= 1994]
dt_claims[, geo := get(agg_geo)]
dt_claims[, period_loss   := ((year_loss - 1994L) %/% 5L) * 5L + 1994L]
dt_claims[, period_constr := bin_constr(year_constr, BIN_CONSTR_YEAR)]
dt_claims[, post1994      := as.integer(year_constr >= 1994L)]

v_shares <- c("building_damage", "net_building_pmt")
v_shares_names <- paste0(v_shares, "_share")
dt_claims[, (v_shares_names) := lapply(
    .SD, function(x) 100 * x / building_value), .SDcols = v_shares]

# covariate prep for robustness specs
dt_claims[, log_repl_cost := fifelse(
    !is.na(building_repl_cost) & building_repl_cost > 0,
    log(building_repl_cost), NA_real_)]
dt_claims[, occupancy_type := factor(occupancy_type)]

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

# outcome names for cell-level ES
v_pclaim <- grep("_share$", v_claim, invert = TRUE, value = TRUE)
v_pclaim <- paste0(v_pclaim, "_pclaim")
s_pclaim <- paste0(
    "c(", paste0(v_pclaim, collapse = ", "),
    ", claim_rate",
    ", ", paste0(v_ppol, collapse = ", "),
    ")")

# event studies ----
# claim-level event study
fmla_claim_es <- as.formula(paste0(
    s_claim, " ~ i(period_constr, mh, ref = ref_period)",
    " | geo^period_loss + mh"
))

est_claim_es <- feols(fmla_claim_es, data = dt_claims)
etable(est_claim_es, fitstat = c("n", "r2", "wr2", "my"))
iplot(est_claim_es[lhs = "building_pmt$"])

v_alt <- c(
    "building_damage$", "net_building_pmt$", "building_damage_share",
    "contents_damage$", "net_contents_pmt$")

etable(est_claim_es[lhs = v_alt], fitstat = c("n", "r2", "wr2", "my"))

etable(
    est_claim_es[lhs = v_alt],
    tex = TRUE,
    file = file.path(out_dir, "claims-outcomes.tex"),
    fitstat = c("n", "r2", "my"),
    digits = 2, digits.stats = 2, replace = TRUE
)

# cell-level event study (aggregated to period_constr bins)
fmla_pclaim_es <- as.formula(paste0(
    s_pclaim, " ~ i(period_constr, mh, ref = ref_period)",
    " | geo^period_loss + mh")
)

est_pclaim_es <- feols(
    fmla_pclaim_es, data = dt_cell,
    weights = ~policies_n,
    lean = TRUE)
etable(est_pclaim_es, fitstat = c("n", "r2", "wr2", "my"))

iplot(est_pclaim_es[lhs = "claim_rate"])

# policy composition summary table
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

fmla_comp_post <- as.formula(paste0(
    s_comp, " ~ i(period_constr, mh, ref = ref_period)",
    " | geo^period_loss + mh"
))

est_comp_post <- feols(
    fmla_comp_post, data = dt_cell,
    weights = ~policies_n,
    lean = TRUE
)
etable(est_comp_post, fitstat = c("n", "r2", "wr2", "my"))


etable(
    est_comp_post,
    tex = TRUE,
    file = file.path(out_dir, "policy-composition.tex"),
    fitstat = c("n", "r2", "my"),
    # keep = "post_mh",
    digits = 1, digits.stats = 2, replace = TRUE
)

# MH share event study

# event study

fmla_share_es <- as.formula(paste0(
    "c(mh_claim_share, mh_policy_share)", " ~ ",
    "i(period_constr, ref = ref_period)",
    " | ", "geo^period_loss"
))

est_share_es <- feols(
    fmla_share_es, data = dt_share_cell,
    weights = ~policies_n, lean = TRUE
)

etable(est_share_es, fitstat = c("n", "r2", "wr2", "my"))

iplot(est_share_es)

# count event study (Poisson)
v_out <- c("claims_n", "policies_n")
s_out <- paste0("c(", paste0(v_out, collapse = ", "), ")")

fmla_out_es <- as.formula(paste0(
    s_out, " ~ i(period_constr, mh, ref = ref_period)",
    " | geo^period_loss + mh"
))

est_pois_es <- fepois(
    fmla_out_es, data = dt_pois,
    lean = TRUE
)
etable(est_pois_es)

iplot(est_pois_es)

# ---------------------------------------------------------------------------
# covariate-controlled robustness: building damage ----
# ---------------------------------------------------------------------------
# Progressively add covariates to assess whether composition changes in the
# insured pool drive the main result. Using building_damage (not net payment)
# to avoid any confounding from deductible changes across vintages.
# FEs vary with agg_geo so the full script runs at a consistent geography.

fmla_rob_a <- building_damage ~
    i(period_constr, mh, ref = ref_period) |
    geo^period_loss + mh

fmla_rob_b <- building_damage ~
    i(period_constr, mh, ref = ref_period) + water_depth |
    geo^period_loss + mh

fmla_rob_c <- building_damage ~
    i(period_constr, mh, ref = ref_period) +
    water_depth + elevated + sfha |
    geo^period_loss + mh

fmla_rob_d <- building_damage ~
    i(period_constr, mh, ref = ref_period) +
    water_depth + elevated + sfha + primary_res |
    geo^period_loss + mh + occupancy_type

est_rob_list <- list(
    "Baseline"          = feols(fmla_rob_a, data = dt_claims, lean = TRUE),
    "+ Water depth"     = feols(fmla_rob_b, data = dt_claims, lean = TRUE),
    "+ Flood controls"  = feols(fmla_rob_c, data = dt_claims, lean = TRUE),
    "+ Demographics"    = feols(fmla_rob_d, data = dt_claims, lean = TRUE)
)

etable(est_rob_list)

# geographic robustness: county vs. tract FEs ----
# Compare baseline county-level controls with census-tract-level controls.
# Both columns use the same interaction specification; only the geographic
# granularity of the location × loss-period fixed effect varies.
fmla_geo_rob <- building_damage ~
    i(period_constr, mh, ref = ref_period) |
    sw(countyfp^period_loss, tractfp^period_loss) + mh

est_geo_rob <- feols(fmla_geo_rob, data = dt_claims, lean = TRUE)

etable(est_geo_rob)

etable(
    est_geo_rob,
    tex = TRUE,
    file = here("output", "event-study", "countyfp", "geo-robustness.tex"),
    fitstat = c("n", "r2", "my"),
    digits = 2, digits.stats = 2, replace = TRUE,
    headers = c("County FE", "Census tract FE")
)

# static ----

# plots ----
v_palette <- c("#0072B2", "#D55E00", "#009E73", "#F0E442")

theme_paper <- function(base_size = 14) {
    theme_classic(base_size = base_size) +
        theme(
            text = element_text(family = "serif"),
            legend.position = "right",
            panel.grid.major.y = element_line(color = "gray85", linewidth = 0.4),
            panel.grid.minor.y = element_blank()
        )
}

# Plot an event study from a fixest model estimated with i(period_constr, mh, ref = ref_period).
# Extracts interaction terms (:mh), appends a zero row at the reference period,
# and draws point estimates with 95% CI ribbon.
plot_es <- function(est, outcome = NULL, vline_x = 1992.5, path = NULL, var = "mh",
                    yscale = 1, ref = ref_period) {
    # [[]] extracts a single fixest object; [lhs=] returns fixest_multi,
    # whose coeftable() output has a different structure
    if (!is.null(outcome)) est <- est[lhs = outcome][[1]]
    ylab <- if (!is.null(outcome) && outcome %in% names(v_dict)) {
        unname(v_dict[[outcome]])
    } else {
        outcome
    }
    if (ylab %in% c("Building damage")) ylab <- paste0(ylab, " (000s)")

    ct <- as.data.table(coeftable(est), keep.rownames = TRUE)
    # i(period_constr, mh) coefficients are named "period_constr::YYYY:mh"
    # i(year_constr) main effects are named "year_constr::YYYY"
    if (is.null(var)) {
        idx <- grepl("^[a-z_]+::\\d{4}$", ct$rn)
    } else {
        idx <- grepl(paste0(":", var, "$"), ct$rn)
    }
    dt_es <- data.table(
        term    = ct$rn[idx],
        est     = ct$Estimate[idx] / yscale,
        se      = ct[["Std. Error"]][idx] / yscale
    )
    dt_es[, period  := as.integer(regmatches(term, regexpr("[0-9]{4}", term)))]
    dt_es[, ci_low  := est - 1.96 * se]
    dt_es[, ci_high := est + 1.96 * se]

    # append reference period normalized to zero
    dt_es <- rbind(
        dt_es,
        data.table(term = NA_character_, est = 0, se = 0,
                   ci_low = 0, ci_high = 0, period = ref)
    )
    setorder(dt_es, period)

    p <- ggplot(dt_es, aes(x = period, y = est)) +
        geom_ribbon(aes(ymin = ci_low, ymax = ci_high),
                    alpha = 0.2, fill = v_palette[1]) +
        geom_point(color = v_palette[1], size = 2) +
        geom_line(color = v_palette[1]) +
        geom_vline(xintercept = vline_x, linetype = "dotted", color = "black") +
        scale_x_continuous(breaks = dt_es$period) +
        labs(x = "Construction period", y = ylab) +
        theme_paper()

    if (!is.null(path)) ggsave(path, p, width = 9, height = 5)
    p
}

# Overlay event studies from a named list of single-LHS fixest objects.
# Each model must be estimated with i(period_constr, mh, ref = ref_period).
plot_es_multi <- function(est_list, vline_x = 1992.5, path = NULL,
                           yscale = 1, ref = ref_period,
                           ylab = "Building damage (000s)") {
    dt_all <- rbindlist(lapply(names(est_list), function(nm) {
        ct <- as.data.table(coeftable(est_list[[nm]]), keep.rownames = TRUE)
        idx <- grepl(":mh$", ct$rn)
        dt <- data.table(
            spec    = nm,
            term    = ct$rn[idx],
            est     = ct$Estimate[idx] / yscale,
            se      = ct[["Std. Error"]][idx] / yscale
        )
        dt[, period  := as.integer(regmatches(term, regexpr("[0-9]{4}", term)))]
        dt[, ci_low  := est - 1.96 * se]
        dt[, ci_high := est + 1.96 * se]
        rbind(dt, data.table(spec = nm, term = NA_character_,
                             est = 0, se = 0, ci_low = 0, ci_high = 0,
                             period = ref))
    }))
    setorder(dt_all, spec, period)
    dt_all[, spec := factor(spec, levels = names(est_list))]

    n <- length(est_list)
    shapes <- c(16, 17, 15, 18)[seq_len(n)]

    p <- ggplot(dt_all, aes(x = period, y = est,
                             color = spec, fill = spec, shape = spec)) +
        geom_ribbon(aes(ymin = ci_low, ymax = ci_high),
                    alpha = 0.10, color = NA) +
        geom_line() +
        geom_point(size = 2) +
        geom_vline(xintercept = vline_x, linetype = "dotted", color = "black") +
        geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
        scale_x_continuous(breaks = sort(unique(dt_all$period))) +
        scale_color_manual(values = v_palette[seq_len(n)]) +
        scale_fill_manual(values  = v_palette[seq_len(n)]) +
        scale_shape_manual(values = shapes) +
        labs(x = "Construction period", y = ylab,
             color = NULL, fill = NULL, shape = NULL) +
        theme_paper() +
        theme(legend.position = "bottom")

    if (!is.null(path)) ggsave(path, p, width = 9, height = 5)
    p
}

plot_es_multi(
    est_rob_list,
    path = file.path(out_dir, "es-building-damage-robust.pdf"))

plot_es(est_claim_es, "net_building_pmt",
        path = file.path(out_dir, "es-net-building-pmt.pdf"))

plot_es(est_claim_es, "building_damage",
        path = file.path(out_dir, "es-building-damage.pdf"))

plot_es(est_claim_es, "net_contents_pmt",
        path = file.path(out_dir, "es-net-contents-pmt.pdf"))

plot_es(est_claim_es, "building_damage_share",
        path = file.path(out_dir, "es-building-damage-share.pdf"))

plot_es(est_pclaim_es, "claim_rate",
        path = file.path(out_dir, "es-claim-rate.pdf"))

plot_es(est_pois_es, "policies_n",
        path = file.path(out_dir, "es-policies.pdf"))

plot_es(est_share_es, "mh_claim_share", var = NULL, ref = ref_period,
        vline_x = 1993.5,
        path = file.path(out_dir, "es-mh-claim-share.pdf"))

plot_es(est_share_es, "mh_policy_share", var = NULL, ref = ref_period,
        vline_x = 1993.5,
        path = file.path(out_dir, "es-mh-policy-share.pdf"))
