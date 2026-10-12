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
# State x vintage FE absorb state-specific vintage shocks that load on zone composition.
mh_states <- CJ(state = 1:3, wind_zone = 1:3, county = 1:4, year_constr = 1989:1999)
mh_states[, countyfp := sprintf("%02d%d%02d", state, wind_zone, county)]
mh_states[, `:=`(z2 = as.integer(wind_zone == 2), z3 = as.integer(wind_zone == 3), post = as.integer(year_constr >= 1994))]
mh_states <- mh_states[!(state == 3 & wind_zone == 1)]
mh_states[, mh_homes := (200 + 20 * county) * exp(state * (year_constr - 1993) / 10) *
    fifelse(z2 == 1 & post == 1, 2, fifelse(z3 == 1 & post == 1, .5, 1))]
mh_state_panel <- cl_mh_count_panel(mh_states)
stopifnot(identical(sort(unique(mh_state_panel$statefp)), c("01", "02", "03")))
mh_state_fit <- fepois(cl_mh_only_formula(quantity = TRUE, state = TRUE), mh_state_panel, vcov = ~countyfp, notes = FALSE)
mh_pooled_fit <- fepois(cl_mh_only_formula(quantity = TRUE), mh_state_panel, vcov = ~countyfp, notes = FALSE)
for (key in c("z2", "z3")) {
    b <- coef(mh_state_fit)[grepl(paste0(":", key, "$"), names(coef(mh_state_fit)))]
    v <- as.integer(sub("year_constr::([0-9]+):.*", "\\1", names(b)))
    stopifnot(length(b) == 10, max(abs(b - c(z2 = log(2), z3 = log(.5))[[key]] * (v >= 1994))) < 1e-6)
}
stopifnot(abs(coef(mh_pooled_fit)[["year_constr::1989:z3"]]) > .05)

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
mh_state_prices <- mh_states[rep(seq_len(.N), each = 4)][, statefp := substr(countyfp, 1, 2)]
mh_state_prices[, year_sale := rep(2000:2003, times = .N / 4)]
mh_state_prices[, log_price := 10 + county/20 + .03 * (year_sale - 2000) +
    as.integer(statefp) * (year_constr - 1993) / 10 + .2 * post * z2 - .1 * post * z3]
mh_state_price_fit <- feols(cl_mh_only_formula(state = TRUE), mh_state_prices, vcov = ~countyfp, notes = FALSE)
for (key in c("z2", "z3")) {
    b <- coef(mh_state_price_fit)[grepl(paste0(":", key, "$"), names(coef(mh_state_price_fit)))]
    v <- as.integer(sub("year_constr::([0-9]+):.*", "\\1", names(b)))
    stopifnot(length(b) == 10, max(abs(b - c(z2 = .2, z3 = -.1)[[key]] * (v >= 1994))) < 1e-8)
}
cat("MH-only price and quantity event studies recover known zone effects, absorb state vintage shocks, and preserve zero counts.\n")
