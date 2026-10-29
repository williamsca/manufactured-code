# HUD's ex ante private benefit of the 1994 wind standard, in 2000 dollars, by
# wind zone. It averages HUD's single- and multi-section figures with the
# national 1988-1993 MHS placement shares and adds the mortality benefit:
#
#   b_z = CPI_2000 / CPI_1992 * (sum_s w_s * private_benefit_pv_zs + mortality_benefit_pv_z)
#
# The CoreLogic price job divides b_z by its own mean pre-reform sale price to
# form the forecast drawn on the price event study.
#
# Inputs:  notes/hud-wind-forecasts.csv (HUD Housing Impact Analysis, 2006),
#          derived/cpi-bls.csv, derived/sample-mhs-type.Rds
# Output:  derived/hud-benefit-2000.csv
#          (copy to the Rivanna public-reference directory; see README)

rm(list = ls())
library(here)
library(data.table)

source(here("program", "import", "project-params.R"))

HUD_DOLLAR_YEAR <- 1992L

hud <- fread(here("notes", "hud-wind-forecasts.csv"))
cpi <- fread(here("derived", "cpi-bls.csv"))[, .(cpi = mean(cpi)), by = year]
cpi_factor <- cpi[year == DISCOUNT_YEAR, cpi] / cpi[year == HUD_DOLLAR_YEAR, cpi]
w <- unique(readRDS(here("derived", "sample-mhs-type.Rds"))[, .(section_type, base_wt)])
stopifnot(length(cpi_factor) == 1L, is.finite(cpi_factor),
    !anyDuplicated(w, by = "section_type"), setequal(w$section_type, c("single", "double")),
    abs(sum(w$base_wt) - 1) < 1e-10)
weights <- w[match(c("single", "double"), section_type), base_wt]

benefit <- function(z) {
    private <- hud[item == "private_benefit_pv" & zone == z & section %in% c("single", "multi")]
    mortality <- hud[item == "mortality_benefit_pv" & zone == z]
    stopifnot(nrow(private) == 2L, nrow(mortality) == 1L, mortality$unit == "usd_1992",
        all(private$unit == "usd_1992"))
    cpi_factor * (sum(weights * private[match(c("single", "multi"), section), lo]) + mortality$lo)
}

out <- data.table(wind_zone = 2:3)
out[, benefit_2000 := sapply(as.character(wind_zone), benefit)]
out[, label := "HUD forecast of private benefits"]
print(out)
stopifnot(nrow(out) == 2L, !anyNA(out), all(out$benefit_2000 > 0))
fwrite(out, here("derived", "hud-benefit-2000.csv"))
