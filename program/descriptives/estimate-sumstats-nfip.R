# Summary statistics: NFIP outcomes by MH vs site-built
#
# Inputs:  derived/nfip-balanced.Rds  (2009-2023, policy outcomes)
#          derived/nfip-claims.Rds    (1994-2023, claim outcomes)
# Output:  output/descriptives/sumstats-nfip.tex

rm(list = ls())
library(here)
library(data.table)
library(kableExtra)

source(here("program", "import", "project-params.R"))

# ── Panel A: balanced panel (2009–2023) ──────────────────────────────────────
dt <- readRDS(here("derived", "nfip-balanced.Rds"))

dt[, mh_lbl := fifelse(mh == 1, "MH", "Site-built")]

pol_stats <- dt[, .(
    policies_tot        = sum(policies_n, na.rm = TRUE),
    claims_tot            = sum(claims_n, na.rm = TRUE),
    elevated_share        = weighted.mean(elevated_share,
                                          policies_n, na.rm = TRUE),
    sfha_share            = weighted.mean(sfha_share,
                                          policies_n, na.rm = TRUE),
    primary_res_share     = weighted.mean(primary_res_share,
                                          policies_n, na.rm = TRUE),
    mandatory_purch_share = weighted.mean(mandatory_purchase_share,
                                          policies_n, na.rm = TRUE)
), by = .(mh_lbl)]
pol_stats[, claim_rate := claims_tot / policies_tot]
pol_stats$claims_tot <- NULL

# ── Panel B: claims data (1994–2023) ─────────────────────────────────────────
dt_claims <- readRDS(here("derived", "nfip-claims.Rds"))
dt_claims <- dt_claims[
    between(year_constr, MIN_YEAR_CONSTR, MAX_YEAR_CONSTR) &
        between(year_loss, MIN_YEAR_LOSS, MAX_YEAR_LOSS)
]

dt_claims[, mh_lbl := fifelse(mh == 1, "MH", "Site-built")]

claim_stats <- dt_claims[, .(
    total_claims     = .N,
    avg_bldg_damage  = mean(building_damage,  na.rm = TRUE),
    avg_cont_damage  = mean(contents_damage,  na.rm = TRUE)
), by = .(mh_lbl)]

# ── Reshape to wide (variable × housing type) ────────────────────────────────
col_order <- c("MH", "Site-built")

# Panel A wide
pol_long  <- melt(pol_stats,  id.vars = "mh_lbl")
pol_wide  <- dcast(pol_long,  variable ~ mh_lbl, value.var = "value")

# Panel B wide
claim_long <- melt(claim_stats, id.vars = "mh_lbl")
claim_wide <- dcast(claim_long, variable ~ mh_lbl, value.var = "value")

# ── Variable ordering and labels ─────────────────────────────────────────────
v_pol_vars <- c("total_policies", "claim_rate",
                "elevated_share", "sfha_share",
                "primary_res_share", "mandatory_purch_share")
v_pol_labels <- c(
    "Total policies",
    "Claim rate",
    "Elevated building (\\%)",
    "SFHA (\\%)",
    "Primary residence (\\%)",
    "Mandatory purchase (\\%)"
)

v_claim_vars <- c("total_claims", "avg_bldg_damage", "avg_cont_damage")
v_claim_labels <- c(
    "Total claims",
    "Building damage (\\$)",
    "Contents damage (\\$)"
)

pol_wide[,   variable := factor(variable, levels = v_pol_vars)]
claim_wide[, variable := factor(variable, levels = v_claim_vars)]
setorder(pol_wide,   variable)
setorder(claim_wide, variable)

# ── Format numbers ────────────────────────────────────────────────────────────
fmt_pol <- function(x, var) {
    if (var %in% c("claim_rate")) {
        formatC(x, format = "f", digits = 3)
    } else if (var %in% c("elevated_share", "sfha_share",
                           "primary_res_share", "mandatory_purch_share")) {
        formatC(x * 100, format = "f", digits = 1)
    } else {
        formatC(x, format = "f", digits = 0, big.mark = ",")
    }
}

fmt_claim <- function(x, var) {
    if (var %in% c("avg_bldg_damage", "avg_cont_damage")) {
        formatC(x, format = "f", digits = 0, big.mark = ",")
    } else {
        formatC(x, format = "f", digits = 0, big.mark = ",")
    }
}

format_panel <- function(dt_wide, v_vars, v_labels, fmt_fn) {
    dt_fmt <- copy(dt_wide)
    cols   <- col_order
    dt_fmt[, (cols) := lapply(.SD, as.character), .SDcols = cols]
    for (j in seq_along(v_vars)) {
        var <- v_vars[j]
        dt_fmt[variable == var,
               (cols) := lapply(.SD,
                   function(x) fmt_fn(as.numeric(x), var = var)),
               .SDcols = cols]
    }
    dt_fmt[, variable := v_labels]
    setnames(dt_fmt, "variable", "Variable")
    setcolorder(dt_fmt, c("Variable", col_order))
    dt_fmt
}

pol_fmt   <- format_panel(pol_wide,   v_pol_vars,   v_pol_labels,   fmt_pol)
claim_fmt <- format_panel(claim_wide, v_claim_vars, v_claim_labels, fmt_claim)

dt_all <- rbind(pol_fmt, claim_fmt)

# ── Build kable ───────────────────────────────────────────────────────────────
kbl(
    dt_all,
    format   = "latex",
    booktabs = TRUE,
    escape   = FALSE,
    col.names = c("Variable", "MH", "Site-built"),
    align    = c("l", "r", "r")
) |>
pack_rows("Policy outcomes (2009--2023)", 1, nrow(pol_fmt)) |>
pack_rows("Claim outcomes (1994--2023)",  nrow(pol_fmt) + 1, nrow(dt_all)) |>
(\(x) writeLines(
    as.character(x),
    here("output", "descriptives", "sumstats-nfip.tex")
))()

# Export scalars ----
dir.create(here("output", "results"), showWarnings = FALSE, recursive = TRUE)
fwrite(
    data.table(
        statistic = c(
            "policies_mh",            "policies_sb",
            "claim_rate_mh",          "claim_rate_sb",
            "avg_building_damage_mh", "avg_building_damage_sb",
            "avg_contents_damage_mh", "avg_contents_damage_sb",
            "total_claims_mh",        "total_claims_all",
            "mh_claim_share"
        ),
        value = c(
            pol_stats[mh_lbl == "MH",         policies_tot],
            pol_stats[mh_lbl == "Site-built",  policies_tot],
            pol_stats[mh_lbl == "MH",         claim_rate],
            pol_stats[mh_lbl == "Site-built",  claim_rate],
            claim_stats[mh_lbl == "MH",        avg_bldg_damage * 1000],
            claim_stats[mh_lbl == "Site-built", avg_bldg_damage * 1000],
            claim_stats[mh_lbl == "MH",        avg_cont_damage * 1000],
            claim_stats[mh_lbl == "Site-built", avg_cont_damage * 1000],
            claim_stats[mh_lbl == "MH",        total_claims],
            claim_stats[, sum(total_claims)],
            claim_stats[mh_lbl == "MH", total_claims] /
                claim_stats[, sum(total_claims)]
        )
    ),
    here("output", "results", "sumstats-nfip-scalars.csv")
)
