# load-results.R
# Loads the scalar CSVs written by the estimation scripts and defines every
# formatting helper and pre-formatted value quoted in paper.Rmd, so the
# Rmd holds only prose.  Sourced from paper.Rmd's setup chunk.
#
# Run order: estimate-sumstats-nfip.R, estimate-mhs.R, estimate-nfip.R,
#            then estimate-welfare.R (depends on the other two).

library(data.table)
library(here)

mhs_sc  <- fread(here("output", "results", "mhs-scalars.csv"))
nfip_sc <- fread(here("output", "results", "nfip-scalars.csv"))
welf_sc <- fread(here("output", "results", "welfare-scalars.csv"))
ss_sc   <- fread(here("output", "results", "sumstats-nfip-scalars.csv"))

get_mhs  <- function(nm) mhs_sc[statistic == nm,  value]
get_nfip <- function(nm) nfip_sc[statistic == nm, value]
get_welf <- function(nm) welf_sc[statistic == nm, value]
get_ss   <- function(nm) ss_sc[statistic == nm,   value]

# Formatting helpers.  All monetary values stored in $000 (2000 dollars).
fmt_d <- function(x, digits = 0) {
    paste0("\\$", formatC(abs(round(x * 1000)), format = "f",
                          digits = digits, big.mark = ","))
}
fmt_pct <- function(x, digits = 0) {
    paste0(formatC(round(x, digits), format = "f", digits = digits), "%")
}

# Pre-compute formatted values used repeatedly in the text
price_eff      <- fmt_d(get_mhs("price_effect_level"))
price_pct      <- fmt_pct(get_mhs("price_effect_pct"))
avg_price_tr   <- fmt_d(get_mhs("avg_price_treated_pre"))
# Fixed-weight price index: basket definition, sample coverage, the
# composition decomposition, and the split by home size.
wt_single      <- formatC(get_mhs("base_wt_single"), format = "f", digits = 2)
wt_double      <- formatC(get_mhs("base_wt_double"), format = "f", digits = 2)
idx_base       <- fmt_d(get_mhs("idx_base_1993") / 1000)
avg_p_single   <- fmt_d(get_mhs("mean_price_single"))
avg_p_double   <- fmt_d(get_mhs("mean_price_double"))
price_ratio    <- formatC(get_mhs("price_ratio_double_single"),
                          format = "f", digits = 1)
n_index        <- format(as.integer(get_mhs("n_index")), big.mark = ",")
n_raw          <- format(as.integer(get_mhs("n_raw")), big.mark = ",")
n_dropped_mhs  <- as.integer(get_mhs("n_dropped_states"))
price_eff_raw     <- fmt_d(get_mhs("price_effect_raw_level"))
price_eff_raw_cmn <- fmt_d(get_mhs("price_effect_raw_cmn_level"))
price_eff_comp    <- fmt_d(get_mhs("price_effect_comp_level"))
share_dbl_eff  <- formatC(get_mhs("share_double_effect") * 100,
                          format = "f", digits = 2)
price_eff_single <- fmt_d(get_mhs("price_effect_single_level"))
price_eff_double <- fmt_d(get_mhs("price_effect_double_level"))
# Quantity side. Estimated on the same index sample as the price effects,
# so the two are read off one panel. Reported in log points: the static
# post-1994 coefficient, its standard error, and the implied 95% interval.
fmt_lp <- function(x, digits = 2) {
    paste0(if (x >= 0) "" else "-",
           formatC(abs(x), format = "f", digits = digits))
}
plc_eff    <- fmt_lp(get_mhs("placements_effect_static"))
plc_se     <- fmt_lp(get_mhs("placements_effect_static_se"))
plc_ci_lo  <- fmt_lp(get_mhs("placements_effect_static") -
                     1.96 * get_mhs("placements_effect_static_se"))
plc_ci_hi  <- fmt_lp(get_mhs("placements_effect_static") +
                     1.96 * get_mhs("placements_effect_static_se"))
n_plc      <- format(as.integer(get_mhs("n_placements")), big.mark = ",")
# Headline ATT: static post_mh coefficient (single precisely-estimated
# number), not the average of the event study's seven noisy period_constr
# x mh coefficients. The event study (bldg_dmg_evt_avg) is retained for
# describing pre-trends and the post-1994 ramp, not as the headline figure.
#
# The headline estimates are PROPORTIONAL (Poisson). Each coefficient is a log
# rate ratio on the conditional mean, so the percentage change is exp(b) - 1
# and NOT the coefficient itself; `pctc_fmt` below does that conversion and is
# used everywhere a percentage is quoted. Dollar figures come from
# `estimate-welfare.R`, which multiplies the ratio by an MH baseline mean --
# the pre-1994 mean for the private calculation and the post-1994 mean for the
# fiscal one, since the two have different counterfactuals.
pctc_fmt <- function(x, digits = 1) {
    paste0(if (x >= 0) "+" else "-",
           formatC(abs(100 * (exp(x) - 1)), format = "f", digits = digits), "%")
}
lp_fmt <- function(x, digits = 3) {
    paste0(if (x >= 0) "" else "-",
           formatC(abs(x), format = "f", digits = digits))
}
se_fmt <- function(x, digits = 3) formatC(x, format = "f", digits = digits)
# Proportional effects, unsigned magnitude for prose that already says "lower".
bldg_dmg_pct   <- fmt_pct(abs(100 * (exp(get_nfip("pois_building_damage_static")) - 1)), 1)
cont_dmg_pct   <- fmt_pct(abs(100 * (exp(get_nfip("pois_contents_damage_static")) - 1)), 1)
net_bldg_pct   <- fmt_pct(abs(100 * (exp(get_nfip("pois_net_building_pmt_static")) - 1)), 1)
net_cont_pct   <- fmt_pct(abs(100 * (exp(get_nfip("pois_net_contents_pmt_static")) - 1)), 1)
bldg_dmg_lp    <- lp_fmt(get_nfip("pois_building_damage_static"))
bldg_dmg_se    <- se_fmt(get_nfip("pois_building_damage_static_se"))
cont_dmg_lp    <- lp_fmt(get_nfip("pois_contents_damage_static"))
cont_dmg_se    <- se_fmt(get_nfip("pois_contents_damage_static_se"))
bldg_dmg_evt_avg <- fmt_pct(abs(100 * (exp(get_nfip("pois_building_damage_avg")) - 1)), 1)
# Dollar conversions, and the MH baseline means they are taken against.
bldg_dmg_eff   <- fmt_d(get_welf("delta_building"))
net_bldg_eff   <- fmt_d(get_welf("delta_building_pmt"))
net_cont_eff   <- fmt_d(get_welf("delta_contents_pmt"))
mh_pre_bldg    <- fmt_d(get_nfip("mh_pre_building_damage"))
mh_pre_cont    <- fmt_d(get_nfip("mh_pre_contents_damage"))
mh_post_nbldg  <- fmt_d(get_nfip("mh_post_net_building_pmt"))
mh_post_ncont  <- fmt_d(get_nfip("mh_post_net_contents_pmt"))
# The levels estimates the proportional ones replaced, for the appendix
# paragraph that reports how far the two scales diverge.
bldg_dmg_pct_unw <- fmt_pct(abs(100 * (exp(get_nfip("pois_building_damage_static_unw")) - 1)), 1)
cont_dmg_pct_unw <- fmt_pct(abs(100 * (exp(get_nfip("pois_contents_damage_static_unw")) - 1)), 1)
bldg_dmg_lvl   <- fmt_d(abs(get_nfip("building_damage_static")))
bldg_dmg_lvl_se <- fmt_d(abs(get_nfip("building_damage_static_se")))
# County-specific housing-type effect. Staged but not yet quoted anywhere: the
# decision on whether this becomes a robustness column in the paper is open (see
# TODO.md Chunk O). The scalars are extracted here so that adding it is a text
# change rather than an estimation change.
bldg_ctymh_pct <- pctc_fmt(get_nfip("pois_building_damage_ctymh"))
bldg_ctymh_se  <- se_fmt(get_nfip("pois_building_damage_ctymh_se"))
cont_ctymh_pct <- pctc_fmt(get_nfip("pois_contents_damage_ctymh"))
cont_ctymh_se  <- se_fmt(get_nfip("pois_contents_damage_ctymh_se"))
nbldg_ctymh_pct <- pctc_fmt(get_nfip("pois_net_building_pmt_ctymh"))
nbldg_ctymh_se <- se_fmt(get_nfip("pois_net_building_pmt_ctymh_se"))
# Break-even for the omitted wind channel.
wind_be        <- fmt_d(get_welf("wind_breakeven_npv"))
wind_be_mult   <- formatC(get_welf("wind_breakeven_mult"), format = "f", digits = 1)
# Winsorization of the claim-level loss outcomes, for the table notes: the cap,
# how many records it binds for, and confirmation that none of them are
# manufactured homes.
winsor_cap     <- fmt_d(get_nfip("winsor_cap"))
winsor_n_bldg  <- as.integer(get_nfip("winsor_n_building_damage"))
winsor_n_cont  <- as.integer(get_nfip("winsor_n_contents_damage"))
repl_zero_pct  <- fmt_pct(get_nfip("repl_cost_zero_share") * 100, 1)
zero_pmt_bldg  <- fmt_pct(get_nfip("zero_share_net_building_pmt") * 100, 0)
zero_pmt_cont  <- fmt_pct(get_nfip("zero_share_net_contents_pmt") * 100, 0)
claim_rate_fmt <- fmt_pct(get_welf("claim_rate_pooled_pre") * 100, 1)
ann_benefit    <- fmt_d(get_welf("annual_benefit"))
npv_baseline   <- fmt_d(get_welf("npv_baseline"))
bcr_pct        <- fmt_pct(get_welf("bcr_baseline") * 100)
# The `\begin{abstract}` block in paper.Rmd is raw LaTeX, which pandoc passes
# through without escaping. An unescaped "%" there starts a LaTeX comment and
# truncates the rest of the paragraph, so wrap any value containing "%" in
# tex() when quoting it inside that block.
tex <- function(x) gsub("%", "\\\\%", x)
cost_fmt       <- fmt_d(get_welf("compliance_cost"))
delta_bldg     <- fmt_d(get_welf("delta_building"))
delta_cont     <- fmt_d(get_welf("delta_contents"))
delta_total    <- fmt_d(get_welf("delta_total"))
n_post_claims  <- format(as.integer(get_welf("post_claims_n")), big.mark = ",")
nfip_sav_m     <- paste0("$", round(get_welf("nfip_savings_total") / 1000),
                          " million")
n_mh_claims    <- format(as.integer(get_ss("total_claims_mh")), big.mark = ",")
mh_claim_pct   <- round(get_ss("mh_claim_share") * 100, 1)

# Take-up per housing-unit stock (Chunk E; third margin added in Chunk I;
# moved to Poisson counts with an exposure offset in Chunk N).
#
# All three take-up coefficients are now LOG RATE RATIOS -- proportional
# changes in the annual rate -- not the level differences in policies per
# 1,000 homes that the earlier ratio regressions produced. The scalar names
# carry a `_ppml` marker for exactly that reason, so a coefficient cannot be
# quoted on the wrong scale by reusing an old name. Percent conversions use
# exp(b) - 1 rather than treating the coefficient as a percentage, since
# several of these are large enough for the difference to show.
signed_fmt <- function(x, digits = 1) {
    paste0(if (x >= 0) "+" else "-",
           formatC(abs(round(x, digits)), format = "f", digits = digits))
}
lp_fmt  <- function(x, digits = 3) signed_fmt(x, digits)
se_fmt  <- function(x, digits = 3) formatC(x, format = "f", digits = digits)
pctc_fmt <- function(x, digits = 1) {
    paste0(if (x >= 0) "+" else "-",
           formatC(abs(100 * (exp(x) - 1)), format = "f", digits = digits), "%")
}
# Column (1), take-up: the static contrast, its state- and county-clustered
# standard errors, the pre-1994 MH level it moves from, and the 95% interval
# in percent terms, which is what the "null but wide" reading rests on.
tk_stc      <- lp_fmt(get_nfip("takeup_ppml_static"))
tk_stc_se   <- se_fmt(get_nfip("takeup_ppml_static_se"))
tk_stc_pct  <- pctc_fmt(get_nfip("takeup_ppml_static"))
tk_stc_cty_se <- se_fmt(get_nfip("takeup_ppml_static_cty_se"))
tk_ci_lo    <- pctc_fmt(get_nfip("takeup_ppml_static") -
                        1.96 * get_nfip("takeup_ppml_static_se"))
tk_ci_hi    <- pctc_fmt(get_nfip("takeup_ppml_static") +
                        1.96 * get_nfip("takeup_ppml_static_se"))
tk_pre_max    <- lp_fmt(get_nfip("takeup_ppml_pre_max"))
tk_pre_max_se <- se_fmt(get_nfip("takeup_ppml_pre_max_se"))
# vintage bins are labelled by their left-hand construction year and are
# BIN_CONSTR_YEAR wide, so name the bin by the years it covers
tk_pre_max_bin <- local({
    y <- as.integer(get_nfip("takeup_ppml_pre_max_bin"))
    paste0(y, "--", y + 1L)
})
tk_pre_first <- lp_fmt(get_nfip("takeup_ppml_pre_first"))
tk_pre_first_se <- se_fmt(get_nfip("takeup_ppml_pre_first_se"))
tk_clm_stc  <- lp_fmt(get_nfip("takeup_ppml_static_clmsample"))
tk_clm_stc_se <- se_fmt(get_nfip("takeup_ppml_static_clmsample_se"))
# Columns (2) and (3).
ch_stc      <- lp_fmt(get_nfip("claims_home_ppml_static"))
ch_stc_se   <- se_fmt(get_nfip("claims_home_ppml_static_se"))
cr_stc      <- lp_fmt(get_nfip("claim_rate_ppml_static"))
cr_stc_se   <- se_fmt(get_nfip("claim_rate_ppml_static_se"))
cr_stc_pct  <- pctc_fmt(get_nfip("claim_rate_ppml_static"))
cr_stc_cty_se <- se_fmt(get_nfip("claim_rate_ppml_static_cty_se"))
cr_ci_lo    <- pctc_fmt(get_nfip("claim_rate_ppml_static") -
                        1.96 * get_nfip("claim_rate_ppml_static_se"))
cr_ci_hi    <- pctc_fmt(get_nfip("claim_rate_ppml_static") +
                        1.96 * get_nfip("claim_rate_ppml_static_se"))
# Pre-1994 MH levels of the three margins, quoted so the log coefficients
# have a magnitude to attach to. These are descriptive rates, not estimates.
ppl_home_base  <- formatC(get_nfip("policies_per_1k_homes_yr_base_mh"),
                          format = "f", digits = 1)
clmrate_base   <- formatC(get_nfip("claim_rate_base_mh") * 1000,
                          format = "f", digits = 1)
# Both sides of the pooled policies-per-home comparison in levels.
lvl_fmt <- function(x) formatC(x, format = "f", digits = 1)
ppl_mh_pre   <- lvl_fmt(get_nfip("policies_per_1k_homes_yr_mh_pre"))
ppl_mh_post  <- lvl_fmt(get_nfip("policies_per_1k_homes_yr_mh_post"))
ppl_sb_pre   <- lvl_fmt(get_nfip("policies_per_1k_homes_yr_sb_pre"))
ppl_sb_post  <- lvl_fmt(get_nfip("policies_per_1k_homes_yr_sb_post"))
tk_nogeo     <- lp_fmt(get_nfip("takeup_ppml_static_nogeo"))
tk_nogeo_se  <- se_fmt(get_nfip("takeup_ppml_static_nogeo_se"))
# Take-up split by mandatory-purchase status. Under a proportional
# specification the two components no longer add to the total; each is a
# proportional change in its own component rate, so the contribution of the
# mandated component is its coefficient times its pre-period share.
tk_mand_stc     <- lp_fmt(get_nfip("takeup_ppml_mand_static"))
tk_mand_stc_se  <- se_fmt(get_nfip("takeup_ppml_mand_static_se"))
tk_mand_pct     <- pctc_fmt(get_nfip("takeup_ppml_mand_static"))
tk_nonmand_stc  <- lp_fmt(get_nfip("takeup_ppml_nonmand_static"))
tk_nonmand_stc_se <- se_fmt(get_nfip("takeup_ppml_nonmand_static_se"))
tk_mand_share   <- fmt_pct(get_nfip("takeup_mand_share_pre_mh") * 100, 1)
tk_mand_contrib <- lp_fmt(get_nfip("takeup_mand_share_pre_mh") *
                          get_nfip("takeup_ppml_mand_static"))
# Specification diagnostics for the levels-vs-counts paragraph. The level
# figures are in annual policies per 1,000 homes; the Poisson ones in log
# points.
lvl_fmt2      <- function(x) signed_fmt(x, 2)
tk_lvl_stc    <- lvl_fmt2(get_nfip("takeup_lvl_static"))
tk_lvl_stc_se <- formatC(get_nfip("takeup_lvl_static_se"),
                         format = "f", digits = 2)
tk_lvl_terc   <- lvl_fmt2(get_nfip("takeup_lvl_static_tercile"))
tk_lvl_ctymh  <- lvl_fmt2(get_nfip("takeup_lvl_static_ctymh"))
tk_lvl_bin5   <- lvl_fmt2(get_nfip("takeup_lvl_static_bin5"))
tk_lvl_t_low  <- lvl_fmt2(get_nfip("takeup_lvl_static_terc_low"))
tk_lvl_t_mid  <- lvl_fmt2(get_nfip("takeup_lvl_static_terc_mid"))
tk_lvl_t_high <- lvl_fmt2(get_nfip("takeup_lvl_static_terc_high"))
tk_rate_low   <- lvl_fmt(get_nfip("takeup_rate_terc_low"))
tk_rate_high  <- lvl_fmt(get_nfip("takeup_rate_terc_high"))
tk_ppml_ctymh <- lp_fmt(get_nfip("takeup_ppml_static_ctymh"))
tk_ppml_bin5  <- lp_fmt(get_nfip("takeup_ppml_static_bin5"))
tk_den_max_t  <- formatC(get_nfip("takeup_den_profile_max_t"),
                         format = "f", digits = 1)

# Water-depth robustness (Chunk K): the three columns of Table
# \ref{tab:water-depth-robustness} share the building-damage headline's
# sample and FE, so column (1) reproduces `bldg_dmg_eff`/`bldg_dmg_se`
# exactly (asserted at estimation time) -- only columns (2)-(3) are new.
# These are now Poisson coefficients (log points), matching the headline scale,
# so they are formatted as coefficients rather than as dollar amounts.
wd_dmg_depth    <- lp_fmt(get_nfip("building_damage_static_rob_depth"))
wd_dmg_depth_se <- se_fmt(get_nfip("building_damage_static_rob_depth_se"))
wd_dmg_depthx    <- lp_fmt(get_nfip("building_damage_static_rob_depthx"))
wd_dmg_depthx_se <- se_fmt(get_nfip("building_damage_static_rob_depthx_se"))
wd_miss_mh_pre   <- fmt_pct(get_nfip("water_depth_missing_mh_pre") * 100, 1)
wd_miss_mh_post  <- fmt_pct(get_nfip("water_depth_missing_mh_post") * 100, 1)
wd_miss_sb_pre   <- fmt_pct(get_nfip("water_depth_missing_sb_pre") * 100, 1)
wd_miss_sb_post  <- fmt_pct(get_nfip("water_depth_missing_sb_post") * 100, 1)
# Within-cell variation in the depth control, so the appendix can establish that
# the small change in fit reflects what drives damage rather than a control with
# nothing to vary on.
wd_n_bins        <- as.integer(get_nfip("water_depth_n_bins"))
wd_bins_cell     <- formatC(get_nfip("water_depth_bins_per_cell"),
                            format = "f", digits = 1)
wd_one_bin       <- fmt_pct(get_nfip("water_depth_single_bin_share") * 100, 1)

# HUD comparison (Table \ref{tab:hud-comparison}): HUD's ex ante forecasts for
# the 1994 standard beside the estimates, at HUD's 7% discount rate and 33-year
# home life. Money is in $000 of 2000 dollars, as above.
hud_sc  <- fread(here("output", "results", "hud-comparison-scalars.csv"))
get_hud <- function(nm) hud_sc[statistic == nm, value]

hud_rate       <- fmt_pct(get_hud("hud_discount_rate") * 100)
hud_life       <- as.integer(get_hud("hud_lifespan"))
hud_cpi        <- formatC(get_hud("hud_cpi_factor"), format = "f", digits = 2)
hud_bcr        <- formatC(get_hud("hud_bcr"), format = "f", digits = 1)
hud_pv_z2      <- fmt_d(get_hud("hud_private_pv_z2"))
hud_pv_z3      <- fmt_d(get_hud("hud_private_pv_z3"))
fl_pv_z2       <- fmt_d(get_hud("flood_private_pv_z2"))
fl_pv_z3       <- fmt_d(get_hud("flood_private_pv_z3"))
fl_pv_z2_share <- fmt_pct(100 * get_hud("flood_private_pv_z2") /
                              get_hud("hud_private_pv_z2"))
fl_pv_z3_share <- fmt_pct(100 * get_hud("flood_private_pv_z3") /
                              get_hud("hud_private_pv_z3"))
fl_red_z1      <- fmt_pct(get_hud("bldg_red_z1"), 1)
fl_red_z2      <- fmt_pct(abs(get_hud("bldg_red_z2")), 1)
fl_red_z3      <- fmt_pct(abs(get_hud("bldg_red_z3")), 1)
fl_bcr_z2      <- formatC(get_hud("bcr_z2"), format = "f", digits = 2)
fl_bcr_z3      <- formatC(get_hud("bcr_z3"), format = "f", digits = 2)
fl_bcr_z23     <- formatC(get_hud("bcr_z23"), format = "f", digits = 2)
hud_rate_tex   <- sub("%", "\\%", hud_rate, fixed = TRUE)

# Pooled Zones II/III present values for the compact HUD comparison.
fl_pv_z23 <- fmt_d(get_hud("flood_private_pv_z23"))
fl_pub_z23 <- fmt_d(get_hud("flood_public_pv_z23"))
