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
# Static ladder: a county x vintage shock common to both types biases only columns 1-2;
# a state x vintage shock specific to MH biases only columns 1 and 3. Column 4 absorbs both.
ladder <- CJ(state = 1:3, wind_zone = 1:3, county = 1:4, year_constr = 1989:1999, mh = 0:1)
ladder <- ladder[!(state == 3 & wind_zone == 1)]
ladder[, `:=`(countyfp = sprintf("%02d%d%02d", state, wind_zone, county), statefp = sprintf("%02d", state),
    post = as.integer(year_constr >= 1994), z2 = as.integer(wind_zone == 2), z3 = as.integer(wind_zone == 3))]
ladder[, `:=`(post_z2 = post * z2, post_z3 = post * z3, post_mh_z2 = post * mh * z2, post_mh_z3 = post * mh * z3)]
truth <- c(log(2), log(.5))
ladder_check <- function(common, state_mh) {
    d <- copy(ladder)
    d[, lmu := 5 + county / 10 + .3 * mh + .02 * (year_constr - 1993) * (1 + mh) +
        truth[1] * post * mh * z2 + truth[2] * post * mh * z3 +
        common * wind_zone * county * (year_constr - 1993) / 40 +
        state_mh * mh * state * (year_constr - 1993) / 10]
    d[, homes := exp(lmu)]
    d2 <- d[rep(seq_len(.N), each = 2)][, year_sale := rep(2000:2001, times = .N / 2)]
    d2[, log_price := lmu + .05 * (year_sale - 2000)]
    vapply(1:4, function(k) {
        sub <- function(x) if (k <= 2) x[mh == 1] else x
        q <- coef(fepois(cl_mh_static_formula(k, quantity = TRUE), sub(d), notes = FALSE))
        p <- coef(feols(cl_mh_static_formula(k), sub(d2), notes = FALSE))
        max(abs(c(q, p) - rep(truth, 2)))
    }, numeric(1))
}
err <- ladder_check(0, 0); stopifnot(all(err < 1e-6))
err <- ladder_check(1, 0); stopifnot(all(err[3:4] < 1e-6), all(err[1:2] > .01))
err <- ladder_check(0, 1); stopifnot(all(err[c(2, 4)] < 1e-6), all(err[c(1, 3)] > .01))
err <- ladder_check(1, 1); stopifnot(err[4] < 1e-6, all(err[1:3] > .01))

# Type panel: site-built = homes - MH, zero-filled over MH-support counties; MH rows match the MH panel.
type_cells <- copy(mh_sparse)[, homes := mh_homes + 100]
type_cells <- type_cells[!(countyfp == "02001" & year_constr == 1995)]
type_panel <- cl_type_count_panel(type_cells)
stopifnot(nrow(type_panel) == 2L * nrow(cl_mh_count_panel(type_cells)),
    type_panel[countyfp == "02001" & year_constr == 1995, all(homes == 0)],
    type_panel[mh == 0 & !(countyfp == "02001" & year_constr == 1995) & countyfp != "01001", all(homes == 100)])
ladder_fits <- cl_mh_static_fits(ladder[, homes := exp(5 + county / 10 + mh + truth[1] * post * mh * z2)], quantity = TRUE)
ladder_tex <- tempfile(fileext = ".tex")
cl_mh_static_table(ladder_fits, ladder_tex, quantity = TRUE)
ladder_lines <- readLines(ladder_tex)
stopifnot(sum(grepl("^ *Zone II \\$\\\\times\\$ post", ladder_lines)) == 1L,
    sum(grepl("^ *Zone III \\$\\\\times\\$ post", ladder_lines)) == 1L, ladder_fits$counties == 32L)

cat("MH-only price and quantity event studies recover known zone effects, absorb state vintage shocks, and preserve zero counts.\n")
cat("Static ladder: each column absorbs exactly the shocks its fixed effects target.\n")
