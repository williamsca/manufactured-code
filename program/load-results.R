# load-results.R
# Loads the scalar CSVs written by the estimation scripts and defines every
# formatting helper and pre-formatted value quoted in paper.Rmd, so the
# Rmd holds only prose.  Sourced from paper.Rmd's setup chunk.
#
# Run order (see `make estimates`): descriptives/, estimate-mhs/,
# estimate-nfip/, then cost-benefit/ (depends on the other two). The CoreLogic
# outputs come from estimate-corelogic/ on Rivanna.

library(data.table)
library(here)

mhs_sc  <- fread(here("output", "mhs", "mhs-scalars.csv"))
source(here("program", "estimate-nfip", "nfip-scalars.R"))
nfip_sc <- read_nfip_scalars()
welf_sc <- fread(here("output", "cost-benefit", "welfare-scalars.csv"))
ss_sc   <- fread(here("output", "descriptives", "sumstats-nfip-scalars.csv"))

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
# Column (1), take-up: the static contrast, its state-clustered standard error,
# and the 95% interval in percent terms.
tk_stc      <- lp_fmt(get_nfip("takeup_ppml_static"))
tk_stc_se   <- se_fmt(get_nfip("takeup_ppml_static_se"))
tk_stc_pct  <- pctc_fmt(get_nfip("takeup_ppml_static"))
tk_ci_lo    <- pctc_fmt(get_nfip("takeup_ppml_static") -
                        1.96 * get_nfip("takeup_ppml_static_se"))
tk_ci_hi    <- pctc_fmt(get_nfip("takeup_ppml_static") +
                        1.96 * get_nfip("takeup_ppml_static_se"))
# Columns (2) and (3).
ch_stc      <- lp_fmt(get_nfip("claims_home_ppml_static"))
ch_stc_se   <- se_fmt(get_nfip("claims_home_ppml_static_se"))
cr_stc      <- lp_fmt(get_nfip("claim_rate_ppml_static"))
cr_stc_se   <- se_fmt(get_nfip("claim_rate_ppml_static_se"))
cr_stc_pct  <- pctc_fmt(get_nfip("claim_rate_ppml_static"))
cr_ci_lo    <- pctc_fmt(get_nfip("claim_rate_ppml_static") -
                        1.96 * get_nfip("claim_rate_ppml_static_se"))
cr_ci_hi    <- pctc_fmt(get_nfip("claim_rate_ppml_static") +
                        1.96 * get_nfip("claim_rate_ppml_static_se"))
# Pre-1994 MH claims per 1,000 policy-years, the base rate the claims-per-policy
# coefficient moves.
clmrate_base   <- formatC(get_nfip("claim_rate_base_mh") * 1000,
                          format = "f", digits = 1)
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
# Wind-zone triple difference, building damage (Table
# \ref{tab:windzone-ddd-building}), in log points.
wz_lp <- function(nm) lp_fmt(get_nfip(paste0("wz_building_damage_", nm)))
wz_se <- function(nm) se_fmt(get_nfip(paste0("wz_building_damage_", nm, "_se")))
wz_did_z1 <- wz_lp("did_z1"); wz_did_z1_se <- wz_se("did_z1")
wz_did_z2 <- wz_lp("did_z2"); wz_did_z2_se <- wz_se("did_z2")
wz_did_z3 <- wz_lp("did_z3"); wz_did_z3_se <- wz_se("did_z3")
wz_ddd_tr <- wz_lp("ddd_tr"); wz_ddd_tr_se <- wz_se("ddd_tr")
wz_ddd_z2 <- wz_lp("ddd_z2"); wz_ddd_z2_se <- wz_se("ddd_z2")
wz_ddd_z3 <- wz_lp("ddd_z3"); wz_ddd_z3_se <- wz_se("ddd_z3")
wz_mh_z1_shr <- fmt_pct(100 * get_nfip("wz_n_mh_claims_z1") /
    sum(sapply(1:3, function(z) get_nfip(paste0("wz_n_mh_claims_z", z)))), 0)
wz_n_cty_z3   <- as.integer(get_nfip("wz_n_counties_z3"))
wz_n_state_z3 <- as.integer(get_nfip("wz_n_states_z3"))
# HUD comparison (Table \ref{tab:hud-comparison}): HUD's ex ante forecasts for
# the 1994 standard beside the estimates, at HUD's 7% discount rate and 33-year
# home life. Money is in $000 of 2000 dollars, as above.
hud_sc  <- fread(here("output", "cost-benefit", "hud-comparison-scalars.csv"))
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

# Stock quantity weights displayed in the HUD table notes.
hud_weight_z2_tex <- tex(fmt_pct(100 * get_hud("hud_quantity_weight_z2"), 1))
hud_weight_z3_tex <- tex(fmt_pct(100 * get_hud("hud_quantity_weight_z3"), 1))

# Separate private and public ratios in the HUD comparison.
hud_bcr_private <- formatC(get_hud("hud_bcr_private"), format = "f", digits = 2)
hud_bcr_public <- formatC(get_hud("hud_bcr_public"), format = "f", digits = 2)
fl_bcr_public <- formatC(get_hud("flood_bcr_public"), format = "f", digits = 2)

# Retained private losses exclude the fiscal NFIP payment component.
fl_retained_pv <- fmt_d(get_hud("flood_private_retained_pv"))
fl_retained_bcr <- formatC(get_hud("flood_bcr_private"), format = "f", digits = 2)
hud_all_bcr <- formatC(get_hud("hud_bcr_all"), format = "f", digits = 2)
fl_all_bcr <- formatC(get_hud("flood_bcr_all"), format = "f", digits = 2)

# CoreLogic cost side (Chunk P): static ladder for prices (OLS, log points) and
# surviving counts (PPML, log points), columns 1-4 as in notes/specs.md §20,
# plus the sample sizes quoted in the data section. Read from the aggregate
# outputs of program/estimate-corelogic/estimate-corelogic-{prices,quantities}.R.
cl_dir <- here("output", "corelogic")
cl_lad <- rbindlist(list(
    fread(file.path(cl_dir, "prices", "mh_static_ladder.csv"))[
        grepl("z[23]$", term)][, outcome := "price"],
    fread(file.path(cl_dir, "quantities", "mh_static_ladder.csv"))[
        , outcome := fifelse(housing_type == "MH", "count", "count_sb")]), fill = TRUE)
cl_lad[, `:=`(col = as.integer(sub("ladder_", "", specification)),
              zone = fifelse(grepl("z2$", term), 2L, 3L))]
cl_lad[, size_adjusted := outcome == "price" & col %in% c(3L, 6L)]
stopifnot(nrow(cl_lad) == 20L, !anyDuplicated(cl_lad, by = c("outcome", "col", "zone")))
get_lad <- function(o, k, z, what = "estimate") {
    x <- cl_lad[outcome == o & col == k & zone == z, get(what)]
    stopifnot(length(x) == 1L)
    x
}
# "0.072 (SE 0.023)" and the implied percentage change.
lad_b  <- function(o, k, z) formatC(get_lad(o, k, z), format = "f", digits = 3)
lad_se <- function(o, k, z) se_fmt(get_lad(o, k, z, "se"))
lad_pc <- function(o, k, z) pctc_fmt(get_lad(o, k, z))
cl_size_common <- fread(file.path(cl_dir, "prices", "size_common_sample_coefficients.csv"))
size_common_pc <- function(k, z) {
    b <- cl_size_common[specification == paste0("common_sample_", k) &
        grepl(paste0("z", z, "$"), term), estimate]
    stopifnot(length(b) == 1L)
    pctc_fmt(b)
}
cl_sales <- fread(file.path(cl_dir, "prices", "sample_by_vintage.csv"))
cl_n_mh_sales <- format(cl_sales[mh == 1, sum(sales)], big.mark = ",")
cl_n_sb_sales <- format(cl_sales[mh == 0, sum(sales)], big.mark = ",")
cl_support <- fread(file.path(cl_dir, "quantities", "mh_static_ladder_support.csv"))
cl_n_mh_homes <- format(cl_support[mh == 1, sum(homes)], big.mark = ",")
cl_n_sb_homes <- format(cl_support[mh == 0, sum(homes)], big.mark = ",")
cl_n_cty_q <- format(cl_support[mh == 1, sum(counties[post == 0])], big.mark = ",")
# Headline price ranges retain the four unadjusted specifications: conditioning
# on size changes the estimand if the regulation affects home or lot size.
lad_min <- function(o, z) pctc_fmt(min(cl_lad[outcome == o & zone == z & !size_adjusted, estimate]))
lad_max <- function(o, z) pctc_fmt(max(cl_lad[outcome == o & zone == z & !size_adjusted, estimate]))
# Plotted state x vintage count event study: range of the Zone III coefficients for
# construction years 1995-1999, quoted in the quantity results paragraph.
cl_es_q <- fread(file.path(cl_dir, "quantities", "mh_only_vintage_coefficients_state_vintage_fe.csv"))
cl_es_q[, vintage := as.integer(sub("year_constr::([0-9]+):.*", "\\1", term))]
stopifnot(nrow(cl_es_q) == 20L)
cl_q_z3_late <- cl_es_q[grepl(":z3$", term) & vintage >= 1995, range(estimate)]
cl_q_z3_lo <- formatC(cl_q_z3_late[1], format = "f", digits = 2)
cl_q_z3_hi <- formatC(cl_q_z3_late[2], format = "f", digits = 2)

# HUD's production cost forecast in log points by wind zone
# (program/cost-benefit/hud-cost-forecast.R), drawn on the price event study.
hud_fc <- fread(here("output", "cost-benefit", "hud-cost-forecast.csv"))
stopifnot(setequal(hud_fc$wind_zone, 2:3))
hud_fc_z2 <- formatC(hud_fc[wind_zone == 2, forecast], format = "f", digits = 3)
hud_fc_z3 <- formatC(hud_fc[wind_zone == 3, forecast], format = "f", digits = 3)
cl_es_p <- fread(file.path(cl_dir, "prices", "mh_only_vintage_coefficients_state_vintage_fe.csv"))
cl_es_p[, vintage := as.integer(sub("year_constr::([0-9]+):.*", "\\1", term))]
stopifnot(nrow(cl_es_p) == 20L)
# The cost-results text states that every post-1994 Zone II point estimate
# lies below the Zone II forecast.
stopifnot(cl_es_p[grepl(":z2$", term) & vintage >= 1994,
                  all(estimate < hud_fc[wind_zone == 2, forecast])])
cl_p_z3_1999 <- formatC(cl_es_p[term == "year_constr::1999:z3", estimate], format = "f", digits = 3)

# Assessor land share of value for 1989-1993 MH parcels by wind zone
# (estimate-corelogic-new-sales.R), and the land-adjusted forecast:
# structure share times the forecast log change.
cl_land <- fread(file.path(cl_dir, "new-sales", "mh_land_share_by_zone.csv"))
stopifnot(setequal(cl_land$wind_zone, 1:3), !anyNA(cl_land$land_share_aggregate))
land_share <- function(z) cl_land[wind_zone == z, land_share_aggregate]
cl_land_z2 <- fmt_pct(100 * land_share(2))
cl_land_z3 <- fmt_pct(100 * land_share(3))
hud_fc_adj <- function(z) (1 - land_share(z)) * hud_fc[wind_zone == z, forecast]
hud_fc_adj_z2 <- formatC(hud_fc_adj(2), format = "f", digits = 3)
hud_fc_adj_z3 <- formatC(hud_fc_adj(3), format = "f", digits = 3)

# Paper's county-level price benchmark and geographically matched benefits.
# Dollar scalars here are in dollars, unlike the legacy $000 welfare outputs.
cl_comparison <- fread(here("output/cost-benefit/corelogic-comparison-scalars.csv"))
get_cl <- function(nm) {
    x <- cl_comparison[statistic == nm, value]
    stopifnot(length(x) == 1L, is.finite(x))
    x
}
cl_d <- function(nm) fmt_d(get_cl(nm) / 1000)
cl_share <- function(nm) fmt_pct(100 * get_cl(nm))
cl_price_base <- cl_d("price_base")
cl_premium <- cl_d("premium_baseline")
cl_premium_lo <- cl_d("premium_min")
cl_premium_hi <- cl_d("premium_max")
cl_flood_pv <- cl_d("gross_pv")
cl_retained_pv <- cl_d("retained_pv")
cl_public_pv <- cl_d("public_pv")
cl_flood_share <- cl_share("gross_share_baseline")
cl_flood_share_lo <- cl_share("gross_share_min")
cl_flood_share_hi <- cl_share("gross_share_max")
cl_private_share <- cl_share("private_share_baseline")
cl_private_gap <- cl_d("private_gap")
