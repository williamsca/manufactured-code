# MH-only county comparisons: price DiD and count PPML, with no site-built term.
# state = TRUE replaces vintage FE with state x vintage FE: zone contrasts are then within state.
cl_mh_only_formula <- function(quantity = FALSE, state = FALSE) {
    outcome <- if (quantity) "mh_homes" else "log_price"
    vintage <- if (state) "statefp^year_constr" else "year_constr"
    fe <- paste(if (quantity) "countyfp" else "countyfp^year_sale", "+", vintage)
    as.formula(paste(outcome, "~ i(year_constr, z2, ref = 1993) + i(year_constr, z3, ref = 1993) |", fe))
}

# Balance every county with any eligible MH over all vintages; retain zero cohorts.
cl_mh_count_panel <- function(cells) {
    support <- cells[, .(mh_total = sum(mh_homes)), by = .(countyfp, wind_zone)][mh_total > 0]
    stopifnot(!anyDuplicated(support$countyfp))
    x <- merge(CJ(countyfp = support$countyfp, year_constr = 1989:1999),
        support[, .(countyfp, wind_zone)], by = "countyfp")
    x <- merge(x, cells[, .(mh_homes = sum(mh_homes)), by = .(countyfp, year_constr)],
        by = c("countyfp", "year_constr"), all.x = TRUE)
    x[is.na(mh_homes), mh_homes := 0]
    x[, `:=`(statefp = substr(countyfp, 1, 2), z2 = as.integer(wind_zone == 2), z3 = as.integer(wind_zone == 3))]
    stopifnot(all(x$mh_homes >= 0), nrow(x) == 11L * nrow(support))
    x
}

cl_mh_only_coefficients <- function(model, id) {
    tab <- cl_coeftable(model, id)
    expected <- setdiff(1989:1999, 1993L)
    for (key in c("z2", "z3")) {
        found <- as.integer(sub("year_constr::([0-9]+):.*", "\\1",
            tab[grepl(paste0(":", key, "$"), term), term]))
        stopifnot(setequal(expected, found))
    }
    tab
}

cl_mh_only_plot <- function(tab, out_dir, quantity = FALSE, state = FALSE) {
    x <- copy(tab)
    x[, `:=`(effect = if (quantity) pct else estimate,
        effect_low = if (quantity) pct_low else ci_low,
        effect_high = if (quantity) pct_high else ci_high)]
    x[, vintage := as.integer(sub("year_constr::([0-9]+):.*", "\\1", term))]
    x[, comparison := fifelse(grepl(":z2$", term), "II minus I", "III minus I")]
    labels <- c("II minus I", "III minus I")
    x <- rbind(x, data.table(comparison = labels, vintage = 1993L,
        effect = 0, effect_low = 0, effect_high = 0), fill = TRUE)
    x[, comparison := factor(comparison, levels = labels)]
    p <- ggplot(x, aes(vintage, effect)) +
        annotate("rect", xmin = 1993.5, xmax = 1994.5, ymin = -Inf, ymax = Inf, fill = "gray80", alpha = .4) +
        geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
        geom_vline(xintercept = 1993.5, linetype = "dotted", color = "black") +
        geom_errorbar(aes(ymin = effect_low, ymax = effect_high), width = .15) +
        geom_point(color = "#0072B2", size = 2) + facet_wrap(~comparison, ncol = 2) +
        scale_x_continuous(breaks = seq(1989, 1999, 2)) +
        labs(x = "Original construction year", y = if (quantity) "MH count contrast (%)" else "MH-only price contrast (log points)",
            caption = if (quantity) paste0("Surviving 2023 MH parcels; PPML with zero counts", if (state) "; state x vintage FE" else "",
                ". 1993 reference; county-clustered 95% intervals.")
                else paste0("MH sales 2000-2023", if (state) "; state x vintage FE" else "",
                    ". 1993 reference; county-clustered 95% intervals. Shaded 1994 partially treated.")) +
        theme_classic(base_size = 14) + theme(text = element_text(family = "serif"), plot.caption = element_text(size = 10))
    filename <- paste0(if (quantity) "mh_only_vintage_quantities" else "mh_only_vintage_prices", if (state) "_state_vintage_fe" else "")
    for (ext in c("pdf", "png")) ggsave(file.path(out_dir, paste0(filename, ".", ext)),
        p, width = 9, height = 5, dpi = 150)
}
