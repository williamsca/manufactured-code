# Ratio of MH placements to single-family building permits by year,
# treated vs. control states
#
# Inputs:  derived/sample-mhs.Rds
# Outputs: output/descriptives/mhs-placement-ratio.pdf

rm(list = ls())
library(here)
library(data.table)
library(ggplot2)

YEAR_MIN <- 1984L
YEAR_MAX <- 1999L

# --- input ---
dt <- readRDS(here("derived", "sample-mhs.Rds"))
dt <- dt[between(year, YEAR_MIN, YEAR_MAX) & !is.na(placements) & permits_sf > 0]

# pooled ratio within treated/control groups: sum across states, then divide
dt_agg <- dt[,
    .(placements = sum(placements, na.rm = TRUE),
      permits_sf = sum(permits_sf, na.rm = TRUE)),
    by = .(year, treated)
]
dt_agg[, ratio := placements / permits_sf]
dt_agg[, group := fifelse(treated == 1L, "Treated", "Control")]

# --- plot ---
v_palette <- c("#0072B2", "#D55E00")

theme_paper <- function(base_size = 14) {
    theme_classic(base_size = base_size) +
        theme(
            text = element_text(family = "serif"),
            legend.position = "right",
            panel.grid.major.y = element_line(color = "gray85", linewidth = 0.4),
            panel.grid.minor.y = element_blank()
        )
}

p <- ggplot(dt_agg, aes(x = year, y = ratio,
                         color = group, shape = group, linetype = group)) +
    geom_line() +
    geom_point(size = 2) +
    geom_vline(xintercept = 1993.5, linetype = "dotted", color = "black") +
    scale_color_manual(values = v_palette, name = NULL) +
    scale_shape_manual(values = c(16, 17), name = NULL) +
    scale_linetype_manual(values = c("solid", "dashed"), name = NULL) +
    scale_x_continuous(breaks = seq(YEAR_MIN, YEAR_MAX, 2)) +
    labs(x = "Year", y = "MH placements / SF permits") +
    theme_paper()

ggsave(here("output", "descriptives", "mhs-placement-ratio.pdf"), p, width = 9, height = 5)
