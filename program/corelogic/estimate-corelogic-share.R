# MH share of the surviving Property Basic dwelling inventory by vintage.
# One parcel per observation; county-vintage cells weighted by parcel counts.
rm(list = ls())
library(here)
source(here("program", "lib", "corelogic-setup.R"))
source(here("program", "lib", "corelogic-windzone.R"))
ref <- Sys.getenv("CORELOGIC_REFERENCE")
if (!nzchar(ref)) stop("Set CORELOGIC_REFERENCE")
geo_file <- file.path(ref, "geo_county.parquet")
wz <- cl_windzone_counties(read_corelogic(paste("SELECT countyfp,statefp,name FROM read_parquet(", quote_path(geo_file), ")")))
# Match the price dwelling universe using snapshot fields; no sale eligibility screen.
glob <- quote_path(file.path(input, "properties", "*.parquet"))
cells <- read_corelogic(sprintf("SELECT countyfp, year_built AS year_constr,
    COUNT(*) AS homes, SUM(mh) AS mh_homes, COUNT(DISTINCT clip) AS parcels
    FROM read_parquet(%s) WHERE countyfp IS NOT NULL AND clip IS NOT NULL
    AND year_built BETWEEN 1989 AND 1999 AND mh IS NOT NULL
    AND COALESCE(land_use_code,'') NOT IN ('135','136','454','400')
    AND COALESCE(property_indicator_code,'') IN ('','00','10')
    AND (number_of_buildings IS NULL OR number_of_buildings=1)
    AND (number_of_units IS NULL OR number_of_units=1)
    GROUP BY countyfp,year_built", glob))
stopifnot(all(cells$homes == cells$parcels))
cells <- merge(cells, wz[, .(countyfp, wind_zone, statefp)], by = "countyfp", all.x = TRUE)
fwrite(cells[is.na(wind_zone), .(homes = sum(homes)), by = countyfp], file.path(out_dir, "unmatched_counties.csv"))
cells <- cells[!is.na(wind_zone)]
cells[, `:=`(share = mh_homes / homes, post = as.integer(year_constr >= 1994),
    z2 = as.integer(wind_zone == 2), z3 = as.integer(wind_zone == 3), tr = as.integer(wind_zone >= 2))]
cells[, `:=`(post_tr = post * tr, post_z2 = post * z2, post_z3 = post * z3)]
raw <- cells[, .(homes = sum(homes), mh_homes = sum(mh_homes), counties = .N), by = .(wind_zone, year_constr)]
raw <- rbind(raw, cells[, .(wind_zone = 0L, homes = sum(homes), mh_homes = sum(mh_homes), counties = .N), by = year_constr])
raw[, mh_share_pct := 100 * mh_homes / homes]
fwrite(raw, file.path(out_dir, "share_by_vintage.csv"))
fwrite(cells[, .(homes = sum(homes), mh_homes = sum(mh_homes), counties = uniqueN(countyfp), states = uniqueN(statefp)),
    by = .(wind_zone, post)], file.path(out_dir, "support_pre_post.csv"))
forms <- list(
    national_dynamic = share ~ i(year_constr, ref = 1993) | countyfp,
    national_static = share ~ post | countyfp,
    pooled_dynamic = share ~ i(year_constr, tr, ref = 1993) | countyfp + year_constr,
    pooled_static = share ~ post_tr | countyfp + year_constr,
    separate_dynamic = share ~ i(year_constr, z2, ref = 1993) + i(year_constr, z3, ref = 1993) | countyfp + year_constr,
    separate_static = share ~ post_z2 + post_z3 | countyfp + year_constr
)
models <- list(); tabs <- list()
for (id in names(forms)) {
    m <- feols(forms[[id]], cells, weights = ~homes, vcov = ~countyfp, lean = TRUE)
    models[[id]] <- m
    tab <- cl_coeftable(m, id)
    # Linear probability outcome: effects are percentage points, not exp(beta)-1.
    tab[, c("pct", "pct_low", "pct_high") := NULL]
    tab[, `:=`(pp = 100 * estimate, pp_low = 100 * ci_low, pp_high = 100 * ci_high,
        homes_input = sum(cells$homes), n_county_vintage_cells = n)]
    tabs[[id]] <- tab
}
coefficients <- rbindlist(tabs)
fwrite(coefficients, file.path(out_dir, "share_coefficients.csv"))
saveRDS(models, file.path(out_dir, "models-private.rds"))
theme_share <- theme_classic(base_size = 14) + theme(text = element_text(family = "serif"), legend.position = "bottom")
raw[, zone := factor(wind_zone, levels = 0:3, labels = c("National", "Zone I", "Zone II", "Zone III"))]
p <- ggplot(raw, aes(year_constr, mh_share_pct, color = zone, shape = zone, linetype = zone)) +
    geom_line() + geom_point(size = 2) + geom_vline(xintercept = 1993.5, linetype = "dotted") +
    scale_color_manual(values = c("black", "#0072B2", "#D55E00", "#009E73")) +
    scale_shape_manual(values = c(18,16,17,15)) + scale_x_continuous(breaks = 1989:1999) +
    labs(x = "Original construction year in snapshot", y = "Manufactured housing share (%)", color = NULL, shape = NULL, linetype = NULL,
        caption = "Surviving 2023 dwelling parcels; no sale requirement. Static treatment starts in 1994.") + theme_share
for (ext in c("pdf", "png")) ggsave(file.path(out_dir, paste0("share_by_vintage.", ext)), p, width = 9, height = 5, dpi = 150)
plotdata <- coefficients[grepl("dynamic$", specification)]
plotdata[, vintage := as.integer(sub("year_constr::([0-9]+).*", "\\1", term))]
plotdata[, comparison := fifelse(specification == "national_dynamic", "National: county-adjusted", fifelse(specification == "pooled_dynamic", "II/III minus I", fifelse(grepl(":z2$", term), "II minus I", "III minus I")))]
plotdata <- rbind(plotdata, unique(plotdata[, .(comparison)])[, `:=`(vintage = 1993L, pp = 0, pp_low = 0, pp_high = 0)], fill = TRUE)
p <- ggplot(plotdata, aes(vintage, pp)) + geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
    geom_vline(xintercept = 1993.5, linetype = "dotted") + geom_errorbar(aes(ymin = pp_low, ymax = pp_high), width = .15) +
    geom_point(color = "#0072B2", size = 2) + facet_wrap(~comparison, ncol = 2) + scale_x_continuous(breaks = seq(1989,1999,2)) +
    labs(x = "Original construction year in snapshot", y = "MH share contrast (percentage points)",
        caption = "1993 reference; county-clustered 95% intervals. Parcel-count weights.") + theme_share
for (ext in c("pdf", "png")) ggsave(file.path(out_dir, paste0("share_vintage_coefficients.", ext)), p, width = 9, height = 5, dpi = 150)
files <- c(here("program", "corelogic", "estimate-corelogic-share.R"), here("program", "lib", "corelogic-setup.R"), here("program", "lib", "corelogic-windzone.R"))
dir.create(file.path(out_dir, "source")); file.copy(files, file.path(out_dir, "source"))
write_json(list(status = "complete", build = input, slurm_job = Sys.getenv("SLURM_JOB_ID"), homes = sum(cells$homes),
    construction_window = c(1989L,1999L), reference_vintage = 1993L, post_from = 1994L,
    outcome = "MH indicator, surviving 2023 dwelling parcels; effects in percentage points",
    weights = "One per parcel, implemented through county-vintage counts", code_reference_md5 = as.list(tools::md5sum(c(files, geo_file))),
    session = capture.output(sessionInfo())), file.path(out_dir, "manifest.json"), pretty = TRUE, auto_unbox = TRUE)
cat("COMPLETE", out_dir, "\n")
