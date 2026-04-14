# Summary statistics: NFIP outcomes by pre/post-1994 × MH
#
# Inputs:  derived/nfip-balanced.Rds
# Outputs: tables/sumstats-nfip.tex

rm(list = ls())
library(here)
library(data.table)
library(kableExtra)

# import ----
dt <- readRDS(here("derived", "nfip-balanced.Rds"))

dt[, mh_lbl     := fifelse(mh == 1, "MH", "Site-built")]
dt[, period_lbl := fifelse(post1994 == 1, "Post-1994", "Pre-1994")]

# aggregate to cell-level weighted means ----
# use claims_n as weight for per-claim averages and policies_n for per-policy averages

summarize_cell <- function(d) {
    list(
        avg_bldg_damage      = weighted.mean(d$building_damage_pclaim, d$claims_n,
                                              na.rm = TRUE),
        avg_cont_damage      = weighted.mean(d$contents_damage_pclaim, d$claims_n,
                                              na.rm = TRUE),
        avg_bldg_coverage    = weighted.mean(d$building_policy_covg_ppol, d$policies_n,
                                              na.rm = TRUE),
        total_claims         = sum(d$claims_n,   na.rm = TRUE),
        total_policies       = sum(d$policies_n, na.rm = TRUE),
        elevated_share       = weighted.mean(d$elevated_share,           d$policies_n,
                                              na.rm = TRUE),
        sfha_share           = weighted.mean(d$sfha_share,               d$policies_n,
                                              na.rm = TRUE),
        primary_res_share    = weighted.mean(d$primary_res_share,        d$policies_n,
                                              na.rm = TRUE),
        mandatory_purch_share = weighted.mean(d$mandatory_purchase_share, d$policies_n,
                                              na.rm = TRUE)
    )
}

groups <- dt[, summarize_cell(.SD),
             by = .(period_lbl, mh_lbl),
             .SDcols = c("building_damage_pclaim", "contents_damage_pclaim",
                         "building_policy_covg_ppol", "claims_n", "policies_n",
                         "elevated_share", "sfha_share",
                         "primary_res_share", "mandatory_purchase_share")]

# reshape: one row per variable, one column per group ----
groups[, group := paste(period_lbl, mh_lbl, sep = " / ")]

# ordered column sequence
col_order <- c(
    "Pre-1994 / MH", "Pre-1994 / Site-built",
    "Post-1994 / MH", "Post-1994 / Site-built"
)

groups[, group := factor(group, levels = col_order)]
setorder(groups, group)

v_vars <- c("avg_bldg_damage", "avg_cont_damage", "avg_bldg_coverage",
            "total_claims", "total_policies",
            "elevated_share", "sfha_share",
            "primary_res_share", "mandatory_purch_share")
v_labels <- c(
    "Avg. building damage (\\$)",
    "Avg. contents damage (\\$)",
    "Avg. building coverage (\\$)",
    "Total claims",
    "Total policies",
    "Elevated building (\\%)",
    "SFHA (\\%)",
    "Primary residence (\\%)",
    "Mandatory purchase (\\%)"
)

# wide format: variables in rows, groups in columns
dt_wide <- dcast(
    melt(groups, id.vars = "group", measure.vars = v_vars),
    variable ~ group,
    value.var = "value"
)
dt_wide[, variable := factor(variable, levels = v_vars)]
setorder(dt_wide, variable)

# format numbers
fmt_row <- function(x, var) {
    if (var %in% c("avg_bldg_damage", "avg_cont_damage", "avg_bldg_coverage")) {
        formatC(x, format = "f", digits = 0, big.mark = ",")
    } else if (var %in% c("elevated_share", "sfha_share",
                           "primary_res_share", "mandatory_purch_share")) {
        formatC(x * 100, format = "f", digits = 1)
    } else {
        formatC(x, format = "f", digits = 0, big.mark = ",")
    }
}

dt_fmt <- copy(dt_wide)
cols_to_fmt <- setdiff(names(dt_fmt), "variable")

# convert to character first so row-by-row assignment doesn't coerce to NA
dt_fmt[, (cols_to_fmt) := lapply(.SD, as.character), .SDcols = cols_to_fmt]

for (j in seq_along(v_vars)) {
    var <- v_vars[j]
    dt_fmt[variable == var,
           (cols_to_fmt) := lapply(.SD, function(x) fmt_row(as.numeric(x), var = var)),
           .SDcols = cols_to_fmt]
}

dt_fmt[, variable := v_labels]
setnames(dt_fmt, "variable", "Variable")

# ensure column order matches col_order
setcolorder(dt_fmt, c("Variable", col_order))

# build kable ----
kbl(
    dt_fmt,
    format    = "latex",
    booktabs  = TRUE,
    escape    = FALSE,
    col.names = c("Variable", rep("", 4)),
    align = c("l", rep("r", 4))
) |>
add_header_above(c(
    " "           = 1,
    "MH"          = 1,
    "Site-built"  = 1,
    "MH"          = 1,
    "Site-built"  = 1
)) |>
add_header_above(c(
    " "         = 1,
    "Pre-1994"  = 2,
    "Post-1994" = 2
)) |>
(\(x) writeLines(as.character(x), here("output", "descriptives", "sumstats-nfip.tex")))()
