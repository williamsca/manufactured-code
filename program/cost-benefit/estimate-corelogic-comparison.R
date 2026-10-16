# Paper's Zone III comparison. Preserve the MHS-based welfare outputs for
# other documents; this table uses county-level prices and Zone III benefits.
# Benefits are the zone-specific outputs of estimate-hud-comparison.R, NOT its
# MHS price estimates or pooled benefit-cost ratios. Money below is dollars.
library(here)
library(data.table)
library(kableExtra)

prices <- fread(here("output/corelogic/prices/mh_static_ladder.csv"))
means <- fread(here("output/corelogic/prices/mh_price_summary.csv"))
benefits <- fread(here("output/cost-benefit/hud-comparison-scalars.csv"))
mhs <- fread(here("output/mhs/mhs-scalars.csv"))
get_b <- function(nm) {
    x <- benefits[statistic == nm, value]
    stopifnot(length(x) == 1L, is.finite(x))
    x
}
base <- means[wind_zone == 3 & post == 0, mean_2000]
stopifnot(length(base) == 1L, base > 0)
price <- prices[grepl("z3$", term) &
    specification %in% paste0("ladder_", c(1L, 2L, 4L, 5L))][order(specification)]
stopifnot(nrow(price) == 4L, all(price$estimate > 0))
premium <- base * expm1(price$estimate)
gross <- 1000 * get_b("flood_private_pv_z3") # avoided damage, before NFIP payments
public <- 1000 * get_b("flood_public_pv_z3")
private <- gross - public

hud <- fread(here("notes/hud-wind-forecasts.csv"))
weights <- mhs[match(c("base_wt_single", "base_wt_double"), statistic), value]
stopifnot(length(weights) == 2L, abs(sum(weights) - 1) < 1e-10)
forecast <- function(it) {
    rows <- hud[zone == "3" & item == it]
    if (all(c("single", "multi") %in% rows$section)) {
        x <- rows[match(c("single", "multi"), section), (lo + hi) / 2]
        sum(weights * x) * get_b("hud_cpi_factor")
    } else {
        stopifnot(nrow(rows) == 1L)
        mean(c(rows$lo, rows$hi)) * get_b("hud_cpi_factor")
    }
}
hud_price <- forecast("consumer_price")
hud_resource <- forecast("production_cost")
hud_private <- forecast("private_benefit_pv") + forecast("mortality_benefit_pv")
hud_public <- forecast("public_benefit_pv")
sc <- c(price_base = base, premium_baseline = premium[1],
    premium_min = min(premium), premium_max = max(premium),
    gross_pv = gross, retained_pv = private, public_pv = public,
    gross_share_baseline = gross / premium[1],
    gross_share_min = min(gross / premium), gross_share_max = max(gross / premium),
    private_share_baseline = private / premium[1],
    private_gap = premium[1] - private,
    hud_price = hud_price, hud_resource_cost = hud_resource,
    hud_private_ratio = hud_private / hud_price,
    hud_all_ratio = (hud_private + hud_public) / hud_resource)
stopifnot(all(is.finite(sc)), gross > 0, private > 0, public > 0)
fwrite(data.table(statistic = names(sc), value = unname(sc)),
    here("output/cost-benefit/corelogic-comparison-scalars.csv"))
fd <- function(x) paste0("\\$", formatC(round(x), format = "f", digits = 0, big.mark = ","))
ratio <- function(x) formatC(x, format = "f", digits = 2)
tab <- data.table(
    item = c("Consumer price increase / resale premium", "Production cost increase",
        "Reduced wind losses, mortality and injury", "Reduced flood losses, net of NFIP payouts",
        "Reduced FEMA relief", "Reduced NFIP payouts", "Private benefits",
        "All measured benefits", "Private benefits / price", "All benefits / resource cost",
        "All measured benefits / resale premium"),
    hud = c(fd(hud_price), fd(hud_resource), fd(hud_private), "---",
        fd(hud_public), "---", fd(hud_private), fd(hud_private + hud_public),
        ratio(hud_private / hud_price), ratio((hud_private + hud_public) / hud_resource), "---"),
    estimate = c(fd(premium[1]), "---", "---", fd(private), "---", fd(public),
        fd(private), fd(gross), ratio(private / premium[1]), "---", ratio(gross / premium[1])))
writeLines(as.character(kbl(tab, format = "latex", booktabs = TRUE, escape = FALSE,
    col.names = c("", "HUD forecast", "Estimate"), align = c("l", "r", "r"))),
    here("output/cost-benefit/corelogic-comparison.tex"))
