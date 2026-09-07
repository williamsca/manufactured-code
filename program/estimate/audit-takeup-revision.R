# Reproduce the previous estimate and isolate the September 2026 corrections.
# Usage: Rscript program/estimate/audit-takeup-revision.R /path/to/before-stock.Rds
library(here)
library(data.table)
library(fixest)
source(here("program", "lib", "takeup-panel.R"))
source(here("program", "import", "project-params.R"))
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L, file.exists(args[1]))
old_stock <- readRDS(args[1])
stock <- readRDS(here("derived", "stock-county-vintage.Rds"))
raw <- readRDS(here("derived", "nfip-balanced.Rds"))
p <- raw[between(year_constr, MIN_YEAR_CONSTR, MAX_YEAR_CONSTR),
    .(countyfp, year_constr, mh, period_loss, policies_n,
      mandatory_purchase_policy_n, claims_n)]
rm(raw); gc()
periods <- sort(unique(p$period_loss))
old_claims <- p[policies_n > 0,
    .(claims_n = sum(claims_n)), by = .(countyfp, year_constr, mh, period_loss)]
cl <- readRDS(here("derived", "nfip-claims.Rds"))
cl[, period_loss := ((year_loss - 1994L) %/% 5L) * 5L + 1994L]
cl <- cl[period_loss %in% periods & between(year_constr, MIN_YEAR_CONSTR, MAX_YEAR_CONSTR),
    .(claims_n = .N), by = .(countyfp, year_constr, mh, period_loss)]
occupied <- copy(stock)
occupied[, homes_n := homes_occupied_n]
panels <- list(
    "Previous construction" = build_takeup_panel(p, old_claims, old_stock, periods)[policies_n > 0],
    "Single-family stock; positive-policy cells" = build_takeup_panel(p, old_claims, occupied, periods)[policies_n > 0],
    "Single-family stock; full stock grid" = build_takeup_panel(p, cl, occupied, periods),
    "Full grid plus vacancy adjustment" = build_takeup_panel(p, cl, stock, periods)
)
result <- rbindlist(lapply(names(panels), function(stage) {
    d <- panels[[stage]]
    rbindlist(lapply(c("Policies per home", "Claims per home", "Claims per policy"), function(margin) {
        lhs <- if (margin == "Policies per home") "policies_n" else "claims_n"
        offset <- if (margin == "Claims per policy") "log_policy_yrs" else "log_home_yrs"
        e <- fepois(as.formula(paste0(lhs, " ~ post_mh | geo^period_loss + mh + post1994")),
            data = if (margin == "Claims per policy") d[policies_n > 0] else d,
            offset = as.formula(paste0("~", offset)), cluster = ~statefp)
        b <- coef(e)[["post_mh"]]; se <- se(e)[["post_mh"]]
        data.table(stage, margin, estimate = b, se, pct = 100 * expm1(b),
            lo_pct = 100 * expm1(b - 1.96 * se), hi_pct = 100 * expm1(b + 1.96 * se),
            n = nobs(e), input_cells = nrow(d), zero_policy_cells = sum(d$policies_n == 0),
            policies = sum(d$policies_n), claims = sum(d$claims_n))
    }))
}))
fwrite(result, here("output", "results", "takeup-revision.csv"))
print(result[, .(stage, margin, estimate, se, pct, lo_pct, hi_pct, n)])
# Keep the vintage profile reviewable alongside the static comparison.
ref_period <- 1992L
dynamics <- rbindlist(lapply(names(panels), function(stage) {
    d <- panels[[stage]]
    e <- fepois(policies_n ~ i(period_constr, mh, ref = ref_period) |
                    geo^period_loss + mh + period_constr,
                data = d, offset = ~log_home_yrs, cluster = ~statefp)
    ct <- as.data.table(coeftable(e), keep.rownames = "term")
    ct[, stage := stage]
    ct
}))
fwrite(dynamics, here("output", "results", "takeup-revision-vintages.csv"))
