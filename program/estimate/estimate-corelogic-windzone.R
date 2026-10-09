# Triple differences in MH vintage sale-price profiles across HUD wind zones.
# Zones II/III minus Zone I remove MH vintage changes common to all zones;
# zone x vintage and county x type FEs retain the lower-order interactions.
# Includes static contrasts, annual profiles, robustness, and figures.
#
# Usage: set CORELOGIC_BUILD, CORELOGIC_RESULTS, and CORELOGIC_REFERENCE;
# submit corelogic-windzone.slurm.

rm(list = ls())
library(here)
source(here("program", "lib", "corelogic-windzone.R"))
source(here("program", "lib", "corelogic-ddd.R"))
ref <- Sys.getenv("CORELOGIC_REFERENCE")
if (!nzchar(ref)) stop("Set CORELOGIC_REFERENCE")
source(here("program", "lib", "corelogic-setup.R"))

# wind-zone crosswalk ----
geo_file <- file.path(ref, "geo_county.parquet")
geo <- read_corelogic(paste("SELECT countyfp,statefp,name FROM read_parquet(", quote_path(geo_file), ")"))
wz <- cl_windzone_counties(geo)
fwrite(wz, file.path(out_dir, "windzone_crosswalk.csv"))
legacy <- fread(file.path(ref, "ecfr-windzone.csv"), colClasses = c(countyfp = "character"))
audit <- merge(wz, legacy, by = "countyfp", all = TRUE, suffixes = c("_reconstructed", "_legacy"))
fwrite(audit[is.na(wind_zone_legacy) | is.na(wind_zone_reconstructed) |
    wind_zone_legacy != wind_zone_reconstructed], file.path(out_dir, "windzone_reconciliation.csv"))
# estimation sample ----
glob <- quote_path(file.path(input, "sales", "*.parquet"))
dt <- read_corelogic(paste("SELECT countyfp, mh, year_constr, year_sale,
    sale_price_2000, eligible_sale, consideration_documented, pb_sqft, pb_lot_sqft,
    wind_zone AS wind_zone_build FROM read_parquet(", glob, ") WHERE eligible_sale AND countyfp IS NOT NULL
    AND date_sale >= MAKE_DATE(year_constr,1,1)"))
dt <- merge(dt, wz[, .(countyfp, wind_zone, statefp)], by = "countyfp", all.x = TRUE, sort = FALSE)
fwrite(dt[is.na(wind_zone), .(sales = .N), by = .(countyfp, mh)], file.path(out_dir, "unmatched_counties.csv"))
fwrite(dt[, .(sales = .N), by = .(wind_zone_build, wind_zone, mh)], file.path(out_dir, "zone_join_audit.csv"))
dt <- dt[!is.na(wind_zone)]
stopifnot(all(dt$sale_price_2000 > 0), !anyNA(dt$sale_price_2000))
dt[, `:=`(
    log_price = log(sale_price_2000), post_mh = mh * as.integer(year_constr >= 1995),
    mh_tr = mh * (wind_zone >= 2), mh_z2 = mh * (wind_zone == 2), mh_z3 = mh * (wind_zone == 3),
    mh_1994 = mh * (year_constr == 1994),
    sizes_ok = pb_sqft >= 200 & pb_sqft <= 10000 & pb_lot_sqft >= 100 & pb_lot_sqft <= 4356000
)]
dt[is.na(sizes_ok), sizes_ok := FALSE]
dt[, `:=`(
    post_mh_tr = post_mh * (wind_zone >= 2), post_mh_z2 = post_mh * (wind_zone == 2),
    post_mh_z3 = post_mh * (wind_zone == 3), mh_1994_tr = mh_1994 * (wind_zone >= 2),
    mh_1994_z2 = mh_1994 * (wind_zone == 2), mh_1994_z3 = mh_1994 * (wind_zone == 3),
    cohort_group = fifelse(year_constr == 1994, "transition_1994", fifelse(year_constr >= 1995, "post", "pre")),
    log_sqft = log(pmax(pb_sqft, 1)), log_lot = log(pmax(pb_lot_sqft, 1))
)]
fwrite(dt[, .(sales = .N, counties = uniqueN(countyfp), states = uniqueN(statefp)),
    by = .(wind_zone, mh, year_constr)
], file.path(out_dir, "support_by_vintage.csv"))
fwrite(dt[year_sale >= 2000, .(sales = .N, counties = uniqueN(countyfp), states = uniqueN(statefp)),
    by = .(wind_zone, mh, cohort_group)
], file.path(out_dir, "support_post_2000.csv"))

# estimation helpers ----
collect <- function(m, id, param, cluster) {
    tab <- cl_coeftable(m, id)
    tab[, `:=`(parameterization = param, cluster = cluster)]
    tab
}
fit <- function(id, rows, controls = "", county_type = TRUE, dynamic = FALSE) {
    coefs <- list()
    profiles <- list()
    dids <- list()
    models <- list()
    support <- list()
    unidentified <- list()
    x <- dt[which(rows)]
    cat("Estimating", id, "dynamic", dynamic, "N", nrow(x), "\n")
    if (!dynamic) {
        support[[id]] <- x[, .(sales = .N, counties = uniqueN(countyfp), states = uniqueN(statefp)),
            by = .(wind_zone, mh, cohort_group)
        ][, specification := id]
    }
    for (by_zone in c(FALSE, TRUE)) {
        param <- if (by_zone) "separate_zones" else "pooled_treated"
        f <- cl_ddd_formula(by_zone, dynamic, controls, county_type)
        m <- feols(f, x, vcov = ~countyfp, mem.clean = TRUE)
        if (dynamic) {
            profiles[[paste(id, param, "county")]] <- collect(m, id, param, "county")
        } else {
            coefs[[paste(id, param, "county")]] <- collect(m, id, param, "county")
        }
        if (dynamic) {
            modifiers <- if (by_zone) c("mh", "mh_z2", "mh_z3") else c("mh", "mh_tr")
            expected <- setdiff(sort(unique(x$year_constr)), c(1992L, 1993L))
            for (key in modifiers) {
                terms <- names(coef(m))[grepl(paste0(":", key, "$"), names(coef(m)))]
                observed <- as.integer(sub("year_constr::([0-9]+):.*", "\\1", terms))
                stopifnot(setequal(expected, observed), 1994L %in% observed)
            }
        } else {
            # State clustering as a sensitivity check, including few-state support caveat.
            ms <- summary(m, vcov = ~statefp)
            coefs[[paste(id, param, "state")]] <- collect(ms, id, param, "state")
            for (cl in c("county", "state")) {
                mm <- if (cl == "county") m else ms
                b <- coef(mm)
                v <- vcov(mm)
                crit <- qt(.975, degrees_freedom(mm, "t"))
                modifiers <- if (by_zone) c("", "post_mh_z2", "post_mh_z3") else c("", "post_mh_tr")
                names(modifiers) <- if (by_zone) c("I", "II", "III") else c("I", "II_III")
                for (z in names(modifiers)) {
                    terms <- c("post_mh", modifiers[[z]])
                    terms <- terms[nzchar(terms)]
                    missing <- setdiff(terms, names(b))
                    if (length(missing)) {
                        unidentified[[paste(id, param, cl, z)]] <- data.table(
                            specification = id,
                            parameterization = param, cluster = cl, zone = z, missing_terms = paste(missing, collapse = ";")
                        )
                        dids[[paste(id, param, cl, z)]] <- data.table(
                            specification = id,
                            parameterization = param, cluster = cl, zone = z, estimate = NA_real_, se = NA_real_,
                            ci_low = NA_real_, ci_high = NA_real_, n = nobs(mm)
                        )
                        next
                    }
                    estimate <- sum(b[terms])
                    se <- sqrt(sum(v[terms, terms, drop = FALSE]))
                    dids[[paste(id, param, cl, z)]] <- data.table(
                        specification = id,
                        parameterization = param, cluster = cl, zone = z, estimate = estimate, se = se,
                        ci_low = estimate - crit * se, ci_high = estimate + crit * se, n = nobs(mm)
                    )
                }
            }
        }
        models[[paste(id, param, dynamic)]] <- summary(m, lean = TRUE)
        rm(m)
        gc()
    }
    list(
        coefs = coefs, profiles = profiles, dids = dids, models = models,
        support = support, unidentified = unidentified
    )
}

# static contrasts and robustness ----
# Each specification fits both II/III versus I and separate II/III contrasts.

later <- dt$year_sale >= 2000
size <- later & dt$sizes_ok
controls <- "+ log_sqft + I(log_sqft^2) + log_lot + I(log_lot^2)"
specs <- list(
    all_sales = list(rows = rep(TRUE, nrow(dt))),
    sales_2000 = list(rows = later),
    size_sample_2000 = list(rows = size),
    size_controls_2000 = list(rows = size, controls = controls),
    no_florida_2000 = list(rows = later & dt$statefp != "12"),
    strict_2000 = list(rows = later & dt$consideration_documented),
    common_type_intercept_2000 = list(rows = later, county_type = FALSE),
    narrow_2000 = list(rows = later & dt$year_constr >= 1990 & dt$year_constr <= 1997)
)
coefs <- list()
profiles <- list()
dids <- list()
models <- list()
support <- list()
unidentified <- list()
for (id in names(specs)) {
    est <- do.call(fit, c(list(id = id), specs[[id]]))
    coefs <- c(coefs, est$coefs)
    dids <- c(dids, est$dids)
    models <- c(models, est$models)
    support <- c(support, est$support)
    unidentified <- c(unidentified, est$unidentified)
    fwrite(rbindlist(coefs), file.path(out_dir, "post_ddd_coefficients.csv"))
    fwrite(rbindlist(dids), file.path(out_dir, "zone_did_coefficients.csv"))
    fwrite(rbindlist(support), file.path(out_dir, "support_by_specification.csv"))
    if (length(unidentified)) {
        fwrite(rbindlist(unidentified), file.path(out_dir, "unidentified_contrasts.csv"))
    }
}

# event studies ----
# Joint 1992-1993 reference; 1994 has its own partially treated coefficient.
for (id in c("sales_2000", "size_sample_2000", "size_controls_2000")) {
    est <- do.call(fit, c(list(id = id, dynamic = TRUE), specs[[id]]))
    profiles <- c(profiles, est$profiles)
    models <- c(models, est$models)
    fwrite(rbindlist(profiles), file.path(out_dir, "vintage_ddd_coefficients.csv"))
}
saveRDS(models, file.path(out_dir, "models-private.rds"))

# plots ----
dt_es <- fread(file.path(out_dir, "vintage_ddd_coefficients.csv"))
dt_es <- dt_es[grepl("^year_constr::", term) & !grepl(":mh$", term)]
dt_es[, `:=`(
    vintage = as.integer(sub("year_constr::([0-9]+):.*", "\\1", term)),
    contrast = sub(".*:", "", term)
)]
draw <- function(sample_ids, labels, by_zone, filename) {
    x <- dt_es[specification %in% sample_ids & parameterization ==
        if (by_zone) "separate_zones" else "pooled_treated"]
    refs <- CJ(
        specification = sample_ids, vintage = c(1992L, 1993L),
        contrast = if (by_zone) c("mh_z2", "mh_z3") else "mh_tr"
    )
    refs[, `:=`(pct = 0, pct_low = 0, pct_high = 0)]
    x <- rbind(x, refs, fill = TRUE)
    x[, series := factor(specification, levels = sample_ids, labels = labels)]
    x[, comparison := factor(contrast,
        levels = c("mh_tr", "mh_z2", "mh_z3"),
        labels = c("Zones II/III minus zone I", "Zone II minus zone I", "Zone III minus zone I")
    )]
    p <- ggplot(x, aes(vintage, pct, color = series, shape = series)) +
        annotate("rect", xmin = 1993.5, xmax = 1994.5, ymin = -Inf, ymax = Inf, fill = "gray80", alpha = .4) +
        geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
        geom_vline(xintercept = 1993.5, linetype = "dotted", color = "black") +
        geom_errorbar(aes(ymin = pct_low, ymax = pct_high), width = .15, position = position_dodge(.25)) +
        geom_point(size = 2, position = position_dodge(.25)) +
        scale_color_manual(values = c("#0072B2", "#D55E00")) +
        scale_shape_manual(values = c(16, 17)) +
        scale_x_continuous(breaks = 1984:1999) +
        labs(
            x = "Original construction year", y = "Triple difference in MH prices (%)",
            color = NULL, shape = NULL, caption = "Sales 2000-2023; joint 1992-1993 reference. Shaded 1994 cohort partially treated; 95% intervals clustered by county."
        ) +
        theme_classic(base_size = 14) +
        theme(
            text = element_text(family = "serif"),
            legend.position = "bottom", legend.text = element_text(size = 12),
            plot.caption = element_text(size = 10)
        )
    if (by_zone) p <- p + facet_wrap(~comparison, ncol = 1)
    ggsave(file.path(out_dir, paste0(filename, ".pdf")), p, width = 9, height = if (by_zone) 7 else 5)
    ggsave(file.path(out_dir, paste0(filename, ".png")), p, width = 9, height = if (by_zone) 7 else 5, dpi = 150)
}
draw(c("sales_2000"), "All qualifying sales", FALSE, "vintage_ddd")
draw(
    c("size_sample_2000", "size_controls_2000"),
    c("Common sample, no size controls", "Floor area and lot size controls"), FALSE, "vintage_ddd_size"
)
draw(
    c("size_sample_2000", "size_controls_2000"),
    c("Common sample, no size controls", "Floor area and lot size controls"), TRUE, "vintage_ddd_byzone"
)

# provenance ----
files <- c(
    here("program", "lib", "corelogic-windzone.R"),
    here("program", "lib", "corelogic-ddd.R"),
    here("program", "lib", "corelogic-setup.R"),
    here("program", "estimate", "estimate-corelogic-windzone.R"), geo_file
)
dir.create(file.path(out_dir, "source"))
file.copy(files[1:4], file.path(out_dir, "source"))
write_json(
    list(
        status = "complete", build = input, job = Sys.getenv("SLURM_JOB_ID"),
        matched_preferred_sales = nrow(dt), crosswalk_counties = nrow(wz),
        vintage_1994 = "Retained as own annual coefficient; static DDD has separate 1994 x MH x zone terms",
        wind_zone_source = "24 CFR 3280.305(c)(2), official 2020 list, matched to geo_county v2026-09-02 incl. historical counties",
        zone_II_counties = 144, zone_III_counties = 25, zone_III_fips_codes = sum(wz$wind_zone == 3),
        lower_order_terms = "county x sale year; county x type (or type x zone sensitivity); zone x annual vintage",
        code_reference_md5 = as.list(tools::md5sum(files)), session = capture.output(sessionInfo())
    ),
    file.path(out_dir, "manifest.json"),
    pretty = TRUE, auto_unbox = TRUE
)
cat("COMPLETE", out_dir, "\n")
