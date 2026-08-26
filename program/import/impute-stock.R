# Impute county x construction-year x housing-type housing stock, used as the
# take-up denominator in estimate-nfip.R (`policies_per_home`) in place of the
# mismatched policies-per-SF-permit ratio (see TODO.md Chunk E).
#
# Levels come from Census 2000 (mh_units / total_units - mh_units, by county x
# vintage bin). Census counts a mobile home as a housing unit regardless of
# titling, so there is no chattel-titling gap in the levels.
#
# Within-bin YEAR allocation only is driven by lower-quality annual sources.
# Shares are normalized over every year the Census bin spans, not over the
# subset retained below, so a bin whose span is only partly retained contributes
# only that fraction of its total (see bin_span).
#
# MHS state-year placements for MH (broadcast to every county in the state,
# since MHS has no county detail); BPS county-year single-family permits for
# site-built, falling back to the state's permit shares when a county has
# zero or missing permits in a bin. Both sources are used only to split a
# Census-anchored bin TOTAL across years within that bin, so their own level
# bias (BPS undercounts non-permitting rural counties; MHS placements are a
# national/state series, not a county one) divides out of the ratio.
#
# Inputs:  derived/census2000-mh-county-vintage.Rds
#          census_mhs_state_year, census_mhs_national_year, census_bps
#          (research-database, via rd_read() - see program/import/UPDATE.md)
# Output:  derived/stock-county-vintage.Rds (countyfp x year_constr x mh, homes_n)

rm(list = ls()); gc()
library(here)
library(data.table)

source(here("program", "import", "rd-client.R"))

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

# Every construction year each Census bin ACTUALLY spans, with the fraction of
# that year the bin covers. This is distinct from bin_years above: the within-bin
# shares must be normalized over the full span, so that dropping a year from
# bin_years drops its stock too instead of redistributing it onto the years that
# remain. Normalizing over kept years only would assign the whole 1980-1989
# Census total to 1984-1989 (a ~1.6x overstatement of those denominators) and
# the whole 1990-1994 total to 1990-1993 (~1.3x), which biases take-up rates
# downward before 1994 relative to after -- i.e. exactly along the treatment
# split. The last Census bin is "1999 to March 2000", so 2000 enters at 3/12.
bin_span <- rbindlist(list(
    data.table(vintage_census = "1980_1989", year = 1980:1989, yr_wt = 1),
    data.table(vintage_census = "1990_1994", year = 1990:1994, yr_wt = 1),
    data.table(vintage_census = "1995_1998", year = 1995:1998, yr_wt = 1),
    data.table(vintage_census = "1999_2000", year = 1999:2000, yr_wt = c(1, 3 / 12))
))
span_years <- unique(bin_span$year)
bin_span[, kept := year %in% kept_years]
# effective number of source years per bin, used for equal-weight fallbacks, and
# the fraction of each bin's span that is retained -- i.e. the fraction of the
# Census bin total the kept years are collectively entitled to
span_tot <- bin_span[, .(n_span = sum(yr_wt), n_kept = sum(yr_wt * kept)),
                     by = vintage_census]
n_span_bin <- span_tot[, setNames(n_span, vintage_census)]
kept_frac  <- span_tot[, setNames(n_kept / n_span, vintage_census)]
stopifnot(
    identical(sort(span_tot$vintage_census), sort(names(bin_years))),
    all(kept_frac > 0), all(kept_frac <= 1 + 1e-12)
)

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

dt_mhs <- rd_read("census_mhs_state_year")
dt_mhs <- dt_mhs[year %in% span_years, .(statefp, year, placements)]
dt_mhs[, placements := fifelse(is.na(placements), 0, placements)]
# bin tag and partial-year weight come from the full span, so the denominator
# below covers every year the Census bin includes
dt_mhs <- merge(dt_mhs, bin_span, by = "year")
dt_mhs[, placements := placements * yr_wt]

state_bin_tot <- dt_mhs[, .(tot = sum(placements)), by = .(statefp, vintage_census)]
dt_mhs <- merge(dt_mhs, state_bin_tot, by = c("statefp", "vintage_census"))
dt_mhs[, share_mh := fifelse(
    tot > 0, placements / tot, yr_wt / n_span_bin[vintage_census])]
# adding-up invariant, checked on the full span before the kept-year subset:
# each state x bin's shares must exhaust the bin exactly. The retained years then
# claim only their own shares, so the dropped years' stock is dropped, not
# redistributed. How much a bin retains is source-implied (placements-weighted),
# not the mechanical year-count fraction, which is why this is the exact test and
# the one in section 5 is a bound.
stopifnot(dt_mhs[, abs(sum(share_mh) - 1) < 1e-9, by = .(statefp, vintage_census)][, all(V1)])

grid <- merge(
    grid,
    dt_mhs[kept == TRUE, .(statefp, vintage_census, year_constr = year, share_mh)],
    by = c("statefp", "vintage_census", "year_constr"),
    all.x = TRUE
)
# states with no MHS row at all in a bin (shouldn't happen, but fail loudly
# rather than silently drop stock) get an equal-weight fallback
grid[is.na(share_mh), share_mh := 1 / n_span_bin[vintage_census]]

# ---------------------------------------------------------------------------
# 3. Site-built within-bin shares: county-year BPS SF permits, with state
#    fallback where a county has zero/missing permits in the bin ----
# ---------------------------------------------------------------------------

dt_bps <- rd_read("census_bps")
dt_bps[, statefp := substr(countyfp, 1, 2)]

# full county x span-year grid so counties absent from BPS enter as explicit
# zeros (and so trigger the state fallback below) rather than as NA rows
full_bps <- CJ(countyfp = counties, year = span_years)
full_bps[, statefp := substr(countyfp, 1, 2)]
full_bps <- merge(
    full_bps, dt_bps[year %in% span_years, .(countyfp, year, permits_sf)],
    by = c("countyfp", "year"), all.x = TRUE
)
full_bps[is.na(permits_sf), permits_sf := 0]
full_bps <- merge(full_bps, bin_span, by = "year")
full_bps[, permits_sf := permits_sf * yr_wt]

county_bin_tot <- full_bps[, .(tot_co = sum(permits_sf)), by = .(countyfp, vintage_census)]
state_year_tot <- full_bps[, .(permits_st = sum(permits_sf)), by = .(statefp, year, vintage_census)]
state_bin_tot  <- state_year_tot[, .(tot_st = sum(permits_st)), by = .(statefp, vintage_census)]

full_bps <- merge(full_bps, county_bin_tot, by = c("countyfp", "vintage_census"))
full_bps <- merge(full_bps, state_year_tot, by = c("statefp", "year", "vintage_census"))
full_bps <- merge(full_bps, state_bin_tot,  by = c("statefp", "vintage_census"))

full_bps[, share_sb := fifelse(
    tot_co > 0, permits_sf / tot_co,
    fifelse(tot_st > 0, permits_st / tot_st, yr_wt / n_span_bin[vintage_census])
)]
# same full-span adding-up invariant as for MH above
stopifnot(full_bps[, abs(sum(share_sb) - 1) < 1e-9, by = .(countyfp, vintage_census)][, all(V1)])

grid <- merge(
    grid,
    full_bps[kept == TRUE, .(countyfp, vintage_census, year_constr = year, share_sb)],
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

# adding-up: the retained years of a bin must never sum to MORE than the Census
# bin total (they sum to exactly the total only where the whole span is retained).
# The exact invariant -- shares exhausting each bin over its full span -- is
# asserted in sections 2 and 3 above; here the concern is that the kept-year
# subset did not inherit stock from the dropped years.
chk <- dt_stock[, .(alloc_tot = sum(homes_n)), by = .(countyfp, vintage_census, mh)]
chk_mh <- merge(chk[mh == 1L], dt_vtg[, .(countyfp, vintage_census, mh_units)],
                by = c("countyfp", "vintage_census"))
chk_sb <- merge(chk[mh == 0L], dt_vtg[, .(countyfp, vintage_census, sb_units)],
                by = c("countyfp", "vintage_census"))
stopifnot(all(chk_mh$alloc_tot <= chk_mh$mh_units * (1 + 1e-9) + 1e-6))
stopifnot(all(chk_sb$alloc_tot <= chk_sb$sb_units * (1 + 1e-9) + 1e-6))
# a fully retained bin must still add up exactly
full_bins <- names(kept_frac)[kept_frac > 1 - 1e-12]
stopifnot(all(abs(
    chk_mh[vintage_census %in% full_bins, alloc_tot - mh_units]) < 1e-6))
stopifnot(all(abs(
    chk_sb[vintage_census %in% full_bins, alloc_tot - sb_units]) < 1e-6))
message("Adding-up test passed: retained years never exceed their Census bin total; fully retained bins match exactly.")
# report the realized retained fraction against the year-count benchmark, so a
# future change to bin_years or bin_span shows up here rather than silently
realized <- rbind(
    chk_mh[, .(mh = 1L, frac = sum(alloc_tot) / sum(mh_units)), by = vintage_census],
    chk_sb[, .(mh = 0L, frac = sum(alloc_tot) / sum(sb_units)), by = vintage_census])
realized[, year_count_frac := kept_frac[vintage_census]]
message("Realized retained fraction of each Census bin total:")
print(realized[order(mh, vintage_census)])

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
dt_nat <- rd_read("census_mhs_national_year")
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
