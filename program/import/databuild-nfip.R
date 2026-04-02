# Build balanced NFIP panel for continental US census block groups
#
# Inputs:  derived/nfip-claims.Rds       (from import-nfip-claims.R)
#          derived/nfip-policies.Rds     (from import-nfip-policy.R)
#          derived/ecfr-windzone.csv     (from import-windzone.R)
# Outputs: derived/nfip-balanced.Rds    (tractfp × period_loss × mh × period_constr)
#
# period_loss: 5-year bins (e.g., 1994 = 1994-1998, 1999 = 1999-2003)
# period:constr: 3-year bins

rm(list = ls())
library(here)
library(data.table)

year_min <- 1985L
year_max <- 2002L

# ---------------------------------------------------------------------------
# import ----
# ---------------------------------------------------------------------------

dt_raw    <- readRDS(here("derived", "nfip-claims.Rds"))
dt_pol    <- fread(
    here("derived", "nfip-policies.csv"), keepLeadingZeros = TRUE)
dt_treat  <- fread(
    here("derived", "ecfr-windzone.csv"), keepLeadingZeros = TRUE)

# ---------------------------------------------------------------------------
# aggregate claims to panel key ----
# ---------------------------------------------------------------------------

v_dmg <- c("net_building_pmt", "building_damage", "building_value",
           "contents_value",   "net_contents_pmt", "contents_damage",
           "building_covg",    "contents_covg")

dt_raw[, period_loss := ((year_loss - 1994L) %/% 5L) * 5L + 1994L]
dt_raw[, period_constr := ((year_constr - year_min) %/% 3L) * 3L + year_min]

dt_agg <- dt_raw[,
    c(.(claims_n = .N), lapply(.SD, sum, na.rm = TRUE)),
    by      = .(tractfp, period_loss, mh, period_constr),
    .SDcols = v_dmg
]
setnames(dt_agg, v_dmg, paste0(v_dmg, "_tot"))

# ---------------------------------------------------------------------------
# balance panel: ----
#   start with all exposed county-years (> 0 claims) after 1994
#   then balance over mh × construction vintage \in (year_min, year_max)
#   cells with no claims get zeros
# ---------------------------------------------------------------------------

exposed_cy <- unique(dt_agg[, .(tractfp, period_loss)])

bins_constr <- unique(((year_min:year_max - year_min) %/% 3L) * 3L + year_min)

grid <- exposed_cy[
    , CJ(mh = 0:1, period_constr = bins_constr),
    by = .(tractfp, period_loss)]
grid[, countyfp := substr(tractfp, 1, 5)]
grid[, statefp  := substr(tractfp, 1, 2)]

dt_balanced <- merge(
    grid, dt_agg,
    by    = c("tractfp", "period_loss", "mh", "period_constr"),
    all.x = TRUE
)
dt_balanced[, post1994 := as.integer(period_constr > 1994L)]

# ---------------------------------------------------------------------------
# merge treatment and policy data ----
# ---------------------------------------------------------------------------

# treatment is county-level; merge on countyfp derived from tractfp
dt_balanced <- merge(dt_balanced, dt_treat, by = "countyfp", all.x = TRUE)

# the NYC boroughs have a consolidated city-county government, so
# they do *not* appear in the COG crosswalk
dt_balanced[is.na(wind_zone) & statefp == "36", wind_zone := 1]

stopifnot(nrow(dt_balanced[is.na(wind_zone)]) == 0L)

dt_balanced[, treated    := (wind_zone >= 2)]
dt_balanced[, treated_wz3 := (wind_zone == 3)]
dt_balanced$wind_zone <- NULL

dt_pol[, period_loss := ((year - 1994L) %/% 5L) * 5L + 1994L]
dt_pol_period <- dt_pol[,
    .(policies_n    = sum(policies_n,    na.rm = TRUE),
      repl_cost_tot = sum(repl_cost_tot, na.rm = TRUE),
      policy_cost_tot = sum(policy_cost_tot, na.rm = TRUE)),
    by = .(tractfp, period_loss, mh, period_constr)
]

dt_balanced <- merge(
    dt_balanced,
    dt_pol_period,
    by    = c("tractfp", "period_loss", "mh", "period_constr"),
    all.x = TRUE
)

# impute zero policies for cells covered in the policy data (i.e., period >= 2009)
dt_balanced[is.na(policies_n) & period_loss >= 2009L, policies_n := 0L]

# ---------------------------------------------------------------------------
# derived outcomes ----
# ---------------------------------------------------------------------------

# impute missing claim outcomes with zeros
v_outcomes <- grep("_tot$|claims_n$", names(dt_balanced), value = TRUE)
for (col in v_outcomes) {
    set(dt_balanced, which(is.na(dt_balanced[[col]])), col, 0)
}

# per-claim averages (claims-derived fields only)
v_pol_tot  <- c("repl_cost_tot", "policy_cost_tot")
v_clm_tot  <- setdiff(grep("_tot$", names(dt_balanced), value = TRUE), v_pol_tot)
v_clm_avg  <- gsub("_tot$", "_pclaim", v_clm_tot)
dt_balanced[, (v_clm_avg) := lapply(
    .SD, function(x) fifelse(claims_n > 0, x / claims_n, NA_real_)),
    .SDcols = v_clm_tot]

# damage shares
v_shares_value <- c(
    "building_damage_tot", "net_building_pmt_tot")

v_shares <- paste0(gsub("_tot", "_share", v_shares_value))
dt_balanced[, (v_shares) := lapply(
    .SD, function(x) 100 * fifelse(
        building_value_tot > 0, x / building_value_tot, NA_real_)),
    .SDcols = v_shares_value]

# per-policy averages (policy-derived fields)
v_pol_avg  <- gsub("_tot$", "_ppol", v_pol_tot)
dt_balanced[, (v_pol_avg) := lapply(
    .SD, function(x) fifelse(!is.na(policies_n) & policies_n > 0L, x / policies_n, NA_real_)),
    .SDcols = v_pol_tot]

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

setkey(dt_balanced, tractfp, period_loss, mh, period_constr)

saveRDS(dt_balanced, here("derived", "nfip-balanced.Rds"))
message(sprintf(
    "Saved balanced panel: %d rows (%d tract-periods x 2 MH x %d vintage years)",
    nrow(dt_balanced), uniqueN(dt_balanced[, .(tractfp, period_loss)]),
    length(unique(dt_balanced$period_constr))))
