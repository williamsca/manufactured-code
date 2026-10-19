# Stylized conceptual figures (no data) for the paper and slides.
# 1. Two-vintage price diagram: how the mandate moves old and new MH prices.
# 2. Mitigation benefits vs. structure value, with stylized MH and
#    site-built value distributions.
# Output: output/visuals/two-vintage-prices.pdf
#         output/visuals/benefit-vs-value.pdf

rm(list = ls())
library(here)
library(data.table)
library(ggplot2)

out_dir <- here("output", "visuals")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

v_palette <- c("#0072B2", "#D55E00", "#009E73", "#F0E442")

theme_paper <- function(base_size = 14) {
    theme_classic(base_size = base_size) +
        theme(text = element_text(family = "serif"),
              legend.position = "right")
}

# Vertical bracket: spine from y0 to y1 at x, with short ticks pointing left.
bracket <- function(x, y0, y1, tick = 0.04) {
    data.table(x = c(x, x, x), xend = c(x, x - tick, x - tick),
               y = c(y0, y0, y1), yend = c(y1, y0, y1))
}

# ---------------------------------------------------------------------------
# Figure 1: two-vintage price diagram
# ---------------------------------------------------------------------------
cost <- 1
dc <- 0.30
scen <- c("Resilience valued (b > 0)", "Resilience not valued (b = 0)")
b_val <- c(0.10, 0)

# Price levels drawn as short horizontal segments at each period.
levels <- rbindlist(lapply(1:2, function(s) {
    b <- b_val[s]
    data.table(
        scenario = scen[s],
        x = c(0.75, 1.85, 1.85), xend = c(1.25, 2.35, 2.35),
        y = c(cost, cost + dc, cost + dc - b),
        vintage = if (b > 0) c("both", "new", "old") else "both")
}))
levels[, scenario := factor(scenario, levels = scen)]

level_labels <- rbindlist(list(
    data.table(scenario = scen[1], x = c(1, 2.1, 2.1),
               y = c(cost, cost + dc, cost + dc - 0.10) + 0.022,
               label = c("Old = new", "New units", "Old units")),
    data.table(scenario = scen[2], x = c(1, 2.1),
               y = c(cost, cost + dc) + 0.022,
               label = c("Old = new", "Old = new"))))
level_labels[, scenario := factor(scenario, levels = scen)]

brackets <- rbindlist(list(
    cbind(scenario = scen[1], bracket(1.65, cost, cost + dc)),
    cbind(scenario = scen[1], bracket(2.45, cost, cost + dc - 0.10)),
    cbind(scenario = scen[1], bracket(2.45, cost + dc - 0.10, cost + dc)),
    cbind(scenario = scen[2], bracket(1.65, cost, cost + dc)),
    cbind(scenario = scen[2], bracket(2.45, cost, cost + dc))))
brackets[, scenario := factor(scenario, levels = scen)]

# Math label (larger) plus a short description underneath.
annot <- rbindlist(list(
    data.table(scenario = scen[1],
               x = c(1.6, 2.5, 2.5),
               y = c(cost + dc / 2, cost + (dc - 0.10) / 2, cost + dc - 0.05),
               hjust = c(1, 0, 0),
               math = c("Δc", "Δc − b", "b"),
               desc = c("rise in\nnew price",
                        "common shift:\nabsorbed by\nmarket × year\neffects",
                        "vintage gap:\nestimated by\nvintage\ncomparison")),
    data.table(scenario = scen[2],
               x = c(1.6, 2.5),
               y = c(cost + dc / 2, cost + dc / 2),
               hjust = c(1, 0),
               math = c("Δc", "Δc"),
               desc = c("rise in\nnew price",
                        "all prices rise:\nno vintage gap"))))
annot[, scenario := factor(scenario, levels = scen)]

fig1 <- ggplot() +
    geom_hline(yintercept = cost, linetype = "dotted", color = "gray60") +
    geom_segment(data = levels,
                 aes(x = x, xend = xend, y = y, yend = y, color = vintage),
                 linewidth = 1.6, lineend = "round") +
    geom_text(data = level_labels, aes(x = x, y = y, label = label),
              family = "serif", size = 4.2, vjust = 0) +
    geom_segment(data = brackets,
                 aes(x = x, xend = xend, y = y, yend = yend),
                 linewidth = 0.4) +
    geom_text(data = annot,
              aes(x = x, y = y, label = math, hjust = hjust),
              family = "serif", size = 4.6, fontface = "italic", vjust = -0.2) +
    geom_text(data = annot,
              aes(x = x, y = y, label = desc, hjust = hjust),
              family = "serif", size = 3.7, vjust = 1.15, lineheight = 0.9,
              color = "gray25") +
    facet_wrap(~scenario, nrow = 1) +
    scale_color_manual(values = c(both = "gray30", new = v_palette[2],
                                  old = v_palette[1]), guide = "none") +
    scale_x_continuous(breaks = c(1, 2.1),
                       labels = c("Before\nmandate", "After\nmandate"),
                       limits = c(0.7, 3.25), expand = c(0, 0)) +
    scale_y_continuous(breaks = c(cost, cost + dc - 0.10, cost + dc),
                       labels = c("c", "c + Δc − b", "c + Δc"),
                       limits = c(0.95, 1.38)) +
    labs(x = NULL, y = "Price") +
    theme_paper() +
    theme(strip.background = element_blank(),
          strip.text = element_text(size = 14),
          axis.ticks.x = element_blank(),
          panel.spacing = unit(1.5, "lines"))

ggsave(file.path(out_dir, "two-vintage-prices.pdf"), fig1,
       width = 9, height = 5, device = cairo_pdf)

# ---------------------------------------------------------------------------
# Figure 2: present value of mitigation benefits vs. structure value
# ---------------------------------------------------------------------------
# Benefit = p * delta_d * H (proportional to value); cost k scales with
# footprint and is nearly flat in value. Crossing at H* = 100.
beta <- 0.010
k0 <- 0.80
k1 <- 0.002
h_star <- k0 / (beta - k1)

lines_dt <- data.table(H = seq(0, 350, length.out = 400))
lines_dt[, benefit := beta * H]
lines_dt[, cost := k0 + k1 * H]

# Stylized lognormal value distributions; site-built median is 2.5x MH median.
band_top <- -0.15
band_height <- 1.3
dens <- rbindlist(lapply(list(c("Manufactured homes", 60),
                              c("Site-built homes", 150)), function(g) {
    d <- data.table(type = g[1], H = seq(1, 350, length.out = 400))
    d[, dens := dlnorm(H, meanlog = log(as.numeric(g[2])), sdlog = 0.5)]
    d
}))
dens[, dens := dens / max(dens)]
dens[, ymin := band_top - band_height]
dens[, ymax := ymin + 0.65 * band_height * dens]

y_top <- 3.6
fig2 <- ggplot() +
    # net-loss and net-gain regions between the two lines
    geom_ribbon(data = lines_dt[H <= h_star],
                aes(x = H, ymin = benefit, ymax = cost),
                fill = v_palette[2], alpha = 0.15) +
    geom_ribbon(data = lines_dt[H >= h_star],
                aes(x = H, ymin = cost, ymax = benefit),
                fill = v_palette[1], alpha = 0.15) +
    geom_line(data = lines_dt, aes(x = H, y = benefit),
              color = v_palette[1], linewidth = 1.1) +
    geom_line(data = lines_dt, aes(x = H, y = cost),
              color = v_palette[2], linewidth = 1.1, linetype = "dashed") +
    geom_segment(aes(x = h_star, xend = h_star,
                     y = band_top - band_height, yend = y_top),
                 linetype = "dotted") +
    geom_hline(yintercept = 0, color = "gray60", linewidth = 0.3) +
    # value distributions in the lower strip
    geom_ribbon(data = dens, aes(x = H, ymin = ymin, ymax = ymax, fill = type),
                alpha = 0.35, color = NA) +
    geom_line(data = dens, aes(x = H, y = ymax, color = type), linewidth = 0.6) +
    annotate("text", x = 50, y = band_top - 0.4, label = "Manufactured\nhomes",
             family = "serif", size = 4, vjust = 0,
             color = v_palette[3], lineheight = 0.9) +
    annotate("text", x = 150, y = band_top - 0.6, label = "Site-built homes",
             family = "serif", size = 4, hjust = 0, color = "gray30") +
    # direct line labels
    annotate("text", x = 280, y = 2.95,
             label = "PV of avoided damage\n(proportional to H)",
             family = "serif", size = 4, hjust = 1, vjust = 0,
             color = v_palette[1], lineheight = 0.9) +
    annotate("text", x = 345, y = k0 + k1 * 345 + 0.12,
             label = "Mitigation cost k\n(scales with size, not value)",
             family = "serif", size = 4, hjust = 1, vjust = 0,
             color = v_palette[2], lineheight = 0.9) +
    annotate("text", x = h_star, y = y_top, label = "H*",
             family = "serif", fontface = "italic", size = 4.6,
             hjust = -0.3, vjust = 1) +
    # region labels
    annotate("text", x = h_star / 2, y = 2.4,
             label = "Mandate costs\nmore than it saves",
             family = "serif", size = 4.2, lineheight = 0.9) +
    annotate("text", x = h_star + 60, y = 2.4, label = "Mandate pays",
             family = "serif", size = 4.2) +
    scale_fill_manual(values = c("Manufactured homes" = v_palette[3],
                                 "Site-built homes" = "gray50"),
                      guide = "none") +
    scale_color_manual(values = c("Manufactured homes" = v_palette[3],
                                  "Site-built homes" = "gray40"),
                       guide = "none") +
    scale_x_continuous(breaks = NULL, expand = c(0, 0)) +
    scale_y_continuous(breaks = NULL) +
    coord_cartesian(xlim = c(0, 350), ylim = c(band_top - band_height, y_top),
                    clip = "off") +
    labs(x = "Structure value, H", y = "Present value ($)") +
    theme_paper()

ggsave(file.path(out_dir, "benefit-vs-value.pdf"), fig2,
       width = 9, height = 5, device = cairo_pdf)
