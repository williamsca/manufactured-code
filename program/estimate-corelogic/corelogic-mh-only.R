# Match the 1988-1999 NFIP vintage window in prices and surviving counts.
CL_VINTAGES <- 1988:1999
CL_QUANTITY_VINTAGES <- 1988:1999
cl_years <- function(quantity = FALSE) if (quantity) CL_QUANTITY_VINTAGES else CL_VINTAGES
cl_breaks <- function(quantity = FALSE) {
    y <- cl_years(quantity)
    seq(min(y), max(y), 2)
}

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
cl_mh_count_panel <- function(cells, years = CL_VINTAGES) {
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

cl_mh_only_coefficients <- function(model, id, years = CL_VINTAGES, reference = 1993L) {
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
cl_mh_only_paper_plot <- function(tab, out_dir, quantity = FALSE, forecast = NULL,
                                  slides = FALSE,
                                  reference = if (quantity) 1991L else 1993L) {
    stopifnot(all(grepl("_state_vintage_fe$", tab$specification)))
    x <- copy(tab)
    x[, vintage := as.integer(sub("year_constr::([0-9]+):.*", "\\1", term))]
    x[, comparison := fifelse(grepl(":z2$", term), "Zone II minus Zone I", "Zone III minus Zone I")]
    years <- cl_years(quantity)
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
            f <- forecast[, .(vintage = c(1993.5, 1994, max(CL_VINTAGES)), estimate = c(0, forecast, forecast)),
                by = comparison][, comparison := factor(comparison, levels = labels)]
            stopifnot(setequal(f$comparison, labels))
            f[, series := factor(series[2], levels = series)]
            # Legend keys: dot and line for estimates, dashed line alone for the forecast.
            list(geom_line(data = f, linewidth = .6),
                 guides(color = guide_legend(override.aes = list(shape = c(16, NA)))))
        }) +
        scale_x_continuous(breaks = cl_breaks(quantity)) +
        labs(x = "Construction year", y = if (quantity) sprintf("Log MH count, relative to %d", reference) else "Log MH sale price, relative to 1993") +
        theme_classic(base_size = 14) + theme(text = element_text(family = "serif"),
            legend.position = if (is.null(forecast)) "none" else "bottom",
            legend.key.width = unit(2, "lines"),
            panel.grid.major.y = element_line(color = "gray85", linewidth = .4))
    filename <- if (quantity) "mh_only_vintage_quantities_paper" else "mh_only_vintage_prices_paper"
    if (slides) {
        # Wide slide content area, with labels readable at presentation size.
        filename <- sub("_paper$", "_slides", filename)
        p <- p + theme(text = element_text(family = "sans", size = 20),
            axis.text = element_text(size = 17),
            axis.title = element_text(size = 19),
            strip.text = element_text(size = 20),
            legend.text = element_text(size = 18),
            legend.key.width = unit(2.2, "lines"),
            panel.spacing = unit(1.2, "lines"))
    }
    for (ext in c("pdf", "png")) ggsave(file.path(out_dir, paste0(filename, ".", ext)),
        p, width = if (slides) 12 else 9,
        height = if (slides) 5.2 else 5, dpi = 180)
    invisible(p)
}

# Raw surviving MH counts by construction year, one panel per wind zone.
cl_raw_count_plot <- function(counts, out_dir) {
    x <- copy(counts)
    stopifnot(!anyDuplicated(x, by = c("wind_zone", "year_constr")),
        all(is.finite(x$mh_homes)), all(x$mh_homes >= 0))
    x[, zone := factor(wind_zone, levels = 1:3, labels = c("Zone I", "Zone II", "Zone III"))]
    p <- ggplot(x, aes(year_constr, mh_homes)) +
        geom_vline(xintercept = 1994.5, linetype = "dashed", color = "gray45") +
        geom_line(color = "#0072B2", linewidth = 0.7) +
        geom_point(color = "#0072B2", size = 1.7) +
        facet_wrap(~zone, nrow = 1, scales = "free_y") +
        scale_y_continuous(labels = scales::label_comma()) +
        scale_x_continuous(breaks = seq(1990, 1998, 2)) +
        labs(x = "Construction year", y = "Surviving manufactured homes") +
        theme_classic(base_size = 14) +
        theme(panel.grid.major.y = element_line(color = "gray90"))
    ggsave(file.path(out_dir, "mh_raw_counts_by_zone.pdf"), p, width = 10, height = 4)
    invisible(p)
}

# MH and site-built counts by county x vintage over the MH-support counties of cl_mh_count_panel.
cl_type_count_panel <- function(cells, years = CL_VINTAGES) {
    mh <- cl_mh_count_panel(cells, years)
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
cl_mh_static_formula <- function(column, quantity = FALSE, size = FALSE, outcome = "log_price") {
    stopifnot(column %in% 1:4)
    stopifnot(!size || !quantity)
    if (quantity) {
        vintage <- if (column %in% c(2L, 4L)) "statefp^year_constr" else "year_constr"
        return(as.formula(paste("homes ~ post_z2 + post_z3 | countyfp +", vintage)))
    }
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
# `outcome` is log_price for the main table or price_level_w for the levels table.
# size_columns = FALSE drops the size-adjusted columns (four columns), for size outcomes;
# `valid` names a logical column restricting every column to the outcome's valid sample.
cl_price_static_fits <- function(x, outcome = "log_price", size_columns = TRUE, valid = NULL) {
    original <- if (size_columns) c(1L, 2L, 2L, 3L, 4L, 4L) else 1:4
    n_col <- length(original)
    fits <- list(); counties <- integer(n_col)
    common <- list()
    for (k in seq_len(n_col)) {
        d <- if (k <= n_col / 2) x[mh == 1] else x
        if (!is.null(valid)) d <- d[get(valid) == TRUE]
        adjusted <- size_columns && k %in% c(3L, 6L)
        if (adjusted) d <- d[valid_size == TRUE]
        m <- feols(cl_mh_static_formula(original[k], size = adjusted, outcome = outcome), d,
            vcov = ~countyfp, mem.clean = TRUE)
        counties[k] <- uniqueN(d$countyfp[obs(m)])
        if (adjusted) {
            # Same retained observations and FEs isolate controls from coverage.
            common[[paste0("common_sample_", k)]] <- summary(feols(
                cl_mh_static_formula(original[k], outcome = outcome), d[obs(m)], vcov = ~countyfp,
                mem.clean = TRUE), lean = TRUE)
        }
        fits[[k]] <- summary(m, lean = TRUE)
    }
    list(fits = fits, counties = counties, common_sample = common)
}

cl_mh_static_table <- function(res, file, quantity = FALSE, digits = "r3") {
    n_models <- length(res$fits)
    stopifnot(n_models == 4L || (!quantity && n_models == 6L))
    place <- if (quantity) "County" else "County $\\times$ sale year"
    etable(res$fits, tex = TRUE, file = file, replace = TRUE, digits = digits,
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
cl_mh_only_compare_plot <- function(tab, tab_state, out_dir, quantity = FALSE,
                                    reference = if (quantity) 1991L else 1993L) {
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
        scale_x_continuous(breaks = cl_breaks(quantity)) +
        labs(x = "Construction year", y = if (quantity) "Log MH count, relative to 1991" else "Log MH sale price, relative to 1993",
            color = NULL, fill = NULL, shape = NULL, linetype = NULL) +
        theme_classic(base_size = 14) + theme(text = element_text(family = "serif"),
            legend.position = "bottom", panel.grid.major.y = element_line(color = "gray85", linewidth = .4))
    filename <- if (quantity) "mh_only_vintage_quantities_compare" else "mh_only_vintage_prices_compare"
    for (ext in c("pdf", "png")) ggsave(file.path(out_dir, paste0(filename, ".", ext)),
        p, width = 9, height = 5, dpi = 150)
}

# Zone x vintage event studies with state x vintage FE. outcome is price_level_w
# (winsorized dollars), log_price, or homes (PPML counts). ddd = FALSE is the MH-only
# DiD (dynamic static column 2); ddd = TRUE adds site-built homes with mh_z terms and
# type-specific FE (dynamic price column 5; for counts, the analogous count DDD).
cl_type_es_formula <- function(outcome, ddd = FALSE, reference = 1993L, size = FALSE) {
    stopifnot(!size || ddd)
    terms <- c("z2", "z3", if (ddd) c("mh_z2", "mh_z3"))
    rhs <- paste(sprintf("i(year_constr, %s, ref = %d)", terms, reference), collapse = " + ")
    if (size) rhs <- paste(rhs, "+ log_living_area + log_lot_size + mh:log_living_area + mh:log_lot_size")
    place <- if (outcome == "homes") "countyfp" else "countyfp^year_sale"
    fe <- if (ddd) paste0(place, "^mh + statefp^year_constr^mh") else paste(place, "+ statefp^year_constr")
    as.formula(paste(outcome, "~", rhs, "|", fe))
}

# One row per zone x vintage x series. In the DDD, "Site-built" is the z terms,
# "MH minus site-built" the mh_z terms, and "MH" their sum (SE from the joint vcov).
cl_type_es_coefficients <- function(model, id, ddd = FALSE, years = CL_VINTAGES, reference = 1993L) {
    b <- coef(model); V <- vcov(model)
    grid <- CJ(zone = c("z2", "z3"), vintage = setdiff(years, reference))
    key <- function(prefix, z, v) sprintf("year_constr::%d:%s%s", v, prefix, z)
    one <- function(series, keys) grid[, {
        k <- keys(zone, vintage)
        stopifnot(all(k %in% names(b)))
        .(series = series, estimate = sum(b[k]), se = sqrt(sum(V[k, k])))
    }, by = .(zone, vintage)]
    tab <- if (!ddd) one("MH", function(z, v) key("", z, v)) else rbind(
        one("Site-built", function(z, v) key("", z, v)),
        one("MH minus site-built", function(z, v) key("mh_", z, v)),
        one("MH", function(z, v) c(key("", z, v), key("mh_", z, v))))
    tab[, `:=`(ci_low = estimate - 1.96 * se, ci_high = estimate + 1.96 * se,
        specification = id, n = nobs(model), reference = reference)]
    stopifnot(!anyDuplicated(tab, by = c("zone", "vintage", "series")))
    tab
}

cl_type_es_plot <- function(tab, out_dir, filename, outcome, keep = unique(tab$series)) {
    reference <- unique(tab$reference)
    stopifnot(length(reference) == 1L)
    quantity <- outcome == "homes"
    scale <- if (outcome == "price_level_w") 1e3 else 1
    x <- tab[series %in% keep]
    x <- rbind(x, CJ(zone = c("z2", "z3"), series = keep)[,
        `:=`(vintage = reference, estimate = 0, ci_low = 0, ci_high = 0)], fill = TRUE)
    x[, comparison := factor(fifelse(zone == "z2", "Zone II minus Zone I", "Zone III minus Zone I"))]
    x[, series := factor(series, levels = keep)]
    pal <- c("#0072B2", "#D55E00", "#009E73")[seq_along(keep)]
    ylab <- switch(outcome,
        price_level_w = "Sale price ($000s, 2000), rel. to 1993",
        log_price = "Log sale price, relative to 1993",
        homes = sprintf("Log count, relative to %d", reference))
    p <- ggplot(x, aes(vintage, estimate / scale, color = series, fill = series)) +
        geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
        cl_mh_timing_lines(quantity) +
        geom_ribbon(aes(ymin = ci_low / scale, ymax = ci_high / scale), alpha = .15, color = NA) +
        geom_line() + geom_point(size = 2) + facet_wrap(~comparison, ncol = 2) +
        scale_color_manual(values = pal, name = NULL) + scale_fill_manual(values = pal, name = NULL) +
        scale_x_continuous(breaks = cl_breaks(quantity)) +
        labs(x = "Construction year", y = ylab) +
        theme_classic(base_size = 14) + theme(text = element_text(family = "serif"),
            legend.position = if (length(keep) > 1) "bottom" else "none",
            panel.grid.major.y = element_line(color = "gray85", linewidth = .4))
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
