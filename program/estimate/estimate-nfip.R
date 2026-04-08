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
    "building_damage_share" = "Building damage share of assessed value (%)",
    "net_building_pmt_share" = "Building payment share (%)",
    "mh_claim_share" = "MH share of claims",
    "mh_policy_share" = "MH share of policies"
)

setFixest_dict(v_dict, reset = TRUE)

# import ----
dt <- readRDS(here("derived", "nfip-balanced.Rds"))

dt[, period_constr := bin_constr(year_constr, BIN_CONSTR_YEAR)]
dt[, treated_mh := (mh == 1) & treated == TRUE]
dt[, post_mh := post1994 * mh]

# claim-level data
dt_claims <- readRDS(here("derived", "nfip-claims.Rds"))
dt_claims <- dt_claims[between(year_constr, 1985, 2002) & year_loss >= 1994]
dt_claims[, period_loss   := ((year_loss - 1994L) %/% 5L) * 5L + 1994L]
dt_claims[, period_constr := bin_constr(year_constr, BIN_CONSTR_YEAR)]
dt_claims[, post1994      := as.integer(year_constr >= 1994L)]

v_shares <- c("building_damage", "net_building_pmt")
v_shares_names <- paste0(v_shares, "_share")
dt_claims[, (v_shares_names) := lapply(
    .SD, function(x) 100 * x / building_value), .SDcols = v_shares]

v_shares_contents <- c("contents_value", "net_contents_pmt")
v_shares_contents_names <- paste0(v_shares_contents, "_share")
dt_claims[, (v_shares_contents_names) := lapply(
    .SD, function(x) 100 * x / contents_value), .SDcols = v_shares_contents
]

v_claim <- c(
    "building_damage", "net_building_pmt",
    "contents_damage", "net_contents_pmt",
    "building_damage_share", "net_building_pmt_share",
    "contents_value_share", "net_contents_pmt_share"
)
s_claim <- paste0("c(", paste0(v_claim, collapse = ", "), ")")

# event studies ----
# claim-level event study
fmla_claim_es <- as.formula(paste0(
    s_claim, " ~ i(period_constr, mh, ref = ref_period)",
    " | sw(tractfp, tractfp^period_loss) + mh"
))

est_claim_es <- feols(fmla_claim_es, data = dt_claims, lean = TRUE)
etable(est_claim_es, fitstat = c("n", "r2", "wr2", "my"))
iplot(est_claim_es[lhs = "building_pmt$"])

# cell-level event study
dt_claims_cell <- dt[
    !is.na(policies_n) & policies_n > 0L &
    between(year_constr, 1985L, 2002L)]
dt_claims_cell[, treated_mh := (mh == 1) & treated == TRUE]

v_pclaim <- grep("_share$", v_claim, invert = TRUE, value = TRUE)
v_pclaim <- paste0(v_pclaim, "_pclaim")
s_pclaim <- paste0(
    "c(", paste0(v_pclaim, collapse = ", "),
    ", claim_rate, repl_cost_ppol, policy_cost_ppol, building_damage_share, net_building_pmt_share",
    ")")

fmla_pclaim_es <- as.formula(paste0(
    s_pclaim, " ~ i(period_constr, mh, ref = ref_period)",
    " | tractfp^period_loss + mh")
)

est_pclaim_es <- feols(
    fmla_pclaim_es, data = dt_claims_cell,
    weights = ~policies_n,
    lean = TRUE)
etable(est_pclaim_es, fitstat = c("n", "r2", "wr2", "my"))

iplot(est_pclaim_es[lhs = "claim_rate"])

# MH share event study
dt_share_cell <- dt_claims_cell[, .(
    claims_n      = sum(claims_n,               na.rm = TRUE),
    policies_n    = sum(policies_n,             na.rm = TRUE),
    mh_claims_n   = sum(claims_n  * (mh == 1L), na.rm = TRUE),
    mh_policies_n = sum(policies_n * (mh == 1L), na.rm = TRUE))
, by = .(tractfp, period_loss, period_constr, treated)]

dt_share_cell[, mh_claim_share  := mh_claims_n  / claims_n]
dt_share_cell[, mh_policy_share := mh_policies_n / policies_n]

fmla_share_es <- as.formula(
    "c(mh_claim_share, mh_policy_share) ~ i(period_constr, ref = ref_period) | tractfp^period_loss"
)

est_share_es <- feols(
    fmla_share_es, data = dt_share_cell,
    weights = ~claims_n, lean = TRUE
)
etable(est_share_es, fitstat = c("n", "r2", "wr2", "my"))

iplot(est_share_es)

# count event study (Poisson)
v_out <- c("claims_n", "policies_n")
s_out <- paste0("c(", paste0(v_out, collapse = ", "), ")")

fmla_out_es <- as.formula(paste0(
    s_out, " ~ i(period_constr, mh, ref = ref_period)",
    " | tractfp^period_loss + mh^period_loss + mh^tractfp"
))

est_pois_es <- fepois(
    fmla_out_es, data = dt,
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
                   ci_low = 0, ci_high = 0, period = 1991L)
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

dir.create(
    here("output", "event-study"), showWarnings = FALSE, recursive = TRUE)

plot_es(est_claim_es, "net_building_pmt", yscale = 1000,
        path = here("output", "event-study", "es-net-building-pmt.pdf"))

plot_es(est_claim_es, "net_contents_pmt", yscale = 1000,
        path = here("output", "event-study", "es-net-contents-pmt.pdf"))

plot_es(est_pclaim_es, "claim_rate",
        path = here("output", "event-study", "es-claim-rate.pdf"))

plot_es(est_pois_es, "policies_n",
        path = here("output", "event-study", "es-policies.pdf"))

plot_es(est_share_es, "mh_claim_share",  var = NULL,
        path = here("output", "event-study", "es-mh-claim-share.pdf"))

plot_es(est_share_es, "mh_policy_share", var = NULL,
        path = here("output", "event-study", "es-mh-policy-share.pdf"))
