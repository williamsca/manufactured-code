# National MH vintage price contrasts and triple differences across HUD wind zones.
# County effects only; no tract lookup or tract fixed effects.
# Usage: ./run_remote.sh corelogic estimate-corelogic-prices.R
rm(list = ls())
library(here)
source(here("program", "lib", "corelogic-setup.R"))
source(here("program", "lib", "corelogic-prices.R"))
source(here("program", "lib", "corelogic-ddd.R"))
source(here("program", "lib", "corelogic-windzone.R"))
source(here("program", "lib", "corelogic-price-sample.R"))
ref <- Sys.getenv("CORELOGIC_REFERENCE")
if (!nzchar(ref)) stop("Set CORELOGIC_REFERENCE")
geo_file <- file.path(ref, "geo_county.parquet")
wz <- cl_windzone_counties(read_corelogic(paste("SELECT countyfp,statefp,name FROM read_parquet(", quote_path(geo_file), ")")))
fwrite(wz, file.path(out_dir, "windzone_crosswalk.csv"))
dt <- cl_price_sample(with_tracts = FALSE)
dt <- merge(dt, wz[, .(countyfp, wind_zone)], by = "countyfp", all.x = TRUE, sort = FALSE)
fwrite(dt[is.na(wind_zone), .(sales = .N), by = .(countyfp, mh)], file.path(out_dir, "unmatched_counties.csv"))
dt <- dt[!is.na(wind_zone)]
dt[, `:=`(mh_tr = mh * (wind_zone >= 2), mh_z2 = mh * (wind_zone == 2), mh_z3 = mh * (wind_zone == 3))]
dt[, `:=`(post_mh_tr = post_mh * (wind_zone >= 2), post_mh_z2 = post_mh * (wind_zone == 2),
    post_mh_z3 = post_mh * (wind_zone == 3))]
fwrite(dt[, .(sales = .N, parcels = uniqueN(clip), counties = uniqueN(countyfp)),
    by = .(mh, year_constr)], file.path(out_dir, "sample_by_vintage.csv"))
fwrite(dt[, .(sales = .N), by = .(mh, year_sale)], file.path(out_dir, "sample_by_sale_year.csv"))
fwrite(dt[, .(sales = .N, counties = uniqueN(countyfp), states = uniqueN(statefp)),
    by = .(wind_zone, mh, year_constr)], file.path(out_dir, "support_by_vintage.csv"))

# The DDD helper retains MH x vintage and zone x vintage lower-order terms.
# The national model remains a vintage x type comparison, as in the share figure.
fe_national <- "countyfp^year_sale + countyfp^mh + year_constr"
forms <- list(
    national_dynamic = cl_price_formula(fe_national),
    national_static = cl_price_formula(fe_national, dynamic_fit = FALSE),
    pooled_dynamic = cl_ddd_formula(dynamic = TRUE),
    pooled_static = cl_ddd_formula(),
    separate_dynamic = cl_ddd_formula(by_zone = TRUE, dynamic = TRUE),
    separate_static = cl_ddd_formula(by_zone = TRUE)
)
models <- list(); tabs <- list()
for (id in names(forms)) {
    cat("Estimating", id, "N=", nrow(dt), "\n")
    m <- feols(forms[[id]], data = dt, vcov = ~countyfp, mem.clean = TRUE, lean = TRUE)
    tab <- cl_coeftable(m, id)
    tab[, `:=`(mh_input = sum(dt$mh), counties_input = uniqueN(dt$countyfp))]
    modifiers <- if (grepl("^national", id)) "mh" else if (grepl("^pooled", id)) c("mh", "mh_tr") else c("mh", "mh_z2", "mh_z3")
    if (grepl("dynamic$", id)) {
        expected <- setdiff(sort(unique(dt$year_constr)), 1993L)
        for (key in modifiers) {
            terms <- tab[grepl(paste0(":", key, "$"), term), term]
            observed <- as.integer(sub("year_constr::([0-9]+):.*", "\\1", terms))
            stopifnot(setequal(expected, observed))
        }
    } else {
        stopifnot(all(paste0("post_", modifiers) %in% tab$term))
    }
    tabs[[id]] <- tab
    models[[id]] <- m
}
coefficients <- rbindlist(tabs)
fwrite(coefficients[grepl("dynamic$", specification)], file.path(out_dir, "vintage_coefficients.csv"))
fwrite(coefficients[grepl("static$", specification)], file.path(out_dir, "post_coefficients.csv"))
saveRDS(models, file.path(out_dir, "models-private.rds"))

# Four panels: national DiD, pooled DDD, and the two separate zone DDDs.
plotdata <- coefficients[grepl("dynamic$", specification) &
    (specification == "national_dynamic" | !grepl(":mh$", term))]
plotdata[, vintage := as.integer(sub("year_constr::([0-9]+).*", "\\1", term))]
comparisons <- c("National: county-adjusted", "II/III minus I", "II minus I", "III minus I")
plotdata[, comparison := fifelse(specification == "national_dynamic", comparisons[1],
    fifelse(specification == "pooled_dynamic", comparisons[2], fifelse(grepl(":mh_z2$", term), comparisons[3], comparisons[4])))]
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
    here("program", "lib", "corelogic-windzone.R"))
dir.create(file.path(out_dir, "source")); file.copy(files, file.path(out_dir, "source"))
write_json(list(status = "complete", build = input, slurm_job = Sys.getenv("SLURM_JOB_ID"),
    sale_rows = nrow(dt), specification_ids = names(forms),
    outcome = "Log land-inclusive sale price, annual CPI-U in 2000 dollars",
    sale_window = c(2000L, 2023L), construction_window = c(1989L, 1999L), reference_vintage = 1993L,
    vintage_1994 = "Own annual coefficient; included in static post (1994-1999)",
    treatment = "HUD zones II/III; untreated zone I; pooled and separate zone contrasts",
    lower_order_terms = "DDD: county x sale year; county x type; zone x annual vintage; MH x vintage",
    national = "Vintage x type DiD with county x sale year, county x type, and vintage effects",
    tract_effect = "None; no tract lookup required", weights = "Equal per transaction",
    source_build_manifest_md5 = unname(tools::md5sum(file.path(input, "manifest.json"))),
    code_reference_md5 = as.list(tools::md5sum(c(files, geo_file))),
    session = capture.output(sessionInfo())), file.path(out_dir, "manifest.json"), pretty = TRUE, auto_unbox = TRUE)
cat("COMPLETE", out_dir, "\n")
