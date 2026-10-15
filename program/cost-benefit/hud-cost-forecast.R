# HUD's ex ante production-cost forecast for the 1994 wind standard, expressed
# as a log change in manufactured-home price, by wind zone. Overlaid on the
# CoreLogic vintage price event study (Figure: MH prices by construction year).
#
# HUD forecasts cost separately for single- and multi-section homes in 1992
# dollars (notes/hud-wind-forecasts.csv, Table 4-16). CoreLogic does not record
# section type, so each zone's forecast is averaged over the single/multi mix
# of the states holding that zone's homes:
#
#   forecast_z = sum_st omega_{z,st} * sum_s share_{st,s} * log(1 + c_{z,s} / P_{st,s})
#
#   c_{z,s}      HUD production cost increase, zone z, section type s (1992 $)
#   P_{st,s}     MHS average sales price, state st, section type s, 1992 (1992 $)
#   share_{st,s} MHS placement share of section type s, state st, 1992
#   omega_{z,st} share of zone-z counties' 1989-1993 MH stock located in state st
#                (Census-imputed stock)
#
# Averaging section-specific log changes matches the event study, whose
# outcome is a mean log price. 1992 is HUD's dollar year, so no deflation is
# needed. States whose section-type cells are suppressed in the MHS drop out
# and the remaining weights are renormalized.
#
# Inputs:  notes/hud-wind-forecasts.csv, derived/mhs-state-year.Rds,
#          derived/stock-county-vintage.Rds, derived/ecfr-windzone.csv
# Output:  output/cost-benefit/hud-cost-forecast.csv

rm(list = ls())
library(here)
library(data.table)

BASE_YEAR <- 1992L
STOCK_VINTAGES <- 1989:1993

# HUD production cost by zone and section type ----
hud <- fread(here("notes", "hud-wind-forecasts.csv"))
hud <- hud[item == "production_cost" & zone %in% c("2", "3"),
           .(wind_zone = as.integer(zone),
             section_type = fifelse(section == "multi", "double", section),
             cost = lo)]
stopifnot(nrow(hud) == 4L, !anyDuplicated(hud, by = c("wind_zone", "section_type")))

# State weights within each treated zone ----
wz <- fread(here("derived", "ecfr-windzone.csv"))
wz[, countyfp := sprintf("%05d", as.integer(countyfp))]
stopifnot(!anyDuplicated(wz$countyfp))
stock <- readRDS(here("derived", "stock-county-vintage.Rds"))
stopifnot(uniqueN(stock, by = c("countyfp", "year_constr", "mh")) == nrow(stock))
stock <- merge(stock[mh == 1L & year_constr %in% STOCK_VINTAGES], wz,
               by = "countyfp", all.x = TRUE)
# Unmatched counties are Alaska boroughs and renumbered FIPS codes, none in a
# hurricane zone.
stopifnot(stock[is.na(wind_zone), sum(homes_n)] / sum(stock$homes_n) < 0.005)
stock <- stock[!is.na(wind_zone)]
omega <- stock[wind_zone >= 2L, .(homes = sum(homes_n)),
               by = .(wind_zone, statefp = as.integer(substr(countyfp, 1, 2)))]

# State section shares and prices ----
mhs <- readRDS(here("derived", "mhs-state-year.Rds"))[year == BASE_YEAR]
stopifnot(!anyDuplicated(mhs$statefp))
mhs <- melt(mhs[, .(statefp,
                    n_single = placements_single, n_double = placements_double,
                    p_single = avg_sales_price_single, p_double = avg_sales_price_double)],
            id.vars = "statefp", measure.vars = patterns(n = "^n_", p = "^p_"),
            variable.name = "section_type")
mhs[, section_type := c("single", "double")[section_type]]
# A state enters only if both section types are published.
mhs[, complete := all(!is.na(n) & n > 0 & !is.na(p)), by = statefp]
mhs <- mhs[complete == TRUE][, share := n / sum(n), by = statefp]

# Combine ----
x <- merge(omega, mhs, by = "statefp", allow.cartesian = TRUE)
x <- merge(x, hud, by = c("wind_zone", "section_type"))
x[, dlog := log(1 + cost / p)]
by_state <- x[, .(homes = homes[1], dlog = sum(share * dlog),
                  share_double = share[section_type == "double"]),
              by = .(wind_zone, statefp)]
coverage <- merge(omega[, .(homes_all = sum(homes)), by = wind_zone],
                  by_state[, .(homes_kept = sum(homes)), by = wind_zone], by = "wind_zone")
print(coverage[, .(wind_zone, stock_covered = homes_kept / homes_all)])
stopifnot(all(coverage$homes_kept / coverage$homes_all > 0.95))

out <- by_state[, .(forecast = weighted.mean(dlog, homes),
                    share_double = weighted.mean(share_double, homes)),
                by = wind_zone]
out <- merge(out, dcast(hud, wind_zone ~ section_type, value.var = "cost")[
    , .(wind_zone, cost_single = single, cost_double = double)], by = "wind_zone")
out[, comparison := fifelse(wind_zone == 2L, "Zone II minus Zone I", "Zone III minus Zone I")]
setorder(out, wind_zone)
print(out)
stopifnot(nrow(out) == 2L, all(out$forecast > 0 & out$forecast < 0.5))

dir.create(here("output", "cost-benefit"), showWarnings = FALSE, recursive = TRUE)
fwrite(out, here("output", "cost-benefit", "hud-cost-forecast.csv"))
