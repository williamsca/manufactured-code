# Impute county x construction-year x housing-type housing stock, used as the
# take-up denominator in estimate-nfip.R (`policies_per_home`) in place of the
# mismatched policies-per-SF-permit ratio (see TODO.md Chunk E).
#
# Levels come from Census 2000 (mh_units / total_units - mh_units, by county x
# vintage bin). Census counts a mobile home as a housing unit regardless of
# titling, so there is no chattel-titling gap in the levels.
#
# Within-bin YEAR allocation only is driven by lower-quality annual sources:
# MHS state-year placements for MH (broadcast to every county in the state,
# since MHS has no county detail); BPS county-year single-family permits for
# site-built, falling back to the state's permit shares when a county has
# zero or missing permits in a bin. Both sources are used only to split a
# Census-anchored bin TOTAL across years within that bin, so their own level
# bias (BPS undercounts non-permitting rural counties; MHS placements are a
# national/state series, not a county one) divides out of the ratio.
#
# Inputs:  derived/census2000-mh-county-vintage.Rds
#          derived/mhs-state-year.Rds
#          derived/permits-co.Rds
# Output:  derived/stock-county-vintage.Rds (countyfp x year_constr x mh, homes_n)

rm(list = ls()); gc()
library(here)
library(data.table)
library(stringr)

# Census vintage bins -> construction years retained within each bin.
# 1980-1983 dropped (no source distinguishes them from 1984+ within the
# 1980_1989 bin); 1994 dropped by default (July effective date +
# production/installation lags make it a mixed pre/post year).
bin_years <- list(
    "1980_1989" = 1984:1989,
    "1990_1994" = 1990:1993,
    "1995_1998" = 1995:1998,
    "1999_2000" = 1999L
)
n_years_bin <- lengths(bin_years)
year_to_bin <- setNames(rep(names(bin_years), n_years_bin), unlist(bin_years))
kept_years  <- unlist(bin_years, use.names = FALSE)

# ---------------------------------------------------------------------------
# 1. Census 2000 levels, by county x vintage bin ----
# ---------------------------------------------------------------------------

dt_vtg <- readRDS(here("derived", "census2000-mh-county-vintage.Rds"))
dt_vtg[, vintage_census := as.character(vintage_census)]
dt_vtg[, sb_units := total_units - mh_units]
stopifnot(all(dt_vtg$mh_units >= 0, na.rm = TRUE))
stopifnot(all(dt_vtg$sb_units >= 0, na.rm = TRUE))
stopifnot(uniqueN(dt_vtg[, .(countyfp, vintage_census)]) == nrow(dt_vtg))

counties <- unique(dt_vtg$countyfp)

# county x year_constr grid (year_constr restricted to kept years, tagged
# with its Census bin) crossed onto every county
grid <- rbindlist(lapply(names(bin_years), function(b) {
    CJ(countyfp = counties, year_constr = bin_years[[b]])[, vintage_census := b]
}))
grid[, statefp := substr(countyfp, 1, 2)]

# ---------------------------------------------------------------------------
# 2. MH within-bin shares: state-year MHS placements, broadcast to counties ----
# ---------------------------------------------------------------------------

dt_mhs <- readRDS(here("derived", "mhs-state-year.Rds"))
dt_mhs[, statefp := str_pad(statefp, width = 2, pad = "0")]
dt_mhs <- dt_mhs[year %in% kept_years, .(statefp, year, placements)]
dt_mhs[, placements := fifelse(is.na(placements), 0, placements)]
dt_mhs[, vintage_census := year_to_bin[as.character(year)]]

state_bin_tot <- dt_mhs[, .(tot = sum(placements)), by = .(statefp, vintage_census)]
dt_mhs <- merge(dt_mhs, state_bin_tot, by = c("statefp", "vintage_census"))
dt_mhs[, share_mh := fifelse(
    tot > 0, placements / tot, 1 / n_years_bin[vintage_census])]

grid <- merge(
    grid,
    dt_mhs[, .(statefp, vintage_census, year_constr = year, share_mh)],
    by = c("statefp", "vintage_census", "year_constr"),
    all.x = TRUE
)
# states with no MHS row at all in a bin (shouldn't happen, but fail loudly
# rather than silently drop stock) get an equal-weight fallback
grid[is.na(share_mh), share_mh := 1 / n_years_bin[vintage_census]]

# ---------------------------------------------------------------------------
# 3. Site-built within-bin shares: county-year BPS SF permits, with state
#    fallback where a county has zero/missing permits in the bin ----
# ---------------------------------------------------------------------------

dt_bps <- readRDS(here("derived", "permits-co.Rds"))
dt_bps[, countyfp := str_pad(as.character(as.integer(countyfp)), width = 5, pad = "0")]
dt_bps[, statefp  := substr(countyfp, 1, 2)]

# full county x kept-year grid so counties absent from BPS enter as explicit
# zeros (and so trigger the state fallback below) rather than as NA rows
full_bps <- CJ(countyfp = counties, year = kept_years)
full_bps[, statefp := substr(countyfp, 1, 2)]
full_bps <- merge(
    full_bps, dt_bps[year %in% kept_years, .(countyfp, year, permits_sf)],
    by = c("countyfp", "year"), all.x = TRUE
)
full_bps[is.na(permits_sf), permits_sf := 0]
full_bps[, vintage_census := year_to_bin[as.character(year)]]

county_bin_tot <- full_bps[, .(tot_co = sum(permits_sf)), by = .(countyfp, vintage_census)]
state_year_tot <- full_bps[, .(permits_st = sum(permits_sf)), by = .(statefp, year, vintage_census)]
state_bin_tot  <- state_year_tot[, .(tot_st = sum(permits_st)), by = .(statefp, vintage_census)]

full_bps <- merge(full_bps, county_bin_tot, by = c("countyfp", "vintage_census"))
full_bps <- merge(full_bps, state_year_tot, by = c("statefp", "year", "vintage_census"))
full_bps <- merge(full_bps, state_bin_tot,  by = c("statefp", "vintage_census"))

full_bps[, share_sb := fifelse(
    tot_co > 0, permits_sf / tot_co,
    fifelse(tot_st > 0, permits_st / tot_st, 1 / n_years_bin[vintage_census])
)]

grid <- merge(
    grid,
    full_bps[, .(countyfp, vintage_census, year_constr = year, share_sb)],
    by = c("countyfp", "vintage_census", "year_constr"),
    all.x = TRUE
)
stopifnot(!anyNA(grid$share_sb))
stopifnot(!anyNA(grid$share_mh))

# ---------------------------------------------------------------------------
# 4. Apply shares to Census bin totals, reshape to countyfp x year_constr x mh
# ---------------------------------------------------------------------------

grid <- merge(
    grid, dt_vtg[, .(countyfp, vintage_census, mh_units, sb_units)],
    by = c("countyfp", "vintage_census")
)
grid[, mh_n := mh_units * share_mh]
grid[, sb_n := sb_units * share_sb]

dt_stock <- rbind(
    grid[, .(countyfp, year_constr, mh = 1L, homes_n = mh_n, vintage_census)],
    grid[, .(countyfp, year_constr, mh = 0L, homes_n = sb_n, vintage_census)]
)
setkey(dt_stock, countyfp, year_constr, mh)

# ---------------------------------------------------------------------------
# 5. Validation ----
# ---------------------------------------------------------------------------

# uniqueness on the intended key
stopifnot(uniqueN(dt_stock[, .(countyfp, year_constr, mh)]) == nrow(dt_stock))
# no negative or missing homes_n
stopifnot(!anyNA(dt_stock$homes_n))
stopifnot(all(dt_stock$homes_n >= 0))

# adding-up: allocated years sum exactly (within floating-point tolerance)
# to the Census bin total they were split from
chk <- dt_stock[, .(alloc_tot = sum(homes_n)), by = .(countyfp, vintage_census, mh)]
chk_mh <- merge(chk[mh == 1L], dt_vtg[, .(countyfp, vintage_census, mh_units)],
                by = c("countyfp", "vintage_census"))
chk_sb <- merge(chk[mh == 0L], dt_vtg[, .(countyfp, vintage_census, sb_units)],
                by = c("countyfp", "vintage_census"))
stopifnot(all(abs(chk_mh$alloc_tot - chk_mh$mh_units) < 1e-6))
stopifnot(all(abs(chk_sb$alloc_tot - chk_sb$sb_units) < 1e-6))
message("Adding-up test passed: allocated years sum to Census bin totals.")

# stability: correlate each county's share of state MH stock across bins
dt_stock[, statefp := substr(countyfp, 1, 2)]
share_by_bin <- dt_stock[mh == 1L, .(mh_n = sum(homes_n)), by = .(countyfp, statefp, vintage_census)]
share_by_bin[, state_mh := sum(mh_n), by = .(statefp, vintage_census)]
share_by_bin[, county_share := fifelse(state_mh > 0, mh_n / state_mh, NA_real_)]
wide <- dcast(share_by_bin, countyfp ~ vintage_census, value.var = "county_share")
bin_pairs <- combn(names(bin_years), 2, simplify = FALSE)
for (p in bin_pairs) {
    r <- cor(wide[[p[1]]], wide[[p[2]]], use = "complete.obs")
    message(sprintf(
        "Correlation of county share of state MH stock, %s vs %s: %.3f",
        p[1], p[2], r))
}

# benchmark: national MH stock 1986-1999 (imputed) vs. cumulative MHS
# national shipments over the same years
dt_nat <- readRDS(here("derived", "mhs-national-year.Rds"))
ship_1986_99 <- dt_nat[year %in% 1986:1999, sum(shipments, na.rm = TRUE)]
stock_1986_99 <- dt_stock[mh == 1L & year_constr %in% 1986:1999, sum(homes_n)]
message(sprintf(
    "National MH stock 1986-1999 (imputed): %.0f units. Cumulative MHS shipments, same years: %.0f. Ratio: %.2f",
    stock_1986_99, ship_1986_99, stock_1986_99 / ship_1986_99))

dt_stock[, statefp := NULL]
dt_stock[, vintage_census := NULL]
setcolorder(dt_stock, c("countyfp", "year_constr", "mh", "homes_n"))

saveRDS(dt_stock, here("derived", "stock-county-vintage.Rds"))
message(sprintf(
    "Saved derived/stock-county-vintage.Rds: %d rows, %d counties, years %d-%d",
    nrow(dt_stock), uniqueN(dt_stock$countyfp),
    min(dt_stock$year_constr), max(dt_stock$year_constr)))
