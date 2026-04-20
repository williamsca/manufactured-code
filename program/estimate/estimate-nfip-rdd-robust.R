# RDD: effect of 1994 HUD wind standard on MH building damage
#
# Running variable: rc = year_constr - 1994 (cutoff at 0)
# Local linear regression with MSE-optimal bandwidth via rdrobust.
# Outcome residualized on county x loss-year FEs; grand mean added back
# so point estimates are in levels.

rm(list = ls())
library(here)
library(data.table)
library(fixest)
library(rdrobust)

source(here("program", "import", "project-params.R"))

out_dir <- here("output", "event-study", "rdd")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---------------------------------------------------------------------------
# data ----
# ---------------------------------------------------------------------------
dt <- readRDS(here("derived", "nfip-claims.Rds"))
dt <- dt[
    mh == 1L &
    between(year_constr, 1985L, 2005L) &
    between(year_loss, MIN_YEAR_LOSS, MAX_YEAR_LOSS) &
    !is.na(building_damage)]

dt[, rc := year_constr - 1994L]

# ---------------------------------------------------------------------------
# residualize on county x loss-year FEs ----
# ---------------------------------------------------------------------------
grand_mean <- dt[, mean(building_damage)]

fit_fe <- feols(building_damage ~ 1 | countyfp^year_loss, data = dt)
dt[, bd_resid := resid(fit_fe) + grand_mean]

# ---------------------------------------------------------------------------
# rdrobust: MSE-optimal bandwidth, local linear ----
# ---------------------------------------------------------------------------
rdd_fit <- rdrobust(
    y      = dt$bd_resid,
    x      = dt$rc,
    c      = 0,
    p      = 1,
    kernel = "triangular",
    bwselect = "mserd")

summary(rdd_fit)

# rdplot using the same bandwidth
rdplot(
    y       = dt$bd_resid,
    x       = dt$rc,
    c       = 0,
    p       = 1,
    h       = rdd_fit$bws["h", "left"],
    kernel  = "triangular",
    x.label = "Construction year (centered at 1994)",
    y.label = "Building damage (FE-adjusted, $)",
    title   = "")