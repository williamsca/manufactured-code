# Appendix table: state-level MH-stock-weighted wind zone II/III intensity.
# Writes output/descriptives/windzone-intensity.tex.

rm(list = ls())
library(here)
library(data.table)
library(kableExtra)

dt_states <- unique(readRDS(here("derived", "sample-mhs.Rds"))[
    , .(statefp, state_name)])

dt_int <- readRDS(here("derived", "mhs-windzone-intensity.Rds"))
dt_int <- merge(dt_int, dt_states, by = "statefp")
dt_int <- dt_int[mh_stock_wz23 > 0]
setorder(dt_int, -treated_intensity)

dt_int_tab <- dt_int[, .(
    "State"                  = state_name,
    "MH stock (1980-2000)"   = formatC(mh_stock, format = "f", digits = 0, big.mark = ","),
    "MH stock in WZ II/III"  = formatC(mh_stock_wz23, format = "f", digits = 0, big.mark = ","),
    "Intensity"              = paste0(formatC(treated_intensity * 100, format = "f", digits = 1), "\\%")
)]

dir.create(here("output", "descriptives"), showWarnings = FALSE, recursive = TRUE)
kbl(
    dt_int_tab,
    format   = "latex",
    booktabs = TRUE,
    escape   = FALSE,
    align    = c("l", "r", "r", "r")
) |>
(\(x) writeLines(as.character(x), here("output", "descriptives", "windzone-intensity.tex")))()
