# Maps contiguous-US counties by HUD wind zone.
# Output: output/descriptives/map-mhs-windzone-counties.pdf

rm(list = ls())
library(here)
library(data.table)
library(ggplot2)
library(tigris)
library(sf)

source(here("program", "import", "project-params.R"))
source(here("program", "import", "rd-client.R"))

options(tigris_use_cache = TRUE)
Sys.setenv(TIGRIS_CACHE_DIR = file.path(tempdir(), "tigris"))

v_fill_county <- c("Zone I" = "#BDBDBD", "Zone II" = "#E6A099",
                   "Zone III" = "#C0392B")

theme_map <- function(base_size = 14) {
    theme_void(base_size = base_size) +
        theme(
            text = element_text(family = "serif"),
            legend.position = "bottom",
            legend.title = element_blank()
        )
}

# import ----
# Full state table (databuild-mhs.R), independent of the price-sample
# base-period-weight drop, so states with no 1988-1993 shipment data still
# appear on the map.
dt_map <- as.data.table(readRDS(here("derived", "mhs-state-treatment.Rds")))

stopifnot(uniqueN(dt_map$statefp) == nrow(dt_map))

dt_wz <- rd_read("ecfr_wind_zone", version = ECFR_WIND_ZONE_VERSION,
                 cols = c("countyfp", "wind_zone"))
stopifnot(!anyDuplicated(dt_wz$countyfp),
          !anyNA(dt_wz$wind_zone), all(dt_wz$wind_zone %in% 1:3))

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

# county wind-zone map ----
# Same contiguous-US state extent and pinned crosswalk as the treatment
# definitions in databuild-mhs.R; state outlines drawn on top.
us_counties <- counties(cb = TRUE, resolution = "5m", year = 2024, class = "sf")
us_counties <- us_counties[us_counties$STATEFP %in% us_states$STATEFP, ]
us_counties <- merge(
    us_counties,
    dt_wz,
    by.x = "GEOID",
    by.y = "countyfp",
    all.x = TRUE,
    sort = FALSE
)
stopifnot(!anyNA(us_counties$wind_zone))
us_counties$zone <- factor(
    us_counties$wind_zone,
    levels = 1:3,
    labels = c("Zone I", "Zone II", "Zone III")
)

p_county <- ggplot(us_counties) +
    geom_sf(aes(fill = zone), color = "white", linewidth = 0.05) +
    geom_sf(data = us_states, fill = NA, color = "white", linewidth = 0.2) +
    scale_fill_manual(values = v_fill_county, drop = FALSE) +
    coord_sf(datum = NA) +
    theme_map()

dir.create(here("output", "descriptives"), showWarnings = FALSE, recursive = TRUE)
ggsave(
    here("output", "descriptives", "map-mhs-windzone-counties.pdf"),
    p_county,
    width = 10,
    height = 6
)
