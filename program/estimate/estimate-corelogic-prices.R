# MH versus site-built sale prices by original construction vintage:
# annual profiles and static contrasts, county and census-tract effects.
# Unlike estimate-corelogic-windzone.R, this does not compare wind zones.
#
# Usage: set CORELOGIC_BUILD and CORELOGIC_RESULTS; submit corelogic-prices.slurm.

rm(list = ls())
library(here)
source(here("program", "lib", "corelogic-setup.R"))
source(here("program", "lib", "corelogic-prices.R"))

source(here("program", "lib", "corelogic-price-sample.R"))
# estimation sample ----
dt <- cl_price_sample()
fwrite(dt[, .(sales = .N, parcels = uniqueN(clip), counties = uniqueN(countyfp)),
    by = .(mh, year_constr)], file.path(out_dir, "sample_by_vintage.csv"))
fwrite(dt[, .(sales = .N), by = .(mh, year_sale)], file.path(out_dir, "sample_by_sale_year.csv"))

# estimation helpers ----
fit <- function(id, rows, fe, controls = "", dynamic_fit = TRUE) {
    x <- dt[which(rows)]
    cat("Estimating", id, "N=", nrow(x), "\n")
    f <- cl_price_formula(fe, controls, dynamic_fit)
    m <- feols(f, data = x, vcov = ~countyfp, mem.clean = TRUE, lean = TRUE)
    tab <- cl_coeftable(m, id)
    tab[, `:=`(mh_input = sum(x$mh), counties_input = uniqueN(x$countyfp))]
    # Check that every non-reference cohort is identified (never silently plot dropped cohorts).
    if (dynamic_fit) {
        expected <- setdiff(sort(unique(x$year_constr)), 1993L)
        found <- as.integer(sub("year_constr::([0-9]+):mh", "\\1", tab[grepl("^year_constr::", term), term]))
        stopifnot(setequal(expected, found))
    }
    list(model = m, coefficients = if (dynamic_fit) tab else tab[term %in% "post_mh"])
}

# County baseline, same-sample comparison, and added census-tract fixed effects.
fe_county_type <- "countyfp^year_sale + countyfp^mh + year_constr"
specs <- list(
    county = list(rep(TRUE, nrow(dt)), fe_county_type),
    county_common = list(dt$tract_ok, fe_county_type),
    tract = list(dt$tract_ok, paste(fe_county_type, "+ tractfp"))
)
dynamic <- list()
static <- list()
models <- list()
for (id in names(specs)) {
    s <- specs[[id]]
    controls <- if (length(s) == 3) s[[3]] else ""
    est_es <- fit(id, s[[1]], s[[2]], controls)
    est_static <- fit(id, s[[1]], s[[2]], controls, dynamic_fit = FALSE)
    dynamic[[id]] <- est_es$coefficients
    static[[id]] <- est_static$coefficients
    models[[paste0(id, "_dynamic")]] <- est_es$model
    models[[paste0(id, "_static")]] <- est_static$model
    fwrite(rbindlist(dynamic), file.path(out_dir, "vintage_coefficients.csv"))
    fwrite(rbindlist(static), file.path(out_dir, "post_coefficients.csv"))
}

saveRDS(models, file.path(out_dir, "models-private.rds"))

# plots ----
dt_es <- fread(file.path(out_dir, "vintage_coefficients.csv"))[grepl("^year_constr::", term)]
dt_es[, vintage := as.integer(sub("year_constr::([0-9]+):mh", "\\1", term))]
draw <- function(selected, labels, filename) {
    plotdata <- dt_es[specification %in% selected]
    plotdata <- rbind(plotdata, CJ(specification = selected, vintage = 1993L)[
        , `:=`(pct = 0, pct_low = 0, pct_high = 0)
    ], fill = TRUE)
    plotdata[, series := factor(specification, levels = selected, labels = labels)]
    p <- ggplot(plotdata, aes(vintage, pct, color = series, shape = series)) +
        annotate("rect", xmin = 1993.5, xmax = 1994.5, ymin = -Inf, ymax = Inf, fill = "gray80", alpha = .4) +
        geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
        geom_vline(xintercept = 1993.5, linetype = "dotted") +
        geom_errorbar(aes(ymin = pct_low, ymax = pct_high), width = .15, position = position_dodge(.25)) +
        geom_point(size = 2, position = position_dodge(.25)) +
        scale_color_manual(values = c("#0072B2", "#D55E00")) +
        scale_shape_manual(values = c(16, 17)) +
        scale_x_continuous(breaks = 1989:1999) +
        labs(
            x = "Original construction year", y = "Relative MH vintage price (%)",
            color = NULL, shape = NULL,
            caption = "Sales 2000-2023; 1993 reference; shaded 1994 cohort partially treated. County-clustered 95% intervals."
        ) +
        theme_classic(base_size = 14) +
        theme(
            text = element_text(family = "serif"),
            legend.position = "bottom", legend.text = element_text(size = 12),
            plot.caption = element_text(size = 11)
        )
    ggsave(file.path(out_dir, paste0(filename, ".pdf")), p, width = 9, height = 5)
    ggsave(file.path(out_dir, paste0(filename, ".png")), p, width = 9, height = 5, dpi = 150)
}
draw(c("county_common", "tract"),
    c("County effects, tract-covered sample", "Also census tract effects"), "vintage_prices")

# provenance ----
dir.create(file.path(out_dir, "source"))
files <- c(
    here("program", "estimate", "estimate-corelogic-prices.R"),
    here("program", "lib", "corelogic-setup.R"),
    here("program", "lib", "corelogic-prices.R"),
    here("program", "lib", "corelogic-price-sample.R")
)
file.copy(files, file.path(out_dir, "source"))
write_json(list(
    status = "complete", build = input, slurm_job = Sys.getenv("SLURM_JOB_ID"),
    sale_rows = nrow(dt), tract_rows = sum(dt$tract_ok), specification_ids = names(specs),
    outcome = "Log land-inclusive sale price, annual CPI-U in 2000 dollars",
    sale_window = c(2000L, 2023L), construction_window = c(1989L, 1999L), reference_vintage = 1993L,
    vintage_1994 = "Own annual coefficient; included in static post (1994-1999)",
    source_build_manifest_md5 = unname(tools::md5sum(file.path(input, "manifest.json"))),
    code_md5 = unname(tools::md5sum(files[1])),
    code_reference_md5 = as.list(tools::md5sum(files)),
    wind_zone = "Not used in the baseline vintage price analysis",
    tract_lookup_manifest_md5 = unname(tools::md5sum(file.path(Sys.getenv("CORELOGIC_TRACTS"), "manifest.json"))),
    tract_effect = "Additive snapshot tract FE; retain county x sale year and county x type",
    session = capture.output(sessionInfo())
), file.path(out_dir, "manifest.json"), pretty = TRUE, auto_unbox = TRUE)
cat("COMPLETE", out_dir, "\n")
