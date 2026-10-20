# HUD's ex ante forecast of the private benefit of the 1994 wind standard,
# expressed as a log difference in resale price between post- and pre-reform
# vintages, by wind zone. Overlaid on the CoreLogic vintage price event study
# (Figure: MH prices by construction year).
#
# Old and new vintages are close substitutes, so buyers pay for a post-reform
# home the price of a pre-reform home plus the capitalized private value of
# its resilience, b. The vintage price gap within a county and sale year is
# therefore b, not the cost increase; the cost increase shifts the price of
# both vintages and is absorbed by county x sale-year effects. HUD's forecast
# of b is its present value of reduced private wind losses plus mortality and
# injury benefits (notes/hud-wind-forecasts.csv, Table 4-13 and sec. 4.2.2):
#
#   forecast_z = log(1 + b_z / P_z)
#
#   b_z  HUD private benefit, zone z, averaged over single- and multi-section
#        homes with national 1988-1993 MHS placement shares (as in
#        estimate-corelogic-comparison.R), converted to 2000 dollars
#   P_z  mean CoreLogic transaction price of 1989-1993 MH vintages in zone-z
#        counties (2000 dollars, land included)
#
# The gap in dollars is b whether or not the price includes land, so P_z is the
# full transaction price.
#
# Inputs:  notes/hud-wind-forecasts.csv, output/mhs/mhs-scalars.csv,
#          output/cost-benefit/hud-comparison-scalars.csv,
#          output/corelogic/prices/mh_price_summary.csv
# Output:  output/cost-benefit/hud-benefit-forecast.csv

rm(list = ls())
library(here)
library(data.table)

hud <- fread(here("notes", "hud-wind-forecasts.csv"))
mhs <- fread(here("output", "mhs", "mhs-scalars.csv"))
cpi <- fread(here("output", "cost-benefit", "hud-comparison-scalars.csv"))[
    statistic == "hud_cpi_factor", value]
means <- fread(file.path(here("output", "corelogic"), "prices", "mh_price_summary.csv"))
weights <- mhs[match(c("base_wt_single", "base_wt_double"), statistic), value]
stopifnot(length(cpi) == 1L, length(weights) == 2L, abs(sum(weights) - 1) < 1e-10,
    !anyDuplicated(means, by = c("wind_zone", "post")))

benefit <- function(z) {
    private <- hud[item == "private_benefit_pv" & zone == z & section %in% c("single", "multi")]
    mortality <- hud[item == "mortality_benefit_pv" & zone == z]
    stopifnot(nrow(private) == 2L, nrow(mortality) == 1L)
    cpi * (sum(weights * private[match(c("single", "multi"), section), lo]) + mortality$lo)
}

out <- data.table(wind_zone = 2:3)
out[, benefit_2000 := sapply(as.character(wind_zone), benefit)]
out[, price_base := means[post == 0][match(out$wind_zone, wind_zone), mean_2000]]
out[, forecast := log1p(benefit_2000 / price_base)]
out[, comparison := fifelse(wind_zone == 2L, "Zone II minus Zone I", "Zone III minus Zone I")]
out[, label := "HUD forecast of private benefits"]
print(out)
stopifnot(nrow(out) == 2L, !anyNA(out), all(out$forecast > 0 & out$forecast < 0.5))

dir.create(here("output", "cost-benefit"), showWarnings = FALSE, recursive = TRUE)
fwrite(out, here("output", "cost-benefit", "hud-benefit-forecast.csv"))
