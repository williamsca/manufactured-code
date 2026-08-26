# This script constructs a panel of state-year observations
# of MH prices and shipments

rm(list = ls())
library(here)
library(data.table)

source(here("program", "import", "project-params.R"))
source(here("program", "import", "rd-client.R"))
source(here("program", "import", "geo-coverage-checks.R"))

year_min <- 1985L
year_max <- 2003L

# import ----

# wind zone classification (research-database curated crosswalk, replaces
# the local eCFR scrape - see program/import/UPDATE.md §5.4/§6.3)
dt_wz <- rd_read("ecfr_wind_zone", version = ECFR_WIND_ZONE_VERSION)

dt_treat <- copy(dt_wz)
dt_treat[, statefp := substr(countyfp, 1, 2)]

dt_treat <- dt_treat[, .(wind_zone = max(wind_zone)), by = .(statefp)]

# continuous treatment intensity: MH-stock-weighted share of a state's
# 1980-2000 MH stock sitting in a Zone II/III county. Binary `treated`
# above is diluted (e.g. GA has one WZ2/3 county but is coded fully
# treated); this recovers within-treated-group variation in how much of
# the state's MH stock the reform actually bound on. AK is not in
# ecfr_wind_zone at all (see its catalog notes); any renamed/consolidated
# FIPS code with no match there defaults to Zone I.
dt_stock <- readRDS(here("derived", "census2000-mh-county-vintage.Rds"))
dt_stock <- dt_stock[, .(mh_stock = sum(mh_units)), by = countyfp]

dt_intensity <- merge(dt_stock, dt_wz, by = "countyfp", all.x = TRUE)
dt_intensity[is.na(wind_zone), wind_zone := 1L]
dt_intensity[, statefp := substr(countyfp, 1, 2)]

dt_intensity <- dt_intensity[, .(
    mh_stock      = sum(mh_stock),
    mh_stock_wz23 = sum(mh_stock * (wind_zone >= 2L))
), by = statefp]
dt_intensity[, treated_intensity := mh_stock_wz23 / mh_stock]

saveRDS(dt_intensity, here("derived", "mhs-windzone-intensity.Rds"))

# state names (census_mhs_state_year carries no state_name of its own)
dt_state <- rd_read("geo_state")[, .(statefp, state_name = name)]

# CPI
dt_cpi <- fread(here("derived", "cpi-bls.csv"))
dt_cpi <- dt_cpi[, .(cpi = mean(cpi)), by = year]

dt_cpi[, cpi := cpi / cpi[year == DISCOUNT_YEAR]]

# MHS sample
dt <- merge(rd_read("census_mhs_state_year"), dt_state, by = "statefp")
dt <- dt[!statefp %in% c("02", "15") & year %between% c(year_min, year_max)]

stopifnot(all(dt$survey_era == "pre_2014"))
dt[, survey_era := NULL]

# merge ----

# treatment status
dt <- merge(dt, dt_treat, by = "statefp", all.x = TRUE)

assert_geo_coverage(dt, "wind_zone", "statefp", "databuild-mhs.R: MHS panel x ecfr_wind_zone")

dt[, treated := (wind_zone >= 2)]
dt[, treated_wz3 := (wind_zone == 3)]

dt <- merge(
    dt, dt_intensity[, .(statefp, treated_intensity)],
    by = "statefp", all.x = TRUE)
dt[is.na(treated_intensity), treated_intensity := 0]

# high-intensity treated states only: FL, LA, MA (see notes/specs.md
# Chunk C for the state table with all intensities)
dt[, high_intensity := statefp %in% c("12", "22", "25")]

# Full state x treatment-status table, saved before the base-period-weight
# drop below removes a few small states from `dt`. Wind-zone treatment
# status is defined for every state regardless of whether it has 1988-1993
# shipment data, so map.R (which just draws treatment status, not the
# price sample) reads this instead of sample-mhs.Rds.
saveRDS(unique(dt[, .(statefp, state_name, treated)]),
        here("derived", "mhs-state-treatment.Rds"))

# CPI
dt <- merge(dt, dt_cpi[, .(year, cpi)], by = "year", all.x = TRUE)

stopifnot(!anyNA(dt$cpi))

# BPS single-family permits aggregated to state-year
dt_perm_state <- rd_read("census_bps")[
    , .(permits_sf = sum(permits_sf, na.rm = TRUE)), by = .(statefp, year)]
dt <- merge(dt, dt_perm_state, by = c("statefp", "year"), all.x = TRUE)

# define outcomes ----
v_price <- grep("avg_sales_price", names(dt), value = TRUE)
dt[, (v_price) := lapply(.SD, function(x) x / cpi), .SDcols = v_price]

v_price_ln <- paste0(v_price, "_ln")
dt[, (v_price_ln) := lapply(.SD, log), .SDcols = v_price]

v_ship <- grep("placements", names(dt), value = TRUE)
v_ship_ln <- paste0(v_ship, "_ln")
dt[, (v_ship_ln) := lapply(.SD, log), .SDcols = v_ship]

dt[, placements_permits_ratio    := fifelse(
    !is.na(permits_sf) & permits_sf > 0, placements / permits_sf, NA_real_)]
dt[, placements_permits_ratio_ln := log(placements_permits_ratio)]

# fixed-weight (Laspeyres) price index ----
# `avg_sales_price` is the placement-weighted mixture of the single- and
# multi-section averages, so a state-year with a rising multi-section
# share shows a rising average price even if neither type's price moved.
# The index replaces the state-year's own mix with a single national
# basket fixed in the pre-reform window, so no cross-state or over-time
# variation in the mix can enter the event-study coefficients.
v_base_years <- 1988:1993

dt[, n_sections  := placements_single + placements_double]
dt[, share_double := fifelse(n_sections > 0, placements_double / n_sections,
                             NA_real_)]

# National base-period placement shares. Summed over states, so a state
# with a mix atypical of the country contributes only via its size.
dt_base <- dt[year %in% v_base_years, .(
    n_single = sum(placements_single, na.rm = TRUE),
    n_double = sum(placements_double, na.rm = TRUE)
)]
BASE_WT_DOUBLE <- dt_base$n_double / (dt_base$n_single + dt_base$n_double)
BASE_WT_SINGLE <- 1 - BASE_WT_DOUBLE

stopifnot(BASE_WT_SINGLE > 0, BASE_WT_DOUBLE > 0)

dt[, avg_sales_price_fw :=
       BASE_WT_SINGLE * avg_sales_price_single +
       BASE_WT_DOUBLE * avg_sales_price_double]
dt[, avg_sales_price_fw_ln := log(avg_sales_price_fw)]

# National base prices by section type, used both to normalize the index
# and to build the composition-only counterfactual below. Placement-
# weighted across states within the base window.
BASE_P_SINGLE <- dt[year %in% v_base_years, weighted.mean(
    avg_sales_price_single, placements_single, na.rm = TRUE)]
BASE_P_DOUBLE <- dt[year %in% v_base_years, weighted.mean(
    avg_sales_price_double, placements_double, na.rm = TRUE)]

# 1993 = 100. A single national scalar, so the normalized index is exactly
# proportional to the dollar index and the two specifications return the
# same estimate in different units. Normalizing each state to its own 1993
# value would instead be a within-state rescaling, i.e. a different
# estimand, and is deliberately not what this does.
IDX_BASE_1993 <- dt[year == 1993L, {
    ps <- weighted.mean(avg_sales_price_single, placements_single, na.rm = TRUE)
    pd <- weighted.mean(avg_sales_price_double, placements_double, na.rm = TRUE)
    BASE_WT_SINGLE * ps + BASE_WT_DOUBLE * pd
}]

dt[, avg_sales_price_fw_idx := 100 * avg_sales_price_fw / IDX_BASE_1993]

# Composition-only counterfactual: the state-year's actual mix valued at
# fixed national base prices. Its event-study coefficient is the part of
# the raw average-price effect attributable purely to the mix shift, and
# raw ~ fixed-weight + composition + interaction.
dt[, avg_sales_price_comp :=
       (1 - share_double) * BASE_P_SINGLE + share_double * BASE_P_DOUBLE]

# Fixed pre-1994 placement weight, used for every MHS regression (state
# size in the base period, not the reform-era outcome itself).
# Contemporaneous placements are themselves an outcome of the reform, so
# weighting on them would condition on treatment; using a fixed pre-period
# mean instead avoids that. Every state is weighted the same way, off the
# mean over v_base_years (1988-1993) alone: states with no recorded
# shipments anywhere in that window (small-cell suppression, e.g.
# Connecticut, Rhode Island) get an undefined weight and are dropped
# below rather than given a different base period.
dt_wt <- dt[year %in% v_base_years, .(
    placements_base = mean(placements, na.rm = TRUE)), by = statefp]
dt_wt[is.nan(placements_base) | placements_base <= 0,
      placements_base := NA_real_]

dt <- merge(dt, dt_wt, by = "statefp", all.x = TRUE)

# States that report an average sales price somewhere in the panel but
# have no defined base-period weight are dropped entirely, so no state
# enters a price regression under a different weighting rule. DC has no
# price data at all, in any year, so it never enters v_price_states or
# v_drop_states; it stays in `dt` and drops out of every price regression
# via the outcome, not the weight.
v_price_states <- dt[!is.na(avg_sales_price), unique(statefp)]
v_drop_states  <- dt[statefp %in% v_price_states,
                      .(placements_base = placements_base[1]), by = statefp][
    is.na(placements_base), statefp]
n_dropped_states <- length(v_drop_states)
dt <- dt[!statefp %in% v_drop_states]

v_price_states <- dt[!is.na(avg_sales_price), unique(statefp)]
stopifnot(!anyNA(dt[statefp %in% v_price_states,
                     .(placements_base = placements_base[1]),
                     by = statefp]$placements_base))

# section-type long panel ----
# One row per state-year-section-type. Estimating on this recovers the
# fixed-weight index when both types are observed, but it also keeps the
# state-years where Census suppresses one type's price, and it allows the
# treatment effect to differ by section type.
dt_type <- melt(
    dt[, .(statefp, state_name, year, treated, treated_wz3, treated_intensity,
           high_intensity, placements_base,
           single = avg_sales_price_single,
           double = avg_sales_price_double)],
    id.vars = c("statefp", "state_name", "year", "treated", "treated_wz3",
                "treated_intensity", "high_intensity", "placements_base"),
    measure.vars  = c("single", "double"),
    variable.name = "section_type",
    value.name    = "price"
)
dt_type <- dt_type[!is.na(price)]
dt_type[, section_type := factor(as.character(section_type),
                                 levels = c("single", "double"))]
dt_type[, price_ln := log(price)]
dt_type[, base_wt := fifelse(section_type == "single",
                             BASE_WT_SINGLE, BASE_WT_DOUBLE)]

# Combined regression weight: state size (placements_base) x national
# section-type share (base_wt). Weighting the stacked panel by this
# product and pooling both types reproduces a placements_base-weighted
# regression on the fixed-weight index itself, when both types are
# observed for a state-year.
dt_type[, reg_wt := placements_base * base_wt]

stopifnot(nrow(dt_type) > 0, !anyNA(dt_type$base_wt),
          !anyNA(dt_type$reg_wt), all(dt_type$reg_wt > 0))

saveRDS(dt_type, here("derived", "sample-mhs-type.Rds"))

# sanity checks ----
# The reported average price should reproduce as the mix-weighted average
# of the two section-type prices; residual gaps are placement rounding
# (published to the nearest hundred), so a loose tolerance is expected.
dt_chk <- dt[!is.na(avg_sales_price) & !is.na(avg_sales_price_single) &
             !is.na(avg_sales_price_double) & n_sections > 0]
dt_chk[, p_mix := (placements_single * avg_sales_price_single +
                   placements_double * avg_sales_price_double) / n_sections]
stopifnot(dt_chk[, median(abs(p_mix / avg_sales_price - 1)) < 0.02])

# The index is defined only where both section-type prices are published.
stopifnot(dt[!is.na(avg_sales_price_fw),
             all(!is.na(avg_sales_price_single) &
                 !is.na(avg_sales_price_double))])

# uniqueness on the panel keys
stopifnot(!anyDuplicated(dt, by = c("statefp", "year")))
stopifnot(!anyDuplicated(dt_type, by = c("statefp", "year", "section_type")))

message(sprintf(
    "base weights (%d-%d): single %.3f, double %.3f | 1993 index base $%.0f",
    min(v_base_years), max(v_base_years),
    BASE_WT_SINGLE, BASE_WT_DOUBLE, IDX_BASE_1993))
message(sprintf(
    "index defined for %d of %d state-years (raw avg price: %d)",
    dt[!is.na(avg_sales_price_fw), .N], nrow(dt),
    dt[!is.na(avg_sales_price), .N]))
message(sprintf(
    "placements_base: defined for all %d price-reporting states (%d states dropped for no 1988-1993 shipments)",
    length(v_price_states), n_dropped_states))

# export ----
saveRDS(dt, here("derived", "sample-mhs.Rds"))
saveRDS(list(n_dropped_states = n_dropped_states,
             states = v_drop_states),
        here("derived", "mhs-dropped-states.Rds"))
