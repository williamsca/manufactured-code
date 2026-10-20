# Public county geography shared by the CoreLogic exclusion and design map.
# Use the same corrected HUD classification as the CoreLogic estimators.
cl_donut_counties <- function(counties, miles = 50) {
    stopifnot(length(miles) == 1L, is.finite(miles), miles >= 0,
              !anyDuplicated(counties$GEOID))
    geo <- data.table::data.table(countyfp = counties$GEOID,
        statefp = counties$STATEFP, name = counties$NAME)
    zones <- cl_windzone_counties(geo)
    counties <- counties[match(zones$countyfp, counties$GEOID), ]
    counties$wind_zone <- zones$wind_zone
    # s2 computes spherical polygon-to-polygon distances, including across water.
    # Pin the setting locally; do not change the caller's geometry backend.
    previous_s2 <- sf::sf_use_s2()
    on.exit(suppressMessages(sf::sf_use_s2(previous_s2)))
    suppressMessages(sf::sf_use_s2(TRUE))
    geometry <- sf::st_make_valid(sf::st_transform(counties, 4326))
    treated <- which(counties$wind_zone > 1L)
    control <- which(counties$wind_zone == 1L)
    counties$distance_to_treated_miles <- 0
    distances <- sf::st_distance(geometry[control, ], geometry[treated, ])
    counties$distance_to_treated_miles[control] <- apply(
        as.matrix(distances) / 1609.344, 1, min)
    counties$donut_excluded <- counties$wind_zone == 1L &
        counties$distance_to_treated_miles <= miles
    counties
}

cl_donut_geometry <- function() {
    path <- Sys.getenv("CORELOGIC_COUNTY_GEOMETRY")
    if (nzchar(path)) return(sf::st_read(path, quiet = TRUE))
    # Pre-2022 Connecticut counties match the licensed source's county codes;
    # current Census files instead contain incompatible planning-region IDs.
    tigris::counties(cb = TRUE, resolution = "5m", year = 2020, class = "sf")
}
