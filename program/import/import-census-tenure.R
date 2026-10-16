# Census 2000 occupied units by tenure x year built x type, all nine vintages.
#
# HCT006 cross-tabulates occupied units by tenure, year built, and units in
# structure. import-census.R pools owners and renters and keeps four vintages;
# this script keeps tenure and the pre-1980 vintages, which the Census 2000
# check on the CoreLogic quantity decline needs (program/estimate-census/).
# Site-built is "1, detached or attached" (HCT006 offset 1 within a block).
#
# Output (derived/): census2000-tenure-county-vintage.Rds, keyed
#   countyfp x vintage_census x tenure, with mh_units, sb_units, tot_units
#   (occupied units), and mh_total_h030 (all MH units incl. vacant, H030010).

library(here)
library(data.table)
library(censusapi)
readRenviron(here(".Renviron"))

vintages <- c("1999_2000", "1995_1998", "1990_1994", "1980_1989", "1970_1979",
              "1960_1969", "1950_1959", "1940_1949", "1939_earlier")
# Variable blocks of 8 per vintage; owner total starts at 003, renter at 076.
block <- function(start) start + 8 * (seq_along(vintages) - 1)
cols <- list(owner  = block(3),  renter = block(76))
getvars <- function(ids) sprintf("HCT006%03d", ids)

pull <- function(tenure) {
    start <- cols[[tenure]]
    vars <- c(getvars(start), getvars(start + 1), getvars(start + 6))
    d <- as.data.table(getCensus(name = "dec/sf3", vintage = 2000, vars = vars,
        region = "county:*", regionin = "state:*"))
    d <- d[as.integer(state) <= 56]
    d[, countyfp := sprintf("%02d%03d", as.integer(state), as.integer(county))]
    rbindlist(lapply(seq_along(vintages), function(i) {
        data.table(countyfp = d$countyfp, vintage_census = vintages[i], tenure = tenure,
            tot_units = as.integer(d[[getvars(start[i])]]),
            sb_units  = as.integer(d[[getvars(start[i] + 1)]]),
            mh_units  = as.integer(d[[getvars(start[i] + 6)]]))
    }))
}
out <- rbindlist(lapply(names(cols), pull))

h030 <- as.data.table(getCensus(name = "dec/sf3", vintage = 2000, vars = "H030010",
    region = "county:*", regionin = "state:*"))
h030 <- h030[as.integer(state) <= 56]
h030[, countyfp := sprintf("%02d%03d", as.integer(state), as.integer(county))]
out <- merge(out, h030[, .(countyfp, mh_total_h030 = as.integer(H030010))], by = "countyfp")

stopifnot(!anyNA(out), all(out[, .(tot_units, sb_units, mh_units)] >= 0),
          !anyDuplicated(out, by = c("countyfp", "vintage_census", "tenure")),
          all(out$tot_units >= out$sb_units + out$mh_units),
          uniqueN(out$countyfp) == 3141L)
out[, vintage_census := factor(vintage_census, levels = rev(vintages))]
setorder(out, countyfp, tenure, vintage_census)
saveRDS(out, here("derived", "census2000-tenure-county-vintage.Rds"))
message(sprintf("Saved derived/census2000-tenure-county-vintage.Rds: %d counties, %d rows",
                uniqueN(out$countyfp), nrow(out)))
