# NFIP take-up per housing unit and claim frequency: static Poisson contrasts on
# the county x calendar-period x housing-type x vintage panel, with the
# imputed housing stock as exposure. Writes the take-up table and
# output/nfip/nfip-takeup-scalars.csv.

rm(list = ls())
library(here)
# The housing-stock denominator ends with the 1999 vintage and is defined from
# 1984, so this design keeps two-year bins and the 1984-1999 window rather than
# the 1988-1999 window of the claim-level event studies.
BIN_CONSTR_DEFAULT <- 2L
source(here("program", "estimate-nfip", "nfip-setup.R"))
MIN_YEAR_CONSTR_NFIP <- MIN_YEAR_CONSTR
MAX_YEAR_CONSTR_NFIP <- MAX_YEAR_CONSTR
source(here("program", "estimate-nfip", "nfip-claims-sample.R"))

# Calendar years per period_loss bin. The cell panel's five-year bins are
# 2009-2013, 2014-2018, 2019-2023 (policy records begin 2009; MAX_YEAR_LOSS is
# 2023), so every retained bin holds exactly this many years. Asserted against
# the data below, since the annualized take-up rates divide by it.
N_YEARS_PERIOD <- 5L

# ---------------------------------------------------------------------------
# data construction ----
# ---------------------------------------------------------------------------

# --- balanced panel ---
dt <- readRDS(here("derived", "nfip-balanced.Rds"))
dt <- nfip_windzone_sample(dt)
dt <- dt[between(year_constr, MIN_YEAR_CONSTR, MAX_YEAR_CONSTR)]

# period_loss bins must be N_YEARS_PERIOD years wide and the last one complete,
# or the annualized take-up rates below divide by the wrong denominator.
periods_obs <- sort(unique(dt$period_loss))
stopifnot(
    length(periods_obs) > 1L,
    all(diff(periods_obs) == N_YEARS_PERIOD),
    max(periods_obs) + N_YEARS_PERIOD - 1L == MAX_YEAR_LOSS
)

# Housing-stock take-up denominator (Chunk E; derived/stock-county-vintage.Rds,
# from program/import/impute-stock.R). Read the current stock independently of
# the policy panel, so a Census denominator change does not require an NFIP
# rebuild.
dt_stock <- readRDS(here("derived", "stock-county-vintage.Rds"))
dt_stock <- nfip_windzone_sample(dt_stock)
dt_stock <- dt_stock[between(year_constr, MIN_YEAR_CONSTR, MAX_YEAR_CONSTR)]

# Take-up per housing-unit stock (Chunk E; Chunk N moves it to PPML). The three
# margins are counts of policy-years and claims relative to an exposure
# denominator, so they are estimated as Poisson counts with the log denominator
# as an offset:
#
#     claims per home = policies per home x claims per policy
#     (hazard realized      (take-up:        (claim frequency
#      per home in the       who insures)     conditional on
#      housing stock)                         holding a policy)
#
# with payment conditional on a claim -- the intensive margin -- reported
# separately in the claim-level damage tables above (`est_claim_es`,
# `est_static`), which need no stock denominator. p(claim | policy) is also the
# object `estimate-welfare.R` uses as its hazard rate, so that column says
# directly whether the reform moved the number the cost-benefit rests on.
#
# WHY COUNTS RATHER THAN OLS ON THE RATIO (Chunk N). These columns previously
# ran OLS on the ratio itself, weighted by the denominator, so the coefficients
# were level differences in policies per 1,000 homes. That specification is not
# identified in its own units, for the same reason the levels damage spec is not
# (Chunk M): the MH/site-built take-up gap is proportional, not additive.
# Weighted take-up runs from about 4 annual policies per 1,000 homes in the
# bottom third of counties to about 108 in the top third, so a single additive
# `mh` fixed effect cannot fit both ends, and `post_mh` absorbs the misfit. The
# diagnostics below (`est_home_diag_*`) quantify it: the pooled level estimate
# is +4.65, but it is NEGATIVE in each of the three take-up terciles estimated
# separately, and flips to about -5.5 as soon as the `mh` and `post1994` main
# effects are allowed to vary by tercile, to about -1.5 with a county-specific
# `mh` effect, and to about +0.4 at five-year construction bins. The PPML
# coefficient moves from 0.007 to 0.170 across the same perturbations -- small
# and sign-stable throughout. Poisson also takes the zeros natively and needs no
# weighting rule.
#
# WHY STATE CLUSTERING (Chunk N). The stock denominator's within-bin annual
# allocation is a STATE-year series (MHS placements) broadcast to every county
# in the state, and county permit shares within a state move together. Its error
# is therefore close to a single draw per state x vintage x housing type, not
# 2,866 independent county draws, and county clustering credits it with
# precision it does not have. Regressing log(homes_n) on the same interaction
# and fixed effects returns a vintage profile with county-clustered t-statistics
# of 5 to 11 on a quantity that contains no policy data at all. Every column
# here clusters by state. Column (3) uses no imputed input and so is not
# exposed to this.
#
# The exact rate identity above holds cell by cell in the data but NOT in the
# fitted coefficients: each column solves its own Poisson score equation against
# its own offset, so (1) + (3) need not equal (2). The appendix says so rather
# than claiming a decomposition the estimator does not deliver.
#
# Construct the denominator from every eligible Census stock cell, then join
# counts. Match numerator construction years to positive stock.
source(here("program", "estimate-nfip", "takeup-panel.R"))
# Claims are aggregated directly so tracts without policies are not silently
# lost from the claims-per-home numerator. The policy panel already contains
# every observed policy; zero-policy county/vintage/type cells come from stock.
takeup_claims <- dt_claims[period_loss %in% periods_obs,
    .(claims_n = .N), by = .(countyfp, period_loss, year_constr, mh)]
dt_home_cell <- build_takeup_panel(dt, takeup_claims, dt_stock, periods_obs,
                                   BIN_CONSTR_YEAR, N_YEARS_PERIOD)

CLUSTER_TAKEUP <- ~statefp

fit_takeup <- function(lhs, offset_var, rhs, data = dt_home_cell,
                       cluster = CLUSTER_TAKEUP) {
    if (offset_var == "log_policy_yrs") data <- data[policies_n > 0]
    fepois(as.formula(paste0(lhs, rhs)), data = data,
           offset = as.formula(paste0("~", offset_var)), cluster = cluster)
}

takeup_headers <- c(
    "Policies per home",
    "Claims per home",
    "Claims per policy"
)

# --- static: one post-1994 x MH coefficient per margin --------------------
takeup_static_rhs <- " ~ post_mh | geo^period_loss + mh + post1994"

est_ppl_home_static <- fit_takeup("policies_n", "log_home_yrs",   takeup_static_rhs)
est_clm_home_static <- fit_takeup("claims_n",   "log_home_yrs",   takeup_static_rhs)
est_claimrate_static <- fit_takeup("claims_n",  "log_policy_yrs", takeup_static_rhs)

est_takeup_static_list <- list(
    est_ppl_home_static, est_clm_home_static, est_claimrate_static)
etable(est_takeup_static_list, fitstat = c("n", "pr2"))

etable(
    est_takeup_static_list,
    digits = 3, digits.stats = 2, fitstat = c("n", "pr2"),
    tex = TRUE, replace = TRUE, depvar = FALSE, se.below = FALSE,
    headers = list("Log annual rate" = takeup_headers),
    file = file.path(out_dir, "take-up-static.tex"))

# Mandatory vs non-mandatory purchase: the same static contrast on each
# component of the policy count.
est_home_mand_static <- fit_takeup(
    "mand_n", "log_home_yrs", takeup_static_rhs)
est_home_nonmand_static <- fit_takeup(
    "nonmand_n", "log_home_yrs", takeup_static_rhs)
etable(list(est_home_mand_static, est_home_nonmand_static), fitstat = c("n"))

# Export key scalars ----
# Every take-up coefficient is a LOG rate ratio -- a proportional change in the
# annual rate. The `_ppml` suffix marks that. The pre-1994 MH levels are
# descriptive statistics, not estimates.
extract_static_single <- function(est_obj) {
    ct <- as.data.table(coeftable(est_obj), keep.rownames = TRUE)
    ct <- ct[rn == "post_mh"]
    stopifnot(nrow(ct) == 1L)
    list(est = ct$Estimate, se = ct[[3L]], t = ct[[4L]])
}

stc_ppl_home    <- extract_static_single(est_ppl_home_static)
stc_clm_home    <- extract_static_single(est_clm_home_static)
stc_claim_rate  <- extract_static_single(est_claimrate_static)
stc_ppl_mand    <- extract_static_single(est_home_mand_static)
stc_ppl_nonmand <- extract_static_single(est_home_nonmand_static)

# Pre-1994 MH baselines for the three take-up margins.
base_ppl_home  <- dt_home_cell[
    mh == 1L & period_constr < 1994L,
    sum(policies_n) / (sum(homes_n) * N_YEARS_PERIOD) * 1000]
base_clm_home  <- dt_home_cell[
    mh == 1L & period_constr < 1994L,
    sum(claims_n) / (sum(homes_n) * N_YEARS_PERIOD) * 1000]
base_claim_rate <- dt_home_cell[
    mh == 1L & period_constr < 1994L, sum(claims_n) / sum(policies_n)]
# pooled pre-1994 policies per 1,000 homes per year, by housing type
ppl_home_pre <- function(is_mh) dt_home_cell[
    mh == is_mh & period_constr < 1994L,
    sum(policies_n) / (sum(homes_n) * N_YEARS_PERIOD) * 1000]
# pre-1994 mandated share of MH policy-years
base_mand_share <- dt_home_cell[
    mh == 1L & period_constr < 1994L, sum(mand_n) / sum(policies_n)]

write_nfip_scalars(list(
    takeup_ppml_static               = stc_ppl_home$est,
    takeup_ppml_static_se            = stc_ppl_home$se,
    takeup_ppml_static_t             = stc_ppl_home$t,
    claims_home_ppml_static          = stc_clm_home$est,
    claims_home_ppml_static_se       = stc_clm_home$se,
    claims_home_ppml_static_t        = stc_clm_home$t,
    claim_rate_ppml_static           = stc_claim_rate$est,
    claim_rate_ppml_static_se        = stc_claim_rate$se,
    claim_rate_ppml_static_t         = stc_claim_rate$t,
    policies_per_1k_homes_yr_base_mh = base_ppl_home,
    claims_per_1k_homes_yr_base_mh   = base_clm_home,
    claim_rate_base_mh               = base_claim_rate,
    policies_per_1k_homes_yr_mh_pre  = ppl_home_pre(1L),
    policies_per_1k_homes_yr_sb_pre  = ppl_home_pre(0L),
    takeup_ppml_mand_static          = stc_ppl_mand$est,
    takeup_ppml_mand_static_se       = stc_ppl_mand$se,
    takeup_ppml_nonmand_static       = stc_ppl_nonmand$est,
    takeup_ppml_nonmand_static_se    = stc_ppl_nonmand$se,
    takeup_mand_share_pre_mh         = base_mand_share
), "takeup")
