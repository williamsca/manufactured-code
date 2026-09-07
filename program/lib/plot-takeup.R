# Shared by the full NFIP estimator and the standalone take-up figure rebuild.
# Models must use i(period_constr, mh), with state-clustered inference.
plot_takeup_event_study <- function(models, ref_period, path) {
    stopifnot(identical(names(models), c("Policies per home", "Claims per policy")))
    points <- data.table::rbindlist(lapply(names(models), function(margin) {
        ct <- data.table::as.data.table(fixest::coeftable(models[[margin]]),
                                        keep.rownames = "term")
        ct <- ct[grepl("^period_constr::[0-9]+:mh$", term)]
        stopifnot(nrow(ct) > 0L)
        d <- ct[, .(margin, period = as.integer(sub(
            "period_constr::([0-9]+):mh", "\\1", term)),
            estimate = Estimate, se = get("Std. Error"), reference = FALSE)]
        d <- rbind(d, data.table::data.table(margin, period = ref_period,
                  estimate = 0, se = 0, reference = TRUE))
        d[, `:=`(ci_low = estimate - 1.96 * se, ci_high = estimate + 1.96 * se)]
        d
    }))
    data.table::setorder(points, margin, period)
    stopifnot(!anyNA(points), all(points$se >= 0),
              data.table::uniqueN(points, by = c("margin", "period")) == nrow(points))
    data.table::fwrite(points, sub("\\.pdf$", ".csv", path))
    points[, margin := factor(margin, levels = names(models))]
    # Small horizontal offsets separate the two confidence intervals in a bin.
    points[, x := period + ifelse(margin == "Policies per home", -0.12, 0.12)]
    p <- ggplot2::ggplot(points, ggplot2::aes(x, estimate, color = margin,
                                             shape = margin, group = margin)) +
        ggplot2::geom_hline(yintercept = 0, color = "gray55", linetype = "dashed") +
        ggplot2::geom_vline(xintercept = 1993.5, linetype = "dotted") +
        ggplot2::geom_line(linewidth = 0.55) +
        ggplot2::geom_errorbar(data = points[reference == FALSE],
            ggplot2::aes(ymin = ci_low, ymax = ci_high), width = 0.16, linewidth = 0.55) +
        ggplot2::geom_point(size = 2.5) +
        ggplot2::scale_x_continuous(breaks = sort(unique(points$period))) +
        ggplot2::scale_color_manual(values = c("#0072B2", "#D55E00")) +
        ggplot2::scale_shape_manual(values = c(16, 17)) +
        ggplot2::labs(x = "Construction vintage (bin starting year)",
                      y = "Effect on annual rate (log points)", color = NULL, shape = NULL) +
        ggplot2::theme_classic(base_size = 14) +
        ggplot2::theme(text = ggplot2::element_text(family = "serif"),
            legend.position = "bottom",
            panel.grid.major.y = ggplot2::element_line(color = "gray85", linewidth = 0.4))
    ggplot2::ggsave(path, p, width = 9, height = 5)
    invisible(p)
}
