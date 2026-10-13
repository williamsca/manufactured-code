# Zone-specific MH vintage price DDDs and a three-column static III-minus-I table.
# Usage: ./run_remote.sh corelogic estimate-corelogic-prices.R
rm(list = ls())
library(here)
source(here("program", "lib", "corelogic-setup.R"))
source(here("program", "lib", "corelogic-prices.R"))
source(here("program", "lib", "corelogic-price-table.R"))
source(here("program", "lib", "corelogic-mh-only.R"))
source(here("program", "lib", "corelogic-ddd.R"))
source(here("program", "lib", "corelogic-windzone.R"))
source(here("program", "lib", "corelogic-price-sample.R"))
ref <- Sys.getenv("CORELOGIC_REFERENCE")
if (!nzchar(ref)) stop("Set CORELOGIC_REFERENCE")
geo_file <- file.path(ref, "geo_county.parquet")
wz <- cl_windzone_counties(read_corelogic(paste("SELECT countyfp,statefp,name FROM read_parquet(", quote_path(geo_file), ")")))
fwrite(wz, file.path(out_dir, "windzone_crosswalk.csv"))
dt <- cl_price_sample(with_tracts = TRUE, with_sizes = TRUE)
dt <- merge(dt, wz[, .(countyfp, wind_zone)], by = "countyfp", all.x = TRUE, sort = FALSE)
fwrite(dt[is.na(wind_zone), .(sales = .N), by = .(countyfp, mh)], file.path(out_dir, "unmatched_counties.csv"))
dt <- dt[!is.na(wind_zone)]
dt[, post := as.integer(year_constr >= 1994)]
dt[, size_ok := is.finite(lot_sqft) & lot_sqft > 0 & is.finite(living_sqft) & living_sqft > 0]
dt[, `:=`(log_lot = fifelse(size_ok, log(pmax(lot_sqft, 1)), NA_real_),
    log_living = fifelse(size_ok, log(pmax(living_sqft, 1)), NA_real_))]
fwrite(dt[, .(sales = .N), by = .(wind_zone, mh, post, tract_ok, size_ok)],
    file.path(out_dir, "static_sample_coverage.csv"))
dt[, `:=`(mh_tr = mh * (wind_zone >= 2), mh_z2 = mh * (wind_zone == 2), mh_z3 = mh * (wind_zone == 3))]
dt[, `:=`(post_mh_tr = post_mh * (wind_zone >= 2), post_mh_z2 = post_mh * (wind_zone == 2),
    post_mh_z3 = post_mh * (wind_zone == 3))]
fwrite(dt[, .(sales = .N, parcels = uniqueN(clip), counties = uniqueN(countyfp)),
    by = .(mh, year_constr)], file.path(out_dir, "sample_by_vintage.csv"))
fwrite(dt[, .(sales = .N), by = .(mh, year_sale)], file.path(out_dir, "sample_by_sale_year.csv"))
fwrite(dt[, .(sales = .N, counties = uniqueN(countyfp), states = uniqueN(statefp)),
    by = .(wind_zone, mh, year_constr)], file.path(out_dir, "support_by_vintage.csv"))

# Annual figure retains all matched eligible sales and the original joint-zone model.
models <- list(); tabs <- list()
cat("Estimating separate_dynamic N=", nrow(dt), "\n")
m <- feols(cl_ddd_formula(by_zone = TRUE, dynamic = TRUE), data = dt,
    vcov = ~countyfp, mem.clean = TRUE, lean = TRUE)
tab <- cl_coeftable(m, "separate_dynamic")
tab[, `:=`(mh_input = sum(dt$mh), counties_input = uniqueN(dt$countyfp))]
for (key in c("mh", "mh_z2", "mh_z3")) {
    terms <- tab[grepl(paste0(":", key, "$"), term), term]
    observed <- as.integer(sub("year_constr::([0-9]+):.*", "\\1", terms))
    stopifnot(setequal(setdiff(sort(unique(dt$year_constr)), 1993L), observed))
}
fwrite(tab, file.path(out_dir, "vintage_coefficients.csv"))
models[["separate_dynamic"]] <- m

# Fully static pre/post model: collapse the vintage lower-order effects to post x zone.
# Select the controlled model's retained observations so all table columns have identical N.
x <- dt[tract_ok & size_ok]
static_input <- nrow(x)
cat("Estimating tract_size_static N=", nrow(x), "\n")
m <- feols(cl_ddd_formula(by_zone = TRUE, controls = "+ log_lot + log_living",
    tract = TRUE, annual_vintage = FALSE), data = x, vcov = ~countyfp, mem.clean = TRUE)
retained <- obs(m)
x <- x[retained]
static_n <- nrow(x)
fwrite(x[, .(sales = .N, counties = uniqueN(countyfp)), by = .(wind_zone, mh, post)],
    file.path(out_dir, "static_support.csv"))
tabs[["tract_size_static"]] <- cl_coeftable(m, "tract_size_static")
models[["tract_size_static"]] <- summary(m, lean = TRUE)
rm(m); gc()
for (id in c("baseline_static", "tract_static")) {
    cat("Estimating", id, "N=", nrow(x), "\n")
    m <- feols(cl_ddd_formula(by_zone = TRUE, tract = id == "tract_static", annual_vintage = FALSE),
        data = x, vcov = ~countyfp, mem.clean = TRUE, lean = TRUE)
    stopifnot(nobs(m) == static_n)
    tabs[[id]] <- cl_coeftable(m, id)
    models[[id]] <- m
}
static <- rbindlist(tabs)
stopifnot(all(c("post_mh", "post_mh_z2", "post_mh_z3") %in% static$term))
static[, `:=`(mh_input = sum(x$mh), counties_input = uniqueN(x$countyfp), sales_input = static_input)]
fwrite(static, file.path(out_dir, "post_coefficients.csv"))
cl_price_static_table(models, out_dir)
# MH-only price event study: no site-built observations or type interactions.
dt[, `:=`(z2 = as.integer(wind_zone == 2), z3 = as.integer(wind_zone == 3))]
dt[, `:=`(post_z2 = post * z2, post_z3 = post * z3)]
mh_sales <- dt[mh == 1]
mh_model <- feols(cl_mh_only_formula(), mh_sales, vcov = ~countyfp, mem.clean = TRUE, lean = TRUE)
mh_tab <- cl_mh_only_coefficients(mh_model, "mh_only_dynamic")
fwrite(mh_tab, file.path(out_dir, "mh_only_vintage_coefficients.csv"))
fwrite(mh_sales[, .(sales = .N, counties = uniqueN(countyfp)), by = .(wind_zone, year_constr)],
    file.path(out_dir, "mh_only_support.csv"))
cl_mh_only_plot(mh_tab, out_dir)
models[["mh_only_dynamic"]] <- mh_model
# Robustness: state x vintage FE, so zone contrasts use only within-state variation.
# Florida has no Zone I county, so it informs III minus II but not either contrast with Zone I.
mh_state_model <- feols(cl_mh_only_formula(state = TRUE), mh_sales, vcov = ~countyfp, mem.clean = TRUE, lean = TRUE)
mh_state_tab <- cl_mh_only_coefficients(mh_state_model, "mh_only_dynamic_state_vintage_fe")
fwrite(mh_state_tab, file.path(out_dir, "mh_only_vintage_coefficients_state_vintage_fe.csv"))
cl_mh_only_plot(mh_state_tab, out_dir, state = TRUE)
models[["mh_only_dynamic_state_vintage_fe"]] <- mh_state_model
cl_mh_only_paper_plot(mh_tab, out_dir)
# Static ladder on the full matched sale sample: (1)-(2) MH only, (3)-(4) MH vs site-built.
ladder <- cl_mh_static_fits(dt)
cl_mh_static_table(ladder, file.path(out_dir, "mh_static_ladder.tex"))
fwrite(rbindlist(lapply(1:4, function(k) cl_coeftable(ladder$fits[[k]], paste0("ladder_", k))[,
    counties := ladder$counties[k]])), file.path(out_dir, "mh_static_ladder.csv"))
models[paste0("mh_static_ladder_", 1:4)] <- ladder$fits
saveRDS(models, file.path(out_dir, "models-private.rds"))

# Two panels from the joint zone-specific model; zone II is retained, not pooled with I.
plotdata <- tab[grepl(":mh_z[23]$", term)]
plotdata[, vintage := as.integer(sub("year_constr::([0-9]+).*", "\\1", term))]
comparisons <- c("II minus I", "III minus I")
plotdata[, comparison := fifelse(grepl(":mh_z2$", term), comparisons[1], comparisons[2])]
plotdata <- rbind(plotdata, data.table(comparison = comparisons, vintage = 1993L,
    pct = 0, pct_low = 0, pct_high = 0), fill = TRUE)
plotdata[, comparison := factor(comparison, levels = comparisons)]
p <- ggplot(plotdata, aes(vintage, pct)) +
    annotate("rect", xmin = 1993.5, xmax = 1994.5, ymin = -Inf, ymax = Inf, fill = "gray80", alpha = .4) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
    geom_vline(xintercept = 1993.5, linetype = "dotted", color = "black") +
    geom_errorbar(aes(ymin = pct_low, ymax = pct_high), width = .15) +
    geom_point(color = "#0072B2", size = 2) + facet_wrap(~comparison, ncol = 2) +
    scale_x_continuous(breaks = seq(1989, 1999, 2)) +
    labs(x = "Original construction year", y = "MH relative price contrast (%)",
        caption = "Sales 2000-2023; 1993 reference; shaded 1994 partially treated. County-clustered 95% intervals.") +
    theme_classic(base_size = 14) + theme(text = element_text(family = "serif"), plot.caption = element_text(size = 10))
for (ext in c("pdf", "png")) ggsave(file.path(out_dir, paste0("vintage_prices.", ext)), p, width = 9, height = 5, dpi = 150)

files <- c(here("program", "corelogic", "estimate-corelogic-prices.R"),
    here("program", "lib", "corelogic-setup.R"), here("program", "lib", "corelogic-prices.R"),
    here("program", "lib", "corelogic-price-sample.R"), here("program", "lib", "corelogic-ddd.R"),
    here("program", "lib", "corelogic-windzone.R"), here("program", "lib", "corelogic-price-table.R"), here("program", "lib", "corelogic-mh-only.R"))
dir.create(file.path(out_dir, "source")); file.copy(files, file.path(out_dir, "source"))
write_json(list(status = "complete", build = input, slurm_job = Sys.getenv("SLURM_JOB_ID"),
    sale_rows = nrow(dt), specification_ids = names(models),
    mh_only_sales = nrow(mh_sales), mh_only_specification = "MH sales only; county x sale year and vintage FE; separate zone x vintage DiDs",
    mh_only_robustness = "Same MH-only price DiD with state x vintage FE in place of vintage FE",
    mh_static_ladder = "Static post x zone II/III: (1) MH, county x sale year + vintage FE; (2) state x vintage FE; (3) MH and site-built, county x sale year x type + county x vintage + type x vintage FE; (4) state x vintage x type FE in place of type x vintage",
    static_complete_sales = static_input, static_retained_sales = static_n,
    outcome = "Log land-inclusive sale price, annual CPI-U in 2000 dollars",
    sale_window = c(2000L, 2023L), construction_window = c(1989L, 1999L), reference_vintage = 1993L,
    vintage_1994 = "Own annual coefficient; included in static post (1994-1999)",
    treatment = "Joint zone II and III contrasts relative to zone I; zone II retained in III contrast",
    lower_order_terms = "Annual: zone x vintage and MH x vintage; static: zone x post and MH x post; county x sale year and county x type throughout",
    tract_effect = "Additive snapshot tract FE in static columns 2 and 3; none in annual figure",
    size_controls = "Log land_square_footage and log living_square_feet_all_buildings, pinned 2023 snapshot, positive finite values",
    static_sample = "Common complete-case sample, after controlled-model singleton removal",
    weights = "Equal per transaction",
    tract_lookup_manifest_md5 = unname(tools::md5sum(file.path(Sys.getenv("CORELOGIC_TRACTS"), "manifest.json"))),
    pb_source_manifest_md5 = unname(tools::md5sum(file.path(Sys.getenv("CORELOGIC_PB_SOURCE"), "_meta.json"))),
    source_build_manifest_md5 = unname(tools::md5sum(file.path(input, "manifest.json"))),
    code_reference_md5 = as.list(tools::md5sum(c(files, geo_file))),
    session = capture.output(sessionInfo())), file.path(out_dir, "manifest.json"), pretty = TRUE, auto_unbox = TRUE)
cat("COMPLETE", out_dir, "\n")
