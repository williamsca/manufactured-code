DISCOUNT_YEAR <- 2000L

MIN_YEAR_LOSS <- 1994
MAX_YEAR_LOSS <- 2023

# Discount rate and home lifespan for every present-value calculation in the
# paper (estimate-welfare.R, estimate-hud-comparison.R). These are HUD's own
# assumptions in its ex ante analysis of the 1994 wind standard: benefits
# discounted at 7% over a 33-year manufactured-home life.
HUD_DISCOUNT_RATE <- 0.07
HUD_LIFESPAN      <- 33L

# Winsorization cap for claim-level loss and payment outcomes, in $000 of 2000
# dollars. Rationale in estimate-nfip.R.
MAX_CLAIM_LOSS <- 1000

# The Census-anchored take-up designs use 1984-1999: two-year bins are
# anchored on 1993, and the imputed stock ends with the 1999 vintage.
MIN_YEAR_CONSTR <- 1984L
MAX_YEAR_CONSTR <- 1999L

# Construction-vintage window for the claim-level and policy-composition event
# studies, which bin construction years in twos anchored on 1993: 1988-1989,
# 1990-1991, 1992-1993 (reference), 1994-1995, 1996-1997, 1998-1999. The endpoint
# excludes the 2002 Florida Building Code,
# though it does not fully exclude Florida installation changes in 1999.
# Unlike take-up, these designs do not require the Census stock denominator.
MIN_YEAR_CONSTR_NFIP <- 1988L
MAX_YEAR_CONSTR_NFIP <- 1999L

# Baseline NFIP results use the counties subject to the 1994 wind reform.
# The wind-zone triple difference explicitly restores Zone I as a comparison.
NFIP_BASELINE_ZONES <- c(2L, 3L)

# Construction-vintage window for the CoreLogic transfer build. The estimators'
# CL_VINTAGES (program/estimate-corelogic/corelogic-mh-only.R) must lie inside it;
# the pinned build predates the 1988 estimation start and still spans 1985-1999.
MIN_YEAR_CONSTR_CL <- 1985L
MAX_YEAR_CONSTR_CL <- 1999L

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
MAX_YEAR_MHS <- 2004L
# First year of the post-period average reported as the headline price
# effect. Chattel lending for MH expanded through 1998-99 and collapsed from
# 2000, so averaging over 2000 onward measures the premium that persists
# after the lending boom rather than one inflated by it.
LASTING_START_MHS <- 2000L

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

# research-database curated snapshot of fhfa_hpi (FHFA county-level all-
# transactions HPI, 2000 = 100). Pinned like the other sources; read by
# import-fhfa-hpi.R to build the state housing price index that databuild-mhs.R
# uses to deflate MH prices.
FHFA_HPI_VERSION <- "v2026-10-19"

# Hosted CoreLogic full builds of the August 2023 delivery. Partial-state
# source versions must never be selected through rd_latest_version().
CORELOGIC_PB_VERSION <- "v2026-10-07"
CORELOGIC_OT_VERSION <- "v2026-10-07"
CORELOGIC_MIN_SALE_YEAR <- 1990L
CORELOGIC_MAX_SALE_YEAR <- 2023L
