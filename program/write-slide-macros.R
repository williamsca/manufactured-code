# write-slide-macros.R: generate LaTeX macros for slides.tex
#
# Reads the same results layer that paper.Rmd reads (output/results/*.csv,
# written by estimate-mhs.R, estimate-nfip.R, estimate-welfare.R, and
# estimate-sumstats-nfip.R) and emits one \newcommand per quoted number to
# output/results/slide-numbers.tex.
#
# The point is that no estimate is ever typed into slides.tex by hand: if a
# number belongs on a slide, it gets a macro here.  Derived quantities
# (confidence bounds, implied elasticities, break-even ratios) are computed
# from the stored scalars rather than pre-computed elsewhere, so they cannot
# drift away from the estimates they are built from.
#
# Convention: macros hold bare numbers.  Dollar signs and percent signs are
# supplied by the slide (\$\vPriceEff, \vBCRPct\%), so no LaTeX escaping is
# needed here and a macro can be reused in either context.

library(data.table)
library(here)

mhs_sc  <- fread(here("output", "results", "mhs-scalars.csv"))
nfip_sc <- fread(here("output", "results", "nfip-scalars.csv"))
welf_sc <- fread(here("output", "results", "welfare-scalars.csv"))
ss_sc   <- fread(here("output", "results", "sumstats-nfip-scalars.csv"))

get_one <- function(dt, nm) {
    v <- dt[statistic == nm, value]
    if (length(v) != 1L) {
        stop("expected exactly one row for statistic '", nm, "', got ",
             length(v), call. = FALSE)
    }
    v
}

get_mhs  <- function(nm) get_one(mhs_sc,  nm)
get_nfip <- function(nm) get_one(nfip_sc, nm)
get_welf <- function(nm) get_one(welf_sc, nm)
get_ss   <- function(nm) get_one(ss_sc,   nm)

# Formatting helpers ----
#
# Monetary scalars in mhs-scalars, nfip-scalars, and welfare-scalars are
# stored in $000 (2000 dollars); sumstats-nfip-scalars stores raw dollars.
# fmt_d converts the former, fmt_draw the latter.  Both take absolute values:
# the sign of a damage reduction is carried by the sentence on the slide, not
# by the macro.

fmt_d    <- function(x) formatC(round(abs(x) * 1000), format = "d", big.mark = ",")
fmt_draw <- function(x) formatC(round(abs(x)), format = "d", big.mark = ",")
fmt_n    <- function(x) formatC(as.integer(round(x)), format = "d", big.mark = ",")
fmt_f    <- function(x, digits = 1) formatC(x, format = "f", digits = digits)
fmt_s    <- function(x, digits = 2) {
    paste0(if (x >= 0) "+" else "-", formatC(abs(x), format = "f", digits = digits))
}

# Macro accumulator ----

macros <- new.env(parent = emptyenv())
macros$lines <- character(0)
macros$names <- character(0)

mac <- function(name, value) {
    if (!grepl("^v[A-Za-z]+$", name)) {
        stop("macro name must be 'v' + letters only: ", name, call. = FALSE)
    }
    if (name %in% macros$names) {
        stop("duplicate macro name: ", name, call. = FALSE)
    }
    macros$names <- c(macros$names, name)
    macros$lines <- c(macros$lines,
                      sprintf("\\newcommand{\\%s}{%s}", name, value))
    invisible(NULL)
}

sec <- function(title) {
    macros$lines <- c(macros$lines, "", paste0("% --- ", title, " ---"))
    invisible(NULL)
}

# ---------------------------------------------------------------------------
# Cost side: Manufactured Housing Survey
# ---------------------------------------------------------------------------

sec("Cost side: prices")

price_eff <- get_mhs("price_effect_level")
price_base <- get_mhs("avg_price_treated_pre")

mac("vPriceEff",        fmt_d(price_eff))
mac("vPriceEffPct",     fmt_f(get_mhs("price_effect_pct"), 1))
mac("vPriceBase",       fmt_d(price_base))
mac("vPriceEffSingle",  fmt_d(get_mhs("price_effect_single_level")))
mac("vPriceEffDouble",  fmt_d(get_mhs("price_effect_double_level")))
mac("vPriceEffDose",    fmt_d(get_mhs("price_effect_dose_level")))
mac("vDoseRatio",       fmt_f(get_mhs("dose_binary_ratio"), 2))

# Composition decomposition: the all-homes average on the index sample, and
# the mix-only counterfactual that holds prices fixed at national levels.
mac("vPriceEffRawCmn",  fmt_d(get_mhs("price_effect_raw_cmn_level")))
mac("vPriceEffComp",    fmt_d(get_mhs("price_effect_comp_level")))
mac("vShareDoublePP",   fmt_f(abs(get_mhs("share_double_effect")) * 100, 2))

# Index construction.
mac("vWtSingle",        fmt_f(get_mhs("base_wt_single"), 2))
mac("vWtDouble",        fmt_f(get_mhs("base_wt_double"), 2))
mac("vAvgPriceSingle",  fmt_d(get_mhs("mean_price_single")))
mac("vAvgPriceDouble",  fmt_d(get_mhs("mean_price_double")))
mac("vPriceRatio",      fmt_f(get_mhs("price_ratio_double_single"), 1))
mac("vNIndex",          fmt_n(get_mhs("n_index")))
mac("vNRaw",            fmt_n(get_mhs("n_raw")))
mac("vNDroppedStates",  fmt_n(get_mhs("n_dropped_states")))

sec("Cost side: placements and the implied demand elasticity")

plc     <- get_mhs("placements_effect_static")
plc_se  <- get_mhs("placements_effect_static_se")
plc_lo  <- plc - 1.96 * plc_se
plc_hi  <- plc + 1.96 * plc_se

mac("vPlcEff",   fmt_f(plc, 3))
mac("vPlcSE",    fmt_f(plc_se, 3))
mac("vPlcCILo",  fmt_f(plc_lo, 2))
mac("vPlcCIHi",  fmt_f(plc_hi, 2))
mac("vPlcCILoLP", fmt_f(abs(plc_lo), 2))
mac("vNPlacements", fmt_n(get_mhs("n_placements")))

# The price effect in log points, so the quantity CI can be divided by it.
# This is the object the "was demand inelastic, or did buyers value the
# upgrade?" question turns on, and the width of the resulting interval is the
# honest answer: the design does not separate the two.
dln_price <- log1p(price_eff / price_base)
mac("vDlnPricePct", fmt_f(dln_price * 100, 1))
mac("vElastPt", fmt_f(plc / dln_price, 1))
mac("vElastLo", fmt_f(plc_lo / dln_price, 1))
mac("vElastHi", fmt_f(plc_hi / dln_price, 1))

# ---------------------------------------------------------------------------
# Benefit side: NFIP claims
# ---------------------------------------------------------------------------

sec("Benefit side: claim-level damage")

# Chunk O: the claim-level headline is PPML, so every estimate here is a LOG
# RATE RATIO. Three formats per outcome, and the slide must pick the right one:
#   *Pct  -- the proportional effect, exp(b) - 1, which is what the estimate IS
#   *LP   -- the raw coefficient and its SE in log points, for the table read-out
#   *Dol  -- the dollar conversion from estimate-welfare.R, which is the
#            proportional effect applied to an MH baseline mean
# A macro that formats a log coefficient with fmt_d would print "$116" for
# -0.116, so fmt_d is never applied to a PPML coefficient below.
pct_of <- function(b) fmt_f(abs(exp(b) - 1) * 100, 1)

bldg_b  <- get_nfip("pois_building_damage_static")
cont_b  <- get_nfip("pois_contents_damage_static")
nbldg_b <- get_nfip("pois_net_building_pmt_static")
ncont_b <- get_nfip("pois_net_contents_pmt_static")

mac("vBldgDmgPct",    pct_of(bldg_b))
mac("vBldgDmgLP",     fmt_f(bldg_b, 3))
mac("vBldgDmgSELP",   fmt_f(get_nfip("pois_building_damage_static_se"), 3))
mac("vBldgDmgEvtPct", pct_of(get_nfip("pois_building_damage_avg")))
mac("vBldgDmgDol",    fmt_d(get_welf("delta_building")))
mac("vBldgDmgBase",   fmt_d(get_nfip("mh_pre_building_damage")))

mac("vContDmgPct",    pct_of(cont_b))
mac("vContDmgLP",     fmt_f(cont_b, 3))
mac("vContDmgSELP",   fmt_f(get_nfip("pois_contents_damage_static_se"), 3))
mac("vContDmgDol",    fmt_d(get_welf("delta_contents")))
mac("vContDmgBase",   fmt_d(get_nfip("mh_pre_contents_damage")))

mac("vNetBldgPmtPct",  pct_of(nbldg_b))
mac("vNetBldgPmtSELP", fmt_f(get_nfip("pois_net_building_pmt_static_se"), 3))
mac("vNetBldgPmtDol",  fmt_d(get_welf("delta_building_pmt")))
mac("vNetBldgPmtBase", fmt_d(get_nfip("mh_post_net_building_pmt")))
mac("vNetContPmtPct",  pct_of(ncont_b))
mac("vNetContPmtSELP", fmt_f(get_nfip("pois_net_contents_pmt_static_se"), 3))
mac("vNetContPmtDol",  fmt_d(get_welf("delta_contents_pmt")))
mac("vNetContPmtBase", fmt_d(get_nfip("mh_post_net_contents_pmt")))

mac("vMeanBldgDmg", fmt_d(get_nfip("avg_building_damage_all")))

# The levels estimates the proportional ones replaced, for the scale slide.
mac("vBldgDmgLvl",   fmt_d(get_nfip("building_damage_static")))
mac("vBldgDmgLvlSE", fmt_d(get_nfip("building_damage_static_se")))
mac("vContDmgLvl",   fmt_d(get_nfip("contents_damage_static")))

mac("vZeroPmtBldgPct",  fmt_n(get_nfip("zero_share_net_building_pmt") * 100))
mac("vZeroPmtContPct",  fmt_n(get_nfip("zero_share_net_contents_pmt") * 100))
mac("vNBldgPois",       fmt_n(get_nfip("n_building_damage_pois")))
mac("vNBldgLevels",     fmt_n(get_nfip("n_building_damage_levels")))

# Winsorization: reported on the headline scale now, since the levels R2 the
# old slide quoted is no longer the fit of any table in the paper.
mac("vWinsorCap",   fmt_d(get_nfip("winsor_cap")))
mac("vWinsorNBldg", fmt_n(get_nfip("winsor_n_building_damage")))
mac("vWinsorNCont", fmt_n(get_nfip("winsor_n_contents_damage")))
mac("vBldgDmgPctUnw", pct_of(get_nfip("pois_building_damage_static_unw")))
mac("vContDmgPctUnw", pct_of(get_nfip("pois_contents_damage_static_unw")))

sec("Benefit side: the extensive margin")

# The three extensive-margin outcomes are now estimated by Poisson (PPML), so
# their coefficients are log points, not levels.  Each gets a point estimate,
# a standard error, and an explicit 95% interval: every one of these is a
# null, and a null is only informative if the slide says how wide it is.
ppml <- function(stem) {
    b  <- get_nfip(paste0(stem, "_static"))
    se <- get_nfip(paste0(stem, "_static_se"))
    list(b = b, se = se, lo = b - 1.96 * se, hi = b + 1.96 * se)
}

takeup   <- ppml("takeup_ppml")
clmhome  <- ppml("claims_home_ppml")
clmrate  <- ppml("claim_rate_ppml")

mac("vTakeupStc",     fmt_s(takeup$b, 3));   mac("vTakeupStcSE",  fmt_f(takeup$se, 3))
mac("vTakeupCILo",    fmt_f(takeup$lo, 2));  mac("vTakeupCIHi",   fmt_f(takeup$hi, 2))
mac("vClaimsHomeStc", fmt_s(clmhome$b, 3));  mac("vClaimsHomeStcSE", fmt_f(clmhome$se, 3))
mac("vClaimRateStc",  fmt_s(clmrate$b, 3));  mac("vClaimRateStcSE",  fmt_f(clmrate$se, 3))
mac("vClaimRateCILo", fmt_f(clmrate$lo, 2)); mac("vClaimRateCIHi",   fmt_f(clmrate$hi, 2))

# Same intervals as percent changes, for the sentence that reads them aloud.
mac("vClaimRateCILoPct", fmt_f((exp(clmrate$lo) - 1) * 100, 1))
mac("vClaimRateCIHiPct", fmt_f((exp(clmrate$hi) - 1) * 100, 1))

# Baseline rates the coefficients move, in readable units.
mac("vClaimRateBase", fmt_f(get_nfip("claim_rate_base_mh") * 1000, 1))
mac("vPolMhPre",  fmt_f(get_nfip("policies_per_1k_homes_yr_mh_pre"), 1))
mac("vPolMhPost", fmt_f(get_nfip("policies_per_1k_homes_yr_mh_post"), 1))
mac("vPolSbPre",  fmt_f(get_nfip("policies_per_1k_homes_yr_sb_pre"), 1))
mac("vPolSbPost", fmt_f(get_nfip("policies_per_1k_homes_yr_sb_post"), 1))

# Take-up robustness: without geographic FE, split by mandatory purchase, and
# the levels analogue that the PPML specification replaced.
mac("vTakeupNoGeo",      fmt_s(get_nfip("takeup_ppml_static_nogeo"), 3))
mac("vTakeupNoGeoSE",    fmt_f(get_nfip("takeup_ppml_static_nogeo_se"), 3))
mac("vTakeupMand",       fmt_s(get_nfip("takeup_ppml_mand_static"), 3))
mac("vTakeupMandSE",     fmt_f(get_nfip("takeup_ppml_mand_static_se"), 3))
mac("vTakeupNonmand",    fmt_s(get_nfip("takeup_ppml_nonmand_static"), 3))
mac("vTakeupNonmandSE",  fmt_f(get_nfip("takeup_ppml_nonmand_static_se"), 3))
mac("vTakeupMandSharePct", fmt_f(get_nfip("takeup_mand_share_pre_mh") * 100, 1))

# The pre-1994 profile, for the slide that reads take-up as descriptive: the
# largest coefficient sits four years *before* the reform, which is why a
# level-break design does not fit this outcome.
mac("vTakeupPreMax",     fmt_s(get_nfip("takeup_ppml_pre_max"), 3))
mac("vTakeupPreMaxSE",   fmt_f(get_nfip("takeup_ppml_pre_max_se"), 3))
mac("vTakeupPreMaxBin",  fmt_n(get_nfip("takeup_ppml_pre_max_bin")))
mac("vTakeupPreFirst",   fmt_s(get_nfip("takeup_ppml_pre_first"), 3))
mac("vTakeupPreFirstSE", fmt_f(get_nfip("takeup_ppml_pre_first_se"), 3))
mac("vTakeupLvlStc",     fmt_s(get_nfip("takeup_lvl_static"), 2))
mac("vTakeupLvlStcSE",   fmt_f(get_nfip("takeup_lvl_static_se"), 2))

sec("Benefit side: water depth")

# These are PPML coefficients as of Chunk O, so they are log points -- NOT
# dollars. Reported both as the raw coefficient (to read against the table) and
# as a percentage (to read aloud).
mac("vWdDepthLP",    fmt_f(get_nfip("building_damage_static_rob_depth"), 3))
mac("vWdDepthSELP",  fmt_f(get_nfip("building_damage_static_rob_depth_se"), 3))
mac("vWdDepthPct",   pct_of(get_nfip("building_damage_static_rob_depth")))
mac("vWdDepthXLP",   fmt_f(get_nfip("building_damage_static_rob_depthx"), 3))
mac("vWdDepthXSELP", fmt_f(get_nfip("building_damage_static_rob_depthx_se"), 3))
mac("vWdDepthXPct",  pct_of(get_nfip("building_damage_static_rob_depthx")))
mac("vWdNBins",     fmt_n(get_nfip("water_depth_n_bins")))
mac("vWdBinsCell",  fmt_f(get_nfip("water_depth_bins_per_cell"), 1))
mac("vWdOneBinPct", fmt_f(get_nfip("water_depth_single_bin_share") * 100, 1))
mac("vWdMissMhPost", fmt_f(get_nfip("water_depth_missing_mh_post") * 100, 1))
mac("vWdMissSbPost", fmt_f(get_nfip("water_depth_missing_sb_post") * 100, 1))

# ---------------------------------------------------------------------------
# Cost-benefit
# ---------------------------------------------------------------------------

sec("Cost-benefit")

cost <- get_welf("compliance_cost")
npv  <- get_welf("npv_3pct_20yr")

mac("vCost",        fmt_d(cost))
mac("vDeltaBldg",   fmt_d(get_welf("delta_building")))
mac("vDeltaCont",   fmt_d(get_welf("delta_contents")))
mac("vDeltaTotal",  fmt_d(get_welf("delta_total")))
mac("vClaimRatePrePct", fmt_f(get_welf("claim_rate_pooled_pre") * 100, 1))
mac("vAnnBenefit",  fmt_d(get_welf("annual_benefit")))
mac("vNPV",         fmt_d(npv))
mac("vBCRPct",      fmt_n(get_welf("bcr_3pct_20yr") * 100))
mac("vNfipSavingsM", fmt_n(get_welf("nfip_savings_total") / 1000))
mac("vNPostClaims", fmt_n(get_welf("post_claims_n")))

# How large would the untargeted-hazard benefits (wind, displacement,
# uninsured losses) have to be, as a multiple of the measured flood benefit,
# for the reform to break even privately?  This is the one number that turns
# the shortfall into a testable magnitude, so it belongs on the slide.
mac("vWindMultiple", fmt_f(get_welf("wind_breakeven_mult"), 1))
mac("vWindBreakeven", fmt_d(get_welf("wind_breakeven_npv")))

# ---------------------------------------------------------------------------
# Summary statistics
# ---------------------------------------------------------------------------

sec("Summary statistics")

mac("vNMhClaims",      fmt_n(get_ss("total_claims_mh")))
mac("vNAllClaims",     fmt_n(get_ss("total_claims_all")))
mac("vMhClaimSharePct", fmt_f(get_ss("mh_claim_share") * 100, 1))
mac("vPoliciesMh",     fmt_n(get_ss("policies_mh")))
mac("vPoliciesSb",     fmt_n(get_ss("policies_sb")))
mac("vMhPolicySharePct",
    fmt_f(get_ss("policies_mh") / (get_ss("policies_mh") + get_ss("policies_sb")) * 100, 1))
mac("vAvgBldgDmgMh",   fmt_draw(get_ss("avg_building_damage_mh")))
mac("vAvgBldgDmgSb",   fmt_draw(get_ss("avg_building_damage_sb")))
mac("vClaimRateMhPct", fmt_f(get_ss("claim_rate_mh") * 100, 1))
mac("vClaimRateSbPct", fmt_f(get_ss("claim_rate_sb") * 100, 1))

# ---------------------------------------------------------------------------
# Write
# ---------------------------------------------------------------------------

out_path <- here("output", "results", "slide-numbers.tex")

header <- c(
    "% slide-numbers.tex -- GENERATED FILE, DO NOT EDIT.",
    "% Written by program/write-slide-macros.R off output/results/*-scalars.csv.",
    "% To change a number on a slide, change the estimator, then rerun the generator.",
    ""
)

writeLines(c(header, macros$lines), out_path)

message("Wrote ", length(macros$names), " macros to ", out_path)
