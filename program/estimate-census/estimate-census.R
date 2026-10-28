# Census 2000 check on the CoreLogic quantity decline (TODO Chunk Q2).
#
# County x construction-vintage-bin counts of occupied MH and single-family
# units from Census 2000, with the county-level analog of the CoreLogic
# quantity design (PPML, county FE, Zone II/III x post). Bins: 1980-89,
# 1990-94 (reference), 1995-98, 1999-2000. Inputs: derived/census2000-tenure-
# county-vintage.Rds (import-census-tenure.R), derived/ecfr-windzone.csv.
# Outputs: output/census/ (tables, coefficients, figure, sanity checks,
# census-scalars.csv).

rm(list = ls())
library(here)
library(data.table)
library(fixest)
library(ggplot2)

source(here("program", "estimate-census", "census-lib.R"))
out_dir <- here("output", "census")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

BINS     <- c("1980_1989", "1990_1994", "1995_1998", "1999_2000")
REF_BIN  <- "1990_1994"
POST     <- c("1995_1998", "1999_2000")
ANDREW   <- c("12086", "12087")  # Miami-Dade (Dade) and Monroe, Hurricane Andrew 1992

# ---------------------------------------------------------------------------
# Input and sanity checks
# ---------------------------------------------------------------------------
tn <- readRDS(here("derived", "census2000-tenure-county-vintage.Rds"))
checks <- list()
add_check <- function(name, value, note = "")
    checks[[length(checks) + 1L]] <<- data.table(check = name, value = value, note = note)

# Uniqueness and missing values
stopifnot(!anyDuplicated(tn, by = c("countyfp", "vintage_census", "tenure")))
add_check("rows", nrow(tn))
add_check("counties", uniqueN(tn$countyfp))
add_check("missing_values", sum(is.na(tn[, .(mh_units, sb_units, tot_units, mh_total_h030)])))
stopifnot(sum(is.na(tn)) == 0)

# Cross-field: occupied MH over all nine vintages cannot exceed all MH (H030010).
ck <- tn[, .(mh_occ = sum(mh_units), mh_all = mh_total_h030[1]), by = countyfp]
add_check("counties_occupied_mh_exceeds_h030", sum(ck$mh_occ > ck$mh_all))
stopifnot(all(ck$mh_occ <= ck$mh_all))
add_check("occupied_share_of_h030_mh", sum(ck$mh_occ) / sum(ck$mh_all),
          "occupied MH, all vintages, over all MH units incl. vacant")

# Cross-field: the four bins used here reproduce the pooled-tenure file.
pooled <- readRDS(here("derived", "census2000-mh-county-vintage.Rds"))
chk <- merge(tn[vintage_census %in% BINS, .(mh = sum(mh_units), tot = sum(tot_units)),
                by = .(countyfp, vintage_census)],
             pooled, by = c("countyfp", "vintage_census"))
add_check("pooled_file_mismatches", sum(chk$mh != chk$mh_units | chk$tot != chk$total_units))
stopifnot(nrow(chk) == nrow(pooled), all(chk$mh == chk$mh_units), all(chk$tot == chk$total_units))

# Bins vs. H030 total, net of pre-1980 stock (pre-1980 is what the bins omit).
by_vint <- tn[, .(mh = sum(mh_units)), by = vintage_census][order(vintage_census)]
fwrite(by_vint, file.path(out_dir, "census-mh-by-vintage.csv"))
add_check("mh_share_in_four_bins", sum(tn[vintage_census %in% BINS, mh_units]) / sum(tn$mh_units),
          "occupied MH in 1980-2000 bins over occupied MH in all vintages")

# Wind zones. Census 2000 counties absent from the zone list (NYC boroughs,
# two Virginia cities later merged, Shannon SD) lie in states with no Zone II/III
# county, so they are Zone I. Alaska and Hawaii are excluded, as in CoreLogic.
wz <- fread(here("derived", "ecfr-windzone.csv"), colClasses = list(character = "countyfp"))
stopifnot(!anyDuplicated(wz$countyfp))
cty <- unique(tn[, .(countyfp, mh_total = mh_total_h030)])
cty[, statefp := substr(countyfp, 1, 2)]
cty <- cty[!statefp %in% c("02", "15")]
cty <- merge(cty, wz, by = "countyfp", all.x = TRUE)
unz <- cty[is.na(wind_zone)]
add_check("counties_without_zone_assigned_zone1", nrow(unz), paste(unz$countyfp, collapse = " "))
stopifnot(setequal(unz$countyfp, c("36005", "36047", "36081", "36085", "46113", "51515", "51560", "08014")[
    c("36005", "36047", "36081", "36085", "46113", "51515", "51560", "08014") %in% unz$countyfp]),
    all(unz$countyfp %in% c("36005", "36047", "36081", "36085", "46113", "51515", "51560")))
cty[is.na(wind_zone), wind_zone := 1L]
cty[, `:=`(z2 = as.integer(wind_zone == 2), z3 = as.integer(wind_zone == 3))]
add_check("zone_counties_II", sum(cty$z2)); add_check("zone_counties_III", sum(cty$z3))
add_check("zone_listed_counties_not_in_census", length(setdiff(wz$countyfp, tn$countyfp)),
          paste(setdiff(wz$countyfp, tn$countyfp), collapse = " "))

# Coverage against the CoreLogic quantity sample (counties with any MH, 1989-99).
cl_file <- here("output", "corelogic", "quantities", "mh_counts_by_county_vintage.csv")
if (file.exists(cl_file)) {
    cl <- fread(cl_file, colClasses = list(character = "countyfp"))
    cl_cty <- unique(cl$countyfp)
    census_cty <- tn[, .(mh = sum(mh_units)), by = countyfp][mh > 0, countyfp]
    census_cty <- setdiff(census_cty, unique(tn[substr(countyfp, 1, 2) %in% c("02", "15"), countyfp]))
    add_check("corelogic_quantity_counties", length(cl_cty))
    add_check("census_counties_with_mh", length(census_cty))
    add_check("in_corelogic_not_census", length(setdiff(cl_cty, census_cty)),
              paste(setdiff(cl_cty, census_cty), collapse = " "))
    add_check("in_census_not_corelogic", length(setdiff(census_cty, cl_cty)))
    mhc <- tn[countyfp %in% setdiff(census_cty, cl_cty) & vintage_census %in% BINS,
              sum(mh_units)] / tn[vintage_census %in% BINS, sum(mh_units)]
    add_check("share_census_mh_in_counties_missing_from_corelogic", mhc)
}

# ---------------------------------------------------------------------------
# Panels: county x bin x type (mh = 1 occupied MH, mh = 0 occupied 1-unit site-built)
# ---------------------------------------------------------------------------
build_panel <- function(tn_sub) {
    d <- tn_sub[vintage_census %in% BINS,
                .(mh_units = sum(mh_units), sb_units = sum(sb_units)),
                by = .(countyfp, bin = as.character(vintage_census))]
    # Analog of the CoreLogic support: counties with any MH across the four bins.
    keep <- d[, .(m = sum(mh_units)), by = countyfp][m > 0, countyfp]
    d <- merge(d[countyfp %in% keep], cty[, .(countyfp, statefp, z2, z3)], by = "countyfp")
    stopifnot(uniqueN(d, by = c("countyfp", "bin")) == nrow(d))
    long <- rbind(d[, .(countyfp, statefp, bin, z2, z3, mh = 1L, homes = mh_units)],
                  d[, .(countyfp, statefp, bin, z2, z3, mh = 0L, homes = sb_units)])
    long[, post := as.integer(bin %in% POST)]
    long[, `:=`(post_z2 = post * z2, post_z3 = post * z3,
                post_mh_z2 = post * mh * z2, post_mh_z3 = post * mh * z3,
                z2_mh = z2 * mh, z3_mh = z3 * mh)]
    stopifnot(!anyDuplicated(long, by = c("countyfp", "bin", "mh")), !anyNA(long), all(long$homes >= 0))
    long[]
}

fit_k <- function(f, k, x) {
    d <- if (k <= 2) x[mh == 1L] else x
    m <- fepois(f(k), d, vcov = ~countyfp, mem.clean = TRUE)
    list(fit = summary(m, lean = TRUE), counties = uniqueN(d$countyfp[obs(m)]))
}

samples <- list(
    all      = tn,
    owner    = tn[tenure == "owner"],
    renter   = tn[tenure == "renter"],
    noandrew = tn[!countyfp %in% ANDREW])
panels <- lapply(samples, build_panel)
for (nm in names(panels)) add_check(paste0("panel_counties_", nm), uniqueN(panels[[nm]]$countyfp))
add_check("panel_mh_units_all", sum(panels$all[mh == 1L, homes]))
stopifnot(all.equal(sum(panels$all[mh == 1L, homes]),
                    sum(tn[vintage_census %in% BINS & countyfp %in% panels$all$countyfp, mh_units])))
# Owner + renter partition the pooled count exactly.
stopifnot(sum(panels$owner[mh == 1L, homes]) + sum(panels$renter[mh == 1L, homes]) ==
          sum(panels$all[mh == 1L, homes]))

# Vacancy-adjusted pooled counts (all MH incl. vacant; vacancy independent of
# vintage within county and type), from import-census-takeup.R.
va <- readRDS(here("derived", "census2000-takeup-county-vintage.Rds"))
va <- va[vintage_census %in% BINS]
tn_va <- va[, .(countyfp, vintage_census = factor(vintage_census, levels = BINS),
                tenure = "all", mh_units = mh_units, sb_units = sb_units,
                mh_total_h030 = 0L)]
panels$vacadj <- build_panel(tn_va)

# ---------------------------------------------------------------------------
# Estimation
# ---------------------------------------------------------------------------
ladders <- lapply(panels, function(x) {
    res <- lapply(1:2, function(k) fit_k(ladder_formula, k, x))
    list(fits = lapply(res, `[[`, "fit"), counties = sapply(res, `[[`, "counties"))
})

dyn <- rbindlist(lapply(names(panels), function(s) rbindlist(lapply(1:4, function(k) {
    r <- fit_k(function(j) dynamic_formula(j, REF_BIN), k, panels[[s]])
    tab <- as.data.table(coeftable(r$fit), keep.rownames = "term")
    setnames(tab, names(tab)[2:5], c("estimate", "se", "t", "p"))
    ci <- confint(r$fit)
    tab[, `:=`(ci_low = ci[term, 1], ci_high = ci[term, 2], sample = s, column = k,
               n = nobs(r$fit), counties = r$counties,
               bin = sub("^bin::(.*):z[23](_mh)?$", "\\1", term),
               zone = sub("^.*:z([23])(_mh)?$", "\\1", term))]
    tab
}))))
dyn[, `:=`(pct = 100 * expm1(estimate), pct_low = 100 * expm1(ci_low), pct_high = 100 * expm1(ci_high))]
stopifnot(all(dyn$bin %in% BINS), all(dyn$zone %in% c("2", "3")))
fwrite(dyn, file.path(out_dir, "census-dynamic-coefficients.csv"))

stat <- rbindlist(lapply(names(ladders), function(s) rbindlist(lapply(1:2, function(k) {
    f <- ladders[[s]]$fits[[k]]
    tab <- as.data.table(coeftable(f), keep.rownames = "term")
    setnames(tab, names(tab)[2:5], c("estimate", "se", "t", "p"))
    tab[, `:=`(sample = s, column = k, zone = sub("^.*z([23])$", "\\1", term),
               n = nobs(f), counties = ladders[[s]]$counties[k])]
}))))
stat[, `:=`(pct = 100 * expm1(estimate))]
fwrite(stat, file.path(out_dir, "census-static-coefficients.csv"))

# ---------------------------------------------------------------------------
# Tables and figure
# ---------------------------------------------------------------------------
# Paper table: same layout as the CoreLogic quantity ladder. Columns 1-2 MH,
# 3-4 site-built as its own outcome (same two specifications), 5-6 owner- and
# renter-occupied MH with the column-2 specification.
paper_fit <- function(x, k) {
    m <- fepois(ladder_formula(k), x, vcov = ~countyfp, mem.clean = TRUE)
    list(fit = summary(m, lean = TRUE), counties = uniqueN(x$countyfp[obs(m)]))
}
six_in <- list(panels$all[mh == 1L], panels$all[mh == 1L], panels$all[mh == 0L], panels$all[mh == 0L],
               panels$owner[mh == 1L], panels$renter[mh == 1L])
six_k  <- c(1, 2, 1, 2, 2, 2)
six    <- Map(paper_fit, six_in, six_k)
six_fits <- lapply(six, `[[`, "fit"); six_counties <- sapply(six, `[[`, "counties")
etable(six_fits, tex = TRUE, file = file.path(out_dir, "census-static-paper.tex"), replace = TRUE,
    digits = "r3", fitstat = c("n", "pr2"), keep = "%post_", style.tex = style.tex(tablefoot = FALSE),
    depvar = FALSE,
    headers = list("Outcome:" = list("MH" = 2, "Site-built" = 2, "MH" = 2),
                   "Occupants:" = list("All" = 4, "Owner" = 1, "Renter" = 1)),
    dict = c(post_z2 = "Zone II $\\times$ post", post_z3 = "Zone III $\\times$ post",
        countyfp = "County", bin = "Vintage", "statefp^bin" = "State $\\times$ vintage"),
    extralines = list("Counties" = format(six_counties, big.mark = ",")), notes = NULL)
six_tab <- rbindlist(lapply(1:6, function(j) {
    tab <- as.data.table(coeftable(six_fits[[j]]), keep.rownames = "term")
    setnames(tab, names(tab)[2:5], c("estimate", "se", "t", "p"))
    tab[, `:=`(column = j, zone = sub("^.*z([23])$", "\\1", term), n = nobs(six_fits[[j]]),
               counties = six_counties[j], pct = 100 * expm1(estimate))]
}))
stopifnot(nrow(six_tab) == 12, all(six_tab$zone %in% c("2", "3")))
fwrite(six_tab, file.path(out_dir, "census-static-paper-coefficients.csv"))

plot_dynamic <- function(s, k) {
    x <- dyn[sample == s & column == k]
    x[, comparison := fifelse(zone == "2", "Zone II minus Zone I", "Zone III minus Zone I")]
    x <- rbind(x, CJ(comparison = unique(x$comparison))[, `:=`(bin = REF_BIN, estimate = 0, ci_low = 0, ci_high = 0)], fill = TRUE)
    x[, bin := factor(bin, levels = BINS, labels = c("1980-89", "1990-94", "1995-98", "1999-2000"))]
    ggplot(x, aes(bin, estimate, group = 1)) +
        geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
        geom_vline(xintercept = 2.5, linetype = "dotted") +
        geom_ribbon(aes(ymin = ci_low, ymax = ci_high), fill = "#0072B2", alpha = .2) +
        geom_line(color = "#0072B2") + geom_point(color = "#0072B2", size = 2) +
        facet_wrap(~comparison, ncol = 2) +
        labs(x = "Construction year", y = "Log MH count, relative to 1990-94") +
        theme_classic(base_size = 14) + theme(text = element_text(family = "serif"),
            panel.grid.major.y = element_line(color = "gray85", linewidth = .4))
}
for (k in c(1, 2, 3)) for (ext in c("pdf", "png"))
    ggsave(file.path(out_dir, sprintf("census-dynamic-column%d.%s", k, ext)),
           plot_dynamic("all", k), width = 9, height = 5, dpi = 150)

# ---------------------------------------------------------------------------
# Scalars and sanity file
# ---------------------------------------------------------------------------
sc <- rbindlist(lapply(seq_len(nrow(stat)), function(i) with(stat[i], data.table(
    statistic = sprintf("census_static_%s_c%d_z%s_%s", sample, column, zone, c("est", "se", "pct")),
    value = c(estimate, se, pct)))))
sc <- rbind(sc, rbindlist(lapply(seq_len(nrow(dyn[sample == "all"])), function(i) with(dyn[sample == "all"][i],
    data.table(statistic = sprintf("census_dyn_c%d_z%s_%s_%s", column, zone, bin, c("est", "se")),
               value = c(estimate, se))))))
sc <- rbind(sc, rbindlist(lapply(seq_len(nrow(six_tab)), function(i) with(six_tab[i], data.table(
    statistic = sprintf("census_paper_c%d_z%s_%s", column, zone, c("est", "se", "pct")),
    value = c(estimate, se, pct))))))
sc <- rbind(sc, data.table(statistic = paste0("census_panel_counties_", names(panels)),
                           value = sapply(panels, function(x) uniqueN(x$countyfp))))
stopifnot(!anyDuplicated(sc$statistic), !anyNA(sc$value))
fwrite(sc, file.path(out_dir, "census-scalars.csv"))
fwrite(rbindlist(checks), file.path(out_dir, "census-sanity-checks.csv"))

print(rbindlist(checks), nrows = 100)
print(stat[, .(sample, column, zone, estimate = round(estimate, 3), se = round(se, 3), counties)], nrows = 100)
print(dcast(dyn[sample == "all"], column + zone ~ bin, value.var = "estimate"))
