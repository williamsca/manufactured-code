# MH-only price event study and static ladder on CoreLogic sales.
# Usage: ./run_remote.sh estimate-corelogic estimate-corelogic-prices.R
rm(list = ls())
library(here)
cl_dir <- here("program", "estimate-corelogic")
source(file.path(cl_dir, "corelogic-setup.R"))
source(file.path(cl_dir, "corelogic-mh-only.R"))
source(file.path(cl_dir, "corelogic-windzone.R"))
source(file.path(cl_dir, "corelogic-price-sample.R"))
ref <- Sys.getenv("CORELOGIC_REFERENCE")
if (!nzchar(ref)) stop("Set CORELOGIC_REFERENCE")
geo_file <- file.path(ref, "geo_county.parquet")
wz <- cl_windzone_counties(read_corelogic(paste("SELECT countyfp,statefp,name FROM read_parquet(", quote_path(geo_file), ")")))
fwrite(wz, file.path(out_dir, "windzone_crosswalk.csv"))
dt <- cl_price_sample()
dt <- merge(dt, wz[, .(countyfp, wind_zone)], by = "countyfp", all.x = TRUE, sort = FALSE)
fwrite(dt[is.na(wind_zone), .(sales = .N), by = .(countyfp, mh)], file.path(out_dir, "unmatched_counties.csv"))
dt <- dt[!is.na(wind_zone)]
dt[, post := as.integer(year_constr >= 1994)]
# Transaction-weighted dollar bases for interpreting the log-price estimates.
# Keep these on the matched sale sample, before fixed-effect singleton removal.
fwrite(dt[mh == 1, .(sales = .N, mean_2000 = mean(sale_price_2000),
    median_2000 = as.numeric(median(sale_price_2000))), by = .(wind_zone, post)],
    file.path(out_dir, "mh_price_summary.csv"))
fwrite(dt[, .(sales = .N, parcels = uniqueN(clip), counties = uniqueN(countyfp)),
    by = .(mh, year_constr)], file.path(out_dir, "sample_by_vintage.csv"))
fwrite(dt[, .(sales = .N), by = .(mh, year_sale)], file.path(out_dir, "sample_by_sale_year.csv"))
fwrite(dt[, .(sales = .N, counties = uniqueN(countyfp), states = uniqueN(statefp)),
    by = .(wind_zone, mh, year_constr)], file.path(out_dir, "support_by_vintage.csv"))
models <- list()
# MH-only price event study: no site-built observations or type interactions.
dt[, `:=`(z2 = as.integer(wind_zone == 2), z3 = as.integer(wind_zone == 3))]
dt[, `:=`(post_z2 = post * z2, post_z3 = post * z3,
    post_mh_z2 = post_mh * z2, post_mh_z3 = post_mh * z3)]
mh_sales <- dt[mh == 1]
mh_model <- feols(cl_mh_only_formula(), mh_sales, vcov = ~countyfp, mem.clean = TRUE, lean = TRUE)
mh_tab <- cl_mh_only_coefficients(mh_model, "mh_only_dynamic")
fwrite(mh_tab, file.path(out_dir, "mh_only_vintage_coefficients.csv"))
fwrite(mh_sales[, .(sales = .N, counties = uniqueN(countyfp)), by = .(wind_zone, year_constr)],
    file.path(out_dir, "mh_only_support.csv"))
models[["mh_only_dynamic"]] <- mh_model
# Main paper figure: state x vintage FE, so zone contrasts use within-state variation.
# Florida has no Zone I county, so it informs III minus II but not either contrast with Zone I.
mh_state_model <- feols(cl_mh_only_formula(state = TRUE), mh_sales, vcov = ~countyfp, mem.clean = TRUE, lean = TRUE)
mh_state_tab <- cl_mh_only_coefficients(mh_state_model, "mh_only_dynamic_state_vintage_fe")
fwrite(mh_state_tab, file.path(out_dir, "mh_only_vintage_coefficients_state_vintage_fe.csv"))
models[["mh_only_dynamic_state_vintage_fe"]] <- mh_state_model
# HUD forecast overlay (program/cost-benefit/hud-benefit-forecast.R), if synced.
forecast_file <- here("output", "cost-benefit", "hud-benefit-forecast.csv")
cl_mh_only_paper_plot(mh_state_tab, out_dir,
    forecast = if (file.exists(forecast_file)) fread(forecast_file) else NULL)
cl_mh_only_compare_plot(mh_tab, mh_state_tab, out_dir)
# Size-adjusted static variants use positive dedicated living area and lot area.
dt <- cl_price_size_controls(dt)
fwrite(dt[, .(sales = .N, size_valid_sales = sum(valid_size)),
    by = .(wind_zone, mh, post)], file.path(out_dir, "size_sample_coverage.csv"))
# Three MH DiDs followed by three housing-type DDDs; the third of each adds size.
ladder <- cl_price_static_fits(dt)
cl_mh_static_table(ladder, file.path(out_dir, "mh_static_ladder.tex"))
fwrite(rbindlist(lapply(1:6, function(k) cl_coeftable(ladder$fits[[k]], paste0("ladder_", k))[,
    counties := ladder$counties[k]])), file.path(out_dir, "mh_static_ladder.csv"))
fwrite(rbindlist(lapply(names(ladder$common_sample), function(id)
    cl_coeftable(ladder$common_sample[[id]], id))), file.path(out_dir, "size_common_sample_coefficients.csv"))
models[paste0("mh_static_ladder_", 1:6)] <- ladder$fits
models[names(ladder$common_sample)] <- ladder$common_sample
saveRDS(models, file.path(out_dir, "models-private.rds"))

files <- file.path(cl_dir, c("estimate-corelogic-prices.R", "corelogic-setup.R",
    "corelogic-price-sample.R", "corelogic-windzone.R", "corelogic-mh-only.R"))
dir.create(file.path(out_dir, "source")); file.copy(files, file.path(out_dir, "source"))
write_json(list(status = "complete", build = input, slurm_job = Sys.getenv("SLURM_JOB_ID"),
    sale_rows = nrow(dt), specification_ids = names(models),
    mh_only_sales = nrow(mh_sales), mh_only_specification = "MH sales only; county x sale year and vintage FE; separate zone x vintage DiDs",
    mh_only_robustness = "Same MH-only price DiD with state x vintage FE in place of vintage FE",
    paper_figure_specification = "mh_only_dynamic_state_vintage_fe",
    mh_static_ladder = "Static post x zone II/III: (1)-(3) MH DiD, common vintage FE then state x vintage FE then size controls; (4)-(6) MH/SB DDD with both post x zone (site-built) and post x zone x MH terms and no county x vintage FE, type x vintage FE then state x type x vintage FE then type-specific size slopes",
    size_controls = "Log living_square_feet_all_buildings and log land_square_footage, pinned 2023 PB, clip and county matched; positive finite values only, no upper trimming or imputation; adjusted columns only",
    outcome = "Log land-inclusive sale price, annual CPI-U in 2000 dollars",
    sale_window = c(2000L, 2023L), construction_window = c(1989L, 1999L), reference_vintage = 1993L,
    vintage_1994 = "Own annual coefficient; included in static post (1994-1999)",
    treatment = "Zone II and zone III contrasts relative to zone I",
    weights = "Equal per transaction",
    source_build_manifest_md5 = unname(tools::md5sum(file.path(input, "manifest.json"))),
    code_reference_md5 = as.list(tools::md5sum(c(files, geo_file))),
    session = capture.output(sessionInfo())), file.path(out_dir, "manifest.json"), pretty = TRUE, auto_unbox = TRUE)
cat("COMPLETE", out_dir, "\n")
