# NFIP summary statistics by housing type and pre/post-1994 construction.
# Inputs: derived/nfip-balanced.Rds, nfip-claims.Rds, stock-county-vintage.Rds
# Outputs: output/descriptives/sumstats-nfip.tex,
#          output/results/sumstats-nfip-scalars.csv

rm(list = ls())
library(here)
library(data.table)
library(kableExtra)
source(here("program", "import", "project-params.R"))

in_window <- function(year) {
    between(year, MIN_YEAR_CONSTR, MAX_YEAR_CONSTR) & year != 1994L
}
tag_groups <- function(d) {
    d[, housing_type := fifelse(mh == 1L, "Manufactured", "Site-built")]
    d[, vintage := fifelse(year_constr < 1994L, "Pre-1994", "Post-1994")]
    d[, group := paste(housing_type, vintage)]
    d
}

# Sum stock from its county-level source, never from the tract-level panel
# where the same county stock is repeated across tracts and calendar periods.
stock <- readRDS(here("derived", "stock-county-vintage.Rds"))
stopifnot(uniqueN(stock, by = c("countyfp", "year_constr", "mh")) == nrow(stock),
          !anyNA(stock$homes_n), all(stock$homes_n >= 0))
stock <- tag_groups(stock[in_window(year_constr)])
stock_stats <- stock[, .(homes_tot = sum(homes_n)), by = group]

dt <- readRDS(here("derived", "nfip-balanced.Rds"))
dt <- tag_groups(dt[in_window(year_constr) & period_loss %in% c(2009L, 2014L, 2019L)])
policy_summary <- function(d, groups) {
    ans <- d[, .(
        policies_tot = sum(policies_n, na.rm = TRUE),
        claims_tot = sum(claims_n, na.rm = TRUE),
        elevated_share = sum(elevated_policy_n, na.rm = TRUE) / sum(policies_n),
        sfha_share = sum(sfha_policy_n, na.rm = TRUE) / sum(policies_n),
        primary_res_share = sum(primary_res_policy_n, na.rm = TRUE) / sum(policies_n),
        mandatory_purch_share = sum(mandatory_purchase_policy_n, na.rm = TRUE) / sum(policies_n)
    ), by = groups]
    ans[, claim_rate := claims_tot / policies_tot]
    ans
}
pol_stats <- policy_summary(dt, "group")
pol_stats <- merge(pol_stats, stock_stats, by = "group", all.x = TRUE)
stopifnot(!anyNA(pol_stats$homes_tot), all(pol_stats$homes_tot > 0))
# Average annual policy terms over all 15 years, divided by group-matched
# stock. The Census 2000 stock is fixed, not observed annually.
pol_stats[, policies_per_1k_homes := 1000 * policies_tot / (15 * homes_tot)]

dt_claims <- readRDS(here("derived", "nfip-claims.Rds"))
dt_claims <- tag_groups(dt_claims[
    in_window(year_constr) & between(year_loss, MIN_YEAR_LOSS, MAX_YEAR_LOSS)
])
dt_claims[, damage_pct := fifelse(
    is.finite(building_value) & building_value > 0 & is.finite(building_damage),
    100 * building_damage / building_value, NA_real_
)]
claim_summary <- function(d, groups) {
    d[, .(
        total_claims = .N,
        avg_bldg_damage = mean(building_damage, na.rm = TRUE),
        avg_cont_damage = mean(contents_damage, na.rm = TRUE),
        avg_bldg_payment = mean(net_building_pmt, na.rm = TRUE),
        avg_cont_payment = mean(net_contents_pmt, na.rm = TRUE),
        median_bldg_value = median(building_value[is.finite(building_value) & building_value > 0], na.rm = TRUE),
        avg_damage_pct = mean(damage_pct, na.rm = TRUE),
        valid_damage_pct_n = sum(!is.na(damage_pct))
    ), by = groups]
}
claim_stats <- claim_summary(dt_claims, "group")

col_order <- c("Manufactured Pre-1994", "Manufactured Post-1994",
               "Site-built Pre-1994", "Site-built Post-1994")
v_pol_vars <- c("policies_per_1k_homes", "claim_rate", "elevated_share",
                "sfha_share", "primary_res_share", "mandatory_purch_share",
                "policies_tot")
v_pol_labels <- c("Policies per 1,000 homes", "Claims per policy-year",
                  "Elevated building", "SFHA", "Primary residence",
                  "Mandatory purchase", "N (policy-years)")
v_claim_vars <- c("avg_bldg_damage", "avg_cont_damage", "avg_bldg_payment",
                  "avg_cont_payment", "median_bldg_value", "avg_damage_pct",
                  "valid_damage_pct_n", "total_claims")
v_claim_labels <- c("Building damage", "Contents damage", "Building payment",
                    "Contents payment", "Median building value",
                    "Building damage / building value (\\%)",
                    "N (damage / value)", "N (claims)")

format_panel <- function(stats, vars, labels) {
    numeric_stats <- copy(stats)
    numeric_stats[, (vars) := lapply(.SD, as.numeric), .SDcols = vars]
    long <- melt(numeric_stats, id.vars = "group", measure.vars = vars)
    wide <- dcast(long, variable ~ group, value.var = "value")
    wide <- wide[match(vars, variable)]
    stopifnot(!anyNA(wide$variable), all(col_order %in% names(wide)))
    wide[, (col_order) := lapply(.SD, as.character), .SDcols = col_order]
    for (j in seq_along(vars)) {
        var <- vars[j]
        is_share <- grepl("_share$", var)
        digits <- if (var == "claim_rate") 3L else if (grepl("_tot$|_n$|^total_", var)) 0L else 1L
        for (col in col_order) {
            value <- as.numeric(wide[[col]][j]) * if (is_share) 100 else 1
            set(wide, i = j, j = col, value = if (is.finite(value)) {
                formatC(value, format = "f", digits = digits, big.mark = ",")
            } else "---")
        }
    }
    wide[, variable := labels]
    setcolorder(wide, c("variable", col_order))
    wide
}
pol_fmt <- format_panel(pol_stats, v_pol_vars, v_pol_labels)
claim_fmt <- format_panel(claim_stats, v_claim_vars, v_claim_labels)

# Put shared units on their own line, preserving just two labeled panels.
unit_row <- function(label) {
    as.data.table(as.list(setNames(c(paste0("\\emph{", label, "}"), rep("", 4)),
                                  names(pol_fmt))))
}
pol_fmt <- rbind(pol_fmt[1:2], unit_row("Shares (\\%)"), pol_fmt[3:7])
claim_fmt <- rbind(unit_row("Thousands of 2000 dollars"), claim_fmt)
dt_all <- rbind(pol_fmt, claim_fmt)
dir.create(here("output", "descriptives"), showWarnings = FALSE, recursive = TRUE)
kbl(dt_all, format = "latex", booktabs = TRUE, escape = FALSE,
    col.names = c("", rep(c("Pre-1994", "Post-1994"), 2)),
    align = c("l", rep("r", 4))) |>
    add_header_above(c(" " = 1, "Manufactured" = 2, "Site-built" = 2)) |>
    pack_rows("Policies", 1, nrow(pol_fmt)) |>
    pack_rows("Claims", nrow(pol_fmt) + 1, nrow(dt_all)) |>
    (\(x) writeLines(as.character(x),
                    here("output", "descriptives", "sumstats-nfip.tex")))()

# Preserve pooled scalar names consumed by the paper, using the table sample.
pol_pooled <- policy_summary(dt, "housing_type")
claim_pooled <- claim_summary(dt_claims, "housing_type")
dir.create(here("output", "results"), showWarnings = FALSE, recursive = TRUE)
fwrite(data.table(
    statistic = c("policies_mh", "policies_sb", "claim_rate_mh", "claim_rate_sb",
                  "avg_building_damage_mh", "avg_building_damage_sb",
                  "avg_contents_damage_mh", "avg_contents_damage_sb",
                  "total_claims_mh", "total_claims_all", "mh_claim_share"),
    value = c(pol_pooled[housing_type == "Manufactured", policies_tot],
              pol_pooled[housing_type == "Site-built", policies_tot],
              pol_pooled[housing_type == "Manufactured", claim_rate],
              pol_pooled[housing_type == "Site-built", claim_rate],
              claim_pooled[housing_type == "Manufactured", avg_bldg_damage * 1000],
              claim_pooled[housing_type == "Site-built", avg_bldg_damage * 1000],
              claim_pooled[housing_type == "Manufactured", avg_cont_damage * 1000],
              claim_pooled[housing_type == "Site-built", avg_cont_damage * 1000],
              claim_pooled[housing_type == "Manufactured", total_claims],
              sum(claim_pooled$total_claims),
              claim_pooled[housing_type == "Manufactured", total_claims] /
                  sum(claim_pooled$total_claims))
), here("output", "results", "sumstats-nfip-scalars.csv"))
