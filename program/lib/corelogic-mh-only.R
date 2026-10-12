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

# Paper figure: vintage-FE and state x vintage-FE event studies overlaid, in log points, no caption.
cl_mh_only_compare_plot <- function(tab, tab_state, out_dir, quantity = FALSE) {
    specs <- c("Vintage FE", "State x vintage FE")
    x <- rbind(copy(tab)[, spec := specs[1]], copy(tab_state)[, spec := specs[2]], fill = TRUE)
    x[, vintage := as.integer(sub("year_constr::([0-9]+):.*", "\\1", term))]
    x[, comparison := fifelse(grepl(":z2$", term), "Zone II minus Zone I", "Zone III minus Zone I")]
    stopifnot(nrow(x) == 40L, !anyDuplicated(x, by = c("spec", "comparison", "vintage")))
    labels <- c("Zone II minus Zone I", "Zone III minus Zone I")
    x <- rbind(x, CJ(comparison = labels, spec = specs)[, `:=`(vintage = 1993L,
        estimate = 0, ci_low = 0, ci_high = 0)], fill = TRUE)
    x[, `:=`(comparison = factor(comparison, levels = labels), spec = factor(spec, levels = specs))]
    dodge <- position_dodge(width = .45)
    p <- ggplot(x, aes(vintage, estimate, shape = spec, color = spec)) +
        geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
        geom_vline(xintercept = 1993.5, linetype = "dotted", color = "black") +
        geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = .2, position = dodge) +
        geom_point(size = 2, position = dodge) + facet_wrap(~comparison, ncol = 2) +
        scale_color_manual(values = c("#0072B2", "#D55E00")) + scale_shape_manual(values = c(16, 17)) +
        scale_x_continuous(breaks = seq(1989, 1999, 2)) +
        labs(x = "Construction year", y = if (quantity) "Log MH count, relative to 1993" else "Log MH sale price, relative to 1993",
            color = NULL, shape = NULL) +
        theme_classic(base_size = 14) + theme(text = element_text(family = "serif"), legend.position = "bottom")
    filename <- if (quantity) "mh_only_vintage_quantities_compare" else "mh_only_vintage_prices_compare"
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

# Static ladder shared by prices and counts. Columns 1-2 use MH only; 3-4 add site-built homes.
# (1) vintage FE; (2) state x vintage FE; (3) county x vintage and type x vintage FE;
# (4) county x vintage and state x vintage x type FE.
cl_mh_static_formula <- function(column, quantity = FALSE) {
    stopifnot(column %in% 1:4)
    outcome <- if (quantity) "homes" else "log_price"
    place <- if (quantity) "countyfp" else "countyfp^year_sale"
    rhs <- if (column <= 2) "post_z2 + post_z3" else "post_mh_z2 + post_mh_z3"
    fe <- switch(column,
        paste(place, "+ year_constr"),
        paste(place, "+ statefp^year_constr"),
        paste0(place, "^mh + countyfp^year_constr + mh^year_constr"),
        paste0(place, "^mh + countyfp^year_constr + statefp^year_constr^mh"))
    as.formula(paste(outcome, "~", rhs, "|", fe))
}

# Columns 1-2 take MH rows only; 3-4 take all rows. Returns the four fits and their cluster counts.
cl_mh_static_fits <- function(x, quantity = FALSE) {
    est <- if (quantity) fepois else feols
    fits <- list(); counties <- integer(4)
    for (k in 1:4) {
        d <- if (k <= 2) x[mh == 1] else x
        m <- est(cl_mh_static_formula(k, quantity), d, vcov = ~countyfp, mem.clean = TRUE)
        counties[k] <- uniqueN(d$countyfp[obs(m)])
        fits[[k]] <- summary(m, lean = TRUE)
    }
    list(fits = fits, counties = counties)
}

cl_mh_static_table <- function(res, file, quantity = FALSE) {
    stopifnot(length(res$fits) == 4L)
    place <- if (quantity) "County" else "County $\\times$ sale year"
    etable(res$fits, tex = TRUE, file = file, replace = TRUE, digits = 3, fitstat = "n",
        keep = "%post_", style.tex = style.tex(tablefoot = FALSE), depvar = FALSE,
        headers = list("Sample:" = list("MH" = 2, "MH and site-built" = 2)),
        dict = c(post_z2 = "Zone II $\\times$ post", post_mh_z2 = "Zone II $\\times$ post",
            post_z3 = "Zone III $\\times$ post", post_mh_z3 = "Zone III $\\times$ post",
            countyfp = "County", "countyfp^year_sale" = place, year_constr = "Vintage",
            "statefp^year_constr" = "State $\\times$ vintage",
            "countyfp^mh" = "County $\\times$ type", "countyfp^year_sale^mh" = paste(place, "$\\times$ type"),
            "countyfp^year_constr" = "County $\\times$ vintage", "mh^year_constr" = "Type $\\times$ vintage",
            "statefp^year_constr^mh" = "State $\\times$ vintage $\\times$ type"),
        extralines = list("Counties" = format(res$counties, big.mark = ",")),
        notes = NULL)
}
