# Claim-level NFIP estimates: damage and payment per claim by construction
# vintage and housing type. Writes the building-damage event-study figure, the
# dynamic and static claims tables, and output/nfip/nfip-claims-scalars.csv.

rm(list = ls())
library(here)
BIN_CONSTR_DEFAULT <- 1L
source(here("program", "estimate-nfip", "nfip-setup.R"))
source(here("program", "estimate-nfip", "nfip-claims-sample.R"))
source(here("program", "estimate-nfip", "plot-es.R"))

# event studies ----
# claim-level event study
fmla_claim_es <- as.formula(paste0(
    s_claim, " ~ i(period_constr, mh, ref = ref_period)",
    " | geo^year_loss + mh + period_constr"
))

est_claim_es <- feols(fmla_claim_es, data = dt_claims_est, cluster = ~countyfp)
etable(est_claim_es, fitstat = c("n", "r2", "wr2", "my"))
iplot(est_claim_es[lhs = "building_pmt$"])

# Log building damage (Chunk M), estimated separately rather than added to
# `s_claim`, so the four columns of `claims-outcomes.tex` and
# `claims-outcomes-static.tex` are unchanged. Identical specification,
# fixed effects, and clustering to `fmla_claim_es`; the sample differs only
# by the dropped zero-damage claims, so N is reported alongside the levels
# fit below rather than assumed equal.
est_claim_es_log <- feols(
    log_building_damage ~ i(period_constr, mh, ref = ref_period) |
        geo^year_loss + mh + period_constr,
    data = dt_claims_est, cluster = ~countyfp)
etable(est_claim_es_log, fitstat = c("n", "r2", "my"))

est_static_log <- feols(
    log_building_damage ~ post_mh | geo^year_loss + mh + post1994,
    data = dt_claims_est, cluster = ~countyfp)
etable(est_static_log, fitstat = c("n", "r2", "my"))

# All four baseline outcomes in logs, dynamic OLS. Same right-hand side,
# fixed effects, and clustering as `est_claim_es`; each column drops its own
# zero-valued claims.
s_log <- paste0("c(log_building_damage, ",
                paste0("log_", v_log, collapse = ", "), ")")
est_claim_es_log_all <- feols(
    as.formula(paste0(
        s_log, " ~ i(period_constr, mh, ref = ref_period)",
        " | geo^year_loss + mh + period_constr")),
    data = dt_claims_est, cluster = ~countyfp)
etable(est_claim_es_log_all, fitstat = c("n", "r2", "my"))

# Log damage share (damage / building_value). Same specification as
# `est_claim_es_log`; the sample also drops claims with unusable building_value.
est_claim_es_log_share <- feols(
    log_building_damage_share ~ i(period_constr, mh, ref = ref_period) |
        geo^year_loss + mh + period_constr,
    data = dt_claims_est, cluster = ~countyfp)
est_static_log_share <- feols(
    log_building_damage_share ~ post_mh | geo^year_loss + mh + post1994,
    data = dt_claims_est, cluster = ~countyfp)
etable(est_claim_es_log_share, est_static_log_share,
       fitstat = c("n", "r2", "my"))

# ---------------------------------------------------------------------------
# Claim-level PPML: the paper's headline scale (Chunk O) ----
# ---------------------------------------------------------------------------
# The four loss outcomes are non-negative claim-level amounts whose conditional
# mean differs across housing types by a factor of roughly two and a half, so
# the vintage effect they share is proportional rather than additive. Chunk M
# established that the levels specification is not identified in its own units
# for exactly that reason (a common proportional gradient on bases differing by
# 2.4x mechanically produces about -2.67 with zero true effect, and a
# zero-effect simulation returns -5.31 in levels against zero under Poisson).
# Chunk N found the same failure independently on the take-up outcomes. Colin's
# decision 2026-08-27: report the proportional estimates as the headline.
#
# PPML rather than log OLS, for three reasons, the third of which is decisive
# for the cost-benefit calculation:
#   1. Zeros enter natively; the log specification drops every zero-damage
#      claim and so changes the sample as well as the scale.
#   2. No retransformation is required to state the result.
#   3. PPML models E[Y|X] directly, so exp(beta) is a ratio of CONDITIONAL
#      MEANS. Multiplying an observed mean by it is therefore valid, which is
#      what `estimate-welfare.R` does to turn the proportional estimate back
#      into dollars per claim. Under log OLS exp(beta) is a ratio of geometric
#      means and that conversion would be biased downward.
#
# The levels fits above are retained, and their scalars still exported, so the
# paper can report how far the two scales diverge rather than asserting it.
v_loss <- c("building_damage", "net_building_pmt",
            "contents_damage", "net_contents_pmt")
s_loss <- paste0("c(", paste0(v_loss, collapse = ", "), ")")

fmla_claim_es_pois <- as.formula(paste0(
    s_loss, " ~ i(period_constr, mh, ref = ref_period)",
    " | geo^year_loss + mh + period_constr"
))
est_claim_es_pois <- fepois(
    fmla_claim_es_pois, data = dt_claims_est, cluster = ~countyfp)
etable(est_claim_es_pois, fitstat = c("n", "pr2"))
iplot(est_claim_es_pois[lhs = "building_damage"])

fmla_static_pois <- as.formula(paste0(
    s_loss, " ~ post_mh | geo^year_loss + mh + post1994"
))
est_static_pois <- fepois(
    fmla_static_pois, data = dt_claims_est, cluster = ~countyfp)
etable(est_static_pois, fitstat = c("n", "pr2"))

# County-specific housing-type effect. `geo^mh` gives every county x housing
# type its own baseline, which in PPML is a MULTIPLICATIVE scale on that cell's
# mean rather than an additive intercept, and it absorbs the `mh` main effect
# (nested). `post_mh` is then identified only from vintage variation WITHIN a
# county and housing type, so the between-county comparison is discarded.
#
# This is a robustness diagnostic, not the headline, because the design is thin
# on exactly the margin it demands: 515 of the 887 counties with any MH claim
# have MH claims on only one side of 1994, and those cells cannot contribute to
# `post_mh` at all. The estimate is correspondingly attenuated on the full
# sample, and converges back toward the headline as the sample is restricted to
# counties where the within-county contrast exists (base/geo^mh: -12.7%/-5.4%
# at one MH claim each side, -16.4%/-10.4% at five, -25.7%/-18.0% at twenty).
# Read the gap as a statement about where the identifying variation lives, not
# as a bias correction. Scalars exported; not tabled.
est_static_pois_ctymh <- fepois(
    as.formula(paste0(s_loss, " ~ post_mh | geo^year_loss + geo^mh + post1994")),
    data = dt_claims_est, cluster = ~countyfp)
etable(est_static_pois_ctymh, fitstat = c("n", "pr2"))

# Baseline MH means for the cost-benefit conversion. `estimate-welfare.R` turns
# each proportional estimate back into dollars per claim, and the two
# calculations there need DIFFERENT baselines because they have different
# counterfactuals:
#   private per-unit NPV applies the PRE-1994 claim rate as the counterfactual
#     hazard, so it pairs with the pre-1994 MH mean damage;
#   fiscal savings multiplies OBSERVED post-1994 claims, so it pairs with the
#     observed post-1994 MH mean grossed up to its counterfactual.
# Both are computed on the estimation sample, after winsorization, so they are
# means of the same variable the coefficient describes.
dt_mh_base <- dt_claims_est[mh == 1L, c(
    lapply(.SD, mean, na.rm = TRUE), .(n = .N)),
    by = post1994, .SDcols = v_loss]
setorder(dt_mh_base, post1994)
stopifnot(nrow(dt_mh_base) == 2L, all(dt_mh_base$n > 0))
print(dt_mh_base)

# Paper table columns. `building_damage_share` is still estimated (its scalars
# feed notes/apps/abstract-appam.Rmd) but is no longer a column of either paper
# table. Two reasons, in order of importance. First, its denominator
# `building_value` is the worst-behaved field in the claims data -- a 99.9th
# percentile of $1.07bn for site-built against $3.75M for MH -- so ~0.3% of the
# estimation sample carries a share above 100, which is impossible by
# construction, and those records drive the R2 from 0.52 down to 0.002. Second,
# and decisively: once the share is bounded at 100 the event study shows
# pre-1994 coefficients of +3.8, +5.4, +4.2, +1.8 against post-1994
# coefficients of +0.07, +0.18, -2.0. That is a trend across the whole vintage
# window, not a break at 1994, so parallel vintage trends fails for this
# outcome and the static -3.8 averages over a pre-trend. The share is also
# near-redundant: it is damage divided by value, and both the numerator (column
# 1) and the denominator (replacement cost, in the composition table) are
# reported separately, so the column adds only their covariance.
v_alt <- c(
    "building_damage$", "net_building_pmt$",
    "contents_damage$", "net_contents_pmt$")

etable(
    est_claim_es[lhs = v_alt], fitstat = c("n", "r2", "wr2", "my"))

# Paper table: the PPML fits, in log points. The levels fit above stays in the
# console output and its scalars stay exported, so the appendix can quote how
# far the two scales diverge.
etable(
    est_claim_es_pois,
    tex = TRUE, se.below = FALSE,
    file = file.path(out_dir, "claims-outcomes.tex"),
    fitstat = c("n", "pr2", "my"),
    digits = 3, digits.stats = 2, replace = TRUE
)

# static ----
# Headline ATT: single post_mh coefficient in place of the event study's
# eleven individually-noisy period_constr x mh terms. Same sample, FE
# structure, and clustering as fmla_claim_es, collapsing the vintage
# profile to a pre/post-1994 comparison.
fmla_static <- as.formula(paste0(
    s_claim, " ~ post_mh | geo^year_loss + mh + post1994"
))

est_static <- feols(fmla_static, data = dt_claims_est, cluster = ~countyfp)
etable(est_static[lhs = v_alt], fitstat = c("n", "r2", "my"))

etable(
    est_static_pois,
    tex = TRUE, se.below = FALSE,
    file = file.path(out_dir, "claims-outcomes-static.tex"),
    fitstat = c("n", "pr2", "my"),
    digits = 3, digits.stats = 2, replace = TRUE
)

# Same static specification on the UNWINSORIZED damage fields, so the paper can
# report how much the MAX_CLAIM_LOSS cap moves each coefficient and its fit
# rather than asserting the cap is innocuous. Not a paper table.
est_static_unw <- feols(
    c(building_damage_unw, contents_damage_unw) ~ post_mh |
        geo^year_loss + mh + post1994,
    data = dt_claims_est, cluster = ~countyfp)
etable(est_static_unw, fitstat = c("n", "r2", "my"))

# Same comparison on the headline PPML scale. Poisson weights observations by
# their fitted mean rather than by squared deviation, so a handful of extreme
# LEVELS records move it far less than they move the OLS fit -- which is worth
# reporting rather than asserting, since it is one of the reasons the
# proportional specification is the headline.
est_static_pois_unw <- fepois(
    c(building_damage_unw, contents_damage_unw) ~ post_mh |
        geo^year_loss + mh + post1994,
    data = dt_claims_est, cluster = ~countyfp)
etable(est_static_pois_unw, fitstat = c("n", "pr2", "my"))

# plots ----
# Paper figure: the PPML event study, matching the headline scale.
plot_es(est_claim_es_pois, "building_damage", ylab = "Building damage (log points)",
        path = file.path(out_dir, "es-building-damage.pdf"))

# Export key scalars ----
extract_post_stats <- function(est_obj, outcome, scale = 1) {
    ct <- as.data.table(coeftable(est_obj[lhs = outcome][[1]]),
                        keep.rownames = TRUE)
    ct <- ct[grepl(":mh$", rn)]
    ct[, period := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]
    post <- ct[period >= 1994L, Estimate / scale]
    list(avg = mean(post), min = min(post), max = max(post))
}

eff_bldg_dmg <- extract_post_stats(est_claim_es, "building_damage",      1)
eff_net_bldg <- extract_post_stats(est_claim_es, "net_building_pmt",     1)
eff_cont_dmg <- extract_post_stats(est_claim_es, "contents_damage",      1)
eff_net_cont <- extract_post_stats(est_claim_es, "net_contents_pmt",     1)
eff_bldg_shr <- extract_post_stats(est_claim_es, "building_damage_share",   1)
avg_bldg_dmg_all <- mean(dt_claims_est$building_damage, na.rm = TRUE)

# static ATT: single post_mh coefficient per outcome (headline number)
extract_static <- function(est_obj, outcome) {
    ct <- as.data.table(coeftable(est_obj[lhs = outcome][[1]]),
                        keep.rownames = TRUE)
    ct <- ct[rn == "post_mh"]
    list(est = ct$Estimate, se = ct[["Std. Error"]], t = ct[["t value"]])
}

stc_bldg_dmg <- extract_static(est_static, "building_damage")
stc_net_bldg <- extract_static(est_static, "net_building_pmt")
stc_cont_dmg <- extract_static(est_static, "contents_damage")
stc_net_cont <- extract_static(est_static, "net_contents_pmt")
stc_bldg_shr <- extract_static(est_static, "building_damage_share")

# Log building damage (Chunk M): the static post_mh coefficient, the
# event-study post-1994 average, and the sample cost of dropping zeros
# relative to the levels fit on the same specification.
stc_bldg_log <- local({
    ct <- as.data.table(coeftable(est_static_log), keep.rownames = TRUE)
    ct <- ct[rn == "post_mh"]
    list(est = ct$Estimate, se = ct[["Std. Error"]], t = ct[["t value"]])
})
eff_bldg_log <- local({
    ct <- as.data.table(coeftable(est_claim_es_log), keep.rownames = TRUE)
    ct <- ct[grepl(":mh$", rn)]
    ct[, period := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]
    post <- ct[period >= 1994L, Estimate]
    list(avg = mean(post), min = min(post), max = max(post))
})
n_lvl_est <- nobs(est_static[lhs = "building_damage$"][[1]])
n_log_est <- nobs(est_static_log)

# Claim-level PPML (Chunk O): the headline scale. Coefficients are log rate
# ratios on the conditional mean, so exp(b) - 1 is the proportional change and
# an observed mean multiplied by exp(b) is the counterfactual mean.
extract_static_lhs <- function(est_obj, lhs) {
    ct <- as.data.table(coeftable(est_obj[lhs = paste0("^", lhs, "$")][[1]]),
                        keep.rownames = TRUE)
    ct <- ct[rn == "post_mh"]
    stopifnot(nrow(ct) == 1L)
    list(est = ct$Estimate, se = ct[[3L]], t = ct[[4L]])
}
extract_post_lhs <- function(est_obj, lhs) {
    ct <- as.data.table(coeftable(est_obj[lhs = paste0("^", lhs, "$")][[1]]),
                        keep.rownames = TRUE)
    ct <- ct[grepl(":mh$", rn)]
    ct[, period := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]
    post <- ct[period >= 1994L, Estimate]
    list(avg = mean(post), min = min(post), max = max(post))
}

pois_bldg  <- extract_static_lhs(est_static_pois, "building_damage")
pois_cont  <- extract_static_lhs(est_static_pois, "contents_damage")
pois_nbldg <- extract_static_lhs(est_static_pois, "net_building_pmt")
pois_ncont <- extract_static_lhs(est_static_pois, "net_contents_pmt")
pois_bldg_es  <- extract_post_lhs(est_claim_es_pois, "building_damage")
pois_cont_es  <- extract_post_lhs(est_claim_es_pois, "contents_damage")

# county-specific housing-type effect, the robustness diagnostic
poisc_bldg  <- extract_static_lhs(est_static_pois_ctymh, "building_damage")
poisc_cont  <- extract_static_lhs(est_static_pois_ctymh, "contents_damage")
poisc_nbldg <- extract_static_lhs(est_static_pois_ctymh, "net_building_pmt")
poisc_ncont <- extract_static_lhs(est_static_pois_ctymh, "net_contents_pmt")

# MH baseline means feeding the cost-benefit conversion in estimate-welfare.R
mh_base <- function(outcome, is_post) dt_mh_base[post1994 == is_post][[outcome]]
n_pois_est <- nobs(est_static_pois[lhs = "^building_damage$"][[1]])

write_nfip_scalars(list(
    building_damage_avg                  = eff_bldg_dmg$avg,
    building_damage_min                  = eff_bldg_dmg$min,
    building_damage_max                  = eff_bldg_dmg$max,
    net_building_pmt_avg                 = eff_net_bldg$avg,
    net_building_pmt_min                 = eff_net_bldg$min,
    net_building_pmt_max                 = eff_net_bldg$max,
    contents_damage_avg                  = eff_cont_dmg$avg,
    contents_damage_min                  = eff_cont_dmg$min,
    contents_damage_max                  = eff_cont_dmg$max,
    net_contents_pmt_avg                 = eff_net_cont$avg,
    net_contents_pmt_min                 = eff_net_cont$min,
    net_contents_pmt_max                 = eff_net_cont$max,
    building_damage_share_avg            = eff_bldg_shr$avg,
    building_damage_share_min            = eff_bldg_shr$min,
    building_damage_share_max            = eff_bldg_shr$max,
    avg_building_damage_all              = avg_bldg_dmg_all,
    building_damage_static               = stc_bldg_dmg$est,
    building_damage_static_se            = stc_bldg_dmg$se,
    building_damage_static_t             = stc_bldg_dmg$t,
    net_building_pmt_static              = stc_net_bldg$est,
    net_building_pmt_static_se           = stc_net_bldg$se,
    net_building_pmt_static_t            = stc_net_bldg$t,
    contents_damage_static               = stc_cont_dmg$est,
    contents_damage_static_se            = stc_cont_dmg$se,
    contents_damage_static_t             = stc_cont_dmg$t,
    net_contents_pmt_static              = stc_net_cont$est,
    net_contents_pmt_static_se           = stc_net_cont$se,
    net_contents_pmt_static_t            = stc_net_cont$t,
    building_damage_share_static         = stc_bldg_shr$est,
    building_damage_share_static_se      = stc_bldg_shr$se,
    building_damage_share_static_t       = stc_bldg_shr$t,
    winsor_cap                           = MAX_CLAIM_LOSS,
    winsor_n_building_damage             = dt_winsor_n$building_damage,
    winsor_n_contents_damage             = dt_winsor_n$contents_damage,
    winsor_n_net_building_pmt            = dt_winsor_n$net_building_pmt,
    winsor_n_net_contents_pmt            = dt_winsor_n$net_contents_pmt,
    winsor_n_mh_building_damage          = dt_winsor_mh[mh == 1L, building_damage],
    winsor_n_mh_contents_damage          = dt_winsor_mh[mh == 1L, contents_damage],
    zero_share_net_building_pmt          = dt_zero_share$net_building_pmt,
    zero_share_net_contents_pmt          = dt_zero_share$net_contents_pmt,
    building_damage_static_unw           = extract_static(est_static_unw, "building_damage_unw")$est,
    contents_damage_static_unw           = extract_static(est_static_unw, "contents_damage_unw")$est,
    building_damage_r2                   = r2(est_static[lhs = "building_damage$"][[1]], "r2"),
    building_damage_r2_unw               = r2(est_static_unw[lhs = "building_damage_unw"][[1]], "r2"),
    contents_damage_r2                   = r2(est_static[lhs = "contents_damage$"][[1]], "r2"),
    contents_damage_r2_unw               = r2(est_static_unw[lhs = "contents_damage_unw"][[1]], "r2"),
    pois_building_damage_static          = pois_bldg$est,
    pois_building_damage_static_se       = pois_bldg$se,
    pois_building_damage_static_t        = pois_bldg$t,
    pois_contents_damage_static          = pois_cont$est,
    pois_contents_damage_static_se       = pois_cont$se,
    pois_contents_damage_static_t        = pois_cont$t,
    pois_net_building_pmt_static         = pois_nbldg$est,
    pois_net_building_pmt_static_se      = pois_nbldg$se,
    pois_net_contents_pmt_static         = pois_ncont$est,
    pois_net_contents_pmt_static_se      = pois_ncont$se,
    pois_building_damage_avg             = pois_bldg_es$avg,
    pois_contents_damage_avg             = pois_cont_es$avg,
    pois_building_damage_ctymh           = poisc_bldg$est,
    pois_building_damage_ctymh_se        = poisc_bldg$se,
    pois_contents_damage_ctymh           = poisc_cont$est,
    pois_contents_damage_ctymh_se        = poisc_cont$se,
    pois_net_building_pmt_ctymh          = poisc_nbldg$est,
    pois_net_building_pmt_ctymh_se       = poisc_nbldg$se,
    pois_net_contents_pmt_ctymh          = poisc_ncont$est,
    pois_net_contents_pmt_ctymh_se       = poisc_ncont$se,
    mh_pre_building_damage               = mh_base("building_damage", 0L),
    mh_post_building_damage              = mh_base("building_damage", 1L),
    mh_pre_contents_damage               = mh_base("contents_damage", 0L),
    mh_post_contents_damage              = mh_base("contents_damage", 1L),
    mh_pre_net_building_pmt              = mh_base("net_building_pmt", 0L),
    mh_post_net_building_pmt             = mh_base("net_building_pmt", 1L),
    mh_pre_net_contents_pmt              = mh_base("net_contents_pmt", 0L),
    mh_post_net_contents_pmt             = mh_base("net_contents_pmt", 1L),
    n_building_damage_pois               = n_pois_est,
    pois_building_damage_static_unw      = extract_static_lhs(est_static_pois_unw, "building_damage_unw")$est,
    pois_contents_damage_static_unw      = extract_static_lhs(est_static_pois_unw, "contents_damage_unw")$est,
    pois_building_damage_pr2             = r2(est_static_pois[lhs = "^building_damage$"][[1]], "pr2"),
    pois_building_damage_pr2_unw         = r2(est_static_pois_unw[lhs = "^building_damage_unw$"][[1]], "pr2"),
    log_building_damage_static           = stc_bldg_log$est,
    log_building_damage_static_se        = stc_bldg_log$se,
    log_building_damage_static_t         = stc_bldg_log$t,
    log_building_damage_avg              = eff_bldg_log$avg,
    log_building_damage_min              = eff_bldg_log$min,
    log_building_damage_max              = eff_bldg_log$max,
    log_building_damage_r2               = r2(est_static_log, "r2"),
    zero_share_building_damage           = dt_zero_share$building_damage,
    n_building_damage_levels             = n_lvl_est,
    n_building_damage_log                = n_log_est
), "claims")
