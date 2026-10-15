# Coverage of near-new MH sales: candidate land-inclusive base price for HUD's
# cost forecast (program/cost-benefit/hud-cost-forecast.R). A near-new sale is
# an eligible MH sale within MAX_AGE years of the construction year, for the
# pre-reform vintages 1989-1993. Also reports the assessor land share of
# value for the same MH parcels, as a direct check on how much land the
# CoreLogic prices carry.
# Usage: ./run_remote.sh estimate-corelogic estimate-corelogic-new-sales.R
# Exports aggregates only; cells with fewer than MIN_CELL sales or parcels
# have their price statistics set to NA.
rm(list = ls())
library(here)
cl_dir <- here("program", "estimate-corelogic")
source(file.path(cl_dir, "corelogic-setup.R"))
source(file.path(cl_dir, "corelogic-windzone.R"))
MAX_AGE <- 2L
MIN_CELL <- 10L
VINTAGES <- 1989:1993

ref <- Sys.getenv("CORELOGIC_REFERENCE")
if (!nzchar(ref)) stop("Set CORELOGIC_REFERENCE")
wz <- cl_windzone_counties(read_corelogic(paste("SELECT countyfp,statefp,name FROM read_parquet(",
    quote_path(file.path(ref, "geo_county.parquet")), ")")))
wz <- wz[, .(countyfp, wind_zone)]

# Sales ----
sales <- read_corelogic(sprintf("SELECT countyfp, clip, mh, year_constr, year_sale, sale_amount,
    sale_price_2000,
    CAST(new_construction_indicator AS VARCHAR) AS new_construction_indicator FROM read_parquet(%s)
    WHERE eligible_sale AND countyfp IS NOT NULL AND year_constr BETWEEN 1984 AND 1999",
    quote_path(file.path(input, "sales", "*.parquet"))))
sales <- merge(sales, wz, by = "countyfp")
sales[, `:=`(age = year_sale - year_constr, statefp = substr(countyfp, 1, 2))]
stopifnot(!anyNA(sales$sale_amount), all(sales$sale_amount > 0))

suppress <- function(x, n_col = "sales", cols) {
    x[get(n_col) < MIN_CELL, (cols) := NA_real_]
    x
}
price_stats <- function(d) d[, .(sales = .N, parcels = uniqueN(clip), counties = uniqueN(countyfp),
    states = uniqueN(statefp),
    median_nominal = as.numeric(median(sale_amount)), mean_nominal = mean(sale_amount),
    mean_log_nominal = mean(log(sale_amount)),
    median_2000 = as.numeric(median(sale_price_2000)), mean_log_2000 = mean(log(sale_price_2000)),
    share_new_flag = mean(toupper(new_construction_indicator) %in% c("Y", "1", "T", "TRUE"), na.rm = TRUE))]
price_cols <- c("median_nominal", "mean_nominal", "mean_log_nominal", "median_2000",
    "mean_log_2000", "share_new_flag")

# Overall deed coverage: MH sales by sale year and zone, any vintage 1984-1999.
fwrite(sales[mh == 1, .(sales = .N, counties = uniqueN(countyfp)), by = .(wind_zone, year_sale)][
    order(wind_zone, year_sale)], file.path(out_dir, "mh_sales_by_sale_year.csv"))

near <- sales[mh == 1 & year_constr %in% VINTAGES & between(age, 0, MAX_AGE)]
fwrite(suppress(near[, price_stats(.SD), by = .(wind_zone, year_constr, age)][
    order(wind_zone, year_constr, age)], cols = price_cols),
    file.path(out_dir, "near_new_by_zone_vintage_age.csv"))
fwrite(suppress(near[, price_stats(.SD), by = .(wind_zone)][order(wind_zone)], cols = price_cols),
    file.path(out_dir, "near_new_by_zone.csv"))
fwrite(suppress(near[, price_stats(.SD), by = .(wind_zone, statefp)][order(wind_zone, statefp)],
    cols = price_cols), file.path(out_dir, "near_new_by_zone_state.csv"))
# Same window with age 0-1 only, to see how much the result depends on MAX_AGE.
fwrite(suppress(near[age <= 1, price_stats(.SD), by = .(wind_zone)][order(wind_zone)], cols = price_cols),
    file.path(out_dir, "near_new_age01_by_zone.csv"))

# Assessor land share for MH parcels of the pre-reform vintages ----
props <- read_corelogic(sprintf("SELECT countyfp, clip, year_built, land_value_calculated AS land,
    improvement_value_calculated AS impr, total_value_calculated AS total
    FROM read_parquet(%s) WHERE mh = 1 AND year_built BETWEEN %d AND %d",
    quote_path(file.path(input, "properties", "*.parquet")), min(VINTAGES), max(VINTAGES)))
props <- merge(props, wz, by = "countyfp")
props[, statefp := substr(countyfp, 1, 2)]
props[, valid := !is.na(land) & !is.na(impr) & land >= 0 & impr >= 0 & land + impr > 0]
land <- props[, .(parcels = .N, parcels_valid = sum(valid), counties = uniqueN(countyfp),
    land_share_mean = mean((land / (land + impr))[valid]),
    land_share_median = as.numeric(median((land / (land + impr))[valid])),
    land_share_aggregate = sum(land[valid]) / sum((land + impr)[valid]),
    share_zero_land = mean((land == 0)[valid])), by = .(wind_zone)][order(wind_zone)]
fwrite(suppress(land, "parcels_valid", c("land_share_mean", "land_share_median",
    "land_share_aggregate", "share_zero_land")), file.path(out_dir, "mh_land_share_by_zone.csv"))

write_json(list(status = "complete", max_age = MAX_AGE, min_cell = MIN_CELL, vintages = VINTAGES,
    near_new_sales = nrow(near)), file.path(out_dir, "manifest.json"), auto_unbox = TRUE)
print(near[, price_stats(.SD), by = wind_zone])
print(land)
