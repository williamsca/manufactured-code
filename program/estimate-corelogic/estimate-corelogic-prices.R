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
# Robustness: state x vintage FE, so zone contrasts use only within-state variation.
# Florida has no Zone I county, so it informs III minus II but not either contrast with Zone I.
mh_state_model <- feols(cl_mh_only_formula(state = TRUE), mh_sales, vcov = ~countyfp, mem.clean = TRUE, lean = TRUE)
mh_state_tab <- cl_mh_only_coefficients(mh_state_model, "mh_only_dynamic_state_vintage_fe")
fwrite(mh_state_tab, file.path(out_dir, "mh_only_vintage_coefficients_state_vintage_fe.csv"))
models[["mh_only_dynamic_state_vintage_fe"]] <- mh_state_model
cl_mh_only_paper_plot(mh_tab, out_dir)
cl_mh_only_compare_plot(mh_tab, mh_state_tab, out_dir)
# Static ladder on the full matched sale sample: (1)-(2) MH only, (3)-(4) MH vs site-built.
ladder <- cl_mh_static_fits(dt)
cl_mh_static_table(ladder, file.path(out_dir, "mh_static_ladder.tex"))
fwrite(rbindlist(lapply(1:4, function(k) cl_coeftable(ladder$fits[[k]], paste0("ladder_", k))[,
    counties := ladder$counties[k]])), file.path(out_dir, "mh_static_ladder.csv"))
models[paste0("mh_static_ladder_", 1:4)] <- ladder$fits
saveRDS(models, file.path(out_dir, "models-private.rds"))

files <- file.path(cl_dir, c("estimate-corelogic-prices.R", "corelogic-setup.R",
    "corelogic-price-sample.R", "corelogic-windzone.R", "corelogic-mh-only.R"))
dir.create(file.path(out_dir, "source")); file.copy(files, file.path(out_dir, "source"))
write_json(list(status = "complete", build = input, slurm_job = Sys.getenv("SLURM_JOB_ID"),
    sale_rows = nrow(dt), specification_ids = names(models),
    mh_only_sales = nrow(mh_sales), mh_only_specification = "MH sales only; county x sale year and vintage FE; separate zone x vintage DiDs",
    mh_only_robustness = "Same MH-only price DiD with state x vintage FE in place of vintage FE",
    mh_static_ladder = "Static post x zone II/III: (1) MH, county x sale year + vintage FE; (2) state x vintage FE; (3) MH and site-built, county x sale year x type + county x vintage + type x vintage FE; (4) state x vintage x type FE in place of type x vintage",
    outcome = "Log land-inclusive sale price, annual CPI-U in 2000 dollars",
    sale_window = c(2000L, 2023L), construction_window = c(1989L, 1999L), reference_vintage = 1993L,
    vintage_1994 = "Own annual coefficient; included in static post (1994-1999)",
    treatment = "Zone II and zone III contrasts relative to zone I",
    weights = "Equal per transaction",
    source_build_manifest_md5 = unname(tools::md5sum(file.path(input, "manifest.json"))),
    code_reference_md5 = as.list(tools::md5sum(c(files, geo_file))),
    session = capture.output(sessionInfo())), file.path(out_dir, "manifest.json"), pretty = TRUE, auto_unbox = TRUE)
cat("COMPLETE", out_dir, "\n")
