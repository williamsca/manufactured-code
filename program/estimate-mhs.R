# Estimate price effects of HUD code changes on manufactured homes
# Analyses: (1) TWFE event study for 1994 wind standard (DiD)
#           (2) Pre-post interrupted time series for energy, smoke alarm, NEC rules

rm(list = ls())
library(here)
library(data.table)
library(fixest)

data_path <- Sys.getenv("DATA_PATH")

# import ----

dt <- readRDS(here("derived", "sample-mhs.Rds"))

# estimate ----
# prices in logs and levels
v_out_p <- grep("avg_sales_price", names(dt), value = TRUE)
s_out_p <- paste0("c(", paste0(v_out_p, collapse = ", "), ")")

# quantities in logs
v_out_q <- c("placements_ln", "placements_single_ln", "placements_double_ln")
s_out_q <- paste0("c(", paste0(v_out_q, collapse = ", "), ")")

fmla_p <- as.formula(paste0(
    s_out_p, " ~ i(year, treated_wz3, ref = 1994) | statefp + year"
))

fmla_q <- as.formula(paste0(
    s_out_q, " ~ i(year, treated_wz3, ref = 1994) | statefp + year"
))

est_p <- feols(fmla_p, data = dt, cluster = ~statefp)
est_q <- feols(fmla_q, data = dt, cluster = ~statefp)

etable(est_p, est_q, digits = 3)
etable(est_p, est_q, digits = 3)
