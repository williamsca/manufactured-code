# MH versus site-built sale prices by original construction vintage:
# annual profiles, static contrasts, size balance, robustness, and figures.
# Unlike estimate-corelogic-windzone.R, this does not compare wind zones.
#
# Usage: set CORELOGIC_BUILD and CORELOGIC_RESULTS; submit corelogic-prices.slurm.

rm(list = ls())
library(here)
source(here("program", "lib", "corelogic-setup.R"))
source(here("program", "lib", "corelogic-prices.R"))

# estimation sample ----
glob <- quote_path(file.path(input, "sales", "*.parquet"))
dt <- read_corelogic(sprintf("SELECT countyfp, clip, mh, year_constr,
    year_sale, date_sale, sale_amount, sale_price_2000, eligible_sale,
    analysis_ready AS analysis_ready_legacy,
    consideration_documented, pb_sqft, pb_lot_sqft, latitude, longitude,
    pb_matched, snapshot_type_differs, snapshot_vintage_differs
    FROM read_parquet(%s) WHERE countyfp IS NOT NULL
    AND date_sale >= MAKE_DATE(year_constr,1,1)", glob))
stopifnot(!anyNA(dt$mh), all(dt$sale_price_2000 > 0), !anyNA(dt$sale_price_2000))
stopifnot(all(dt$eligible_sale))
# The persisted legacy flag excludes 1994; eligibility plus the date guard
# keeps the transition cohort while retaining every other production screen.
dt[, `:=`(
    analysis_ready = eligible_sale, log_price = log(sale_price_2000),
    post_mh = mh * as.integer(year_constr >= 1995), mh_1994 = mh * (year_constr == 1994),
    statefp = substr(countyfp, 1, 2),
    sizes_ok = pb_sqft >= 200 & pb_sqft <= 10000 & pb_lot_sqft >= 100 & pb_lot_sqft <= 4356000
)]
dt[is.na(sizes_ok), sizes_ok := FALSE]
dt[, `:=`(log_sqft = log(pmax(pb_sqft, 1)), log_lot = log(pmax(pb_lot_sqft, 1)))]
fwrite(
    dt[, .(
        sales = .N, parcels = uniqueN(clip), counties = uniqueN(countyfp),
        median_price_2000 = median(sale_price_2000), size_coverage = mean(sizes_ok),
        coordinate_coverage = mean(!is.na(latitude) & !is.na(longitude)),
        snapshot_match = mean(pb_matched)
    ), by = .(mh, year_constr, analysis_ready)],
    file.path(out_dir, "sample_by_vintage.csv")
)
fwrite(
    dt[analysis_ready == TRUE, .(sales = .N), by = .(mh, year_sale)],
    file.path(out_dir, "sample_by_sale_year.csv")
)

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
        expected <- setdiff(sort(unique(x$year_constr)), c(1992, 1993))
        found <- as.integer(sub("year_constr::([0-9]+):mh", "\\1", tab[grepl("^year_constr::", term), term]))
        stopifnot(setequal(expected, found))
    }
    list(model = m, coefficients = if (dynamic_fit) tab else tab[term %in% c("post_mh", "mh_1994")])
}

# event studies and static robustness ----
# County x sale-year absorbs local market changes. County x type allows the
# MH price level to differ across counties. All fits keep 1994 separately.

baseline <- "countyfp^year_sale + mh + year_constr"
fe_county_type <- "countyfp^year_sale + countyfp^mh + year_constr"
ready <- dt$analysis_ready
later <- ready & dt$year_sale >= 2000
specs <- list(
    pooled = list(ready, baseline), county_type = list(ready, fe_county_type),
    sales_2000 = list(later, baseline), county_type_2000 = list(later, fe_county_type),
    strict_2000 = list(later & dt$consideration_documented, fe_county_type),
    no_florida_2000 = list(later & dt$statefp != "12", fe_county_type),
    size_sample_2000 = list(later & dt$sizes_ok, fe_county_type),
    size_controls_2000 = list(later & dt$sizes_ok, fe_county_type, "+ log_sqft + I(log_sqft^2) + log_lot + I(log_lot^2)"),
    narrow_2000 = list(later & dt$year_constr >= 1990 & dt$year_constr <= 1997, fe_county_type)
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

# snapshot size balance ----
# Snapshot size balance: use the same complete-case sample and specification.
balance <- rbindlist(lapply(c("log_sqft", "log_lot"), function(y) {
    m <- feols(as.formula(paste(y, "~ post_mh + mh_1994 |", fe_county_type)),
        data = dt[which(later & dt$sizes_ok)], vcov = ~countyfp, lean = TRUE, mem.clean = TRUE
    )
    ci <- confint(m, "post_mh")
    data.table(
        outcome = y, estimate = coef(m)[["post_mh"]], se = se(m)[["post_mh"]],
        ci_low = ci[1, 1], ci_high = ci[1, 2], n = nobs(m)
    )
}))
fwrite(balance, file.path(out_dir, "snapshot_size_balance.csv"))
saveRDS(models, file.path(out_dir, "models-private.rds"))

# plots ----
dt_es <- fread(file.path(out_dir, "vintage_coefficients.csv"))[grepl("^year_constr::", term)]
dt_es[, vintage := as.integer(sub("year_constr::([0-9]+):mh", "\\1", term))]
draw <- function(selected, labels, filename) {
    plotdata <- dt_es[specification %in% selected]
    plotdata <- rbind(plotdata, CJ(specification = selected, vintage = c(1992L, 1993L))[
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
        scale_x_continuous(breaks = 1984:1999) +
        labs(
            x = "Original construction year", y = "Relative MH vintage price (%)",
            color = NULL, shape = NULL,
            caption = "Joint 1992-1993 reference; shaded 1994 cohort partially treated. County-clustered 95% intervals."
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
draw(
    c("pooled", "county_type_2000"),
    c("County x sale year; 1990-2023", "Also county x type; 2000-2023"), "vintage_prices"
)
draw(
    c("size_sample_2000", "size_controls_2000"),
    c("Common sample, no size controls", "Floor area and lot size controls"), "vintage_prices_size"
)

# provenance ----
dir.create(file.path(out_dir, "source"))
files <- c(
    here("program", "estimate", "estimate-corelogic-prices.R"),
    here("program", "lib", "corelogic-setup.R"),
    here("program", "lib", "corelogic-prices.R")
)
file.copy(files, file.path(out_dir, "source"))
write_json(list(
    status = "complete", build = input, slurm_job = Sys.getenv("SLURM_JOB_ID"),
    sale_rows = nrow(dt), preferred_rows = sum(ready), specification_ids = names(specs),
    outcome = "Log land-inclusive sale price, annual CPI-U in 2000 dollars",
    vintage_1994 = "Retained as own annual coefficient; static model has separate MH x 1994 term",
    source_build_manifest_md5 = unname(tools::md5sum(file.path(input, "manifest.json"))),
    code_md5 = unname(tools::md5sum(files[1])),
    code_reference_md5 = as.list(tools::md5sum(files)),
    wind_zone = "Not used in the baseline vintage price analysis",
    session = capture.output(sessionInfo())
), file.path(out_dir, "manifest.json"), pretty = TRUE, auto_unbox = TRUE)
cat("COMPLETE", out_dir, "\n")
