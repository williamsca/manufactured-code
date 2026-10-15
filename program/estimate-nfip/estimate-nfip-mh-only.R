# Cost-side county x vintage design applied to NFIP losses, shares and claim rates.
# Work in progress; not in the paper. Usage: Rscript program/estimate-nfip/estimate-nfip-mh-only.R
# Annual 1989-1999 vintages and 1993 reference match the CoreLogic design.
# PPML retains zero losses and estimates proportional changes in mean losses.
rm(list = ls())
library(here)
BIN_CONSTR_DEFAULT <- 1L
source(here("program", "estimate-nfip", "nfip-setup.R"))
source(here("program", "estimate-nfip", "nfip-claims-sample.R"))
source(here("program", "estimate-nfip", "plot-es.R"))

out <- here("output", "nfip", "mh-only")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
dt <- copy(dt_claims_est[between(year_constr, 1989L, 1999L) &
    !statefp %in% c("02", "15")])
dt[, `:=`(z2 = as.integer(wind_zone == 2L),
          z3 = as.integer(wind_zone == 3L))]
dt[, `:=`(post_z2 = post1994 * z2, post_z3 = post1994 * z3,
          post_mh_z2 = post_mh * z2, post_mh_z3 = post_mh * z3)]
stopifnot(!anyNA(dt[, .(countyfp, statefp, wind_zone, year_constr, year_loss, mh)]),
          all(dt$wind_zone %in% 1:3))
v_loss <- c("building_damage", "net_building_pmt",
            "contents_damage", "net_contents_pmt")
# Shares use the same denominators as the main NFIP analysis. Invalid values
# are missing; bounded counterparts show sensitivity to shares exceeding 100%.
v_share <- paste0(v_loss, "_share")
for (y in v_share) {
    dt[!is.finite(get(y)) | get(y) < 0, (y) := NA_real_]
    denominator <- if (grepl("building", y)) "building_value" else "contents_value"
    dt[!is.finite(get(denominator)) | get(denominator) <= 0, (y) := NA_real_]
    dt[, (paste0(y, "_bounded")) := pmin(get(y), 100)]
}
fwrite(dt[mh == 1L, lapply(.SD, function(x) sum(x > 100, na.rm = TRUE)),
    by = .(wind_zone, post1994), .SDcols = v_share], file.path(out, "shares-above-100.csv"))
v_share <- c(v_share, paste0(v_share, "_bounded"))
v_dict[paste0(v_loss, "_share_bounded")] <- paste0(v_dict[paste0(v_loss, "_share")], " [capped at 100%]")

# Policy-years and claims come from the same balanced tract panel. Aggregate
# BEFORE requiring positive exposure, retaining claims in zero-policy tracts
# when the corresponding county-period-vintage-type has positive exposure.
rate <- readRDS(here("derived", "nfip-balanced.Rds"))
rate <- rate[between(year_constr, 1989L, 1999L) & !statefp %in% c("02", "15"),
    .(claims_n = sum(claims_n), policies_n = sum(policies_n)),
    by = .(countyfp, statefp, period_loss, year_constr, mh)]
rate[dt_wz, wind_zone := i.wind_zone, on = "countyfp"]
stopifnot(!anyNA(rate), all(rate$wind_zone %in% 1:3),
    all(rate$claims_n >= 0), all(rate$policies_n >= 0))
fwrite(rate[, .(cells = .N, claims = sum(claims_n), policy_years = sum(policies_n)),
    by = .(wind_zone, mh, positive_exposure = policies_n > 0)],
    file.path(out, "claim-rate-exposure-support.csv"))
rate <- rate[policies_n > 0]
rate[, `:=`(z2 = as.integer(wind_zone == 2L), z3 = as.integer(wind_zone == 3L),
    post1994 = as.integer(year_constr >= 1994L), log_policy_years = log(policies_n))]
rate[, `:=`(post_z2 = post1994 * z2, post_z3 = post1994 * z3,
    post_mh_z2 = post1994 * mh * z2, post_mh_z3 = post1994 * mh * z3)]
# Label the PPML count-with-exposure model by its estimand in every export.
rate[, claim_rate := claims_n]
v_outcomes <- c(v_loss, v_share, "claim_rate")
lhs_share <- paste0("c(", paste(v_share, collapse = ", "), ")")
lhs <- paste0("c(", paste(v_loss, collapse = ", "), ")")

# Same four static columns as paper.Rmd; loss year replaces sale year.
fes <- c("countyfp^year_loss + year_constr",
         "countyfp^year_loss + statefp^year_constr",
         "countyfp^year_loss^mh + countyfp^year_constr + mh^year_constr",
         "countyfp^year_loss^mh + countyfp^year_constr + statefp^year_constr^mh")
fit <- function(k, dynamic = FALSE) {
    rhs <- if (dynamic) {
        "i(year_constr, z2, ref = 1993) + i(year_constr, z3, ref = 1993)"
    } else if (k <= 2L) "post_z2 + post_z3" else "post_mh_z2 + post_mh_z3"
    sample <- if (k <= 2L) dt[mh == 1L] else dt
    formula <- function(y, fe = fes[k]) as.formula(paste(y, "~", rhs, "|", fe))
    losses <- as.list(fepois(formula(lhs), data = sample, cluster = ~countyfp))
    shares <- as.list(feols(formula(lhs_share), data = sample, cluster = ~countyfp))
    frequency <- fepois(formula("claim_rate", gsub("year_loss", "period_loss", fes[k])),
        data = if (k <= 2L) rate[mh == 1L] else rate,
        offset = ~log_policy_years, cluster = ~countyfp)
    setNames(c(losses, shares, list(frequency)), v_outcomes)
}
static <- lapply(1:4, fit)
events <- lapply(1:2, fit, dynamic = TRUE)

# Export actual estimation-sample counts (PPML may remove all-zero FE cells).
extract <- function(models, dynamic = FALSE) {
    rbindlist(lapply(seq_along(models), function(k) {
        rbindlist(lapply(v_outcomes, function(y) {
            m <- models[[k]][[y]]
            ct <- coeftable(m)
            cs <- coeftable(summary(m, cluster = ~statefp))
            d <- data.table(specification = k, outcome = y,
                term = rownames(ct), estimate = ct[, 1], se = ct[, 2],
                p_value = ct[, 4], se_state = cs[rownames(ct), 2],
                n = nobs(m))
            source_data <- if (y == "claim_rate") rate else dt
            sample <- if (k <= 2L) source_data[mh == 1L] else source_data
            d[, counties := uniqueN(sample$countyfp[obs(m)])]
            d[, `:=`(ci_low = estimate - 1.96 * se,
                     ci_high = estimate + 1.96 * se)]
            d[, `:=`(estimator = if (y %in% v_share) "OLS" else "PPML",
                     scale = if (y %in% v_share) "percentage points" else "log points")]
            d[, `:=`(pct = if (y %in% v_share) NA_real_ else 100 * expm1(estimate),
                     pct_low = if (y %in% v_share) NA_real_ else 100 * expm1(ci_low),
                     pct_high = if (y %in% v_share) NA_real_ else 100 * expm1(ci_high))]
            d[, identified := TRUE]
            if (dynamic) {
                # Some contents shares have no usable value observations in an
                # early zone-vintage cell. Export that coefficient as missing.
                expected <- paste0("year_constr::", rep(setdiff(1989:1999, 1993L), 2),
                    ":", rep(c("z2", "z3"), each = 10))
                missing <- setdiff(expected, d$term)
                if (length(missing)) d <- rbind(d, data.table(
                    specification = k, outcome = y, term = missing, n = nobs(m),
                    counties = d$counties[1], estimator = d$estimator[1],
                    scale = d$scale[1], identified = FALSE), fill = TRUE)
                d[, vintage := as.integer(sub("year_constr::([0-9]+):.*", "\\1", term))]
                stopifnot(nrow(d) == 20L, setequal(d$vintage, setdiff(1989:1999, 1993)))
            } else stopifnot(nrow(d) == 2L)
            d
        }))
    }))
}
st <- extract(static)
es <- extract(events, TRUE)
fwrite(st, file.path(out, "static.csv"))
fwrite(es, file.path(out, "event-study.csv"))
support <- dt[mh == 1L, .(claims = .N, counties = uniqueN(countyfp),
    states = uniqueN(statefp)), keyby = .(wind_zone, post1994)]
fwrite(support, file.path(out, "sample-support.csv"))
saveRDS(list(static = lapply(static, function(x) lapply(x, summary, lean = TRUE)),
             events = lapply(events, function(x) lapply(x, summary, lean = TRUE))), file.path(out, "models.Rds"))

dict <- c(v_dict, post_z2 = "Zone II $\\times$ post",
    post_z3 = "Zone III $\\times$ post")
dict[c("post_mh_z2", "post_mh_z3")] <- dict[c("post_z2", "post_z3")]
for (y in v_outcomes) {
    fits <- lapply(static, function(x) x[[y]])
    etable(fits, tex = TRUE, file = file.path(out, paste0(y, "-static.tex")),
        replace = TRUE, digits = 3, fitstat = if (y %in% v_share) c("n", "r2") else c("n", "pr2"),
        dict = dict,
        notes = if (y == "claim_rate") "PPML on claim counts with log policy-years as an offset; coefficients are log rate contrasts." else NULL,
        headers = c("MH", "MH, state vintage", "MH and SB", "MH and SB, state vintage"))
    for (k in 1:2) {
        pdt <- copy(es[specification == k & outcome == y])
        pdt[, zone := fifelse(grepl(":z2$", term), "Zone II minus Zone I", "Zone III minus Zone I")]
        pdt <- rbind(pdt, data.table(zone = unique(pdt$zone), vintage = 1993L,
            estimate = 0, ci_low = 0, ci_high = 0), fill = TRUE)
        p <- ggplot(pdt, aes(vintage, estimate)) +
            geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
            geom_vline(xintercept = 1993.5, linetype = "dotted") +
            geom_ribbon(aes(ymin = ci_low, ymax = ci_high), fill = "#0072B2", alpha = .2) +
            geom_line(color = "#0072B2") +
            geom_point(color = "#0072B2", size = 2) +
            facet_wrap(~zone, ncol = 2) +
            scale_x_continuous(breaks = seq(1989, 1999, 2)) +
            labs(x = "Construction year", y = paste0(sub(" (%)", "", v_dict[[y]], fixed = TRUE), if (y %in% v_share) " (percentage points)" else " (log points)")) +
            theme_paper()
        ggsave(file.path(out, paste0(y, "-es", if (k == 2) "-state-vintage" else "", ".pdf")),
               p, width = 9, height = 5)
    }
}
writeLines(c(
    "NFIP county x vintage design, matching paper.Rmd cost specifications.",
    "Construction years 1989-1999; loss years 1994-2023; excludes AK/HI.",
    "PPML on four nonnegative damage/payment outcomes; shared NFIP cleaning and caps.",
    "Static columns 1-2: MH only, county x loss-year FE and vintage/state x vintage FE.",
    "Static columns 3-4: MH/SB, county x loss-year x type and county x vintage FE,",
    "plus type x vintage/state x type x vintage FE.",
    "Post includes 1994; event-study reference is 1993. County-clustered 95% intervals.",
    "CSV also reports state-clustered SE. Zone III is concentrated in three states.",
    "Damage/payment amounts and shares condition on filing an NFIP claim.",
    "Shares: OLS in percentage points; nonpositive/missing denominators excluded.",
    "Raw shares and sensitivity capped at 100% are both exported (suffix _bounded).",
    "Unidentified zone-vintage contrasts have missing estimates and identified=FALSE in CSV.",
    "Claim rate: county x five-year calendar-period x vintage x type panel, 2009-2023.",
    "PPML claims with log policy-years offset, positive county-cell exposure, zero claims retained.",
    "Rate FE replace loss year with calendar period in all four specifications.",
    "Claim-rate sample does not require an imputed housing-stock denominator.",
    "Claim-rate N counts cells; loss/share N counts claims. Percent effects are undefined for OLS."
), file.path(out, "README.txt"))
print(st[, .(specification, outcome, term, estimate, se, pct, n, counties)])
