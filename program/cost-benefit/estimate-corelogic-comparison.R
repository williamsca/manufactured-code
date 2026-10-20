# Paper's Zone III comparison. Preserve the MHS-based welfare outputs for
# other documents; this table uses county-level prices and Zone III benefits.
# Benefits are the zone-specific outputs of estimate-hud-comparison.R, NOT its
# MHS price estimates or pooled benefit-cost ratios. Money below is dollars.
# The table separates the cost of the standard, which raises the price of new
# homes and is not identified by the vintage comparison, from the capitalized
# private value of resilience, which the vintage resale gap measures and which
# HUD's private benefit forecast predicts.
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
# Columns 1-2 report Zone III x post; columns 4-5 report Zone III x post x MH.
price <- prices[(specification %in% c("ladder_1", "ladder_2") & term == "post_z3") |
    (specification %in% c("ladder_4", "ladder_5") & term == "post_mh_z3")][order(specification)]
stopifnot(nrow(price) == 4L, all(price$estimate > 0))
premium <- base * expm1(price$estimate)
premium_lo <- base * expm1(price$ci_low)
premium_hi <- base * expm1(price$ci_high)
count <- fread(here("output/corelogic/quantities/mh_static_ladder.csv"))[
    term == "post_z3" & specification == "ladder_2" & housing_type == "MH"]
stopifnot(nrow(count) == 1L)
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
sc <- c(price_base = base, premium_baseline = premium[2],
    premium_min = min(premium), premium_max = max(premium),
    gross_pv = gross, retained_pv = private, public_pv = public,
    gross_share_baseline = gross / premium[2],
    gross_share_min = min(gross / premium), gross_share_max = max(gross / premium),
    private_share_baseline = private / premium[2],
    private_gap = premium[2] - private,
    hud_price = hud_price, hud_resource_cost = hud_resource,
    hud_private_ratio = hud_private / hud_price,
    hud_all_ratio = (hud_private + hud_public) / hud_resource,
    hud_private = hud_private, hud_public = hud_public, hud_private_cost_ratio = hud_private / hud_resource,
    premium_ci_lo_1 = premium_lo[1], premium_ci_hi_1 = premium_hi[1],
    premium_2 = premium[2], premium_ci_lo_2 = premium_lo[2], premium_ci_hi_2 = premium_hi[2])
stopifnot(all(is.finite(sc)), gross > 0, private > 0, public > 0)
fwrite(data.table(statistic = names(sc), value = unname(sc)),
    here("output/cost-benefit/corelogic-comparison-scalars.csv"))
fd <- function(x) sub("\\$-", "$-$\\$", paste0("\\$", formatC(round(x), format = "f",
    digits = 0, big.mark = ",")), fixed = TRUE)
ci <- function(lo, hi) paste0("[", fd(lo), ", ", fd(hi), "]")
ratio <- function(x) formatC(x, format = "f", digits = 2)
tab <- data.table(
    item = c("Consumer price increase", "Production cost increase",
        "Vintage resale price gap, column (1)", "\\quad 95\\% interval",
        "Vintage resale price gap, column (2)", "\\quad 95\\% interval",
        "Reduced wind losses, mortality and injury", "Reduced flood losses, net of NFIP payouts",
        "Reduced FEMA relief", "Reduced NFIP payouts",
        "Surviving MH count, column (2)", "Private benefits / production cost"),
    hud = c(fd(hud_price), fd(hud_resource), fd(hud_private), "", "", "",
        fd(hud_private), "---", fd(hud_public), "---", "---",
        ratio(hud_private / hud_resource)),
    estimate = c("---", "---", fd(premium[1]), ci(premium_lo[1], premium_hi[1]),
        fd(premium[2]), ci(premium_lo[2], premium_hi[2]), "---", fd(private),
        "---", fd(public), sub("-", "$-$", paste0(formatC(100 * expm1(count$estimate), format = "f", digits = 1),
            "\\%"), fixed = TRUE),
        "---"))
writeLines(as.character(
    kbl(tab, format = "latex", booktabs = TRUE, escape = FALSE,
        col.names = c("", "HUD forecast", "Estimate"), align = c("l", "r", "r")) |>
    pack_rows("A. Cost of the standard (price of new homes)", 1, 2, escape = FALSE) |>
    pack_rows("B. Capitalized private value of resilience", 3, 8, escape = FALSE) |>
    pack_rows("C. Public benefits", 9, 10, escape = FALSE) |>
    pack_rows("D. Quantity and ratio", 11, 12, escape = FALSE)),
    here("output/cost-benefit/corelogic-comparison.tex"))
