# Cost-side county x vintage design applied to NFIP damage and payments.
# Usage: Rscript program/estimate/estimate-nfip-mh-only.R
# Annual 1989-1999 vintages and 1993 reference match the CoreLogic design.
# PPML retains zero losses and estimates proportional changes in mean losses.
rm(list = ls())
library(here)
BIN_CONSTR_DEFAULT <- 1L
source(here("program", "lib", "nfip-setup.R"))
source(here("program", "lib", "nfip-claims-sample.R"))

out <- here("output", "event-study", "countyfp", "mh-only")
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
lhs <- paste0("c(", paste(v_loss, collapse = ", "), ")")

# Same four static columns as paper.Rmd; loss year replaces sale year.
fes <- c("countyfp^year_loss + year_constr",
         "countyfp^year_loss + statefp^year_constr",
         "countyfp^year_loss^mh + countyfp^year_constr + mh^year_constr",
         "countyfp^year_loss^mh + countyfp^year_constr + statefp^year_constr^mh")
static <- lapply(1:4, function(k) {
    rhs <- if (k <= 2L) "post_z2 + post_z3" else "post_mh_z2 + post_mh_z3"
    fepois(as.formula(paste(lhs, "~", rhs, "|", fes[k])),
           data = if (k <= 2L) dt[mh == 1L] else dt,
           cluster = ~countyfp)
})
events <- lapply(1:2, function(k) {
    fepois(as.formula(paste(lhs,
        "~ i(year_constr, z2, ref = 1993) + i(year_constr, z3, ref = 1993) |",
        fes[k])), data = dt[mh == 1L], cluster = ~countyfp)
})

# Export actual estimation-sample counts (PPML may remove all-zero FE cells).
extract <- function(models, dynamic = FALSE) {
    rbindlist(lapply(seq_along(models), function(k) {
        rbindlist(lapply(v_loss, function(y) {
            m <- models[[k]][lhs = paste0("^", y, "$")][[1]]
            ct <- coeftable(m)
            cs <- coeftable(summary(m, cluster = ~statefp))
            d <- data.table(specification = k, outcome = y,
                term = rownames(ct), estimate = ct[, 1], se = ct[, 2],
                p_value = ct[, 4], se_state = cs[rownames(ct), 2],
                n = nobs(m))
            sample <- if (k <= 2L) dt[mh == 1L] else dt
            d[, counties := uniqueN(sample$countyfp[obs(m)])]
            d[, `:=`(ci_low = estimate - 1.96 * se,
                     ci_high = estimate + 1.96 * se)]
            d[, `:=`(pct = 100 * expm1(estimate),
                     pct_low = 100 * expm1(ci_low),
                     pct_high = 100 * expm1(ci_high))]
            if (dynamic) {
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
saveRDS(list(static = lapply(static, summary, lean = TRUE),
             events = lapply(events, summary, lean = TRUE)), file.path(out, "models.Rds"))

dict <- c(v_dict, post_z2 = "Zone II $\\times$ post",
    post_z3 = "Zone III $\\times$ post")
dict[c("post_mh_z2", "post_mh_z3")] <- dict[c("post_z2", "post_z3")]
for (y in v_loss) {
    fits <- lapply(static, function(x) x[lhs = paste0("^", y, "$")][[1]])
    etable(fits, tex = TRUE, file = file.path(out, paste0(y, "-static.tex")),
        replace = TRUE, digits = 3, fitstat = c("n", "pr2"),
        dict = dict,
        headers = c("MH", "MH, state vintage", "MH and SB", "MH and SB, state vintage"))
    for (k in 1:2) {
        pdt <- copy(es[specification == k & outcome == y])
        pdt[, zone := fifelse(grepl(":z2$", term), "Zone II minus Zone I", "Zone III minus Zone I")]
        pdt <- rbind(pdt, data.table(zone = unique(pdt$zone), vintage = 1993L,
            estimate = 0, ci_low = 0, ci_high = 0), fill = TRUE)
        p <- ggplot(pdt, aes(vintage, estimate)) +
            geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
            geom_vline(xintercept = 1993.5, linetype = "dotted") +
            geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = .2) +
            geom_point(color = "#0072B2", size = 2) +
            facet_wrap(~zone, ncol = 2) +
            scale_x_continuous(breaks = seq(1989, 1999, 2)) +
            labs(x = "Construction year", y = paste0(v_dict[[y]], " (log points)")) +
            theme_classic(base_size = 14) + theme(text = element_text(family = "serif"))
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
    "All effects condition on filing an NFIP claim; no claim-frequency effect is estimated."
), file.path(out, "README.txt"))
print(st[, .(specification, outcome, term, estimate, se, pct, n, counties)])
