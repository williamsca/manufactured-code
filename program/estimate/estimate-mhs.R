# Estimate price effects of HUD code changes on manufactured homes
# Analyses: (1) TWFE event study for 1994 wind standard (DiD)
#           (2) Pre-post interrupted time series for energy, smoke alarm, NEC rules

rm(list = ls())
library(here)
library(data.table)
library(fixest)
library(ggplot2)
library(kableExtra)

# import ----

dt <- readRDS(here("derived", "sample-mhs.Rds"))
dt <- dt[between(year, 1988, 1999)]

# estimate ----
# prices in logs and levels
v_out_p <- grep("avg_sales_price", names(dt), value = TRUE)
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

est_p <- feols(fmla_p, data = dt, cluster = ~statefp)
est_q <- feols(fmla_q, data = dt, cluster = ~statefp)

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
est_p_dose <- feols(fmla_p_dose, data = dt, cluster = ~statefp)
etable(est_p_dose, digits = 3)

# Same substitution on the quantity side: does the placements event study
# also steepen under continuous intensity, or does it stay flat/null like
# the binary version?
fmla_q_dose <- as.formula(paste0(
    s_out_q, " ~ i(year, treated_intensity, ref = 1993) | statefp + year"
))
est_q_dose <- feols(fmla_q_dose, data = dt, cluster = ~statefp)
etable(est_q_dose, digits = 3)

# Binary spec, restricted to the three high-intensity treated states
# (FL, LA, MA) vs. the zone I controls, so any dilution from partially
# treated states (e.g. GA at 6% intensity) cannot attenuate the estimate.
dt_hi <- dt[high_intensity == TRUE | treated == FALSE]
est_p_hi <- feols(fmla_p, data = dt_hi, cluster = ~statefp)
etable(est_p_hi, digits = 3)

# Static (single-coefficient) comparison table: binary vs. continuous
# treatment, same outcome, same sample/FE/clustering, so the two columns
# differ only in how "treated" is coded. Collapses the event study's
# per-year interactions to one post-1994 coefficient, the same
# simplification `post_mh` makes for the NFIP claim spec.
dt[, post1994 := as.numeric(year >= 1994)]
dt[, post_treated      := post1994 * treated]
dt[, post_treated_dose := post1994 * treated_intensity]

fmla_static_bin  <- avg_sales_price ~ post_treated      | statefp + year
fmla_static_dose <- avg_sales_price ~ post_treated_dose | statefp + year

est_static_bin  <- feols(fmla_static_bin,  data = dt, cluster = ~statefp)
est_static_dose <- feols(fmla_static_dose, data = dt, cluster = ~statefp)

dict_static <- c(
    "post_treated"      = "Post 1994 x Treated",
    "post_treated_dose" = "Post 1994 x Treated",
    "avg_sales_price"   = "Average sales price (\\$)",
    "statefp"           = "State",
    "year"              = "Year"
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

# plots ----
v_palette <- c("#0072B2", "#D55E00", "#009E73", "#F0E442")

v_dict <- c(
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
    if (!is.null(outcome)) est <- est[lhs = outcome][[1]]
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
    yscale <- if (grepl("_ln$", out)) 1 else 1000
    plot_es(est_p, out, yscale = yscale,
            path = here("output", "event-study", paste0("es-mhs-", out, ".pdf")))
}

for (out in v_out_q) {
    plot_es(est_q, out,
            path = here("output", "event-study", paste0("es-mhs-", out, ".pdf")))
}

# Chunk C dose-response plots ----
plot_es(est_p_dose, "avg_sales_price", yscale = 1000,
        path = here("output", "event-study", "es-mhs-avg_sales_price-dose.pdf"))
plot_es(est_p_hi, "avg_sales_price", yscale = 1000,
        path = here("output", "event-study", "es-mhs-avg_sales_price-hi.pdf"))
plot_es(est_q_dose, "placements_ln",
        path = here("output", "event-study", "es-mhs-placements_ln-dose.pdf"))

# Export key scalars ----
dir.create(here("output", "results"), showWarnings = FALSE, recursive = TRUE)

ct_price <- as.data.table(
    coeftable(est_p[lhs = "avg_sales_price"][[1]]),
    keep.rownames = TRUE)
ct_price[, year := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]
ct_price <- ct_price[grepl(":treated$", rn)]

price_effect_level <- ct_price[year >= 1994, mean(Estimate) / 1000]
price_effect_1994  <- ct_price[year == 1994, Estimate / 1000]
avg_price_treated_pre <- dt[treated == TRUE & year < 1994,
    weighted.mean(avg_sales_price, placements, na.rm = TRUE) / 1000]
price_effect_pct <- price_effect_level / avg_price_treated_pre * 100

# Chunk C dose-response scalars ----
# `price_effect_dose_level` is the implied price effect of moving a state
# from 0% to 100% Zone II/III MH stock (fully comparable to
# `price_effect_level`'s binary treated/control contrast). A flat
# gradient (dose ~ binary) supports regional production standardization;
# a steep gradient (dose >> binary) means the true per-unit compliance
# cost is larger than the binary design implies.
ct_price_dose <- as.data.table(
    coeftable(est_p_dose[lhs = "avg_sales_price"][[1]]),
    keep.rownames = TRUE)
ct_price_dose[, year := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]
ct_price_dose <- ct_price_dose[grepl(":treated_intensity$", rn)]
price_effect_dose_level <- ct_price_dose[year >= 1994, mean(Estimate) / 1000]

ct_price_hi <- as.data.table(
    coeftable(est_p_hi[lhs = "avg_sales_price"][[1]]),
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
    coeftable(est_q_dose[lhs = "placements_ln"][[1]]),
    keep.rownames = TRUE)
ct_placements_dose[, year := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]
ct_placements_dose <- ct_placements_dose[grepl(":treated_intensity$", rn)]
placements_effect_dose_level <- ct_placements_dose[year >= 1994, mean(Estimate)]

fwrite(
    data.table(
        statistic = c("price_effect_level", "price_effect_1994",
                      "avg_price_treated_pre", "price_effect_pct",
                      "price_effect_dose_level", "price_effect_hi_level",
                      "dose_binary_ratio", "placements_effect_dose_level"),
        value     = c(price_effect_level, price_effect_1994,
                      avg_price_treated_pre, price_effect_pct,
                      price_effect_dose_level, price_effect_hi_level,
                      dose_binary_ratio, placements_effect_dose_level)
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
