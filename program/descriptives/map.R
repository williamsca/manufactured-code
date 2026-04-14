# This script creates a map of US states colored by treatment status
# from the manufactured housing sample.
# Output: output/descriptives/map-mhs-treated-states.pdf

rm(list = ls())
library(here)
library(data.table)
library(ggplot2)
library(tigris)
library(sf)

options(
    tigris_use_cache = TRUE,
    tigris_cache_dir = file.path(tempdir(), "tigris")
)

v_fill <- c("Control" = "#BDBDBD", "Treated" = "#C0392B")

theme_map <- function(base_size = 14) {
    theme_void(base_size = base_size) +
        theme(
            text = element_text(family = "serif"),
            legend.position = "bottom",
            legend.title = element_blank()
        )
}

# import ----
dt <- as.data.table(readRDS(here("derived", "sample-mhs.Rds")))

dt_map <- unique(dt[, .(statefp, state_name, treated)])

stopifnot(uniqueN(dt_map$statefp) == nrow(dt_map))

# shapefile ----
us_states <- states(cb = TRUE, resolution = "20m", year = 2024, class = "sf")
us_states <- us_states[
    !us_states$STUSPS %in% c("AK", "HI", "PR", "VI", "MP", "GU", "AS"),
]

us_states <- merge(
    us_states,
    dt_map,
    by.x = "STATEFP",
    by.y = "statefp",
    all.x = FALSE,
    all.y = TRUE,
    sort = FALSE
)

stopifnot(!anyNA(us_states$treated))

us_states$group <- ifelse(us_states$treated, "Treated", "Control")

# map ----
p <- ggplot(us_states) +
    geom_sf(aes(fill = group), color = "white", linewidth = 0.2) +
    scale_fill_manual(values = v_fill) +
    coord_sf(datum = NA) +
    theme_map()

ggsave(
    here("output", "descriptives", "map-mhs-treated-states.pdf"),
    p,
    width = 10,
    height = 6
)
