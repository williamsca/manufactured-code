# This script builds a state-year house price index from the research-
# database fhfa_hpi dataset (FHFA county-level all-transactions HPI,
# 2000 = 100). The state index is the weighted geometric mean of county
# indices over a fixed set of counties, so changes in county coverage cannot
# move it. Weights are owner-occupied units built before 1990 (Census 2000),
# fixed and predetermined with respect to the 1994 wind standard. Used by
# databuild-mhs.R to deflate MH prices by the state housing cycle.

rm(list = ls())
library(here)
library(data.table)

source(here("program", "import", "project-params.R"))
source(here("program", "import", "rd-client.R"))

# import ----
dt <- rd_read("fhfa_hpi", version = FHFA_HPI_VERSION)
dt <- dt[year %between% c(MIN_YEAR_MHS, MAX_YEAR_MHS)]

dt_ten <- readRDS(here("derived", "census2000-tenure-county-vintage.Rds"))
dt_wt <- dt_ten[tenure == "owner" &
                vintage_census %in% c("1939_earlier", "1940_1949", "1950_1959",
                                      "1960_1969", "1970_1979", "1980_1989"),
                .(wt = sum(tot_units)), by = countyfp]

# clean ----
# Fixed county set: a county enters only if its index is observed in every
# year of the estimation window, and only if it has a weight.
n_years <- MAX_YEAR_MHS - MIN_YEAR_MHS + 1L
dt_cov <- dt[, .(n_obs = sum(!is.na(hpi))), by = countyfp]
v_keep <- dt_cov[n_obs == n_years, countyfp]

message(sprintf("counties with a full %d-%d index: %d of %d",
                MIN_YEAR_MHS, MAX_YEAR_MHS, length(v_keep), nrow(dt_cov)))
message(sprintf("  dropped for no Census 2000 weight: %s",
                paste(setdiff(v_keep, dt_wt$countyfp), collapse = ", ")))

dt <- merge(dt[countyfp %in% v_keep], dt_wt, by = "countyfp")
dt <- dt[wt > 0]
stopifnot(!anyNA(dt$hpi), all(dt$hpi > 0), !anyNA(dt$wt))
dt[, statefp := substr(countyfp, 1, 2)]

dt_state <- dt[, .(
    hpi_state  = exp(weighted.mean(log(hpi), wt)),
    n_counties = uniqueN(countyfp)
), by = .(statefp, year)]

# Share of each state's weighted housing stock the index covers, as a check
# on states whose index rests on a few counties.
dt_all <- dt_wt[, .(wt_all = sum(wt)), by = .(statefp = substr(countyfp, 1, 2))]
dt_use <- unique(dt[, .(countyfp, wt, statefp)])[, .(wt_use = sum(wt)), by = statefp]
dt_state <- merge(dt_state, merge(dt_all, dt_use, by = "statefp"), by = "statefp")
dt_state[, cover := wt_use / wt_all]
dt_state[, c("wt_all", "wt_use") := NULL]

setorder(dt_state, statefp, year)

# sanity checks ----
stopifnot(!anyDuplicated(dt_state, by = c("statefp", "year")))
stopifnot(!anyNA(dt_state$hpi_state))
stopifnot(dt_state[, .N, by = statefp][, all(N == n_years)])
message(sprintf("state index: %d states; median %d counties, coverage of weighted stock %.2f (min %.2f)",
                uniqueN(dt_state$statefp),
                as.integer(median(dt_state[year == MIN_YEAR_MHS, n_counties])),
                dt_state[year == MIN_YEAR_MHS, median(cover)],
                dt_state[year == MIN_YEAR_MHS, min(cover)]))
message("states missing: ",
        paste(setdiff(sprintf("%02d", c(1, 4:6, 8:13, 16:42, 44:51, 53:56)),
                      dt_state$statefp), collapse = ", "))

# export ----
fwrite(dt_state, here("derived", "hpi-state.csv"))
