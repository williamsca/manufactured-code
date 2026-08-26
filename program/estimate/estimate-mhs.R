# Estimate price effects of HUD code changes on manufactured homes
# Analyses: (1) TWFE event study for 1994 wind standard (DiD)
#           (2) Pre-post interrupted time series for energy, smoke alarm, NEC rules

rm(list = ls())
library(here)
library(data.table)
library(fixest)
library(ggplot2)
library(kableExtra)

source(here("program", "import", "project-params.R"))

# import ----

dt <- readRDS(here("derived", "sample-mhs.Rds"))
dt <- dt[between(year, MIN_YEAR_MHS, MAX_YEAR_MHS)]

dt_type <- readRDS(here("derived", "sample-mhs-type.Rds"))
dt_type <- dt_type[between(year, MIN_YEAR_MHS, MAX_YEAR_MHS)]

n_dropped_states <- readRDS(here("derived", "mhs-dropped-states.Rds"))$n_dropped_states

# Every MHS regression below is weighted by `placements_base`, the state's
# mean 1988-1993 placements (databuild-mhs.R), a fixed pre-reform measure
# of state size. Verify it is defined for every state that could actually
# enter a regression in this sample - i.e. every state with at least one
# non-missing value on some price or quantity outcome within the
# estimation window - so no state silently drops out through an undefined
# weight rather than through having no data.
v_all_out <- unique(c(
    "avg_sales_price_fw", "avg_sales_price_fw_idx", "avg_sales_price_fw_ln",
    "avg_sales_price_comp", "avg_sales_price", "avg_sales_price_ln",
    "avg_sales_price_single", "avg_sales_price_double",
    "avg_sales_price_single_ln", "avg_sales_price_double_ln",
    "placements_ln", "placements_single_ln", "placements_double_ln",
    "placements_permits_ratio"
))
dt[, has_any_outcome := Reduce(`|`, lapply(.SD, function(x) !is.na(x))),
   .SDcols = v_all_out]
v_active_states <- dt[has_any_outcome == TRUE, unique(statefp)]
bad_wt <- dt[statefp %in% v_active_states,
             .(placements_base = placements_base[1]), by = statefp][
    is.na(placements_base) | placements_base <= 0]
if (nrow(bad_wt) > 0) {
    stop("placements_base undefined for states with outcome data: ",
         paste(bad_wt$statefp, collapse = ", "))
}
dt[, has_any_outcome := NULL]
stopifnot(!anyNA(dt_type$reg_wt), all(dt_type$reg_wt > 0),
          !anyNA(dt_type$placements_base), all(dt_type$placements_base > 0))

# Post-1994 indicators, defined here rather than beside the static models
# below so that `dt_common` inherits them.
dt[, post1994 := as.numeric(year >= 1994)]
dt[, post_treated      := post1994 * treated]
dt[, post_treated_dose := post1994 * treated_intensity]

# The index sample. Constructing the fixed-weight index requires both
# size-specific prices, which Census suppresses for small states, so the
# index is defined on fewer state-years than the all-homes average is.
# Every quantity estimate below is restricted to this sample as well, so
# that the price and quantity effects describe the same set of states and
# years rather than being read off two different panels. The all-homes
# average is published wherever the index is defined (the check below), so
# this subset is exactly the index sample.
stopifnot(dt[!is.na(avg_sales_price_fw) & is.na(avg_sales_price), .N] == 0L)
dt_common <- dt[!is.na(avg_sales_price_fw)]

# estimate ----
# Headline price outcome is the fixed-weight index built in
# databuild-mhs.R, which holds the single-/multi-section mix at a national
# pre-reform basket, so a shift toward multi-section units cannot register
# as a price effect. `avg_sales_price` is retained for comparison and
# `avg_sales_price_comp` isolates the mix shift on its own.
v_out_p <- c("avg_sales_price_fw", "avg_sales_price_fw_idx",
             "avg_sales_price_fw_ln", "avg_sales_price_comp",
             "avg_sales_price", "avg_sales_price_ln",
             "avg_sales_price_single", "avg_sales_price_double",
             "avg_sales_price_single_ln", "avg_sales_price_double_ln")
stopifnot(all(v_out_p %in% names(dt)))
s_out_p <- paste0("c(", paste0(v_out_p, collapse = ", "), ")")

# quantities in logs
v_out_q <- c("placements_ln", "placements_single_ln", "placements_double_ln",
             "placements_permits_ratio")
s_out_q <- paste0("c(", paste0(v_out_q, collapse = ", "), ")")

fmla_p <- as.formula(paste0(
    s_out_p, " ~ i(year, treated, ref = 1993) | statefp + year"
))

fmla_q <- as.formula(paste0(
    s_out_q, " ~ i(year, treated, ref = 1993) | statefp + year"
))

# All MHS estimates are weighted by placements_base, the state's fixed
# pre-reform (1988-1993 mean) placement count, so a state placing a few
# hundred homes a year does not count as much as one placing tens of
# thousands. States with no recorded shipments over 1988-1993 have no
# defined weight and are dropped in databuild-mhs.R.
est_p <- feols(fmla_p, data = dt, weights = ~placements_base, cluster = ~statefp)
est_q <- feols(fmla_q, data = dt_common, weights = ~placements_base,
               cluster = ~statefp)

# Exact left-hand-side selection. `est[lhs = "avg_sales_price"]` uses
# partial matching, so with `avg_sales_price_fw` also in the multi-model
# it silently returns the wrong equation; match on the model index
# instead.
pick_lhs <- function(est, lhs) {
    i <- which(models(est)$lhs == lhs)
    stopifnot(length(i) == 1L)
    est[[i]]
}

etable(est_p, digits = 3)
etable(est_q, digits = 3)

# Chunk C: wind-zone dose-response ----
# The binary `treated` above codes a state as treated if it contains any
# Zone II/III county, which badly dilutes the design: pooled across
# treated states only ~30% of the 1980-2000 MH stock actually sits in a
# Zone II/III county (range: FL 97% down to VA 3%; see
# derived/mhs-windzone-intensity.Rds). `treated_intensity` replaces the
# binary indicator with the MH-stock-weighted share of a state's stock in
# Zone II/III, so beta_k is directly comparable to the binary spec's
# coefficient: it is the implied price effect of moving a state from 0%
# to 100% zone II/III MH stock.
fmla_p_dose <- as.formula(paste0(
    s_out_p, " ~ i(year, treated_intensity, ref = 1993) | statefp + year"
))
est_p_dose <- feols(fmla_p_dose, data = dt, weights = ~placements_base,
                    cluster = ~statefp)
etable(est_p_dose, digits = 3)

# Same substitution on the quantity side: does the placements event study
# also steepen under continuous intensity, or does it stay flat/null like
# the binary version?
fmla_q_dose <- as.formula(paste0(
    s_out_q, " ~ i(year, treated_intensity, ref = 1993) | statefp + year"
))
est_q_dose <- feols(fmla_q_dose, data = dt_common, weights = ~placements_base,
                    cluster = ~statefp)
etable(est_q_dose, digits = 3)

# Binary spec, restricted to the three high-intensity treated states
# (FL, LA, MA) vs. the zone I controls, so any dilution from partially
# treated states (e.g. GA at 6% intensity) cannot attenuate the estimate.
dt_hi <- dt[high_intensity == TRUE | treated == FALSE]
est_p_hi <- feols(fmla_p, data = dt_hi, weights = ~placements_base,
                  cluster = ~statefp)
etable(est_p_hi, digits = 3)

# Static (single-coefficient) comparison table: binary vs. continuous
# treatment, same outcome, same sample/FE/clustering, so the two columns
# differ only in how "treated" is coded. Collapses the event study's
# per-year interactions to one post-1994 coefficient, the same
# simplification `post_mh` makes for the NFIP claim spec. The post-1994
# interactions are built above, with `dt_common`.
fmla_static_bin  <- avg_sales_price_fw ~ post_treated      | statefp + year
fmla_static_dose <- avg_sales_price_fw ~ post_treated_dose | statefp + year

est_static_bin  <- feols(fmla_static_bin,  data = dt, weights = ~placements_base,
                         cluster = ~statefp)
est_static_dose <- feols(fmla_static_dose, data = dt, weights = ~placements_base,
                         cluster = ~statefp)

# Quantity-side counterpart of `est_static_bin`: one post-1994 coefficient
# on log placements, on the same index sample as the price estimates, so
# the paper can report a single semi-elasticity and its standard error
# rather than characterizing eleven event-study coefficients in prose.
est_q_static <- feols(placements_ln ~ post_treated | statefp + year,
                      data = dt_common, weights = ~placements_base,
                      cluster = ~statefp)

dict_static <- c(
    "post_treated"          = "Post 1994 x Treated",
    "post_treated_dose"     = "Post 1994 x Treated",
    "avg_sales_price_fw"    = "Fixed-weight price index (\\$)",
    "avg_sales_price_fw_idx" = "Fixed-weight price index (1993 = 100)",
    "avg_sales_price_comp"  = "Composition-only index (\\$)",
    "avg_sales_price"       = "Average sales price (\\$)",
    "share_double"          = "Multi-section share",
    "price"                 = "Sales price (\\$)",
    "section_type"          = "Section type",
    "statefp"               = "State",
    "year"                  = "Year"
)

etable(
    list(est_static_bin, est_static_dose),
    dict = dict_static,
    headers = list("Treatment" = list("Binary" = 1, "Continuous intensity" = 1)),
    fitstat = c("n", "r2", "my"), digits = 3
)

dir.create(here("output", "event-study"), showWarnings = FALSE, recursive = TRUE)
etable(
    list(est_static_bin, est_static_dose),
    dict = dict_static,
    headers = list("Treatment" = list("Binary" = 1, "Continuous intensity" = 1)),
    tex = TRUE, se.below = FALSE,
    file = here("output", "event-study", "mhs-dose-response-static.tex"),
    fitstat = c("n", "r2", "my"),
    digits = 2, digits.stats = 2, replace = TRUE
)

# Composition decomposition ----
# Four static DiDs that separate two distinct reasons the headline number
# moves relative to the old raw-average specification.
#   (1) raw average price on every state-year where it is published;
#   (2) the same outcome restricted to the state-years where both
#       section-type prices are published, so the index is defined - this
#       isolates the effect of the smaller sample on its own;
#   (3) the fixed-weight index on that same sample - the difference from
#       (2) is what holding the mix fixed does;
#   (4) the state-year's actual mix valued at fixed national base prices,
#       i.e. the mix shift alone, in dollars.
# By construction raw ~ fixed-weight + composition + interaction, so (4)
# is the part of (1) that a composition shift could account for.
# `dt_common`, the index sample, is defined above.

# Event-study counterpart of the same restriction. fixest estimates each
# left-hand side of `est_p` on its own non-missing rows, so the raw-average
# equation there runs on more state-years than the index equation does;
# this re-estimates it on the index's sample so the two event-study
# averages are like-for-like.
est_raw_cmn <- feols(
    avg_sales_price ~ i(year, treated, ref = 1993) | statefp + year,
    data = dt_common, weights = ~placements_base, cluster = ~statefp)

est_dec_raw      <- feols(avg_sales_price ~ post_treated | statefp + year,
                          data = dt, weights = ~placements_base,
                          cluster = ~statefp)
est_dec_raw_cmn  <- feols(avg_sales_price ~ post_treated | statefp + year,
                          data = dt_common, weights = ~placements_base,
                          cluster = ~statefp)
est_dec_fw       <- feols(avg_sales_price_fw ~ post_treated | statefp + year,
                          data = dt_common, weights = ~placements_base,
                          cluster = ~statefp)
est_dec_comp     <- feols(avg_sales_price_comp ~ post_treated | statefp + year,
                          data = dt_common, weights = ~placements_base,
                          cluster = ~statefp)
est_dec_share    <- feols(share_double ~ post_treated | statefp + year,
                          data = dt, weights = ~placements_base,
                          cluster = ~statefp)

etable(list(est_dec_raw, est_dec_raw_cmn, est_dec_fw, est_dec_comp,
            est_dec_share), dict = dict_static, digits = 3,
       fitstat = c("n", "r2", "my"))

etable(
    list(est_dec_raw, est_dec_raw_cmn, est_dec_fw, est_dec_comp,
         est_dec_share),
    dict = dict_static,
    headers = list("Sample" = list("All" = 1, "Index sample" = 3, "All" = 1)),
    tex = TRUE, se.below = FALSE,
    file = here("output", "event-study", "mhs-composition-decomposition.tex"),
    fitstat = c("n", "r2", "my"),
    digits = 2, digits.stats = 2, replace = TRUE
)

# Weighting robustness. The headline specification (est_static_bin, above)
# is weighted by placements_base; this re-estimates it unweighted, so a
# state placing a few hundred homes a year counts as much as one placing
# tens of thousands, as a check on how much the weighting choice matters.
est_static_unwtd <- feols(fmla_static_bin, data = dt, cluster = ~statefp)
etable(list(est_static_bin, est_static_unwtd), dict = dict_static, digits = 3,
       fitstat = c("n", "r2", "my"))

# Section-type heterogeneity ----
# Stacked panel of one price per state-year-section-type, with section-
# type-specific state and year fixed effects, so identification is within
# section type and the mix cannot enter. Observations are weighted by
# `reg_wt` = placements_base (state size) x the national base-period share
# of their section type (databuild-mhs.R): this reproduces a
# placements_base-weighted regression on the fixed-weight index itself
# where both prices are published, and additionally keeps the state-years
# where Census suppresses one of the two.
dt_type[, post_treated := as.numeric(year >= 1994) * treated]

fmla_type_pool <- price ~ post_treated | statefp^section_type + year^section_type
fmla_type_het  <- price ~ post_treated:section_type |
    statefp^section_type + year^section_type

est_type_pool <- feols(fmla_type_pool, data = dt_type, weights = ~reg_wt,
                       cluster = ~statefp)
est_type_het  <- feols(fmla_type_het, data = dt_type, weights = ~reg_wt,
                       cluster = ~statefp)

# Same contrast estimated separately by section type, as a check that the
# interacted specification is not being driven by the shared fixed effects.
# Within one size the type share drops out, so the weight is state size
# (placements_base) alone. Console-only: the two size-specific columns
# reproduce est_type_het's coefficients exactly, so they are not exported
# to the paper table.
est_type_single <- feols(price ~ post_treated | statefp + year,
                         data = dt_type[section_type == "single"],
                         weights = ~placements_base, cluster = ~statefp)
est_type_double <- feols(price ~ post_treated | statefp + year,
                         data = dt_type[section_type == "double"],
                         weights = ~placements_base, cluster = ~statefp)

dict_type <- c(dict_static,
    "post_treated:section_typesingle" = "Post 1994 x Treated x Single",
    "post_treated:section_typedouble" = "Post 1994 x Treated x Double",
    "statefp^section_type"            = "State x Section type",
    "year^section_type"               = "Year x Section type")

etable(list(est_type_pool, est_type_het, est_type_single, est_type_double),
       dict = dict_type, digits = 3, fitstat = c("n", "r2", "my"))

# Coefficients and the dependent-variable mean are in dollars, so both are
# rounded to the nearest dollar: `digits = "r0"` rounds the estimates, and
# the mean is formatted by hand and passed through `extralines` (fixest's
# `digits.stats` applies to every fit statistic at once, and rounding R2 to
# zero decimals would report it as 1).
fmt_dvm <- function(est) {
    formatC(fitstat(est, "my")$my, format = "f", digits = 0, big.mark = ",")
}

etable(
    list(est_type_pool, est_type_het),
    dict = dict_type,
    tex = TRUE, se.below = FALSE,
    file = here("output", "event-study", "mhs-section-type.tex"),
    fitstat = c("n", "r2"),
    extralines = list("__Dependent variable mean" =
        c(fmt_dvm(est_type_pool), fmt_dvm(est_type_het))),
    digits = "r0", digits.stats = 2, replace = TRUE
)

# plots ----
v_palette <- c("#0072B2", "#D55E00", "#009E73", "#F0E442")

v_dict <- c(
    "avg_sales_price_fw"        = "Fixed-weight price index (000s)",
    "avg_sales_price_fw_idx"    = "Fixed-weight price index (1993 = 100)",
    "avg_sales_price_fw_ln"     = "Fixed-weight price index (log)",
    "avg_sales_price_comp"      = "Composition-only index (000s)",
    "avg_sales_price"           = "Average sales price (000s)",
    "avg_sales_price_single"    = "Average sales price, single-wide (000s)",
    "avg_sales_price_double"    = "Average sales price, double-wide (000s)",
    "avg_sales_price_ln"        = "Average sales price (log)",
    "avg_sales_price_single_ln" = "Average sales price, single-wide (log)",
    "avg_sales_price_double_ln" = "Average sales price, double-wide (log)",
    "placements_ln"                  = "Placements (log)",
    "placements_single_ln"           = "Single-wide placements (log)",
    "placements_double_ln"           = "Double-wide placements (log)",
    "placements_permits_ratio"    = "Placements / SF permits"
)

# Level outcomes are stored in dollars and plotted in thousands; logs and
# the 1993 = 100 index are plotted on their own scale.
yscale_for <- function(out) {
    if (grepl("_ln$|_idx$", out)) 1 else 1000
}

theme_paper <- function(base_size = 14) {
    theme_classic(base_size = base_size) +
        theme(
            text = element_text(family = "serif"),
            legend.position = "right",
            panel.grid.major.y = element_line(color = "gray85", linewidth = 0.4),
            panel.grid.minor.y = element_blank()
        )
}

# Plot an event study from a fixest model estimated with i(year, treated, ref = 1993).
# Extracts interaction terms (:treated), appends a zero row at the reference year,
# and draws point estimates with 95% CI ribbon.
plot_es <- function(est, outcome = NULL, ref = 1993L, vline_x = 1993.5,
                    xlab = "Year", path = NULL, var = "treated", yscale = 1) {
    if (!is.null(outcome)) est <- pick_lhs(est, outcome)
    ylab <- if (!is.null(outcome) && outcome %in% names(v_dict)) {
        unname(v_dict[[outcome]])
    } else {
        outcome
    }

    ct <- as.data.table(coeftable(est), keep.rownames = TRUE)
    idx <- grepl(paste0(":", var, "$"), ct$rn)
    dt_es <- data.table(
        term = ct$rn[idx],
        est  = ct$Estimate[idx] / yscale,
        se   = ct[["Std. Error"]][idx] / yscale
    )
    dt_es[, period  := as.integer(regmatches(term, regexpr("[0-9]{4}", term)))]
    dt_es[, ci_low  := est - 1.96 * se]
    dt_es[, ci_high := est + 1.96 * se]

    dt_es <- rbind(
        dt_es,
        data.table(term = NA_character_, est = 0, se = 0,
                   ci_low = 0, ci_high = 0, period = ref)
    )
    setorder(dt_es, period)

    p <- ggplot(dt_es, aes(x = period, y = est)) +
        geom_ribbon(aes(ymin = ci_low, ymax = ci_high),
                    alpha = 0.2, fill = v_palette[1]) +
        geom_point(color = v_palette[1], size = 2) +
        geom_line(color = v_palette[1]) +
        geom_vline(xintercept = vline_x, linetype = "dotted", color = "black") +
        # geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
        scale_x_continuous(breaks = dt_es$period) +
        labs(x = xlab, y = ylab) +
        theme_paper()

    if (!is.null(path)) ggsave(path, p, width = 9, height = 5)
    p
}

dir.create(
    here("output", "event-study"), showWarnings = FALSE, recursive = TRUE)

for (out in v_out_p) {
    plot_es(est_p, out, yscale = yscale_for(out),
            path = here("output", "event-study", paste0("es-mhs-", out, ".pdf")))
}

for (out in v_out_q) {
    plot_es(est_q, out,
            path = here("output", "event-study", paste0("es-mhs-", out, ".pdf")))
}

# Chunk C dose-response plots ----
# Dynamic (per-year) continuous-treatment event study, same var = "treated"
# in plot_es because i(year, treated_intensity, ref = 1993) still names its
# interaction terms "...:treated" internally via fixest's i() — the
# treated_intensity variable is what varies, not the term name.
for (out in v_out_p) {
    plot_es(est_p_dose, out, yscale = yscale_for(out), var = "treated_intensity",
            path = here("output", "event-study", paste0("es-mhs-", out, "-dose.pdf")))
}

for (out in v_out_q) {
    plot_es(est_q_dose, out, var = "treated_intensity",
            path = here("output", "event-study", paste0("es-mhs-", out, "-dose.pdf")))
}

plot_es(est_p_hi, "avg_sales_price_fw_idx", yscale = 1,
        path = here("output", "event-study", "es-mhs-avg_sales_price_fw_idx-hi.pdf"))

# Export key scalars ----
dir.create(here("output", "results"), showWarnings = FALSE, recursive = TRUE)

# Post-1994 average of the event-study interactions, for one outcome of
# the multi-LHS price model.
post_avg <- function(est, lhs, var = "treated", scale = 1000) {
    ct <- as.data.table(coeftable(pick_lhs(est, lhs)), keep.rownames = TRUE)
    ct[, year := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]
    ct <- ct[grepl(paste0(":", var, "$"), rn)]
    ct[year >= 1994, mean(Estimate) / scale]
}

# Headline effect is now measured on the fixed-weight index, so it is the
# price of a fixed national basket of single- and multi-section homes and
# cannot reflect a shift in the mix. Still in thousands of 2000 dollars,
# which is the unit estimate-welfare.R reads it in.
ct_price <- as.data.table(
    coeftable(pick_lhs(est_p, "avg_sales_price_fw")),
    keep.rownames = TRUE)
ct_price[, year := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]
ct_price <- ct_price[grepl(":treated$", rn)]

price_effect_level <- ct_price[year >= 1994, mean(Estimate) / 1000]
price_effect_1994  <- ct_price[year == 1994, Estimate / 1000]

# Denominator for the percentage effect is the same object as the
# numerator: the pre-reform level of the fixed-weight index in treated
# states, so the ratio is a percentage change in the index rather than a
# dollar effect divided by a differently-composed average. Weighted by
# placements_base rather than contemporaneous placements, consistent with
# every other estimate in this script.
avg_price_treated_pre <- dt[treated == TRUE & year < 1994,
    weighted.mean(avg_sales_price_fw, placements_base, na.rm = TRUE) / 1000]
price_effect_pct <- price_effect_level / avg_price_treated_pre * 100

# Same estimate expressed in index points (national 1993 = 100). Exactly
# proportional to price_effect_level, since the normalization divides by a
# single national constant.
price_effect_idx <- post_avg(est_p, "avg_sales_price_fw_idx", scale = 1)

# Composition decomposition, in thousands of 2000 dollars: the raw
# average-price effect, the same on the index sample, and the mix shift
# valued at fixed base prices.
price_effect_raw_level     <- post_avg(est_p, "avg_sales_price")
ct_raw_cmn <- as.data.table(coeftable(est_raw_cmn), keep.rownames = TRUE)
ct_raw_cmn[, year := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]
price_effect_raw_cmn_level <- ct_raw_cmn[
    grepl(":treated$", rn) & year >= 1994, mean(Estimate) / 1000]
price_effect_comp_level    <- post_avg(est_p, "avg_sales_price_comp")
price_effect_raw_static    <- coef(est_dec_raw)[["post_treated"]] / 1000
price_effect_raw_cmn_static <- coef(est_dec_raw_cmn)[["post_treated"]] / 1000
price_effect_fw_static     <- coef(est_dec_fw)[["post_treated"]] / 1000
price_effect_comp_static   <- coef(est_dec_comp)[["post_treated"]] / 1000
share_double_effect        <- coef(est_dec_share)[["post_treated"]]
price_effect_unwtd_static  <- coef(est_static_unwtd)[["post_treated"]] / 1000

# Basket weights and the normalization constant, recovered from the
# section-type panel so the paper can report the index definition without
# duplicating databuild-mhs.R's constants.
base_wt_single <- dt_type[section_type == "single", base_wt[1]]
base_wt_double <- dt_type[section_type == "double", base_wt[1]]
idx_base_1993  <- (price_effect_level / price_effect_idx) * 100 * 1000
mean_price_single <- dt_type[section_type == "single", mean(price)] / 1000
mean_price_double <- dt_type[section_type == "double", mean(price)] / 1000
price_ratio_double_single <- mean_price_double / mean_price_single

# Section-type heterogeneity, in thousands of 2000 dollars.
ct_type <- coef(est_type_het)
price_effect_single_level <- ct_type[["post_treated:section_typesingle"]] / 1000
price_effect_double_level <- ct_type[["post_treated:section_typedouble"]] / 1000
price_effect_type_pool    <- coef(est_type_pool)[["post_treated"]] / 1000

# Chunk C dose-response scalars ----
# `price_effect_dose_level` is the implied price effect of moving a state
# from 0% to 100% Zone II/III MH stock (fully comparable to
# `price_effect_level`'s binary treated/control contrast). A flat
# gradient (dose ~ binary) supports regional production standardization;
# a steep gradient (dose >> binary) means the true per-unit compliance
# cost is larger than the binary design implies.
ct_price_dose <- as.data.table(
    coeftable(pick_lhs(est_p_dose, "avg_sales_price_fw")),
    keep.rownames = TRUE)
ct_price_dose[, year := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]
ct_price_dose <- ct_price_dose[grepl(":treated_intensity$", rn)]
price_effect_dose_level <- ct_price_dose[year >= 1994, mean(Estimate) / 1000]

ct_price_hi <- as.data.table(
    coeftable(pick_lhs(est_p_hi, "avg_sales_price_fw")),
    keep.rownames = TRUE)
ct_price_hi[, year := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]
ct_price_hi <- ct_price_hi[grepl(":treated$", rn)]
price_effect_hi_level <- ct_price_hi[year >= 1994, mean(Estimate) / 1000]

dose_binary_ratio <- price_effect_dose_level / price_effect_level

# Quantity-side dose-response scalar, same construction as
# `price_effect_dose_level`: average of the post-1994 treated_intensity
# interactions, i.e. the implied log-placements effect of moving a state
# from 0% to 100% Zone II/III MH stock.
ct_placements_dose <- as.data.table(
    coeftable(pick_lhs(est_q_dose, "placements_ln")),
    keep.rownames = TRUE)
ct_placements_dose[, year := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]
ct_placements_dose <- ct_placements_dose[grepl(":treated_intensity$", rn)]
placements_effect_dose_level <- ct_placements_dose[year >= 1994, mean(Estimate)]

# Binary-treatment quantity effects, on the index sample. The event-study
# average is the counterpart of `price_effect_level`; the static
# coefficient and its standard error are what the text reports, since a
# single estimate is more informative than an average of eleven noisy
# per-year coefficients. Both are log points.
ct_placements <- as.data.table(
    coeftable(pick_lhs(est_q, "placements_ln")), keep.rownames = TRUE)
ct_placements[, year := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]
ct_placements <- ct_placements[grepl(":treated$", rn)]
placements_effect_level <- ct_placements[year >= 1994, mean(Estimate)]

placements_effect_static    <- coef(est_q_static)[["post_treated"]]
placements_effect_static_se <- se(est_q_static)[["post_treated"]]
n_placements <- nobs(est_q_static)

fwrite(
    data.table(
        statistic = c("price_effect_level", "price_effect_1994",
                      "avg_price_treated_pre", "price_effect_pct",
                      "price_effect_dose_level", "price_effect_hi_level",
                      "dose_binary_ratio", "placements_effect_dose_level",
                      "price_effect_idx", "price_effect_raw_level",
                      "price_effect_comp_level", "price_effect_raw_cmn_level",
                      "price_effect_raw_static",
                      "price_effect_raw_cmn_static", "price_effect_fw_static",
                      "price_effect_comp_static", "share_double_effect",
                      "price_effect_unwtd_static", "price_effect_single_level",
                      "price_effect_double_level", "price_effect_type_pool",
                      "n_index", "n_raw", "n_dropped_states",
                      "base_wt_single", "base_wt_double",
                      "idx_base_1993", "mean_price_single",
                      "mean_price_double", "price_ratio_double_single",
                      "placements_effect_level", "placements_effect_static",
                      "placements_effect_static_se", "n_placements"),
        value     = c(price_effect_level, price_effect_1994,
                      avg_price_treated_pre, price_effect_pct,
                      price_effect_dose_level, price_effect_hi_level,
                      dose_binary_ratio, placements_effect_dose_level,
                      price_effect_idx, price_effect_raw_level,
                      price_effect_comp_level, price_effect_raw_cmn_level,
                      price_effect_raw_static,
                      price_effect_raw_cmn_static, price_effect_fw_static,
                      price_effect_comp_static, share_double_effect,
                      price_effect_unwtd_static, price_effect_single_level,
                      price_effect_double_level, price_effect_type_pool,
                      dt[!is.na(avg_sales_price_fw), .N],
                      dt[!is.na(avg_sales_price), .N],
                      n_dropped_states,
                      base_wt_single, base_wt_double, idx_base_1993,
                      mean_price_single, mean_price_double,
                      price_ratio_double_single,
                      placements_effect_level, placements_effect_static,
                      placements_effect_static_se, n_placements)
    ),
    here("output", "results", "mhs-scalars.csv")
)

# Appendix table: state-level MH-stock-weighted wind zone intensity ----
dt_int <- readRDS(here("derived", "mhs-windzone-intensity.Rds"))
dt_int <- merge(dt_int, unique(dt[, .(statefp, state_name)]), by = "statefp")
dt_int <- dt_int[mh_stock_wz23 > 0]
setorder(dt_int, -treated_intensity)

dt_int_tab <- dt_int[, .(
    "State"                  = state_name,
    "MH stock (1980-2000)"   = formatC(mh_stock, format = "f", digits = 0, big.mark = ","),
    "MH stock in WZ II/III"  = formatC(mh_stock_wz23, format = "f", digits = 0, big.mark = ","),
    "Intensity"              = paste0(formatC(treated_intensity * 100, format = "f", digits = 1), "\\%")
)]

dir.create(here("output", "descriptives"), showWarnings = FALSE, recursive = TRUE)
kbl(
    dt_int_tab,
    format   = "latex",
    booktabs = TRUE,
    escape   = FALSE,
    align    = c("l", "r", "r", "r")
) |>
(\(x) writeLines(as.character(x), here("output", "descriptives", "windzone-intensity.tex")))()
