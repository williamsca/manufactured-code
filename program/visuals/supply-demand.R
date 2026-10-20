# Stylized supply-and-demand diagram (no data) for the slides.
# Market for manufactured housing in pre-reform-equivalent units: the old
# stock is fixed, new units are supplied elastically at cost, and a buyer pays
# b more for a post-reform unit. The mandate shifts effective new supply from
# c to c + dc - b.
# Output: output/visuals/supply-demand-step{1-4}.pdf (walk-through builds)

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
bracket <- function(x, y0, y1, tick = 0.12) {
    data.table(x = c(x, x, x), xend = c(x, x - tick, x - tick),
               y = c(y0, y0, y1), yend = c(y1, y0, y1))
}

txt <- function(x, y, label, hjust = 0, vjust = 0.5, size = 4.2,
                color = "black") {
    annotate("text", x = x, y = y, label = label, hjust = hjust, vjust = vjust,
             size = size, color = color, family = "serif", lineheight = 0.9)
}

# ---------------------------------------------------------------------------
# Parameters
# ---------------------------------------------------------------------------
# Inverse demand p = a - s * Q
a <- 2.4
s <- 0.2
cost <- 1
dc <- 0.45
b <- 0.20
s_bar <- 4

p0 <- cost
p1 <- cost + dc - b
q0 <- (a - p0) / s
q1 <- (a - p1) / s

x_min <- 2.6
x_max <- 9.7
y_min <- 0.7
y_max <- 1.75
x_lab <- x_max + 0.15  # right-margin labels

col_old <- "gray30"
col_post <- v_palette[1]
col_new <- v_palette[2]

demand <- data.table(Q = c((a - y_max) / s, (a - y_min - 0.05) / s))
demand[, p := a - s * Q]

supply <- function(p) {
    data.table(x = c(s_bar, s_bar), xend = c(s_bar, x_max),
               y = c(y_min, p), yend = c(p, p))
}

# ---------------------------------------------------------------------------
# Build steps
#   1. Before the mandate: fixed old stock, new units at cost c
#   2. Mandate raises the cost of new units to c + dc
#   3. Buyers value resilience at b: effective supply at c + dc - b
#   4. Vintage gap b and the fall in quantity
# Line descriptions are dropped in step 4, where the brackets replace them.
# ---------------------------------------------------------------------------
build <- function(step) {
    desc <- step < 4

    g <- ggplot() +
        geom_line(data = demand, aes(x = Q, y = p), linewidth = 1.1) +
        txt(demand$Q[1] + 0.45, y_max - 0.02, "Demand", vjust = 1) +
        geom_segment(data = supply(p0),
                     aes(x = x, xend = xend, y = y, yend = yend),
                     color = col_old, linewidth = 1.1,
                     linetype = if (step >= 3) "dashed" else "solid") +
        txt(x_lab, p0, "c") +
        txt(s_bar - 0.1, y_min + 0.04, "Pre-reform\nstock",
            hjust = 1, vjust = 0, size = 3.8, color = "gray25") +
        annotate("point", x = q0, y = p0, size = 2.5) +
        annotate("segment", x = q0, xend = q0, y = y_min, yend = p0,
                 linetype = "dotted", color = "gray50") +
        annotate("text", x = q0, y = y_min - 0.03, label = "Q[0]",
                 parse = TRUE, family = "serif", size = 4.2, vjust = 1)
    if (desc) {
        g <- g + txt(x_max - 0.1, p0 - 0.03, "New units at cost",
                     hjust = 1, vjust = 1, size = 3.8, color = "gray25")
    }

    if (step >= 2) {
        g <- g +
            annotate("segment", x = s_bar, xend = x_max,
                     y = cost + dc, yend = cost + dc,
                     color = col_new, linewidth = 1.1, linetype = "dotted") +
            txt(x_lab, cost + dc, "c + Δc", color = col_new)
        if (desc) {
            g <- g + txt(x_max - 0.1, cost + dc + 0.03,
                         "Cost of a new unit after the mandate",
                         hjust = 1, vjust = 0, size = 3.8, color = col_new)
        }
    }

    if (step >= 3) {
        g <- g +
            geom_segment(data = supply(p1),
                         aes(x = x, xend = xend, y = y, yend = yend),
                         color = col_post, linewidth = 1.3) +
            txt(x_lab, p1, "c + Δc − b", color = col_post) +
            annotate("point", x = q1, y = p1, size = 2.5, color = col_post) +
            annotate("segment", x = q1, xend = q1, y = y_min, yend = p1,
                     linetype = "dotted", color = "gray50") +
            annotate("text", x = q1, y = y_min - 0.03, label = "Q[1]",
                     parse = TRUE, family = "serif", size = 4.2, vjust = 1,
                     color = col_post)
        if (desc) {
            g <- g + txt(x_max - 0.1, p1 + 0.03,
                         "Same, net of the value of resilience",
                         hjust = 1, vjust = 0, size = 3.8, color = col_post)
        }
    }

    if (step >= 4) {
        bx <- 7.7
        arrow_y <- y_min + 0.07
        g <- g +
            geom_segment(data = bracket(bx, p1, cost + dc),
                         aes(x = x, xend = xend, y = y, yend = yend),
                         linewidth = 0.4) +
            txt(bx + 0.12, (p1 + cost + dc) / 2,
                "b: vintage price gap\n(price comparison)") +
            annotate("segment", x = q0, xend = q1, y = arrow_y, yend = arrow_y,
                     arrow = arrow(length = unit(0.12, "inches"),
                                   type = "closed"),
                     color = col_post, linewidth = 0.6)
    }

    g +
        scale_x_continuous(breaks = s_bar, labels = expression(bar(S)),
                           expand = c(0, 0)) +
        scale_y_continuous(breaks = NULL, expand = c(0, 0)) +
        coord_cartesian(xlim = c(x_min, x_max), ylim = c(y_min, y_max),
                        clip = "off") +
        labs(x = "Manufactured homes",
             y = "Price of a pre-reform home") +
        theme_paper() +
        theme(plot.margin = margin(10, 95, 10, 10),
              axis.title.x = element_text(margin = margin(t = 14)))
}

for (k in 1:4) {
    ggsave(file.path(out_dir, sprintf("supply-demand-step%d.pdf", k)),
           build(k), width = 9, height = 5, device = cairo_pdf)
}
