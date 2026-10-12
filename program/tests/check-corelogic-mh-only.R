# Known-truth checks for MH-only price DiD and count PPML, without housing-type fields.
library(data.table)
library(fixest)
source("program/lib/corelogic-mh-only.R")
mh_fixture <- CJ(wind_zone = 1:3, county = 1:6, year_constr = 1989:1999)
mh_fixture[, countyfp := sprintf("%02d%03d", wind_zone, county)]
mh_fixture[, `:=`(z2 = as.integer(wind_zone == 2), z3 = as.integer(wind_zone == 3),
    post = as.integer(year_constr >= 1994))]
mh_fixture[, mh_homes := (200 + 20 * county) * fifelse(year_constr >= 1995, 3, 1) *
    fifelse(z2 == 1 & post == 1, 2, fifelse(z3 == 1 & post == 1, .5, 1))]
mh_counts <- cl_mh_count_panel(mh_fixture)
mh_count_fit <- fepois(cl_mh_only_formula(quantity = TRUE), mh_counts, vcov = ~countyfp, notes = FALSE)
for (key in c("z2", "z3")) {
    b <- coef(mh_count_fit)[grepl(paste0(":", key, "$"), names(coef(mh_count_fit)))]
    v <- as.integer(sub("year_constr::([0-9]+):.*", "\\1", names(b)))
    stopifnot(length(b) == 10, max(abs(b - c(z2 = log(2), z3 = log(.5))[[key]] * (v >= 1994))) < 1e-7)
}
# Missing cohorts become zeros; counties with no MH over the whole window add no count information.
mh_sparse <- rbind(mh_fixture[!(countyfp == "01001" & year_constr == 1990)],
    data.table(countyfp = "99999", wind_zone = 1, year_constr = 1989, mh_homes = 0), fill = TRUE)
mh_balanced <- cl_mh_count_panel(mh_sparse)
stopifnot(mh_balanced[countyfp == "01001" & year_constr == 1990, mh_homes] == 0,
    !"99999" %in% mh_balanced$countyfp, nrow(mh_balanced) == nrow(mh_counts))
mh_zero_fit <- fepois(cl_mh_only_formula(quantity = TRUE), mh_balanced, vcov = ~countyfp, notes = FALSE)
stopifnot(length(coef(mh_zero_fit)) == 20, all(is.finite(coef(mh_zero_fit))))

mh_prices <- mh_fixture[rep(seq_len(.N), each = 4)]
mh_prices[, year_sale := rep(2000:2003, times = .N / 4)]
mh_prices[, log_price := 10 + county/20 + .03 * (year_sale - 2000) +
    .1 * (year_constr - 1993) + .2 * post * z2 - .1 * post * z3]
mh_price_fit <- feols(cl_mh_only_formula(), mh_prices, vcov = ~countyfp, notes = FALSE)
for (key in c("z2", "z3")) {
    b <- coef(mh_price_fit)[grepl(paste0(":", key, "$"), names(coef(mh_price_fit)))]
    v <- as.integer(sub("year_constr::([0-9]+):.*", "\\1", names(b)))
    stopifnot(length(b) == 10, max(abs(b - c(z2 = .2, z3 = -.1)[[key]] * (v >= 1994))) < 1e-8)
}
cat("MH-only price and quantity event studies recover known zone effects and preserve zero counts.\n")
