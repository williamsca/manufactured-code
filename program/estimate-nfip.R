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

v_dict <- c(
    "claims_n" = "Claims (#)",
    "policies_n" = "Policies (#)",
    "building_damage" = "Building damage ($)",
    "net_building_pmt" = "Net building payment ($)",
    "contents_damage" = "Contents damage ($)",
    "net_contents_pmt" = "Net contents payment ($)",
    "claim_rate" = "Claims per policy",
    "building_damage_share" = "Building damage share of assessed value (%)",
    "building_pmt_share" = "Building payment share (%)"
)

setFixest_dict(v_dict, reset = TRUE)

# import ----
dt <- readRDS(here("derived", "nfip-balanced.Rds"))

dt[, treated_mh := (mh == 1) & treated == TRUE]
dt[, post_mh := post1994 * mh]

dt_treated <- unique(dt[, .(countyfp, treated)])

# claim-level data
dt_claims <- readRDS(here("derived", "nfip-claims.Rds"))
dt_claims <- dt_claims[between(year_constr, 1985, 2002) & year_loss >= 1994]
dt_claims[, period_loss := ((year_loss - 1994L) %/% 5L) * 5L + 1994L]
dt_claims[, period_constr := ((year_constr - 1985L) %/% 3L) * 3L + 1985L]
dt_claims[, post1994 := as.integer(year_constr > 1994L)]

v_claim <- c(
    "building_damage", "net_building_pmt",
    "contents_damage", "net_contents_pmt"
)
s_claim <- paste0("c(", paste0(v_claim, collapse = ", "), ")")

# event studies ----
# claim-level event study
fmla_claim_es <- as.formula(paste0(
    s_claim, " ~ i(period_constr, mh, ref = 1991)",
    " | tractfp^period_loss + mh"
))

est_claim_es <- feols(fmla_claim_es, data = dt_claims, lean = TRUE)
etable(est_claim_es, fitstat = c("n", "r2", "wr2", "my"))
iplot(est_claim_es[lhs = "building_pmt$"])

# cell-level event study
dt_claims_cell <- dt[
    claims_n > 0 & building_damage_tot > 0 & !is.na(policies_n) &
    between(period_constr, 1985L, 2002L)]
dt_claims_cell[, treated_mh := (mh == 1) & treated == TRUE]

v_pclaim <- paste0(v_claim, "_pclaim")
s_pclaim <- paste0(
    "c(", paste0(v_pclaim, collapse = ", "),
    ", claim_rate, repl_cost_ppol, policy_cost_ppol", ")")

fmla_pclaim_es <- as.formula(paste0(
    s_pclaim, " ~ i(period_constr, mh, ref = 1991)",
    " | tractfp^period_loss + mh")
)

est_pclaim_es <- feols(
    fmla_pclaim_es, data = dt_claims_cell[policies_n > 0],
    weights = ~policies_n,
    lean = TRUE)
etable(est_pclaim_es, fitstat = c("n", "r2", "wr2", "my"))

iplot(est_pclaim_es[lhs = "claim_rate"])

# count event study (Poisson)
v_out <- c("claims_n", "policies_n")
s_out <- paste0("c(", paste0(v_out, collapse = ", "), ")")

fmla_out_es <- as.formula(paste0(
    s_out, " ~ i(period_constr, mh, ref = 1991)",
    " | tractfp^period_loss + mh"
))

est_pois_es <- fepois(
    fmla_out_es, data = dt,
    weights = ~claims_n, lean = TRUE
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

# Plot an event study from a fixest model estimated with i(period_constr, mh, ref = 1991).
# Extracts interaction terms (:mh), appends a zero row at the reference period,
# and draws point estimates with 95% CI ribbon.
plot_es <- function(est, outcome = NULL, vline_x = 1992.5, path = NULL) {
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
    # after as.data.table(), rownames live in the "rn" column
    idx <- grepl(":mh$", ct$rn)
    dt_es <- data.table(
        term    = ct$rn[idx],
        est     = ct$Estimate[idx],
        se      = ct[["Std. Error"]][idx]
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
        geom_line(color = v_palette[1]) +
        geom_point(color = v_palette[1], size = 2) +
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

plot_es(est_claim_es, "net_building_pmt",
        path = here("output", "event-study", "es-net-building-pmt.pdf"))

plot_es(est_claim_es, "net_contents_pmt",
        path = here("output", "event-study", "es-net-contents-pmt.pdf"))

plot_es(est_pclaim_es, "claim_rate",
        path = here("output", "event-study", "es-claim-rate.pdf"))

plot_es(est_pois_es, "policies_n",
        path = here("output", "event-study", "es-policies.pdf"))
