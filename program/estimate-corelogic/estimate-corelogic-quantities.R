# Surviving MH parcels by county and construction year in the 2023 Property
# Basic snapshot: MH-only PPML event study and static ladder.
# Usage: ./run_remote.sh estimate-corelogic estimate-corelogic-quantities.R
rm(list = ls())
library(here)
cl_dir <- here("program", "estimate-corelogic")
source(file.path(cl_dir, "corelogic-setup.R"))
source(file.path(cl_dir, "corelogic-windzone.R"))
source(file.path(cl_dir, "corelogic-inventory.R"))
source(file.path(cl_dir, "corelogic-mh-only.R"))
ref <- Sys.getenv("CORELOGIC_REFERENCE")
if (!nzchar(ref)) stop("Set CORELOGIC_REFERENCE")
geo_file <- file.path(ref, "geo_county.parquet")
wz <- cl_windzone_counties(read_corelogic(paste("SELECT countyfp,statefp,name FROM read_parquet(", quote_path(geo_file), ")")))
# Match the price dwelling universe using snapshot fields; no sale eligibility screen.
glob <- quote_path(file.path(input, "properties", "*.parquet"))
dynamic_years <- CL_QUANTITY_VINTAGES
reference <- 1991L
cells <- cl_inventory_cells(glob, years = dynamic_years)
cells <- cells[, .(homes = sum(homes), mh_homes = sum(mh_homes), parcels = sum(parcels)),
    by = .(countyfp, year_constr)]
stopifnot(all(cells$homes == cells$parcels))
cells <- merge(cells, wz[, .(countyfp, wind_zone, statefp)], by = "countyfp", all.x = TRUE)
fwrite(cells[is.na(wind_zone), .(homes = sum(homes)), by = countyfp], file.path(out_dir, "unmatched_counties.csv"))
cells <- cells[!is.na(wind_zone)]
models <- list()
# MH-only quantities by construction vintage, with zero-count county-vintage cells.
# No site-built denominator, parcel weighting, or sale screen enters this count model.
quantity <- cl_mh_count_panel(cells, years = dynamic_years)
quantity_model <- fepois(cl_mh_only_formula(quantity = TRUE, reference = reference), quantity,
    vcov = ~countyfp, mem.clean = TRUE, lean = TRUE)
quantity_tab <- cl_mh_only_coefficients(quantity_model, "mh_only_quantity_dynamic", dynamic_years, reference)
fwrite(quantity_tab, file.path(out_dir, "mh_only_vintage_coefficients.csv"))
fwrite(quantity, file.path(out_dir, "mh_counts_by_county_vintage.csv"))
fwrite(quantity[, .(mh_homes = sum(mh_homes), counties = .N, zero_cells = sum(mh_homes == 0)),
    by = .(wind_zone, year_constr)], file.path(out_dir, "mh_counts_by_vintage.csv"))
models[["mh_only_quantity_dynamic"]] <- quantity_model
# Main paper figure: state x vintage FE, so zone contrasts use within-state variation.
# Florida has no Zone I county, so it informs III minus II but not either contrast with Zone I.
quantity_state_model <- fepois(cl_mh_only_formula(quantity = TRUE, state = TRUE, reference = reference), quantity,
    vcov = ~countyfp, mem.clean = TRUE, lean = TRUE)
quantity_state_tab <- cl_mh_only_coefficients(quantity_state_model, "mh_only_quantity_dynamic_state_vintage_fe", dynamic_years, reference)
fwrite(quantity_state_tab, file.path(out_dir, "mh_only_vintage_coefficients_state_vintage_fe.csv"))
models[["mh_only_quantity_dynamic_state_vintage_fe"]] <- quantity_state_model
cl_mh_only_paper_plot(quantity_state_tab, out_dir, quantity = TRUE)
cl_mh_only_paper_plot(quantity_state_tab, out_dir, quantity = TRUE, slides = TRUE)
cl_mh_only_compare_plot(quantity_tab, quantity_state_tab, out_dir, quantity = TRUE)
# Static counts: (1)-(2) MH, (3)-(4) site-built on the same MH-support county universe.
# SB is an outcome, not a comparison type: substitution can change its cohort counts.
type_counts <- cl_type_count_panel(cells)
ladder <- cl_mh_static_fits(type_counts, quantity = TRUE)
cl_mh_static_table(ladder, file.path(out_dir, "mh_static_ladder.tex"), quantity = TRUE)
fwrite(rbindlist(lapply(1:4, function(k) cl_coeftable(ladder$fits[[k]], paste0("ladder_", k))[,
    `:=`(counties = ladder$counties[k], housing_type = if (k <= 2) "MH" else "SB")])),
    file.path(out_dir, "mh_static_ladder.csv"))
# Aggregate cohort counts retain the separate outcomes for descriptive checks.
fwrite(type_counts[, .(homes = sum(homes), counties = uniqueN(countyfp)),
    by = .(wind_zone, mh, year_constr)], file.path(out_dir, "type_counts_by_vintage.csv"))
fwrite(type_counts[, .(homes = sum(homes), counties = uniqueN(countyfp)), by = .(wind_zone, mh, post)],
    file.path(out_dir, "mh_static_ladder_support.csv"))
models[paste0("mh_static_ladder_", 1:4)] <- ladder$fits
# Count DDD event study: MH and site-built counts over CL_QUANTITY_VINTAGES with county x type
# and state x vintage x type FE; mh_z terms are the MH-specific zone x vintage change.
type_dynamic <- cl_type_count_panel(cells, years = dynamic_years)
type_dynamic[, `:=`(mh_z2 = mh * z2, mh_z3 = mh * z3)]
count_ddd <- fepois(cl_type_es_formula("homes", ddd = TRUE, reference = reference), type_dynamic,
    vcov = ~countyfp, mem.clean = TRUE)
count_ddd_tab <- cl_type_es_coefficients(count_ddd, "count_es_ddd", ddd = TRUE,
    years = dynamic_years, reference = reference)[, outcome := "homes"]
fwrite(count_ddd_tab, file.path(out_dir, "type_es_coefficients.csv"))
cl_type_es_plot(count_ddd_tab, out_dir, "count_es_ddd", "homes",
    keep = c("MH minus site-built", "Site-built", "MH"))
models[["count_es_ddd"]] <- summary(count_ddd, lean = TRUE)
# Robustness: drop Florida (see estimate-corelogic-prices.R).
out_nofl <- file.path(out_dir, "no-florida"); dir.create(out_nofl)
quantity_nofl_tab <- cl_mh_only_coefficients(
    fepois(cl_mh_only_formula(quantity = TRUE, state = TRUE, reference = reference), quantity[statefp != "12"],
        vcov = ~countyfp, mem.clean = TRUE, lean = TRUE),
    "mh_only_quantity_dynamic_no_florida_state_vintage_fe", dynamic_years, reference)
fwrite(quantity_nofl_tab, file.path(out_nofl, "mh_only_vintage_coefficients_state_vintage_fe.csv"))
cl_mh_only_paper_plot(quantity_nofl_tab, out_nofl, quantity = TRUE)
ladder_nofl <- cl_mh_static_fits(type_counts[statefp != "12"], quantity = TRUE)
cl_mh_static_table(ladder_nofl, file.path(out_nofl, "mh_static_ladder.tex"), quantity = TRUE)
fwrite(rbindlist(lapply(1:4, function(k) cl_coeftable(ladder_nofl$fits[[k]], paste0("ladder_no_florida_", k))[,
    `:=`(counties = ladder_nofl$counties[k], housing_type = if (k <= 2) "MH" else "SB")])),
    file.path(out_nofl, "mh_static_ladder.csv"))
saveRDS(models, file.path(out_dir, "models-private.rds"))

files <- file.path(cl_dir, c("estimate-corelogic-quantities.R", "corelogic-setup.R",
    "corelogic-windzone.R", "corelogic-inventory.R", "corelogic-mh-only.R"))
dir.create(file.path(out_dir, "source")); file.copy(files, file.path(out_dir, "source"))
write_json(list(status = "complete", build = input, slurm_job = Sys.getenv("SLURM_JOB_ID"), homes = sum(cells$homes),
    mh_only_homes = sum(quantity$mh_homes), mh_only_county_vintage_cells = nrow(quantity),
    mh_only_quantity_specification = "County-FE PPML on MH counts with zero county-vintage cells; vintage FE; separate zone x vintage",
    mh_only_quantity_robustness = "Same PPML with state x vintage FE in place of vintage FE",
    paper_figure_specification = "mh_only_quantity_dynamic_state_vintage_fe",
    mh_static_ladder = "Static PPML post x zone II/III: (1) MH counts, county + vintage FE; (2) MH counts, county + state x vintage FE; (3) SB counts, county + vintage FE; (4) SB counts, county + state x vintage FE; all on the MH-support county universe with zero cohorts retained",
    pb_source_manifest_md5 = unname(tools::md5sum(file.path(Sys.getenv("CORELOGIC_PB_SOURCE"), "_meta.json"))),
    construction_window = range(dynamic_years), reference_vintage = reference,
    static_construction_window = range(CL_VINTAGES), post_from = 1994L,
    outcome = "Counts of surviving 2023 dwelling parcels by county, vintage and type; effects in log points",
    code_reference_md5 = as.list(tools::md5sum(c(files, geo_file))),
    session = capture.output(sessionInfo())), file.path(out_dir, "manifest.json"), pretty = TRUE, auto_unbox = TRUE)
cat("COMPLETE", out_dir, "\n")
