# Estimate price effects of HUD code changes on manufactured homes
# Analyses: (1) TWFE event study for 1994 wind standard (DiD)
#           (2) Pre-post interrupted time series for energy, smoke alarm, NEC rules

rm(list = ls())
library(here)
library(data.table)
library(fixest)
library(ggplot2)

data_path <- Sys.getenv("DATA_PATH")

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

# Export key scalars ----
dir.create(here("output", "results"), showWarnings = FALSE, recursive = TRUE)

ct_price <- as.data.table(
    coeftable(est_p[lhs = "avg_sales_price"][[1]]),
    keep.rownames = TRUE)
ct_price[, year := as.integer(regmatches(rn, regexpr("[0-9]{4}", rn)))]
ct_price <- ct_price[grepl(":treated$", rn)]

price_effect_level <- ct_price[year >= 1994, mean(Estimate / 1000)]
price_effect_1994  <- ct_price[year == 1994, Estimate / 1000]
avg_price_treated_pre <- dt[treated == TRUE & year < 1994,
    weighted.mean(avg_sales_price / 1000, placements, na.rm = TRUE)]
price_effect_pct <- price_effect_level / avg_price_treated_pre * 100

fwrite(
    data.table(
        statistic = c("price_effect_level", "price_effect_1994",
                      "avg_price_treated_pre", "price_effect_pct"),
        value     = c(price_effect_level, price_effect_1994,
                      avg_price_treated_pre, price_effect_pct)
    ),
    here("output", "results", "mhs-scalars.csv")
)
