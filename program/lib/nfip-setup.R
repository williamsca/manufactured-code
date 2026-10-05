# Shared setup for the NFIP estimation scripts (estimate-nfip-*.R): command-line
# arguments, construction-year binning, output directory, and the fixest
# variable dictionary.

library(here)
library(data.table)
library(fixest)
library(ggplot2)

# BIN_CONSTR_YEAR: width of construction-year bins.
#   1993 is always the right-end of the last pre-treatment bin, so that the
#   HUD 1994 cutoff falls cleanly at a bin boundary.
#     N=1 → annual (no binning); ref period = 1993
#     N=2 → 1992-1993, 1994-1995, ...;  ref period = 1992
#     N=3 → 1991-1993, 1994-1996, ...;  ref period = 1991
# Pass as positional arguments: Rscript estimate-nfip-claims.R 3 countyfp
# You can also omit the bin width and pass only the geography:
#   Rscript estimate-nfip-claims.R tractfp
args <- commandArgs(trailingOnly = TRUE)
bin_arg <- args[grepl("^[0-9]+$", args)][1L]
geo_arg <- args[args %in% c("countyfp", "tractfp")][1L]
# A script may set BIN_CONSTR_DEFAULT before sourcing this file; the
# claim-level scripts use annual vintages, the cell-level ones two-year bins.
BIN_CONSTR_YEAR <- if (!is.na(bin_arg)) {
    as.integer(bin_arg)
} else if (exists("BIN_CONSTR_DEFAULT")) {
    BIN_CONSTR_DEFAULT
} else {
    2L
}
agg_geo <- if (!is.na(geo_arg)) geo_arg else "countyfp"

source(here("program", "import", "project-params.R"))
source(here("program", "import", "rd-client.R"))
source(here("program", "import", "geo-coverage-checks.R"))

if (!agg_geo %in% c("countyfp", "tractfp", "statefp")) {
    stop("agg_geo must be one of 'countyfp', 'tractfp', or 'statefp'.")
}
geo_label <- c(
    "statefp" = "State",
    "countyfp" = "County",
    "tractfp" = "Census tract"
)[[agg_geo]]
out_dir <- here("output", "event-study", agg_geo)

# bin construction years: bins are anchored so 1993 is always the right-end
# of the last pre-treatment bin; each bin is labeled by its left-end year.
bin_constr <- function(y, N) {
    ifelse(
        y <= 1993L,
        1994L - N  - ((1993L - y) %/% N) * N,
        1994L      + ((y - 1994L) %/% N) * N
    )
}
# Omitted vintages: the last two pre-reform years. With annual vintages both
# 1992 and 1993 are omitted jointly, so the normalization matches the two-year
# bin and does not rest on one year's MH claims (about 400 in 1993).
ref_period <- if (BIN_CONSTR_YEAR == 1L) c(1992L, 1993L) else 1994L - BIN_CONSTR_YEAR
# x position of the reform line in event-study plots (1993.5 annual, 1992.5
# with two-year bins)
vline_constr <- 1993.5 - (BIN_CONSTR_YEAR - 1L)

v_dict <- c(
    "claims_n" = "Claims (#)",
    "policies_n" = "Policies (#)",
    "building_damage" = "Building damage",
    "log_building_damage" = "Log building damage",
    "log_building_damage_share" = "Log bldg. dmg. share",
    "log_net_building_pmt" = "Log net building pmt.",
    "log_contents_damage" = "Log contents damage",
    "log_net_contents_pmt" = "Log net contents pmt.",
    "net_building_pmt" = "Net building pmt.",
    "contents_damage" = "Contents damage",
    "net_contents_pmt" = "Net contents pmt.",
    "claim_rate" = "Claims per policy-year",
    "repl_cost_ppol" = "Repl. cost",
    "policy_cost_ppol" = "Policy cost per policy",
    "building_policy_covg_ppol" = "Bldg covg.",
    "contents_policy_covg_ppol" = "Contents covg.",
    "elevated_share" = "Elevated",
    "sfha_share" = "SFHA",
    "water_depth" = "Water depth (ft)",
    "water_depth_bin" = "Water depth bin",
    "post1994" = "Post-1994",
    "elevated" = "Elevated",
    "sfha" = "SFHA",
    "primary_res_share" = "Primary res.",
    "mandatory_purchase_share" = "Mandatory",
    # policy-level composition (Chunk J: derived/nfip-policy-micro.parquet,
    # one row per policy term, replacing the cell-level averages above)
    "repl_cost" = "Repl. cost",
    "repl_cost_pol" = "Repl. cost",
    "building_policy_covg" = "Bldg covg.",
    "contents_policy_covg" = "Contents covg.",
    "contents_covg_positive" = "Contents covg. $>0$",
    "contents_policy_covg_pos" = "Contents covg. (if $>0$)",
    "elevated_policy" = "Elevated",
    "sfha_policy" = "SFHA",
    "policies_per_1k_homes_yr" = "Policies per 1,000 homes per year",
    "claims_per_1k_homes_yr" = "Claims per 1,000 homes per year",
    "homes_n" = "Homes (stock)",
    "building_damage_share" = "Bldg. dmg. share (%)",
    "net_building_pmt_share" = "Bldg. pmt. share (%)",
    "contents_damage_share" = "Contents dmg. share (%)",
    "net_contents_pmt_share" = "Contents pmt. share (%)",
    "mh_claim_share" = "MH share of claims",
    "mh_policy_share" = "MH share of policies",
    "geo" = geo_label,
    "statefp" = "State",
    "countyfp" = "County",
    "tractfp" = "Census tract",
    # Cell panels bin calendar years into 5-year periods and assign both
    # policy records and claims to them, so "loss period" mislabels the
    # policy-composition and take-up tables (review comments 17-18).
    "period_loss" = "Calendar period",
    "year_loss" = "Loss year",
    "mh" = "MH",
    "period_constr" = "$\\nu_i$",
    "post_mh" = "$1\\{\\nu_i \\geq 1994\\} \\times$ MH",
    "post_mh_tr" = "$1\\{\\nu_i \\geq 1994\\} \\times$ MH $\\times$ Zone II/III",
    "post_mh_z2" = "$1\\{\\nu_i \\geq 1994\\} \\times$ MH $\\times$ Zone II",
    "post_mh_z3" = "$1\\{\\nu_i \\geq 1994\\} \\times$ MH $\\times$ Zone III",
    "wind_zone" = "Wind zone",
    "treated" = "Zone II/III",
    "mh_z1" = "MH $\\times$ Zone I",
    "mh_z2" = "MH $\\times$ Zone II",
    "mh_z3" = "MH $\\times$ Zone III",
    "mh_tr" = "MH $\\times$ Zone II/III",
    "capped_pmt" = "Capped payment (=1)",
    "pmt_covg_ratio" = "Payment / coverage",
    "damage_repl_ratio" = "Damage / repl. cost",
    "zero_pmt" = "Zero/small payment (=1)"
)

setFixest_dict(v_dict, reset = TRUE)
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(here("output", "results"), showWarnings = FALSE, recursive = TRUE)

# Each estimate-nfip-*.R script writes its scalars to its own file; readers
# load them all through read_nfip_scalars() (program/lib/nfip-scalars.R).
write_nfip_scalars <- function(x, part) {
    stopifnot(is.list(x), all(lengths(x) == 1L), !anyDuplicated(names(x)))
    fwrite(data.table(statistic = names(x), value = as.numeric(unlist(x))),
           here("output", "results", paste0("nfip-", part, "-scalars.csv")))
}
