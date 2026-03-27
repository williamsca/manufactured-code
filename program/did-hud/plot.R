# Plot HUD code change analyses
# Inputs: derived/did-hud-results.Rds, derived/did-hud-data.Rds

rm(list = ls())
library(here)
library(data.table)
library(ggplot2)
library(fixest)
library(scales)

v_palette <- c("#0072B2", "#D55E00", "#009E73", "#F0E442", "#CC79A7", "#595959")

theme_paper <- function(base_size = 14) {
    theme_classic(base_size = base_size) +
        theme(
            text = element_text(family = "serif"),
            legend.position = "bottom",
            panel.grid.major.y = element_line(color = "gray90"),
            panel.grid.minor   = element_blank()
        )
}

# Regulatory events to mark on national plots
reg_events <- data.table(
    year  = c(1994, 1994, 2002, 2006),
    label = c("Wind zones", "Energy Uo", "Smoke alarms", "NEC/AFCI"),
    nudge = c(-0.4, 0.4, 0, 0)    # horizontal nudge for overlapping 1994 labels
)

# Import ----
res  <- readRDS(here("derived", "did-hud-results.Rds"))
data <- readRDS(here("derived", "did-hud-data.Rds"))
dt_nat <- data$dt_nat
dt_st  <- data$dt_st
dt_did <- data$dt_did

# Helper: extract event study coefficients from fixest i() model ----
extract_es <- function(mod, treatment_var = "treated") {
    ct  <- as.data.table(coeftable(mod), keep.rownames = "term")
    setnames(ct, c("term", "estimate", "se", "tstat", "pval"))
    ct  <- ct[grep("^event_time", term)]
    ct[, event_time := as.integer(sub(
        paste0("event_time::([-0-9]+):", treatment_var), "\\1", term
    ))]
    # Add the omitted reference period (event_time = -1, estimate = 0)
    ct <- rbind(
        ct,
        data.table(term = "ref", estimate = 0, se = 0,
                   tstat = NA_real_, pval = NA_real_, event_time = -1L)
    )
    setorder(ct, event_time)
    ct[, ci_lo := estimate - 1.96 * se]
    ct[, ci_hi := estimate + 1.96 * se]
    ct[]
}

# Plot 1: national real price time series with regulatory markers ----
dt_prices <- dt_nat[!is.na(real_price) & year %between% c(1980, 2013)]

p_nat_prices <- ggplot(dt_prices, aes(x = year, y = real_price)) +
    geom_vline(
        data = reg_events,
        aes(xintercept = year),
        linetype = "dashed", color = "gray60", linewidth = 0.4
    ) +
    geom_line(linewidth = 0.8, color = v_palette[1]) +
    geom_text(
        data = reg_events,
        aes(x = year + nudge, y = Inf, label = label),
        hjust = 0.5, vjust = 1.4, size = 3, family = "serif", color = "gray40"
    ) +
    scale_y_continuous(labels = dollar_format(scale = 1e-3, suffix = "k")) +
    labs(x = NULL, y = "Average sales price (2000 dollars)") +
    theme_paper()

ggsave(
    here("output", "did-hud", "did_hud_nat_prices.pdf"),
    p_nat_prices, width = 9, height = 5
)

# Plot 2: national TFP alongside real price (normalized to 1990 = 1) ----
base_yr <- 1990
dt_index <- dt_nat[
    !is.na(real_price) & !is.na(tfp4_nberces) & year %between% c(1980, 2013)
]
base_price <- dt_index[year == base_yr, real_price]
base_tfp   <- dt_index[year == base_yr, tfp4_nberces]
dt_index[, price_idx := real_price     / base_price]
dt_index[, tfp_idx   := tfp4_nberces   / base_tfp]

dt_index_long <- melt(
    dt_index[, .(year, price_idx, tfp_idx)],
    id.vars      = "year",
    variable.name = "series",
    value.name    = "value"
)
index_labels <- c(price_idx = "Real MH price", tfp_idx = "TFP index (NBER-CES)")

p_nat_index <- ggplot(dt_index_long, aes(x = year, y = value, color = series, shape = series)) +
    geom_vline(
        data = reg_events,
        aes(xintercept = year),
        linetype = "dashed", color = "gray60", linewidth = 0.4
    ) +
    geom_hline(yintercept = 1, color = "gray80") +
    geom_line(linewidth = 0.5, linetype = "dashed") +
    geom_point(size = 2) +
    scale_color_manual(
        values = setNames(v_palette[1:2], names(index_labels)),
        labels = unname(index_labels)
    ) +
    scale_shape_manual(
        values = setNames(c(16, 17), names(index_labels)),
        labels = unname(index_labels)
    ) +
    labs(
        x = NULL,
        y = paste0("Index (", base_yr, " = 1)"),
        color = NULL, shape = NULL
    ) +
    theme_paper()

ggsave(
    here("output", "did-hud", "did_hud_nat_index.pdf"),
    p_nat_index, width = 9, height = 5
)

# Plot 3: average real price by treatment group, 1988-2002 ----
dt_zone <- dt_st[
    year %between% c(1988, 2002) & !is.na(real_price) & state_name != "Alaska"
]

# Placement-weighted mean by group and year
dt_zone_agg <- dt_zone[
    !is.na(placements),
    .(avg_price = weighted.mean(real_price, placements, na.rm = TRUE)),
    by = .(year, treated)
][order(year, treated)]
dt_zone_agg[, group := ifelse(treated, "Zone II/III (treated)", "Zone I (control)")]

p_zone_prices <- ggplot(
    dt_zone_agg,
    aes(x = year, y = avg_price, color = group, shape = group)
) +
    geom_vline(xintercept = 1994, linetype = "dashed", color = "gray60", linewidth = 0.4) +
    annotate("text", x = 1994.2, y = Inf, label = "Rule effective",
             hjust = 0, vjust = 1.4, size = 3, family = "serif", color = "gray40") +
    geom_line(linewidth = 0.5, linetype = "dashed") +
    geom_point(size = 2.5) +
    scale_color_manual(values = setNames(v_palette[1:2], c("Zone II/III (treated)", "Zone I (control)"))) +
    scale_shape_manual(values = setNames(c(16, 17), c("Zone II/III (treated)", "Zone I (control)"))) +
    scale_y_continuous(labels = dollar_format(scale = 1e-3, suffix = "k")) +
    labs(
        x = NULL,
        y = "Placement-weighted avg price (2000 dollars)",
        color = NULL, shape = NULL
    ) +
    theme_paper()

ggsave(
    here("output", "did-hud", "did_hud_zone_prices.pdf"),
    p_zone_prices, width = 9, height = 5
)

# Plot 4: treated-control price gap over time ----
dt_gap <- dcast(dt_zone_agg, year ~ treated, value.var = "avg_price")
setnames(dt_gap, c("year", "control", "treated"))
dt_gap[, gap := treated - control]

p_gap <- ggplot(dt_gap, aes(x = year, y = gap)) +
    geom_vline(xintercept = 1994, linetype = "dashed", color = "gray60", linewidth = 0.4) +
    geom_hline(yintercept = 0, color = "gray80") +
    geom_line(linewidth = 0.8, color = v_palette[1]) +
    geom_point(size = 2.5, color = v_palette[1]) +
    scale_y_continuous(labels = dollar_format(scale = 1e-3, suffix = "k")) +
    labs(
        x = NULL,
        y = "Treated minus control avg price (2000 dollars)"
    ) +
    theme_paper()

ggsave(
    here("output", "did-hud", "did_hud_gap.pdf"),
    p_gap, width = 9, height = 5
)

# Plot 5: event study — baseline ----
es_dt <- extract_es(res$es_baseline)

p_es <- ggplot(es_dt, aes(x = event_time, y = estimate)) +
    geom_vline(xintercept = -0.5, linetype = "dashed", color = "gray60", linewidth = 0.4) +
    geom_hline(yintercept = 0, color = "gray80") +
    geom_ribbon(aes(ymin = ci_lo, ymax = ci_hi), alpha = 0.15, fill = v_palette[1]) +
    geom_line(linewidth = 0.7, color = v_palette[1]) +
    geom_point(size = 2.5, color = v_palette[1]) +
    scale_x_continuous(
        breaks = seq(min(es_dt$event_time), max(es_dt$event_time), by = 2),
        labels = function(x) ifelse(x == 0, "1994", as.character(x))
    ) +
    labs(
        x     = "Years relative to 1994 rule",
        y     = "Log price difference (treated vs. control)"
    ) +
    theme_paper()

ggsave(
    here("output", "did-hud", "did_hud_es.pdf"),
    p_es, width = 9, height = 5
)

# Plot 6: event study by section type (single- vs double-wide) ----
es_sw_dt <- extract_es(res$es_sw)[, type := "Single-wide"]
es_dw_dt <- extract_es(res$es_dw)[, type := "Double-wide"]
es_type  <- rbind(es_sw_dt, es_dw_dt)

p_es_type <- ggplot(es_type, aes(x = event_time, y = estimate, color = type, fill = type)) +
    geom_vline(xintercept = -0.5, linetype = "dashed", color = "gray60", linewidth = 0.4) +
    geom_hline(yintercept = 0, color = "gray80") +
    geom_ribbon(aes(ymin = ci_lo, ymax = ci_hi), alpha = 0.12, color = NA) +
    geom_line(linewidth = 0.6, linetype = "dashed") +
    geom_point(size = 2) +
    scale_color_manual(values = setNames(v_palette[1:2], c("Single-wide", "Double-wide"))) +
    scale_fill_manual(values  = setNames(v_palette[1:2], c("Single-wide", "Double-wide"))) +
    scale_x_continuous(
        breaks = seq(min(es_type$event_time), max(es_type$event_time), by = 2),
        labels = function(x) ifelse(x == 0, "1994", as.character(x))
    ) +
    labs(
        x = "Years relative to 1994 rule",
        y = "Log price difference (treated vs. control)",
        color = NULL, fill = NULL
    ) +
    theme_paper()

ggsave(
    here("output", "did-hud", "did_hud_es_type.pdf"),
    p_es_type, width = 9, height = 5
)

# Plot 7: pre-post interrupted time series for smoke alarm and NEC rules ----
# (Excludes energy rule since it is contemporaneous with the wind DiD)
prepost_plot_events <- list(
    smoke = res$events$smoke,
    nec   = res$events$nec
)

plots_prepost <- lapply(names(prepost_plot_events), function(nm) {
    ev  <- prepost_plot_events[[nm]]
    mod <- res$prepost[[nm]]

    sub <- dt_nat[year %between% ev$window & !is.na(log_price)]
    sub[, post  := as.integer(year >= ev$year)]
    sub[, trend := year - ev$year]
    sub[, fitted := predict(mod, newdata = sub)]

    ggplot(sub, aes(x = year)) +
        geom_vline(xintercept = ev$year, linetype = "dashed",
                   color = "gray60", linewidth = 0.4) +
        geom_point(aes(y = log_price), size = 2.5, color = v_palette[1]) +
        geom_line(aes(y = fitted, group = post), linewidth = 0.8, color = v_palette[2]) +
        labs(
            x = NULL,
            y = "Log real price",
            title = ev$label
        ) +
        theme_paper() +
        theme(plot.title = element_text(size = 12))
})

# Combine into one figure (two panels)
library(patchwork)
p_prepost <- plots_prepost[[1]] + plots_prepost[[2]] +
    plot_layout(ncol = 2)

ggsave(
    here("output", "did-hud", "did_hud_prepost.pdf"),
    p_prepost, width = 12, height = 5
)
