DISCOUNT_YEAR <- 2000L

MIN_YEAR_LOSS <- 1994
MAX_YEAR_LOSS <- 2023

# Construction-vintage window for the NFIP claim and policy designs. 1984-1999
# (Chunk I, 2026-08-26; was 1983-1999). Two reasons for the 1984 start: with
# two-year bins anchored so 1992-1993 is the last pre-treatment bin, 1984 makes
# every bin full (the 1983 start left a bin holding one construction year), and
# the take-up denominator homes_n (program/import/impute-stock.R) is only
# defined from 1984 on, since no source separates 1980-1983 inside the Census
# 1980_1989 vintage bin. 1999 is the last vintage with a homes_n value.
MIN_YEAR_CONSTR <- 1984L
MAX_YEAR_CONSTR <- 1999L

# Single-family-residential restriction on occupancy_type, shared by every
# NFIP claim and policy query (databuild-nfip.R, databuild-nfip-policy.R) so
# the two samples cannot drift apart. occupancy_type mixes two FEMA coding
# eras (see the fema_nfip_claims/fema_nfip_policies data dictionary): legacy
# 1-digit codes and 2-digit Risk Rating 2.0 codes. Kept codes are detached
# single-family residential under both eras, including manufactured homes:
#   1  = single family residence (legacy; also covers MH claims/policies
#        written before RR2.0, since the legacy scheme has no separate MH
#        occupancy code)
#   11 = single-family residential building, excepting a mobile home or a
#        single unit within a multi-unit building (RR2.0)
#   14 = residential mobile/manufactured home (RR2.0)
# Everything else is either non-residential (4, 6, 17, 18, 19) or multi-unit
# (2, 3, 12, 13, 15, 16), which is dropped: the diagnostic behind Chunk I's
# rewrite of the composition table found the site-built comparison group's
# 1980s coverage gaps traced largely to a tail of multi-family and
# commercial policies, not to MH selection (TODO.md Chunk J/K, 2026-08-26).
OCCUPANCY_TYPE_SF <- c(1L, 11L, 14L)

# estimate-mhs.R state-DiD sample window (state x year panel of MH prices
# and placements around the 1994 HUD wind standard).
MIN_YEAR_MHS <- 1988L
MAX_YEAR_MHS <- 2000L

# research-database curated snapshot of fema_nfip_claims / fema_nfip_policies.
# Pinned rather than resolved via rd_latest_version() so a paper's headline
# numbers don't silently move when a newer snapshot lands in the cache/S3;
# bump deliberately and re-run databuild-nfip.R. See program/import/UPDATE.md §5.5.
NFIP_VERSION <- "v2-2026-09-02"

# research-database curated snapshot of ecfr_wind_zone (24 CFR 3280.305 HUD
# wind zone crosswalk, formerly built locally by import-ecfr-windzone.R -
# see program/import/UPDATE.md §5.4/§6.3). Pinned for the same reason as
# NFIP_VERSION: this crosswalk defines treatment for both the MHS and NFIP
# designs, so an eCFR amendment must not silently move it.
ECFR_WIND_ZONE_VERSION <- "v2026-09-03"
