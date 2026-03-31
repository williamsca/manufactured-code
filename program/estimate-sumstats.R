# Summary statistics to evaluate whether policy data starting in 2009
# provides sufficient variation for the NFIP event study.
#
# Estimation strategy: event study of year_constr × treated_mh effects on
# per-claim damage amounts, with county × year_loss and mh FEs. Identification
# requires within-cell (county × year_loss) variation in year_constr,
# especially around the 1994 HUD wind-standard threshold.
#
# Concern: restricting to year_loss >= 2009 may leave too few claims from the
# key vintage window (1985–2004) to estimate the event-study coefficients.
#
# Inputs:  derived/nfip-balanced.Rds

rm(list = ls())
library(here)
library(data.table)
library(kableExtra)

# import ----
dt <- readRDS(here("derived", "nfip-balanced.Rds"))

# estimate ----


