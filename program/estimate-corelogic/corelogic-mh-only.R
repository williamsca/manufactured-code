# MH-only county comparisons: price DiD and count PPML, with no site-built term.
# state = TRUE replaces vintage FE with state x vintage FE: zone contrasts are then within state.
cl_mh_only_formula <- function(quantity = FALSE, state = FALSE, reference = 1993L) {
    outcome <- if (quantity) "mh_homes" else "log_price"
    vintage <- if (state) "statefp^year_constr" else "year_constr"
    fe <- paste(if (quantity) "countyfp" else "countyfp^year_sale", "+", vintage)
    as.formula(sprintf("%s ~ i(year_constr, z2, ref = %d) + i(year_constr, z3, ref = %d) | %s",
        outcome, reference, reference, fe))
}

# Balance every county with any eligible MH over all vintages; retain zero cohorts.
cl_mh_count_panel <- function(cells, years = 1989:1999) {
    cells <- cells[year_constr %in% years]
    support <- cells[, .(mh_total = sum(mh_homes)), by = .(countyfp, wind_zone)][mh_total > 0]
    stopifnot(!anyDuplicated(support$countyfp))
    x <- merge(CJ(countyfp = support$countyfp, year_constr = years),
        support[, .(countyfp, wind_zone)], by = "countyfp")
    x <- merge(x, cells[, .(mh_homes = sum(mh_homes)), by = .(countyfp, year_constr)],
        by = c("countyfp", "year_constr"), all.x = TRUE)
    x[is.na(mh_homes), mh_homes := 0]
    x[, `:=`(statefp = substr(countyfp, 1, 2), z2 = as.integer(wind_zone == 2), z3 = as.integer(wind_zone == 3))]
    stopifnot(all(x$mh_homes >= 0), nrow(x) == length(years) * nrow(support))
    x
}

cl_mh_only_coefficients <- function(model, id, years = 1989:1999, reference = 1993L) {
    tab <- cl_coeftable(model, id)
    expected <- setdiff(years, reference)
    for (key in c("z2", "z3")) {
        found <- as.integer(sub("year_constr::([0-9]+):.*", "\\1",
            tab[grepl(paste0(":", key, "$"), term), term]))
        stopifnot(setequal(expected, found))
    }
    tab
}

# Paper figure: state x vintage FE event study, in log points, no caption.
# `forecast` (optional): one row per comparison with a forecast log price gap
# (`forecast`) and a common legend `label`, drawn as a dashed path rising from 0
# at 1993.5 to the forecast in 1994, with a common legend below the panels.
cl_mh_only_paper_plot <- function(tab, out_dir, quantity = FALSE, forecast = NULL) {
    stopifnot(all(grepl("_state_vintage_fe$", tab$specification)))
    x <- copy(tab)
    x[, vintage := as.integer(sub("year_constr::([0-9]+):.*", "\\1", term))]
    x[, comparison := fifelse(grepl(":z2$", term), "Zone II minus Zone I", "Zone III minus Zone I")]
    reference <- if (quantity) 1991L else 1993L
    years <- if (quantity) 1986:1999 else 1989:1999
    stopifnot(nrow(x) == 2L * (length(years) - 1L),
        setequal(x$vintage, setdiff(years, reference)),
        !anyDuplicated(x, by = c("comparison", "vintage")))
    labels <- c("Zone II minus Zone I", "Zone III minus Zone I")
    x <- rbind(x, data.table(comparison = labels, vintage = reference,
        estimate = 0, ci_low = 0, ci_high = 0), fill = TRUE)
    x[, comparison := factor(comparison, levels = labels)]
    series <- c("Regression estimates",
        if (is.null(forecast)) "Forecast" else unique(forecast$label))
    stopifnot(length(series) == 2L)
    x[, series := factor(series[1], levels = series)]
    p <- ggplot(x, aes(vintage, estimate, color = series, linetype = series)) +
        geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
        cl_mh_timing_lines(quantity) +
        geom_ribbon(aes(ymin = ci_low, ymax = ci_high), fill = "#0072B2", alpha = .2,
            color = NA, show.legend = FALSE) +
        geom_line() +
        geom_point(size = 2) + facet_wrap(~comparison, ncol = 2) +
        scale_color_manual(values = setNames(c("#0072B2", "#D55E00"), series), name = NULL) +
        scale_linetype_manual(values = setNames(c("solid", "dashed"), series), name = NULL) +
        (if (!is.null(forecast)) {
            f <- forecast[, .(vintage = c(1993.5, 1994, 1999), estimate = c(0, forecast, forecast)),
                by = comparison][, comparison := factor(comparison, levels = labels)]
            stopifnot(setequal(f$comparison, labels))
            f[, series := factor(series[2], levels = series)]
            # Legend keys: dot and line for estimates, dashed line alone for the forecast.
            list(geom_line(data = f, linewidth = .6),
                 guides(color = guide_legend(override.aes = list(shape = c(16, NA)))))
        }) +
        scale_x_continuous(breaks = if (quantity) seq(1986, 1998, 2) else seq(1989, 1999, 2)) +
        labs(x = "Construction year", y = if (quantity) "Log MH count, relative to 1991" else "Log MH sale price, relative to 1993") +
        theme_classic(base_size = 14) + theme(text = element_text(family = "serif"),
            legend.position = if (is.null(forecast)) "none" else "bottom",
            legend.key.width = unit(2, "lines"),
            panel.grid.major.y = element_line(color = "gray85", linewidth = .4))
    filename <- if (quantity) "mh_only_vintage_quantities_paper" else "mh_only_vintage_prices_paper"
    for (ext in c("pdf", "png")) ggsave(file.path(out_dir, paste0(filename, ".", ext)),
        p, width = 9, height = 5, dpi = 150)
}

# MH and site-built counts by county x vintage over the MH-support counties of cl_mh_count_panel.
cl_type_count_panel <- function(cells) {
    mh <- cl_mh_count_panel(cells)
    keys <- c("countyfp", "year_constr", "wind_zone", "statefp", "z2", "z3")
    sb <- merge(mh[, ..keys], cells[, .(sb_homes = sum(homes - mh_homes)), by = .(countyfp, year_constr)],
        by = c("countyfp", "year_constr"), all.x = TRUE)
    sb[is.na(sb_homes), sb_homes := 0]
    x <- rbind(mh[, c(keys, "mh_homes"), with = FALSE][, mh := 1L], sb[, mh := 0L], use.names = FALSE)
    setnames(x, "mh_homes", "homes")
    x[, post := as.integer(year_constr >= 1994)]
    x[, `:=`(post_z2 = post * z2, post_z3 = post * z3, post_mh_z2 = post * mh * z2, post_mh_z3 = post * mh * z3)]
    stopifnot(!anyDuplicated(x, by = c("countyfp", "year_constr", "mh")), !anyNA(x), all(x$homes >= 0),
        nrow(x) == 2L * nrow(mh), all.equal(sum(x[mh == 1, homes]), sum(mh$mh_homes)))
    x
}

# Price columns 3-4 add the housing-type triple difference. Zone x post is kept as a
# regressor (the site-built change), so no county x vintage effect is included.
# Quantity columns 3-4 instead replicate columns 1-2 on site-built counts, allowing substitution.
cl_mh_static_formula <- function(column, quantity = FALSE, size = FALSE) {
    stopifnot(column %in% 1:4)
    stopifnot(!size || !quantity)
    if (quantity) {
        vintage <- if (column %in% c(2L, 4L)) "statefp^year_constr" else "year_constr"
        return(as.formula(paste("homes ~ post_z2 + post_z3 | countyfp +", vintage)))
    }
    outcome <- if (quantity) "homes" else "log_price"
    place <- if (quantity) "countyfp" else "countyfp^year_sale"
    rhs <- if (column <= 2) "post_z2 + post_z3" else "post_z2 + post_z3 + post_mh_z2 + post_mh_z3"
    if (size) rhs <- paste(rhs, if (column <= 2) "+ log_living_area + log_lot_size" else
        "+ log_living_area + log_lot_size + mh:log_living_area + mh:log_lot_size")
    fe <- switch(column,
        paste(place, "+ year_constr"),
        paste(place, "+ statefp^year_constr"),
        paste0(place, "^mh + mh^year_constr"),
        paste0(place, "^mh + statefp^year_constr^mh"))
    as.formula(paste(outcome, "~", rhs, "|", fe))
}

# Quantity columns 3-4 take SB only; price columns 3-4 take both types.
cl_mh_static_fits <- function(x, quantity = FALSE) {
    est <- if (quantity) fepois else feols
    fits <- list(); counties <- integer(4)
    for (k in 1:4) {
        d <- if (k <= 2) x[mh == 1] else if (quantity) x[mh == 0] else x
        m <- est(cl_mh_static_formula(k, quantity), d, vcov = ~countyfp, mem.clean = TRUE)
        counties[k] <- uniqueN(d$countyfp[obs(m)])
        fits[[k]] <- summary(m, lean = TRUE)
    }
    list(fits = fits, counties = counties)
}

# Three price variants per design: common vintage, state x vintage, and
# state x vintage plus size. Keep full samples for unadjusted columns.
cl_price_static_fits <- function(x) {
    original <- c(1L, 2L, 2L, 3L, 4L, 4L)
    fits <- list(); counties <- integer(6)
    common <- list()
    for (k in 1:6) {
        d <- if (k <= 3) x[mh == 1] else x
        adjusted <- k %in% c(3L, 6L)
        if (adjusted) d <- d[valid_size == TRUE]
        m <- feols(cl_mh_static_formula(original[k], size = adjusted), d,
            vcov = ~countyfp, mem.clean = TRUE)
        counties[k] <- uniqueN(d$countyfp[obs(m)])
        if (adjusted) {
            # Same retained observations and FEs isolate controls from coverage.
            common[[paste0("common_sample_", k)]] <- summary(feols(
                cl_mh_static_formula(original[k]), d[obs(m)], vcov = ~countyfp,
                mem.clean = TRUE), lean = TRUE)
        }
        fits[[k]] <- summary(m, lean = TRUE)
    }
    list(fits = fits, counties = counties, common_sample = common)
}

cl_mh_static_table <- function(res, file, quantity = FALSE) {
    n_models <- length(res$fits)
    stopifnot(n_models == 4L || (!quantity && n_models == 6L))
    place <- if (quantity) "County" else "County $\\times$ sale year"
    etable(res$fits, tex = TRUE, file = file, replace = TRUE, digits = "r3",
        fitstat = c("n", if (quantity) "pr2" else "r2"),
        keep = "%post_", style.tex = style.tex(tablefoot = FALSE), depvar = FALSE,
        headers = if (quantity) list("Outcome:" = list("MH" = 2, "Site-built" = 2)) else
            list("Sample:" = list("MH" = n_models / 2, "MH and site-built" = n_models / 2)),
        dict = c(post_z2 = "Zone II $\\times$ post", post_z3 = "Zone III $\\times$ post",
            post_mh_z2 = "Zone II $\\times$ post $\\times$ MH", post_mh_z3 = "Zone III $\\times$ post $\\times$ MH",
            countyfp = "County", "countyfp^year_sale" = place, year_constr = "Vintage",
            "statefp^year_constr" = "State $\\times$ vintage",
            "countyfp^mh" = "County $\\times$ type", "countyfp^year_sale^mh" = paste(place, "$\\times$ type"),
            "mh^year_constr" = "Type $\\times$ vintage",
            "statefp^year_constr^mh" = "State $\\times$ vintage $\\times$ type"),
        extralines = c(list("Counties" = format(res$counties, big.mark = ",")),
            if (n_models == 6L) list("Size controls" = c("No", "No", "Yes", "No", "No", "Yes"))),
        notes = NULL)
}

# Overlay vintage and state x vintage specifications, both in log points.
cl_mh_only_compare_plot <- function(tab, tab_state, out_dir, quantity = FALSE) {
    reference <- if (quantity) 1991L else 1993L
    x <- rbindlist(list(copy(tab)[, specification := "Vintage FE"],
        copy(tab_state)[, specification := "State x vintage FE"]), use.names = TRUE, fill = TRUE)
    x[, vintage := as.integer(sub("year_constr::([0-9]+):.*", "\\1", term))]
    x[, comparison := fifelse(grepl(":z2$", term), "Zone II minus Zone I", "Zone III minus Zone I")]
    x <- rbind(x, CJ(specification = unique(x$specification), comparison = unique(x$comparison))[
        , `:=`(vintage = reference, estimate = 0, ci_low = 0, ci_high = 0)], fill = TRUE)
    x[, specification := factor(specification, levels = c("Vintage FE", "State x vintage FE"))]
    p <- ggplot(x, aes(vintage, estimate, color = specification, fill = specification,
        shape = specification, linetype = specification)) +
        geom_ribbon(aes(ymin = ci_low, ymax = ci_high), alpha = .15, color = NA) +
        geom_line() + geom_point(size = 2) +
        geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
        cl_mh_timing_lines(quantity) +
        facet_wrap(~comparison, ncol = 2) +
        scale_color_manual(values = c("#0072B2", "#D55E00")) +
        scale_fill_manual(values = c("#0072B2", "#D55E00")) +
        scale_shape_manual(values = c(16, 17)) +
        scale_linetype_manual(values = c("solid", "dashed")) +
        scale_x_continuous(breaks = if (quantity) seq(1986, 1998, 2) else seq(1989, 1999, 2)) +
        labs(x = "Construction year", y = if (quantity) "Log MH count, relative to 1991" else "Log MH sale price, relative to 1993",
            color = NULL, fill = NULL, shape = NULL, linetype = NULL) +
        theme_classic(base_size = 14) + theme(text = element_text(family = "serif"),
            legend.position = "bottom", panel.grid.major.y = element_line(color = "gray85", linewidth = .4))
    filename <- if (quantity) "mh_only_vintage_quantities_compare" else "mh_only_vintage_prices_compare"
    for (ext in c("pdf", "png")) ggsave(file.path(out_dir, paste0(filename, ".", ext)),
        p, width = 9, height = 5, dpi = 150)
}

# Fractional calendar dates mark the events within annual construction cohorts.
cl_mh_timing_lines <- function(quantity = FALSE) {
    if (!quantity) return(geom_vline(xintercept = 1993.5, linetype = "dotted", color = "black"))
    dates <- c(1992 + 236 / 366, 1994 + 193 / 365)
    list(
        geom_vline(xintercept = dates[1], linetype = "dotdash", color = "black"),
        geom_vline(xintercept = dates[2], linetype = "dotted", color = "black"),
        annotate("text", x = dates[1], y = -Inf,
            label = "Hurricane Andrew", angle = 90,
            hjust = -.05, vjust = -.35, size = 3.2, family = "serif"),
        annotate("text", x = dates[2], y = -Inf,
            label = "HUD code reform", angle = 90,
            hjust = -.05, vjust = -.35, size = 3.2, family = "serif")
    )
}
