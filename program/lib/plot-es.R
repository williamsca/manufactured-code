# Event-study plotting helpers for the NFIP estimation scripts. Expects
# `ref_period` and `v_dict` from program/lib/nfip-setup.R.

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
plot_es <- function(est, outcome = NULL, vline_x = vline_constr, path = NULL, var = "mh",
                    yscale = 1, ref = ref_period, ylab = NULL) {
    # [[]] extracts a single fixest object; [lhs=] returns fixest_multi,
    # whose coeftable() output has a different structure
    if (!is.null(outcome)) est <- est[lhs = outcome][[1]]
    # `ylab` given explicitly wins, so a single-LHS fit (passed with
    # outcome = NULL, which cannot be looked up in `v_dict`) can still be
    # labeled.
    if (is.null(ylab)) {
        ylab <- if (!is.null(outcome) && outcome %in% names(v_dict)) {
            unname(v_dict[[outcome]])
        } else {
            outcome
        }
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

# Coefficients of i(period_constr, <var>, ref = ref) from a single-LHS fit, with
# the reference period appended at zero.
es_coefs <- function(est, var, ref = ref_period) {
    ct <- as.data.table(coeftable(est), keep.rownames = TRUE)
    ct <- ct[grepl(paste0(":", var, "$"), rn)]
    stopifnot(nrow(ct) > 0L)
    dt_es <- ct[, .(period = as.integer(regmatches(rn, regexpr("[0-9]{4}", rn))),
                    est = Estimate, se = `Std. Error`)]
    dt_es <- rbind(dt_es, data.table(period = ref, est = 0, se = 0))
    dt_es[, `:=`(ci_low = est - 1.96 * se, ci_high = est + 1.96 * se)]
    setorder(dt_es, period)
}

# Overlay event studies from a named list of single-LHS fixest objects.
# Each model must be estimated with i(period_constr, mh, ref = ref_period).
plot_es_multi <- function(est_list, vline_x = vline_constr, path = NULL,
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
