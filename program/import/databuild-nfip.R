# Build balanced NFIP panel for continental US census block groups
#
# Inputs:  derived/nfip-claims.Rds       (from import-nfip-claims.R)
#          derived/nfip-policies.Rds     (from import-nfip-policy.R)
#          derived/ecfr-windzone.csv     (from import-windzone.R)
# Outputs: derived/nfip-balanced.Rds    (bgfp × year_loss × mh × year_constr)

rm(list = ls())
library(here)
library(data.table)

year_min <- 1984L
year_max <- 2005L

# ---------------------------------------------------------------------------
# import ----
# ---------------------------------------------------------------------------

dt_raw    <- readRDS(here("derived", "nfip-claims.Rds"))
dt_pol    <- fread(
    here("derived", "nfip-policies.Rds"), keepLeadingZeros = TRUE)
dt_treat  <- fread(
    here("derived", "ecfr-windzone.csv"), keepLeadingZeros = TRUE)

# ---------------------------------------------------------------------------
# aggregate claims to panel key ----
# ---------------------------------------------------------------------------

v_dmg <- c("net_building_pmt", "building_damage", "building_value",
           "contents_value",   "net_contents_pmt", "contents_damage",
           "building_covg",    "contents_covg")

dt_agg <- dt_raw[,
    c(.(claims_n = .N), lapply(.SD, sum, na.rm = TRUE)),
    by      = .(bgfp, year_loss, mh, year_constr),
    .SDcols = v_dmg
]
setnames(dt_agg, v_dmg, paste0(v_dmg, "_tot"))

# ---------------------------------------------------------------------------
# balance panel: ----
#   start with all exposed county-years (> 0 claims) after 1994
#   then balance over mh × construction vintage \in (year_min, year_max)
#   cells with no claims get zeros
# ---------------------------------------------------------------------------

exposed_cy <- unique(dt_agg[year_loss > 1994L, .(bgfp, year_loss)])

grid <- exposed_cy[
    , CJ(mh = 0:1, year_constr = year_min:year_max),
    by = .(bgfp, year_loss)]
grid[, countyfp := substr(bgfp, 1, 5)]
grid[, statefp  := substr(bgfp, 1, 2)]

dt_balanced <- merge(
    grid, dt_agg,
    by    = c("bgfp", "year_loss", "mh", "year_constr"),
    all.x = TRUE
)
dt_balanced[, post1994 := as.integer(year_constr > 1994L)]

# ---------------------------------------------------------------------------
# merge treatment and policy data ----
# ---------------------------------------------------------------------------

# treatment is county-level; merge on countyfp derived from bgfp
dt_balanced <- merge(dt_balanced, dt_treat, by = "countyfp", all.x = TRUE)

# the NYC boroughs have a consolidated city-county government, so
# they do *not* appear in the COG crosswalk
dt_balanced[is.na(wind_zone) & statefp == "36", wind_zone := 1]

stopifnot(nrow(dt_balanced[is.na(wind_zone)]) == 0L)

dt_balanced[, treated    := (wind_zone >= 2)]
dt_balanced[, treated_wz3 := (wind_zone == 3)]
dt_balanced$wind_zone <- NULL

dt_balanced <- merge(
    dt_balanced,
    dt_pol[, .(bgfp, year_loss = year, mh, year_constr,
               policies_n, repl_cost_tot, policy_cost_tot)],
    by    = c("bgfp", "year_loss", "mh", "year_constr"),
    all.x = TRUE
)

# impute zero policies for cells which are covered
# in the policy data (i.e., after 2009)
dt_balanced[is.na(policies_n) & year_loss >= 2009L, policies_n := 0L]

# ---------------------------------------------------------------------------
# derived outcomes ----
# ---------------------------------------------------------------------------

# impute missing claim outcomes with zeros
v_outcomes <- grep("_tot$|claims_n$", names(dt_balanced), value = TRUE)
for (col in v_outcomes) {
    set(dt_balanced, which(is.na(dt_balanced[[col]])), col, 0)
}

# per-claim averages
v_tot <- grep("_tot$", names(dt_balanced), value = TRUE)
v_avg <- gsub("_tot$", "_pclaim", v_tot)
dt_balanced[, (v_avg) := lapply(
    .SD, function(x) fifelse(claims_n > 0, x / claims_n, NA_real_)),
    .SDcols = v_tot]

# claim rate: claims per policy in force that year
# NA where the county × year × cell has no policy records (coverage gap)
dt_balanced[, claim_rate := fifelse(
    !is.na(policies_n) & policies_n > 0L,
    claims_n / policies_n,
    NA_real_
)]

message(sprintf(
    "Policy merge: %.1f%% of panel cells have policy coverage",
    100 * dt_balanced[!is.na(policies_n), .N] / nrow(dt_balanced)
))

setkey(dt_balanced, bgfp, year_loss, mh, year_constr)

saveRDS(dt_balanced, here("derived", "nfip-balanced.Rds"))
message(sprintf(
    "Saved balanced panel: %d rows (%d BG-years x 2 MH x %d vintage years)",
    nrow(dt_balanced), uniqueN(dt_balanced[, .(bgfp, year_loss)]),
    length(unique(dt_balanced$year_constr))))
