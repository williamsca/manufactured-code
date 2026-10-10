# Triple differences in MH vintage sale-price profiles across HUD wind zones.
# Zones II/III minus Zone I remove MH vintage changes common to all zones;
# zone x vintage and county x type FEs retain the lower-order interactions.
# Includes static contrasts and annual profiles, county and census-tract effects.
#
# Usage: ./run_remote.sh corelogic estimate-corelogic-windzone.R

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
source(here("program", "lib", "corelogic-price-sample.R"))
dt <- cl_price_sample()
dt <- merge(dt, wz[, .(countyfp, wind_zone)], by = "countyfp", all.x = TRUE, sort = FALSE)
fwrite(dt[is.na(wind_zone), .(sales = .N), by = .(countyfp, mh)], file.path(out_dir, "unmatched_counties.csv"))
dt <- dt[!is.na(wind_zone)]
dt[, `:=`(mh_tr = mh * (wind_zone >= 2), mh_z2 = mh * (wind_zone == 2), mh_z3 = mh * (wind_zone == 3))]
dt[, `:=`(post_mh_tr = post_mh * (wind_zone >= 2), post_mh_z2 = post_mh * (wind_zone == 2),
    post_mh_z3 = post_mh * (wind_zone == 3), cohort_group = fifelse(year_constr >= 1994, "post", "pre"))]
fwrite(dt[, .(sales = .N, counties = uniqueN(countyfp), states = uniqueN(statefp)),
    by = .(wind_zone, mh, year_constr)], file.path(out_dir, "support_by_vintage.csv"))

# estimation helpers ----
collect <- function(m, id, param, cluster) {
    tab <- cl_coeftable(m, id)
    tab[, `:=`(parameterization = param, cluster = cluster)]
    tab
}
fit <- function(id, rows, tract = FALSE, dynamic = FALSE) {
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
        f <- cl_ddd_formula(by_zone, dynamic, tract = tract)
        m <- feols(f, x, vcov = ~countyfp, mem.clean = TRUE)
        if (dynamic) {
            profiles[[paste(id, param, "county")]] <- collect(m, id, param, "county")
        } else {
            coefs[[paste(id, param, "county")]] <- collect(m, id, param, "county")
        }
        if (dynamic) {
            modifiers <- if (by_zone) c("mh", "mh_z2", "mh_z3") else c("mh", "mh_tr")
            expected <- setdiff(sort(unique(x$year_constr)), 1993L)
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

# Static contrasts: no measured covariates; census-tract comparison on a common sample.
specs <- list(
    county = list(rows = rep(TRUE, nrow(dt))),
    county_common = list(rows = dt$tract_ok),
    tract = list(rows = dt$tract_ok, tract = TRUE)
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
# 1993 reference; static treatment includes the partially treated 1994 cohort.
for (id in names(specs)) {
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
        specification = sample_ids, vintage = 1993L,
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
        scale_x_continuous(breaks = 1989:1999) +
        labs(
            x = "Original construction year", y = "Triple difference in MH prices (%)",
            color = NULL, shape = NULL, caption = "Sales 2000-2023; 1993 reference. Shaded 1994 cohort partially treated; 95% intervals clustered by county."
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
draw(c("county_common", "tract"),
    c("County effects, tract-covered sample", "Also census tract effects"), FALSE, "vintage_ddd")
draw(c("county_common", "tract"),
    c("County effects, tract-covered sample", "Also census tract effects"), TRUE, "vintage_ddd_byzone")

# provenance ----
files <- c(
    here("program", "lib", "corelogic-windzone.R"),
    here("program", "lib", "corelogic-ddd.R"),
    here("program", "lib", "corelogic-setup.R"),
    here("program", "corelogic", "estimate-corelogic-windzone.R"),
    here("program", "lib", "corelogic-price-sample.R"), geo_file
)
dir.create(file.path(out_dir, "source"))
file.copy(files[1:5], file.path(out_dir, "source"))
write_json(
    list(
        status = "complete", build = input, job = Sys.getenv("SLURM_JOB_ID"),
        matched_preferred_sales = nrow(dt), crosswalk_counties = nrow(wz),
        sale_window = c(2000L, 2023L), construction_window = c(1989L, 1999L), reference_vintage = 1993L,
        vintage_1994 = "Own annual coefficient; included in static post (1994-1999)",
        wind_zone_source = "24 CFR 3280.305(c)(2), official 2020 list, matched to geo_county v2026-09-02 incl. historical counties",
        zone_II_counties = 144, zone_III_counties = 25, zone_III_fips_codes = sum(wz$wind_zone == 3),
        lower_order_terms = "county x sale year; county x type; zone x annual vintage",
        tract_effect = "Additive snapshot tract FE; county controls retained",
        tract_lookup_manifest_md5 = unname(tools::md5sum(file.path(Sys.getenv("CORELOGIC_TRACTS"), "manifest.json"))),
        code_reference_md5 = as.list(tools::md5sum(files)), session = capture.output(sessionInfo())
    ),
    file.path(out_dir, "manifest.json"),
    pretty = TRUE, auto_unbox = TRUE
)
cat("COMPLETE", out_dir, "\n")
