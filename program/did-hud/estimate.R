# Estimate price effects of HUD code changes on manufactured homes
# Analyses: (1) TWFE event study for 1994 wind standard (DiD)
#           (2) Pre-post interrupted time series for energy, smoke alarm, NEC rules

rm(list = ls())
library(here)
library(data.table)
library(fixest)

# Wind zone treatment classification ----
# Based on HUD 1994 Basic Wind Zone Map (24 CFR 3280.305, effective July 1994).
# "Treated" = state where a substantial share of MH placements face Zone II/III
# structural requirements (100-110 mph design wind speed).
# Primary treated: Gulf and Atlantic coastal states clearly in Zone II/III.
# Fringe: states with a small coastal zone-II strip; excluded from primary analysis.
v_treated_primary <- c(
    "Florida", "South Carolina", "North Carolina", "Georgia",
    "Alabama", "Mississippi", "Louisiana", "Texas"
)
v_treated_fringe <- c(
    "Virginia", "Maryland", "Delaware", "New Jersey", "Connecticut",
    "Rhode Island", "Massachusetts", "New York", "Maine", "New Hampshire",
    "Hawaii"
)

# CPI-U annual average (base 1982-84 = 100), 1980-2015 ----
dt_cpi <- data.table(
    year = 1980:2015,
    cpi  = c(
         82.4,  90.9,  96.5,  99.6, 103.9, 107.6, 109.6, 113.6, 118.3, 124.0,
        130.7, 136.2, 140.3, 144.5, 148.2, 152.4, 156.9, 160.5, 163.0, 166.6,
        172.2, 177.1, 179.9, 184.0, 188.9, 195.3, 201.6, 207.3, 215.3, 214.5,
        218.1, 224.9, 229.6, 233.0, 236.7, 237.0
    )
)
# Express prices in year-2000 dollars
cpi_2000 <- dt_cpi[year == 2000, cpi]
dt_cpi[, cpi_idx := cpi / cpi_2000]

# Import and prepare data ----
dt_nat <- readRDS(here("derived", "sample.Rds"))
dt_st  <- readRDS(here("derived", "sample-state.Rds"))

# Deflate state-level prices
dt_st <- dt_cpi[dt_st, on = "year"]
dt_st[, real_price    := avg_sales_price        / cpi_idx]
dt_st[, real_price_sw := avg_sales_price_single / cpi_idx]
dt_st[, real_price_dw := avg_sales_price_double / cpi_idx]
dt_st[, log_price     := log(real_price)]
dt_st[, log_price_sw  := log(real_price_sw)]
dt_st[, log_price_dw  := log(real_price_dw)]

# Deflate national prices
dt_nat <- dt_cpi[dt_nat, on = "year"]
dt_nat[, real_price     := avg_sales_price        / cpi_idx]
dt_nat[, real_price_sw  := avg_sales_price_single / cpi_idx]
dt_nat[, log_price      := log(real_price)]

# Treatment indicators and controls
dt_st[, treated      := state_name %in% v_treated_primary]
dt_st[, treated_broad := state_name %in% c(v_treated_primary, v_treated_fringe)]
dt_st[, alaska       := state_name == "Alaska"]
dt_st[, share_double := placements_double / placements]

# DiD sample: 1988-2002, exclude Alaska (no wind zone designation) ----
# Base year: 1993 (last full year before July 1994 effective date)
dt_did <- dt_st[
    year %between% c(1985, 2002) & !is.na(log_price) & !alaska
]
dt_did[, event_time := year - 1994]
dt_did[, post        := as.integer(year >= 1994)]

# TWFE event study: baseline ----
es_baseline <- feols(
    log_price ~ i(event_time, treated, ref = -1) | statefp + year,
    data    = dt_did,
    cluster = ~statefp
)

# Single-wide and double-wide separately
es_sw <- feols(
    log_price_sw ~ i(event_time, treated, ref = -1) | statefp + year,
    data    = dt_did[!is.na(log_price_sw)],
    cluster = ~statefp
)
es_dw <- feols(
    log_price_dw ~ i(event_time, treated, ref = -1) | statefp + year,
    data    = dt_did[!is.na(log_price_dw)],
    cluster = ~statefp
)

etable(
    es_baseline, es_sw, es_dw,
    title = "Event study: 1994 wind standard effect on log real MH price",
    headers = c("Baseline (all)", "Single-wide", "Double-wide", "Broad treatment (Zones II/III)"),
    digits = 3
)

# Robustness: broad treatment definition (include fringe coastal states)
es_broad <- feols(
    log_price ~ i(event_time, treated_broad, ref = -1) | statefp + year,
    data    = dt_did,
    cluster = ~statefp
)

etable(es_broad, digits = 3)


# Summary DiD (single post coefficient) ----
# Use explicit interaction variable to avoid collinearity with state FEs
dt_did[, treat_post       := as.integer(treated)       * post]
dt_did[, treat_post_broad := as.integer(treated_broad) * post]

did_simple <- feols(
    log_price ~ treat_post | statefp + year,
    data    = dt_did,
    cluster = ~statefp
)
did_comp <- feols(
    log_price ~ treat_post + share_double | statefp + year,
    data    = dt_did[!is.na(share_double)],
    cluster = ~statefp
)
did_broad <- feols(
    log_price ~ treat_post_broad | statefp + year,
    data    = dt_did,
    cluster = ~statefp
)

etable(did_simple, did_comp, did_broad, digits = 3)