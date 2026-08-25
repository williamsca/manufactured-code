DISCOUNT_YEAR <- 2000L

MIN_YEAR_LOSS <- 1994
MAX_YEAR_LOSS <- 2023

MIN_YEAR_CONSTR <- 1983L
MAX_YEAR_CONSTR <- 1999L

# estimate-mhs.R state-DiD sample window (state x year panel of MH prices
# and placements around the 1994 HUD wind standard).
MIN_YEAR_MHS <- 1988L
MAX_YEAR_MHS <- 2000L

# research-database curated snapshot of fema_nfip_claims / fema_nfip_policies.
# Pinned rather than resolved via rd_latest_version() so a paper's headline
# numbers don't silently move when a newer snapshot lands in the cache/S3;
# bump deliberately and re-run databuild-nfip.R. See program/import/UPDATE.md §5.5.
NFIP_VERSION <- "v2026-08-15"

# research-database curated snapshot of ecfr_wind_zone (24 CFR 3280.305 HUD
# wind zone crosswalk, formerly built locally by import-ecfr-windzone.R -
# see program/import/UPDATE.md §5.4/§6.3). Pinned for the same reason as
# NFIP_VERSION: this crosswalk defines treatment for both the MHS and NFIP
# designs, so an eCFR amendment must not silently move it.
ECFR_WIND_ZONE_VERSION <- "v2026-08-24"
