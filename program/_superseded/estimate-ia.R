# Estimate IA damage differences for MH in HUD wind-zone counties
#
# The IA registrations do not report construction year.  The main coefficient
# is therefore an indicator design: MH registrations in Zone II/III counties
# relative to site-built registrations in the same county-disaster and relative
# to the national MH-site-built gap in the same disaster.

# THESE RESULTS HAVE BEEN SUPERSEDED BECAUSE
# - the data do *not* indicate a construction year,
# so the vintage dimension of the analysis is lost; and
# - the panel begins long after the 1994 HUD code reform,
# so there is no 'pre' period for a DiD design on treated and untreated
# counties.



rm(list = ls())
library(here)
library(DBI)
library(duckdb)
library(data.table)
library(fixest)
library(ggplot2)

ia_path <- here("derived", "ia-registrations.parquet")
if (!file.exists(ia_path)) {
    stop("Missing ", ia_path, ". Run program/import/databuild-ia.R first.")
}

q <- function(db, x) as.character(dbQuoteString(db, x))

db <- dbConnect(duckdb::duckdb(), dbdir = ":memory:")
on.exit(dbDisconnect(db, shutdown = TRUE), add = TRUE)

read_ia_cells <- function(owner_only = FALSE) {
    where_owner <- if (owner_only) "where own_rent = 'O'" else ""

    sql <- sprintf("
        select
            countyfp,
            disaster_number,
            year_declared,
            incident_type,
            mh,
            treated,
            treated_wz3,
            wind_zone,
            count(*)::integer as n,
            avg(ihp_amount) as ihp_amount,
            avg(fip_amount) as fip_amount,
            avg(ha_amount) as ha_amount,
            avg(ona_amount) as ona_amount,
            avg(rpfvl) as rpfvl,
            avg(ppfvl) as ppfvl,
            avg(flood_damage_amount) as flood_damage_amount,
            avg(foundation_damage_amount) as foundation_damage_amount,
            avg(roof_damage_amount) as roof_damage_amount,
            avg(rental_assistance_amount) as rental_assistance_amount,
            avg(repair_amount) as repair_amount,
            avg(replacement_amount) as replacement_amount,
            avg(personal_property_amount) as personal_property_amount,
            avg(unmet_need_rp) as unmet_need_rp,
            avg(unmet_need_pp) as unmet_need_pp,
            avg(case when ihp_eligible then 1.0 else 0.0 end) as ihp_eligible,
            avg(case when ha_eligible then 1.0 else 0.0 end) as ha_eligible,
            avg(case when ona_eligible then 1.0 else 0.0 end) as ona_eligible,
            avg(case when utilities_out then 1.0 else 0.0 end) as utilities_out,
            avg(case when home_damage then 1.0 else 0.0 end) as home_damage,
            avg(case when auto_damage then 1.0 else 0.0 end) as auto_damage,
            avg(case when emergency_needs then 1.0 else 0.0 end) as emergency_needs,
            avg(case when food_need then 1.0 else 0.0 end) as food_need,
            avg(case when shelter_need then 1.0 else 0.0 end) as shelter_need,
            avg(case when access_functional_needs then 1.0 else 0.0 end) as access_functional_needs,
            avg(case when sba_approved then 1.0 else 0.0 end) as sba_approved,
            avg(case when inspection_issued then 1.0 else 0.0 end) as inspection_issued,
            avg(case when inspection_returned then 1.0 else 0.0 end) as inspection_returned,
            avg(case when habitability_repairs_required then 1.0 else 0.0 end) as habitability_repairs_required,
            avg(case when destroyed then 1.0 else 0.0 end) as destroyed,
            avg(case when flood_damage then 1.0 else 0.0 end) as flood_damage,
            avg(case when foundation_damage then 1.0 else 0.0 end) as foundation_damage,
            avg(case when roof_damage then 1.0 else 0.0 end) as roof_damage,
            avg(case when rental_assistance_eligible then 1.0 else 0.0 end) as rental_assistance_eligible,
            avg(case when repair_assistance_eligible then 1.0 else 0.0 end) as repair_assistance_eligible,
            avg(case when replacement_assistance_eligible then 1.0 else 0.0 end) as replacement_assistance_eligible,
            avg(case when personal_property_eligible then 1.0 else 0.0 end) as personal_property_eligible,
            avg(case when ihp_max then 1.0 else 0.0 end) as ihp_max,
            avg(case when ha_max then 1.0 else 0.0 end) as ha_max,
            avg(case when ona_max then 1.0 else 0.0 end) as ona_max,
            avg(case when reported_damage then 1.0 else 0.0 end) as reported_damage,
            avg(case when insufficient_damage then 1.0 else 0.0 end) as insufficient_damage,
            avg(case when ineligible_insurance then 1.0 else 0.0 end) as ineligible_insurance,
            avg(case when verified_ownership then 1.0 else 0.0 end) as verified_ownership,
            avg(case when verified_occupancy then 1.0 else 0.0 end) as verified_occupancy
        from read_parquet(%s)
        %s
        group by 1, 2, 3, 4, 5, 6, 7, 8
    ", q(db, ia_path), where_owner)

    as.data.table(dbGetQuery(db, sql))
}

dt_all   <- read_ia_cells(owner_only = FALSE)
dt_owner <- read_ia_cells(owner_only = TRUE)

for (dt in list(dt_all, dt_owner)) {
    dt[, treated_mh := treated * mh]
    dt[, treated_wz3_mh := treated_wz3 * mh]
}

message(sprintf(
    "All primary residences: %d cells, %d registrations",
    nrow(dt_all), sum(dt_all$n)
))
message(sprintf(
    "Owner primary residences: %d cells, %d registrations",
    nrow(dt_owner), sum(dt_owner$n)
))

v_dict <- c(
    "ihp_amount" = "IHP amount",
    "ha_amount" = "Housing assistance amount",
    "ona_amount" = "ONA amount",
    "rpfvl" = "Real property FEMA verified loss",
    "ppfvl" = "Personal property FEMA verified loss",
    "repair_amount" = "Repair amount",
    "replacement_amount" = "Replacement amount",
    "roof_damage_amount" = "Roof damage amount",
    "foundation_damage_amount" = "Foundation damage amount",
    "personal_property_amount" = "Personal property amount",
    "rental_assistance_amount" = "Rental assistance amount",
    "unmet_need_rp" = "Unmet need, real property",
    "destroyed" = "Destroyed",
    "habitability_repairs_required" = "Habitability repairs required",
    "repair_assistance_eligible" = "Repair assistance eligible",
    "replacement_assistance_eligible" = "Replacement assistance eligible",
    "roof_damage" = "Roof damage",
    "foundation_damage" = "Foundation damage",
    "ihp_eligible" = "IHP eligible",
    "ha_eligible" = "Housing assistance eligible"
)
setFixest_dict(v_dict, reset = TRUE)

estimate_indicator <- function(dt, outcomes, treat_var = "treated_mh") {
    lhs <- paste0("c(", paste(outcomes, collapse = ", "), ")")
    fml <- as.formula(paste0(
        lhs, " ~ ", treat_var,
        " | countyfp^disaster_number + mh^disaster_number"
    ))

    feols(
        fml,
        data = dt,
        weights = ~n,
        cluster = ~countyfp + disaster_number,
        lean = TRUE
    )
}

v_owner_amount <- c(
    "rpfvl", "repair_amount", "replacement_amount",
    "roof_damage_amount", "foundation_damage_amount",
    "unmet_need_rp", "ihp_amount", "ha_amount"
)

v_owner_binary <- c(
    "destroyed", "habitability_repairs_required",
    "repair_assistance_eligible", "replacement_assistance_eligible",
    "roof_damage", "foundation_damage", "ihp_eligible", "ha_eligible"
)

v_all_amount <- c(
    "ihp_amount", "ha_amount", "ona_amount", "ppfvl",
    "personal_property_amount", "rental_assistance_amount", "unmet_need_pp"
)

v_all_binary <- c(
    "ihp_eligible", "ha_eligible", "ona_eligible",
    "personal_property_eligible", "rental_assistance_eligible",
    "reported_damage", "insufficient_damage", "ineligible_insurance"
)

est_owner_amount <- estimate_indicator(dt_owner, v_owner_amount)
est_owner_binary <- estimate_indicator(dt_owner, v_owner_binary)
est_all_amount   <- estimate_indicator(dt_all,   v_all_amount)
est_all_binary   <- estimate_indicator(dt_all,   v_all_binary)

est_owner_amount_wz3 <- estimate_indicator(
    dt_owner, v_owner_amount, treat_var = "treated_wz3_mh")

etable(est_owner_amount, est_owner_binary, fitstat = c("n", "r2", "wr2", "my"))
etable(est_all_amount,   est_all_binary,   fitstat = c("n", "r2", "wr2", "my"))
etable(est_owner_amount_wz3, fitstat = c("n", "r2", "wr2", "my"))

# Event-study diagnostic: treated MH difference by declaration year.  This is
# not a pre-trend test; all IA observations are post-reform.  It is useful for
# seeing whether the spatial treated-MH gap changes after the possible producer
# standardization period around 2003.
choose_ref_year <- function(dt) {
    support <- dt[
        , .(has_treated_mh = any(treated_mh == 1L),
            has_other      = any(treated_mh == 0L)),
        by = year_declared]
    support <- support[has_treated_mh & has_other]
    support[which.min(year_declared), year_declared]
}

ref_year <- choose_ref_year(dt_owner)

estimate_year_event <- function(dt, outcomes) {
    lhs <- paste0("c(", paste(outcomes, collapse = ", "), ")")
    fml <- as.formula(paste0(
        lhs, " ~ i(year_declared, treated_mh, ref = ref_year)",
        " | countyfp^disaster_number + mh^disaster_number"
    ))

    feols(
        fml,
        data = dt,
        weights = ~n,
        cluster = ~countyfp + disaster_number,
        lean = TRUE
    )
}

est_owner_year <- estimate_year_event(
    dt_owner,
    c("rpfvl", "repair_amount", "replacement_amount", "destroyed")
)
etable(est_owner_year, fitstat = c("n", "r2", "wr2", "my"))

v_palette <- c("#0072B2", "#D55E00", "#009E73", "#F0E442")

theme_paper <- function(base_size = 14) {
    theme_classic(base_size = base_size) +
        theme(
            text = element_text(family = "serif"),
            legend.position = "right"
        )
}

plot_year_event <- function(est, outcome, path = NULL) {
    est <- est[lhs = outcome][[1]]
    ct <- as.data.table(coeftable(est), keep.rownames = TRUE)
    idx <- grepl("^year_declared::[0-9]{4}:treated_mh$", ct$rn)

    dt_es <- data.table(
        term = ct$rn[idx],
        est  = ct$Estimate[idx],
        se   = ct[["Std. Error"]][idx]
    )
    dt_es[, year := as.integer(regmatches(term, regexpr("[0-9]{4}", term)))]
    dt_es[, ci_low  := est - 1.96 * se]
    dt_es[, ci_high := est + 1.96 * se]

    dt_es <- rbind(
        dt_es,
        data.table(term = NA_character_, est = 0, se = 0,
                   ci_low = 0, ci_high = 0, year = ref_year)
    )
    setorder(dt_es, year)

    ylab <- if (outcome %in% names(v_dict)) unname(v_dict[[outcome]]) else outcome

    p <- ggplot(dt_es, aes(x = year, y = est)) +
        geom_ribbon(aes(ymin = ci_low, ymax = ci_high),
                    alpha = 0.2, fill = v_palette[1]) +
        geom_point(color = v_palette[1], size = 2) +
        geom_line(color = v_palette[1]) +
        geom_vline(xintercept = 2003.5, linetype = "dotted", color = "black") +
        geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
        scale_x_continuous(breaks = dt_es$year) +
        labs(x = "Declaration year", y = ylab) +
        theme_paper()

    if (!is.null(path)) ggsave(path, p, width = 9, height = 5)
    p
}

dir.create(here("output", "event-study"), showWarnings = FALSE, recursive = TRUE)
dir.create(here("output", "estimates"), showWarnings = FALSE, recursive = TRUE)

plot_year_event(
    est_owner_year, "rpfvl",
    here("output", "event-study", "es-ia-rpfvl.pdf"))
plot_year_event(
    est_owner_year, "repair_amount",
    here("output", "event-study", "es-ia-repair-amount.pdf"))
plot_year_event(
    est_owner_year, "replacement_amount",
    here("output", "event-study", "es-ia-replacement-amount.pdf"))
plot_year_event(
    est_owner_year, "destroyed",
    here("output", "event-study", "es-ia-destroyed.pdf"))

saveRDS(
    list(
        owner_amount = est_owner_amount,
        owner_binary = est_owner_binary,
        all_amount = est_all_amount,
        all_binary = est_all_binary,
        owner_amount_wz3 = est_owner_amount_wz3,
        owner_year = est_owner_year,
        ref_year = ref_year
    ),
    here("output", "estimates", "ia-estimates.Rds")
)
