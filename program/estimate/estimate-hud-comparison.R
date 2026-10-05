# Compare HUD's ex ante forecasts for the 1994 wind standard with the
# estimates in this paper, object by object.
#
# HUD forecasts: notes/hud-wind-forecasts.csv (Dacquisto and Rodda 2006,
#   Housing Impact Analysis), in 1992 dollars. Converted to 2000 dollars with
#   the CPI so they sit in the same units as every estimate in the paper.
# Cost side:    MHS price DiD by home size and wind zone (II, III).
# Benefit side: NFIP flood-claim Poisson DiD by county wind zone, converted to
#   a per-unit present value using HUD's own discount rate and home lifespan.
#
# Inputs:  derived/sample-mhs-type.Rds, derived/nfip-claims.Rds,
#          derived/welfare-county-vintage.Rds, output/results/mhs-scalars.csv
# Outputs: output/results/hud-comparison.tex
#          output/results/hud-comparison-scalars.csv

rm(list = ls())
library(here)
library(data.table)
library(fixest)
library(kableExtra)

source(here("program", "import", "project-params.R"))
source(here("program", "import", "rd-client.R"))
source(here("program", "import", "geo-coverage-checks.R"))
source(here("program", "estimate", "welfare-lib.R"))

# ---------------------------------------------------------------------------
# Parameters ----
# ---------------------------------------------------------------------------

# HUD's discount rate (7%) and home lifespan (33 years) are set in
# project-params.R, shared with estimate-welfare.R.
HUD_DOLLAR_YEAR   <- 1992L

# Outcomes entering each benefit calculation. Private benefit is avoided damage
# to the building and its contents; the public benefit is the reduction in
# NFIP payments, the closest observable to HUD's reduced FEMA spending.
V_PRIVATE <- c("building_damage", "contents_damage")
V_PUBLIC  <- c("net_building_pmt", "net_contents_pmt")
V_LOSS    <- c(V_PRIVATE, V_PUBLIC)

# ---------------------------------------------------------------------------
# HUD forecasts, in 2000 dollars ----
# ---------------------------------------------------------------------------

dt_cpi <- fread(here("derived", "cpi-bls.csv"))[, .(cpi = mean(cpi)), by = year]
CPI_FACTOR <- dt_cpi[year == DISCOUNT_YEAR, cpi] / dt_cpi[year == HUD_DOLLAR_YEAR, cpi]
stopifnot(length(CPI_FACTOR) == 1L, is.finite(CPI_FACTOR))

dt_hud <- fread(here("notes", "hud-wind-forecasts.csv"))
dt_hud[, zone := as.character(zone)]
dt_hud[unit == "usd_1992", `:=`(lo = lo * CPI_FACTOR, hi = hi * CPI_FACTOR)]
get_hud <- function(it, z = "all", s = "all", col = "lo") {
    out <- dt_hud[item == it & zone == z & section == s, get(col)]
    stopifnot(length(out) == 1L)
    out
}

hud_bcr <- get_hud("annual_benefit_total") / get_hud("annual_cost_total")

# ---------------------------------------------------------------------------
# Cost side: price effect by home size and wind zone ----
# ---------------------------------------------------------------------------

# Late-period difference-in-differences: the post period starts at
# LASTING_START_MHS, so the premium that persists after the lending expansion
# is measured, and the 1994-1999 transition years are dropped. Zone is the
# highest wind zone in the state. Within-size state and year effects, as in
# the section-type table of estimate-mhs.R.
dt_type <- readRDS(here("derived", "sample-mhs-type.Rds"))
dt_type <- dt_type[between(year, MIN_YEAR_MHS, MAX_YEAR_MHS) &
                   (year < 1994L | year >= LASTING_START_MHS)]
dt_type[, post := as.numeric(year >= LASTING_START_MHS)]
dt_type[, `:=`(
    z2  = post * (treated & !treated_wz3),
    z3  = post * treated_wz3,
    z23 = post * treated)]

wt_size <- unique(dt_type[, .(section_type, base_wt)])
wt <- setNames(wt_size$base_wt, as.character(wt_size$section_type))

est_cost <- feols(
    price ~ z2:section_type + z3:section_type |
        statefp^section_type + year^section_type,
    data = dt_type, weights = ~reg_wt, cluster = ~statefp)
est_cost23 <- feols(
    price ~ z23:section_type | statefp^section_type + year^section_type,
    data = dt_type, weights = ~reg_wt, cluster = ~statefp)

# fixest orders the two terms of an interaction inconsistently across
# coefficients, so look each one up by its parts rather than by its name.
term <- function(est, stem, size) {
    nm <- grep(paste0("(^|:)", stem, "(:|$)"), names(coef(est)), value = TRUE)
    nm <- grep(paste0("section_type", size), nm, value = TRUE)
    stopifnot(length(nm) == 1L)
    nm
}
one <- function(est, stem, size) {
    nm <- term(est, stem, size)
    c(est = coef(est)[[nm]], se = se(est)[[nm]])
}
# Size-weighted effect (fixed national basket, as in the paper's price index),
# with a standard error from the joint covariance of the two size coefficients.
size_weighted <- function(est, stem) {
    nm <- c(term(est, stem, "single"), term(est, stem, "double"))
    w  <- unname(wt[c("single", "double")])
    c(est = sum(w * coef(est)[nm]),
      se  = sqrt(drop(t(w) %*% vcov(est)[nm, nm] %*% w)))
}
cost <- list(
    z2_single = one(est_cost, "z2", "single"),
    z2_double = one(est_cost, "z2", "double"),
    z3_single = one(est_cost, "z3", "single"),
    z3_double = one(est_cost, "z3", "double"),
    z2  = size_weighted(est_cost, "z2"),
    z3  = size_weighted(est_cost, "z3"),
    z23_single = one(est_cost23, "z23", "single"),
    z23_double = one(est_cost23, "z23", "double"),
    z23 = size_weighted(est_cost23, "z23"))
cat("\nPrice effects (2000 dollars):\n")
print(round(do.call(rbind, cost), 1))

# ---------------------------------------------------------------------------
# Benefit side: flood damage by county wind zone ----
# ---------------------------------------------------------------------------

dt_claims <- readRDS(here("derived", "nfip-claims.Rds"))
dt_claims <- dt_claims[
    between(year_constr, MIN_YEAR_CONSTR, MAX_YEAR_CONSTR) &
    between(year_loss, MIN_YEAR_LOSS, MAX_YEAR_LOSS)]
dt_claims[, (V_LOSS) := lapply(.SD, pmin, MAX_CLAIM_LOSS), .SDcols = V_LOSS]
# Same estimation sample as estimate-nfip.R: Poisson excludes negative payments.
dt_claims <- dt_claims[
    (is.na(net_building_pmt) | net_building_pmt >= 0) &
    (is.na(net_contents_pmt) | net_contents_pmt >= 0)]

dt_wz <- rd_read("ecfr_wind_zone", version = ECFR_WIND_ZONE_VERSION)
dt_claims <- merge(dt_claims, dt_wz, by = "countyfp", all.x = TRUE)
assert_geo_coverage(dt_claims, "wind_zone", "countyfp",
                    "estimate-hud-comparison.R: claims x ecfr_wind_zone")

dt_claims[, post1994 := as.integer(year_constr >= 1994L)]
dt_claims[, `:=`(
    mh_z1  = post1994 * mh * (wind_zone == 1L),
    mh_z2  = post1994 * mh * (wind_zone == 2L),
    mh_z3  = post1994 * mh * (wind_zone == 3L),
    mh_z23 = post1994 * mh * (wind_zone >= 2L))]

# Zone I is the placebo: the standard did not bind there. Estimating it
# alongside II and III separates the wind-zone contrast from the pooled
# post-1994 difference.
fit_zone <- function(y) {
    fepois(as.formula(paste0(
               y, " ~ mh_z1 + mh_z2 + mh_z3 | countyfp^year_loss + mh + post1994")),
           data = dt_claims, cluster = ~countyfp)
}
fit_pool <- function(y) {
    fepois(as.formula(paste0(
               y, " ~ mh_z1 + mh_z23 | countyfp^year_loss + mh + post1994")),
           data = dt_claims, cluster = ~countyfp)
}
est_zone <- setNames(lapply(V_LOSS, fit_zone), V_LOSS)
est_pool <- setNames(lapply(V_LOSS, fit_pool), V_LOSS)

# Baselines: pre-1994 manufactured-home means and the pre-1994 insured claim
# rate, by zone group. The per-unit calculation asks what a buyer of a
# post-1994 home saves relative to an otherwise identical pre-1994 home, so
# it pairs the pre-1994 hazard with the pre-1994 mean (see estimate-welfare.R).
dt_mh_pre <- dt_claims[mh == 1L & post1994 == 0L]
dt_rate <- readRDS(here("derived", "welfare-county-vintage.Rds"))
dt_rate <- merge(dt_rate, dt_wz, by = "countyfp", all.x = TRUE)
dt_rate[is.na(wind_zone), wind_zone := 1L]
dt_rate <- dt_rate[!is.na(policies_n) & !post1994]

baseline <- function(zones) {
    list(
        rate = dt_rate[wind_zone %in% zones, sum(claims_n) / sum(policies_n)],
        mean = dt_mh_pre[wind_zone %in% zones,
                         lapply(.SD, mean, na.rm = TRUE), .SDcols = V_LOSS])
}
ANNUITY <- npv_annuity(1, HUD_DISCOUNT_RATE, HUD_LIFESPAN)

# Proportional reduction in expected loss, with a delta-method standard error.
reduction <- function(est, term) {
    b <- coef(est)[[term]]
    c(pct = 100 * (exp(b) - 1), se = 100 * exp(b) * se(est)[[term]])
}
# Per-unit present value (2000 dollars, in $000) of the reduction in `v_set`.
pv_unit <- function(est_list, term, zones, v_set) {
    bs <- baseline(zones)
    annual <- bs$rate * sum(vapply(v_set, function(v) {
        bs$mean[[v]] * (1 - exp(coef(est_list[[v]])[[term]]))
    }, numeric(1)))
    annual * ANNUITY
}

ben <- list()
for (z in 2:3) {
    term <- paste0("mh_z", z)
    ben[[paste0("z", z)]] <- list(
        bldg_red  = reduction(est_zone$building_damage, term),
        pv_priv   = pv_unit(est_zone, term, z, V_PRIVATE),
        pv_pub    = pv_unit(est_zone, term, z, V_PUBLIC))
}
ben$z23 <- list(
    bldg_red = reduction(est_pool$building_damage, "mh_z23"),
    pv_priv  = pv_unit(est_pool, "mh_z23", 2:3, V_PRIVATE),
    pv_pub   = pv_unit(est_pool, "mh_z23", 2:3, V_PUBLIC))
ben$z1_bldg_red <- reduction(est_zone$building_damage, "mh_z1")

cat("\nBenefit side (PV in $000 of 2000 dollars):\n")
str(ben)

# Flood-only benefit-cost ratio: private PV over the size-weighted price effect.
bcr <- c(
    z2  = ben$z2$pv_priv  / (cost$z2[["est"]] / 1000),
    z3  = ben$z3$pv_priv  / (cost$z3[["est"]] / 1000),
    z23 = ben$z23$pv_priv / (cost$z23[["est"]] / 1000))
cat("\nFlood-only benefit-cost ratios:\n"); print(round(bcr, 2))

# ---------------------------------------------------------------------------
# Table ----
# ---------------------------------------------------------------------------

fd <- function(x) paste0("\\$", formatC(round(x), format = "f", digits = 0,
                                       big.mark = ","))
fse <- function(x) paste0("(", formatC(round(x), format = "f", digits = 0,
                                       big.mark = ","), ")")
fpct <- function(x, se = NULL) {
    out <- paste0(sub("^-", "$-$", formatC(x, format = "f", digits = 1)), "\\%")
    if (is.null(se)) out else paste0(out, " (", formatC(se, format = "f", digits = 1), ")")
}
fx <- function(x) formatC(x, format = "f", digits = 2)
fcost <- function(v) paste(fd(v["est"]), fse(v["se"]))
fhud_range <- function(it, z) {
    lo <- get_hud(it, z); hi <- get_hud(it, z, col = "hi")
    if (isTRUE(all.equal(lo, hi))) fd(lo) else paste0(fd(lo), "--", fd(hi))
}
usd <- function(x_000) fd(x_000 * 1000)

# Preserve the range across zones instead of imposing arbitrary zone weights.
hud_range <- function(item, section = "all") {
    c(lo = min(vapply(c("2", "3"), function(z) get_hud(item, z, section), numeric(1))),
      hi = max(vapply(c("2", "3"), function(z) get_hud(item, z, section, "hi"), numeric(1))))
}
format_range <- function(x) paste0(fd(x[["lo"]]), "--", fd(x[["hi"]]))
hud_private <- hud_range("private_benefit_pv")
hud_mortality <- hud_range("mortality_benefit_pv")
hud_public <- hud_range("public_benefit_pv")
# Zone II is the lower endpoint of both private components, Zone III the upper.
hud_private_total <- hud_private + hud_mortality

dt_tab <- data.table(
    label = c("Consumer price, single-section", "Consumer price, multi-section",
              "Reduced losses (wind)", "Reduced losses (flood)",
              "Mortality and injury", "Reduced FEMA relief",
              "Reduced NFIP payouts", "Total", "Benefit-cost ratio"),
    hud_private = c(format_range(hud_range("consumer_price", "single")),
                    format_range(hud_range("consumer_price", "multi")),
                    format_range(hud_private), "---", format_range(hud_mortality),
                    "---", "---", format_range(hud_private_total), fx(hud_bcr)),
    hud_public = c(rep("---", 5), format_range(hud_public), "---",
                   format_range(hud_public), ""),
    est_private = c(fcost(cost$z23_single), fcost(cost$z23_double),
                    "---", usd(ben$z23$pv_priv), "Not estimated", "---", "---",
                    usd(ben$z23$pv_priv), fx(bcr["z23"])),
    est_public = c(rep("---", 5), "Not estimated", usd(ben$z23$pv_pub),
                   usd(ben$z23$pv_pub), ""))

dir.create(here("output", "results"), showWarnings = FALSE, recursive = TRUE)
tab <- kbl(dt_tab, format = "latex", booktabs = TRUE, escape = FALSE,
    col.names = c("", "Private", "Public", "Private", "Public"),
    align = c("l", rep("r", 4))) |>
    add_header_above(c(" " = 1, "HUD forecast" = 2, "Estimate" = 2)) |>
    pack_rows("Costs (2000 dollars per unit)", 1, 2) |>
    pack_rows("Benefits (present value per unit)", 3, 7) |>
    pack_rows("Totals", 8, 9)
# Each source has one BCR; the notes identify their different numerators.
tab <- sub(paste0(fx(hud_bcr), " &  & ", fx(bcr["z23"]), " & "),
           paste0("\\multicolumn{2}{c}{", fx(hud_bcr), "} & ",
                  "\\multicolumn{2}{c}{", fx(bcr["z23"]), "}"),
           as.character(tab), fixed = TRUE)
writeLines(tab, here("output", "results", "hud-comparison.tex"))

# ---------------------------------------------------------------------------
# Scalars ----
# ---------------------------------------------------------------------------

# Money in $000 of 2000 dollars, as elsewhere in output/results/.
sc <- c(
    hud_discount_rate = HUD_DISCOUNT_RATE,
    hud_lifespan = HUD_LIFESPAN,
    hud_cpi_factor = CPI_FACTOR,
    hud_bcr = hud_bcr,
    hud_private_total_lo = hud_private_total[["lo"]] / 1000,
    hud_private_total_hi = hud_private_total[["hi"]] / 1000,
    hud_public_total_lo = hud_public[["lo"]] / 1000,
    hud_public_total_hi = hud_public[["hi"]] / 1000,
    hud_private_pv_z2 = get_hud("private_benefit_pv", "2") / 1000,
    hud_private_pv_z3 = get_hud("private_benefit_pv", "3") / 1000,
    cost_z2_single = cost$z2_single[["est"]] / 1000,
    cost_z2_double = cost$z2_double[["est"]] / 1000,
    cost_z3_single = cost$z3_single[["est"]] / 1000,
    cost_z3_double = cost$z3_double[["est"]] / 1000,
    cost_z2 = cost$z2[["est"]] / 1000,
    cost_z3 = cost$z3[["est"]] / 1000,
    cost_z23 = cost$z23[["est"]] / 1000,
    bldg_red_z1 = ben$z1_bldg_red[["pct"]],
    bldg_red_z2 = ben$z2$bldg_red[["pct"]],
    bldg_red_z3 = ben$z3$bldg_red[["pct"]],
    bldg_red_z23 = ben$z23$bldg_red[["pct"]],
    flood_private_pv_z2 = ben$z2$pv_priv,
    flood_private_pv_z3 = ben$z3$pv_priv,
    flood_private_pv_z23 = ben$z23$pv_priv,
    flood_public_pv_z23 = ben$z23$pv_pub,
    flood_public_pv_z2 = ben$z2$pv_pub,
    flood_public_pv_z3 = ben$z3$pv_pub,
    bcr_z2 = bcr[["z2"]], bcr_z3 = bcr[["z3"]], bcr_z23 = bcr[["z23"]])
fwrite(data.table(statistic = names(sc), value = unname(sc)),
       here("output", "results", "hud-comparison-scalars.csv"))
