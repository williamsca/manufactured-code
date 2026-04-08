# Difference-in-discontinuities RD plots using rdrobust::rdplot
#
# Produces a single figure per outcome with MH and site-built overlaid.
# Outcomes are residualized against county x loss-year FEs before plotting,
# so the visual gap at 1994 corresponds to the regression estimate.

rm(list = ls())
library(here)
library(data.table)
library(fixest)
library(rdrobust)
library(ggplot2)

# ---------------------------------------------------------------------------
# data prep (mirrors estimate-nfip.R) ----
# ---------------------------------------------------------------------------
BW <- 6L  # bandwidth: +/- years around 1994 cutoff

dt <- readRDS(here("derived", "nfip-claims.Rds"))
dt <- dt[between(year_constr, 1994L - BW, 1994L + BW - 1L) &
         year_loss >= 1994]

# running variable centered at cutoff
dt[, v := year_constr - 1994L]

# outcomes to plot
outcomes <- c("net_building_pmt", "building_damage")
labels <- c(
    "Net building payment ($000s)",
    "Building damage ($000s)"
)
sc <- c(1000, 1000)
names(labels) <- outcomes
names(sc) <- outcomes

# ---------------------------------------------------------------------------
# residualize against county x loss-year FEs ----
# ---------------------------------------------------------------------------
resid_cols <- paste0(outcomes, "_resid")

for (i in seq_along(outcomes)) {
    yvar <- outcomes[i]
    rvar <- resid_cols[i]

    cell_mean <- dt[is.finite(get(yvar)),
        .(cm = mean(get(yvar), na.rm = TRUE)),
        by = .(countyfp, year_loss)]
    dt[cell_mean, cm := i.cm, on = .(countyfp, year_loss)]

    group_mean <- dt[is.finite(get(yvar)),
        .(gm = mean(get(yvar), na.rm = TRUE)),
        by = mh]
    dt[group_mean, gm := i.gm, on = .(mh)]

    dt[is.finite(get(yvar)),
       (rvar) := (get(yvar) - cm + gm) / sc[i]]

    dt[, c("cm", "gm") := NULL]
}

# ---------------------------------------------------------------------------
# plot ----
# ---------------------------------------------------------------------------
v_palette <- c(
    "Manufactured" = "#0072B2",
    "Site-built"   = "#D55E00"
)

theme_paper <- function(base_size = 14) {
    theme_classic(base_size = base_size) +
        theme(
            text = element_text(family = "serif"),
            legend.position.inside = c(0.85, 0.85),
            legend.background = element_blank()
        )
}

dir.create(here("output", "rd"), showWarnings = FALSE,
           recursive = TRUE)

for (i in seq_along(outcomes)) {
    yvar <- outcomes[i]
    rvar <- resid_cols[i]
    ylabel <- labels[yvar]

    # run rdplot separately per type, extract bin means + poly
    all_bins <- list()
    all_poly <- list()

    for (type in c("mh", "sb")) {
        is_mh <- as.integer(type == "mh")
        sub <- dt[mh == is_mh & !is.na(get(rvar))]
        type_label <- if (is_mh) "Manufactured" else "Site-built"

        rd <- rdplot(
            y = sub[[rvar]],
            x = sub[["v"]],
            c = 0, p = 1,
            hide = TRUE
        )

        bins_dt <- as.data.table(rd$vars_bins)
        bins_dt[, type := type_label]
        all_bins[[type]] <- bins_dt

        poly_dt <- as.data.table(rd$vars_poly)
        poly_dt[, type := type_label]
        all_poly[[type]] <- poly_dt
    }

    bins <- rbindlist(all_bins)
    polys <- rbindlist(all_poly)

    # side indicator for grouping fitted lines
    polys[, side := fifelse(rdplot_x < 0, "pre", "post")]

    p <- ggplot() +
        geom_point(
            data = bins,
            aes(x = rdplot_mean_x, y = rdplot_mean_y,
                color = type, shape = type),
            size = 2.5
        ) +
        geom_line(
            data = polys,
            aes(x = rdplot_x, y = rdplot_y,
                color = type,
                group = interaction(type, side)),
            linewidth = 0.8
        ) +
        geom_vline(xintercept = -0.5, linetype = "dotted") +
        scale_color_manual(values = v_palette) +
        scale_shape_manual(values = c(
            "Manufactured" = 16, "Site-built" = 17
        )) +
        labs(x = "Construction year (centered at 1994)",
             y = ylabel, color = NULL, shape = NULL) +
        theme_paper()

    fname <- sprintf("rd-%s.pdf", yvar)
    ggsave(here("output", "rd", fname), p,
           width = 9, height = 5)
}

cat("RD plots saved to output/rd/\n")
