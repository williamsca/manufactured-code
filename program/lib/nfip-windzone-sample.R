# Apply the same county wind-zone definition to claims, policies, and stock.
# Call after loading rd-client.R, project-params.R, and geo-coverage-checks.R.
nfip_windzone_sample <- function(x, zones = NFIP_BASELINE_ZONES) {
    x <- data.table::copy(x)
    crosswalk <- rd_read("ecfr_wind_zone", version = ECFR_WIND_ZONE_VERSION)
    stopifnot(!anyDuplicated(crosswalk$countyfp), all(zones %in% 1:3))
    x[crosswalk, wind_zone := i.wind_zone, on = "countyfp"]
    assert_geo_coverage(x, "wind_zone", "countyfp", "NFIP wind-zone sample")
    x[wind_zone %in% zones]
}
