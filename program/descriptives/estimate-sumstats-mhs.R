# Summary statistics: MH prices and shipments by wind zone treatment status
#
# Inputs:  derived/sample-mhs.Rds
# Outputs: output/descriptives/sumstats-mhs.tex

rm(list = ls())
library(here)
library(data.table)
library(kableExtra)

# import ----
dt <- readRDS(here("derived", "sample-mhs.Rds"))

dt[, treat_lbl := fifelse(treated, "Wind Zones II/III", "Wind Zone I")]

# aggregate to group-level weighted means and totals ----
wt_mean <- function(x, w) {
    keep <- !is.na(x) & !is.na(w) & w > 0
    if (!any(keep)) return(NA_real_)
    sum(x[keep] * w[keep]) / sum(w[keep])
}

summarize_cell <- function(d) {
    list(
        avg_price        = wt_mean(d$avg_sales_price,        d$placements),
        avg_price_single = wt_mean(d$avg_sales_price_single, d$placements_single),
        avg_price_double = wt_mean(d$avg_sales_price_double, d$placements_double),
        total_placements        = sum(d$placements,        na.rm = TRUE),
        total_placements_single = sum(d$placements_single, na.rm = TRUE),
        total_placements_double = sum(d$placements_double, na.rm = TRUE)
    )
}

groups <- dt[, summarize_cell(.SD), by = treat_lbl,
             .SDcols = c("avg_sales_price", "avg_sales_price_single", "avg_sales_price_double",
                         "placements", "placements_single", "placements_double")]

# reshape: variables in rows, treatment groups in columns ----
col_order <- c("Wind Zone I", "Wind Zones II/III")
groups[, treat_lbl := factor(treat_lbl, levels = col_order)]
setorder(groups, treat_lbl)

v_vars <- c("avg_price", "avg_price_single", "avg_price_double",
            "total_placements", "total_placements_single", "total_placements_double")

v_labels <- c(
    "Avg. sales price (\\$)",
    "Avg. sales price, single-wide (\\$)",
    "Avg. sales price, double-wide (\\$)",
    "Total placements",
    "Total placements, single-wide",
    "Total placements, double-wide"
)

dt_wide <- dcast(
    melt(groups, id.vars = "treat_lbl", measure.vars = v_vars),
    variable ~ treat_lbl,
    value.var = "value"
)
dt_wide[, variable := factor(variable, levels = v_vars)]
setorder(dt_wide, variable)

# format numbers ----
fmt_val <- function(x, var) {
    if (grepl("^avg_price", var)) {
        formatC(x, format = "f", digits = 0, big.mark = ",")
    } else {
        formatC(x, format = "f", digits = 0, big.mark = ",")
    }
}

dt_fmt <- copy(dt_wide)
cols_to_fmt <- setdiff(names(dt_fmt), "variable")
dt_fmt[, (cols_to_fmt) := lapply(.SD, as.character), .SDcols = cols_to_fmt]

for (j in seq_along(v_vars)) {
    var <- v_vars[j]
    dt_fmt[variable == var,
           (cols_to_fmt) := lapply(.SD, function(x) fmt_val(as.numeric(x), var = var)),
           .SDcols = cols_to_fmt]
}

dt_fmt[, variable := v_labels]
setnames(dt_fmt, "variable", "Variable")
setcolorder(dt_fmt, c("Variable", col_order))

# build kable ----
dir.create(here("output", "descriptives"), showWarnings = FALSE, recursive = TRUE)

kbl(
    dt_fmt,
    format   = "latex",
    booktabs = TRUE,
    escape   = FALSE,
    col.names = c("Variable", col_order),
    align    = c("l", "r", "r")
) |>
(\(x) writeLines(as.character(x), here("output", "descriptives", "sumstats-mhs.tex")))()
