# Type-matched Census 2000 stock anchors for NFIP take-up.
# HCT006 counts occupied units by vintage and type. H030 counts all units
# by type, including vacant units. Apply the county x type all/occupied
# ratio to each vintage: this assumes vacancy is independent of vintage
# within county and type. Single-family includes attached and detached units.
# Keep this file separate from the occupied MH anchor used by welfare/MHS.
library(here)
library(data.table)
library(censusapi)
readRenviron(here(".Renviron"))

owner_sf <- sprintf("HCT006%03d", seq(4, 68, 8))
owner_mh <- sprintf("HCT006%03d", seq(9, 73, 8))
renter_sf <- sprintf("HCT006%03d", seq(77, 141, 8))
renter_mh <- sprintf("HCT006%03d", seq(82, 146, 8))
vars <- c(owner_sf, owner_mh, renter_sf, renter_mh,
          "H030002", "H030003", "H030010")
d <- as.data.table(getCensus(name = "dec/sf3", vintage = 2000,
    vars = vars, region = "county:*", regionin = "state:*"))
d[, countyfp := sprintf("%02d%03d", as.integer(state), as.integer(county))]
d <- d[as.integer(state) <= 56]
d[, (vars) := lapply(.SD, as.numeric), .SDcols = vars]
stopifnot(!anyNA(d[, ..vars]), all(as.matrix(d[, ..vars]) >= 0),
          uniqueN(d$countyfp) == nrow(d))
d[, sf_occupied_all := rowSums(.SD), .SDcols = c(owner_sf, renter_sf)]
d[, mh_occupied_all := rowSums(.SD), .SDcols = c(owner_mh, renter_mh)]
d[, sf_total_all := H030002 + H030003]
d[, mh_total_all := H030010]
stopifnot(all(d$sf_total_all >= d$sf_occupied_all),
          all(d$mh_total_all >= d$mh_occupied_all))
# No occupied units means no observed vintage composition to allocate. Leave
# these county-types unsupported instead of inventing a vintage distribution.
d[, sf_vacancy_factor := fifelse(sf_occupied_all > 0,
                               sf_total_all / sf_occupied_all, NA_real_)]
d[, mh_vacancy_factor := fifelse(mh_occupied_all > 0,
                               mh_total_all / mh_occupied_all, NA_real_)]
vintages <- c("1999_2000", "1995_1998", "1990_1994", "1980_1989")
out <- rbindlist(lapply(seq_along(vintages), function(i) {
    d[, .(countyfp, vintage_census = vintages[i],
          mh_occupied = get(owner_mh[i]) + get(renter_mh[i]),
          sf_occupied = get(owner_sf[i]) + get(renter_sf[i]),
          mh_vacancy_factor, sf_vacancy_factor)]
}))
out[, mh_units := fifelse(mh_occupied > 0, mh_occupied * mh_vacancy_factor, 0)]
out[, sb_units := fifelse(sf_occupied > 0, sf_occupied * sf_vacancy_factor, 0)]
stopifnot(!anyNA(out$mh_units), !anyNA(out$sb_units),
          uniqueN(out, by = c("countyfp", "vintage_census")) == nrow(out))
setorder(out, countyfp, vintage_census)
saveRDS(out, here("derived", "census2000-takeup-county-vintage.Rds"))
fwrite(d[, c("countyfp", vars), with = FALSE],
       here("derived", "census2000-takeup-source.csv"))
print(out[, .(mh_occupied = sum(mh_occupied), sf_occupied = sum(sf_occupied),
              mh_units = sum(mh_units), sb_units = sum(sb_units)), by = vintage_census])
