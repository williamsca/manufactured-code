# Raw surviving MH counts, separate wind-zone panels; no licensed data needed.
library(data.table)
library(ggplot2)
library(here)
x <- fread(here("output", "corelogic", "quantities", "mh_counts_by_vintage.csv"))
stopifnot(!anyDuplicated(x[, .(wind_zone, year_constr)]),
          all(is.finite(x$mh_homes)), all(x$mh_homes >= 0))
x[, zone := factor(wind_zone, levels = 1:3,
                   labels = c("Zone I", "Zone II", "Zone III"))]
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
ggsave(here("output", "corelogic", "quantities", "mh_raw_counts_by_zone.pdf"),
       p, width = 10, height = 4)
