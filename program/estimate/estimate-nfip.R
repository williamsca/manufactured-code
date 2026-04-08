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
# Pass as first positional argument: Rscript estimate-nfip.R 3
args <- commandArgs(trailingOnly = TRUE)
BIN_CONSTR_YEAR <- if (length(args) >= 1L) as.integer(args[1L]) else 2L

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
    "building_damage" = "Building damage (000s)",
    "net_building_pmt" = "Net building payment (000s)",
    "contents_damage" = "Contents damage (000s)",
    "net_contents_pmt" = "Net contents payment (000s)",
    "claim_rate" = "Claims per policy",
    "repl_cost_ppol" = "Replacement cost per policy",
    "policy_cost_ppol" = "Policy cost per policy",
    "building_policy_covg_ppol" = "Building coverage per policy",
    "contents_policy_covg_ppol" = "Contents coverage per policy",
    "elevated_share" = "Elevated building share",
    "sfha_share" = "SFHA share",
    "primary_res_share" = "Primary residence share",
    "mandatory_purchase_share" = "Mandatory purchase share",
    "building_damage_share" = "Building damage share of assessed value (%)",
    "net_building_pmt_share" = "Building payment share (%)",
    "mh_claim_share" = "MH share of claims",
    "mh_policy_share" = "MH share of policies"
)

setFixest_dict(v_dict, reset = TRUE)
dir.create(
    here("output", "event-study"), showWarnings = FALSE, recursive = TRUE)

# ---------------------------------------------------------------------------
# data construction ----
# ---------------------------------------------------------------------------

# --- balanced panel ---
dt <- readRDS(here("derived", "nfip-balanced.Rds"))
dt <- dt[between(year_constr, 1985L, 2000L)]
dt[, period_constr := bin_constr(year_constr, BIN_CONSTR_YEAR)]

# MH-share panel: annual year_constr resolution (for RDD / annual ES)
dt_share_cell <- dt[
    !is.na(policies_n) & policies_n > 0L,
    .(claims_n      = sum(claims_n,               na.rm = TRUE),
      policies_n    = sum(policies_n,             na.rm = TRUE),
      mh_claims_n   = sum(claims_n  * (mh == 1L), na.rm = TRUE),
      mh_policies_n = sum(policies_n * (mh == 1L), na.rm = TRUE)),
    by = .(tractfp, period_loss, year_constr, treated, post1994)]
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
           "primary_res_policy_n", "mandatory_purchase_policy_n")

dt_cell <- dt[
    !is.na(policies_n) & policies_n > 0L,
    lapply(.SD, sum, na.rm = TRUE),
    by = .(tractfp, period_loss, mh, period_constr),
    .SDcols = v_raw]

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
dt_cell[, repl_cost_ppol := fifelse(
    policies_n > 0L, repl_cost_tot / policies_n, NA_real_)]
dt_cell[, policy_cost_ppol := fifelse(
    policies_n > 0L, policy_cost_tot / policies_n, NA_real_)]
dt_cell[, building_policy_covg_ppol := fifelse(
    policies_n > 0L, building_policy_covg_tot / policies_n, NA_real_)]
dt_cell[, contents_policy_covg_ppol := fifelse(
    policies_n > 0L, contents_policy_covg_tot / policies_n, NA_real_)]
dt_cell[, elevated_share := fifelse(
    policies_n > 0L, elevated_policy_n / policies_n, NA_real_)]
dt_cell[, sfha_share := fifelse(
    policies_n > 0L, sfha_policy_n / policies_n, NA_real_)]
dt_cell[, primary_res_share := fifelse(
    policies_n > 0L, primary_res_policy_n / policies_n, NA_real_)]
dt_cell[, mandatory_purchase_share := fifelse(
    policies_n > 0L, mandatory_purchase_policy_n / policies_n, NA_real_)]

# claim rate
dt_cell[, claim_rate := fifelse(
    policies_n > 0L, claims_n / policies_n, NA_real_)]
dt_cell[, post_mh := as.integer(period_constr >= 1994L) * mh]

# Poisson panel: aggregate all cells (including zero-policy) to period_constr
dt_pois <- dt[, .(claims_n   = sum(claims_n,   na.rm = TRUE),
                  policies_n = sum(policies_n, na.rm = TRUE)),
    by = .(tractfp, period_loss, mh, period_constr)]

# --- claim-level data ---
dt_claims <- readRDS(here("derived", "nfip-claims.Rds"))
dt_claims <- dt_claims[between(year_constr, 1985, 2000) & year_loss >= 1994]
dt_claims[, period_loss   := ((year_loss - 1994L) %/% 5L) * 5L + 1994L]
dt_claims[, period_constr := bin_constr(year_constr, BIN_CONSTR_YEAR)]
dt_claims[, post1994      := as.integer(year_constr >= 1994L)]

v_shares <- c("building_damage", "net_building_pmt")
v_shares_names <- paste0(v_shares, "_share")
dt_claims[, (v_shares_names) := lapply(
    .SD, function(x) 100 * x / building_value), .SDcols = v_shares]

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
    ", repl_cost_ppol, policy_cost_ppol",
    ", building_policy_covg_ppol, contents_policy_covg_ppol",
    ", elevated_share, sfha_share, primary_res_share, mandatory_purchase_share",
    ", building_damage_share, net_building_pmt_share",
    ")")

v_poly <- c("poly(year_constr, 1)*post1994")
s_poly <- paste(v_poly, collapse = " + ")

# ---------------------------------------------------------------------------
# difference-in-discontinuities ----
# ---------------------------------------------------------------------------
# Running variable: construction year centered at 1994 cutoff
dt_claims[, v := year_constr - 1994L]
dt_claims[, post94 := as.integer(year_constr >= 1994L)]

# Piecewise-linear slopes: separate on each side of cutoff
dt_claims[, v_pre  := v * (1L - post94)]
dt_claims[, v_post := v * post94]

# Diff-in-disc: claim-level, county × loss-year FEs
# Linear polynomial, type-specific, separate on each side
fmla_dd <- as.formula(paste0(
    s_claim,
    " ~ post94 + post94:mh",
    " + v_pre + v_post + v_pre:mh + v_post:mh",
    " | tractfp^period_loss + mh"
))

est_dd <- feols(fmla_dd, data = dt_claims, lean = TRUE)
etable(est_dd, fitstat = c("n", "r2", "wr2", "my"),
       keep = "post94")

# Quadratic robustness
dt_claims[, v2_pre  := v^2 * (1L - post94)]
dt_claims[, v2_post := v^2 * post94]

fmla_dd_q <- as.formula(paste0(
    s_claim,
    " ~ post94 + post94:mh",
    " + v_pre + v_post + v_pre:mh + v_post:mh",
    " + v2_pre + v2_post + v2_pre:mh + v2_post:mh",
    " | tractfp^period_loss + mh"
))

est_dd_q <- feols(fmla_dd_q, data = dt_claims, lean = TRUE)
etable(est_dd_q, fitstat = c("n", "r2", "wr2", "my"),
       keep = "post94")

# event studies ----
# claim-level event study
fmla_claim_es <- as.formula(paste0(
    s_claim, " ~ i(period_constr, mh, ref = ref_period)",
    " | sw(tractfp^year_loss) + mh"
))

est_claim_es <- feols(fmla_claim_es, data = dt_claims, lean = TRUE)
etable(est_claim_es, fitstat = c("n", "r2", "wr2", "my"))
iplot(est_claim_es[lhs = "building_pmt$"])

# cell-level event study (aggregated to period_constr bins)
fmla_pclaim_es <- as.formula(paste0(
    s_pclaim, " ~ i(period_constr, mh, ref = ref_period)",
    " | tractfp^period_loss + mh")
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
    " | tractfp^period_loss + mh"
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
    file = here("output", "event-study", "policy-composition.tex"),
    fitstat = c("n", "r2", "wr2", "my"),
    # keep = "post_mh",
    digits = 3, replace = TRUE
)

# MH share event study
# RDD
fmla_share_rd <- as.formula(paste0(
    "c(mh_claim_share, mh_policy_share)", " ~ ",
    s_poly, " | ", "tractfp^period_loss"
))

est_share_rd <- feols(
    fmla_share_rd, data = dt_share_cell,
    weights = ~policies_n, lean = TRUE
)
etable(est_share_rd, fitstat = c("n", "r2", "wr2", "my"))

# event study

fmla_share_es <- as.formula(paste0(
    "c(mh_claim_share, mh_policy_share)", " ~ ",
    "i(year_constr, ref = 1993)",
    " | ", "tractfp^period_loss"
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
    " | tractfp^period_loss + mh"
))

est_pois_es <- fepois(
    fmla_out_es, data = dt_pois,
    lean = TRUE
)
etable(est_pois_es)

# static ----

# plots ----
v_palette <- c("#0072B2", "#D55E00", "#009E73", "#F0E442")

theme_paper <- function(base_size = 14) {
    theme_classic(base_size = base_size) +
        theme(
            text = element_text(family = "serif"),
            legend.position = "right"
        )
}

# Plot an event study from a fixest model estimated with i(period_constr, mh, ref = ref_period).
# Extracts interaction terms (:mh), appends a zero row at the reference period,
# and draws point estimates with 95% CI ribbon.
plot_es <- function(est, outcome = NULL, vline_x = 1992.5, path = NULL, var = "mh",
                    yscale = 1) {
    # [[]] extracts a single fixest object; [lhs=] returns fixest_multi,
    # whose coeftable() output has a different structure
    if (!is.null(outcome)) est <- est[lhs = outcome][[1]]
    ylab <- if (!is.null(outcome) && outcome %in% names(v_dict)) {
        unname(v_dict[[outcome]])
    } else {
        outcome
    }

    ct <- as.data.table(coeftable(est), keep.rownames = TRUE)
    # i(period_constr, mh) coefficients are named "period_constr::YYYY:mh"
    # i(period_constr) main effects are named "period_constr::YYYY"
    if (is.null(var)) {
        idx <- grepl("^period_constr::\\d{4}$", ct$rn)
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
                   ci_low = 0, ci_high = 0, period = ref_period)
    )
    setorder(dt_es, period)

    p <- ggplot(dt_es, aes(x = period, y = est)) +
        geom_ribbon(aes(ymin = ci_low, ymax = ci_high),
                    alpha = 0.2, fill = v_palette[1]) +
        geom_point(color = v_palette[1], size = 2) +
        geom_line(color = v_palette[1]) +
        geom_vline(xintercept = vline_x, linetype = "dotted", color = "black") +
        geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
        scale_x_continuous(breaks = dt_es$period) +
        labs(x = "Construction period", y = ylab) +
        theme_paper()

    if (!is.null(path)) ggsave(path, p, width = 9, height = 5)
    p
}

plot_es(est_claim_es, "net_building_pmt", yscale = 1000,
        path = here("output", "event-study", "es-net-building-pmt.pdf"))

plot_es(est_claim_es, "net_contents_pmt", yscale = 1000,
        path = here("output", "event-study", "es-net-contents-pmt.pdf"))

plot_es(est_pclaim_es, "claim_rate",
        path = here("output", "event-study", "es-claim-rate.pdf"))

plot_es(est_pois_es, "policies_n",
        path = here("output", "event-study", "es-policies.pdf"))