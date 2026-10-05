# Policy-level composition of the insured MH and site-built stock by vintage
# (Chunk J), on the policy-term microdata. Kept separate from the other NFIP
# scripts because it is the only one that reads the policy parquet.
# Writes output/results/nfip-composition-scalars.csv.

rm(list = ls())
library(here)
source(here("program", "lib", "nfip-setup.R"))

# ---------------------------------------------------------------------------
# policy-level composition table (Chunk J) ----
#
#   Replaces the cell-level policy-composition table (which averaged policy
#   characteristics within geo x period x mh x vintage cells before
#   regressing). This regresses policy characteristics directly on the
#   policy-term microdata (derived/nfip-policy-micro.parquet, built by
#   program/import/databuild-nfip-policy.R: one row per policy term, already
#   restricted to single-family residential occupancy_type -- see
#   project-params.R). Always at countyfp x period_loss, per the Chunk J
#   spec, independent of the agg_geo command-line argument.
# ---------------------------------------------------------------------------

dt_pol_micro <- as.data.table(arrow::read_parquet(
    here("derived", "nfip-policy-micro.parquet")))
dt_pol_micro <- dt_pol_micro[between(year_constr, MIN_YEAR_CONSTR, MAX_YEAR_CONSTR)]
dt_pol_micro[, period_constr := bin_constr(year_constr, BIN_CONSTR_YEAR)]

# All five composition outcomes are estimated by PPML (fepois), on the same
# reasoning as the claim-level outcomes above (Chunk O): the vintage effect
# a common force exerts on these outcomes is proportional, not additive, so a
# single housing-type fixed effect cannot absorb a gap that scales with the
# outcome's own level, and PPML models E[Y|X] directly so exp(beta) is a ratio
# of conditional means rather than of geometric means. Replacement cost used to
# be the deciding case for logging instead: it is the worst-behaved field on
# the policy file (mean 199.9, s.d. 2,269, 99th percentile 997, max 1,371,528 --
# a single-family home with a $1.37bn replacement cost), so a level fit gave an
# R2 of 0.001 and an unstable vintage profile (+32, +30, +10, -8, +31, +18, +2
# across the seven bins) driven by records no fixed effect can explain. PPML
# does not have that problem: it weights an observation by its fitted mean
# rather than by its squared deviation, so the same extreme records that broke
# the OLS level fit do not dominate the Poisson one, and the entered outcome is
# the raw dollar level rather than its log. The 5.6% of policy terms recording
# an exact zero replacement cost are still dropped: a $0 replacement cost on an
# insured single-family home is a missing code rather than a fact, independent
# of which estimator reads the column.
dt_pol_micro[, repl_cost_pol := fifelse(
    !is.na(repl_cost) & repl_cost > 0, repl_cost, NA_real_)]
n_repl_zero <- dt_pol_micro[, mean(!is.na(repl_cost) & repl_cost == 0)]

# Contents coverage enters unconditionally, with the zeros included, as one
# column rather than as separate extensive- and intensive-margin columns. Both
# margins are individually null after 1994 (the extensive margin is +0.004,
# -0.01, -0.02 and the conditional amount -0.30, +0.22, +0.16), so one column
# carries the whole finding, and the unconditional amount does not condition on
# a variable that itself moves across vintages -- the conditional-amount column
# was estimated on a sample selected by the outcome of the column beside it.
# PPML handles the contents-coverage zeros natively, the same way it handles
# the payment-outcome zeros in the claims table.
#
# The two location/design indicators (elevated, SFHA) enter as 0/1 rather than
# rescaled to percentage points. Under OLS that rescaling mattered, so the
# coefficients would print at the same number of significant digits as the
# dollar columns; under PPML it is redundant, because a constant rescaling of
# the outcome is absorbed by the fixed effects and leaves the fitted
# coefficients on `period_constr x mh` unchanged -- every column's coefficient
# is already a log rate ratio, on the same scale, regardless of the units the
# outcome happened to arrive in.
v_comp_pol <- c(
    "repl_cost_pol",
    "building_policy_covg",
    "contents_policy_covg",
    "elevated_policy",
    "sfha_policy"
)
s_comp_pol <- paste0("c(", paste(v_comp_pol, collapse = ", "), ")")

fmla_comp_pol <- as.formula(paste0(
    s_comp_pol, " ~ i(period_constr, mh, ref = ref_period)",
    " | countyfp^period_loss + mh + period_constr"
))

est_comp_pol <- fepois(
    fmla_comp_pol, data = dt_pol_micro,
    cluster = ~countyfp, lean = TRUE
)
etable(est_comp_pol, fitstat = c("n", "pr2", "my"))

etable(
    est_comp_pol,
    tex = TRUE, se.below = FALSE,
    file = file.path(out_dir, "policy-composition.tex"),
    fitstat = c("n", "pr2", "my"),
    digits = 3, digits.stats = 2, replace = TRUE
)

write_nfip_scalars(list(
    repl_cost_zero_share = n_repl_zero
), "composition")
