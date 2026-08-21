DISCOUNT_YEAR <- 2000L

MIN_YEAR_LOSS <- 1994
MAX_YEAR_LOSS <- 2023

MIN_YEAR_CONSTR <- 1983L
MAX_YEAR_CONSTR <- 1999L

# research-database curated snapshot of fema_nfip_claims / fema_nfip_policies.
# Pinned rather than resolved via rd_latest_version() so a paper's headline
# numbers don't silently move when a newer snapshot lands in the cache/S3;
# bump deliberately and re-run databuild-nfip.R. See program/import/UPDATE.md §5.5.
NFIP_VERSION <- "v2026-08-15"
