# Known-truth checks for MH-only price DiD and count PPML, without housing-type fields.
library(data.table)
library(fixest)
source("program/estimate-corelogic/corelogic-mh-only.R")
mh_fixture <- CJ(wind_zone = 1:3, county = 1:6, year_constr = CL_VINTAGES)
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
    stopifnot(length(b) == length(CL_VINTAGES) - 1L, max(abs(b - c(z2 = log(2), z3 = log(.5))[[key]] * (v >= 1994))) < 1e-7)
}
# Missing cohorts become zeros; counties with no MH over the whole window add no count information.
mh_sparse <- rbind(mh_fixture[!(countyfp == "01001" & year_constr == 1990)],
    data.table(countyfp = "99999", wind_zone = 1, year_constr = 1989, mh_homes = 0), fill = TRUE)
mh_balanced <- cl_mh_count_panel(mh_sparse)
stopifnot(mh_balanced[countyfp == "01001" & year_constr == 1990, mh_homes] == 0,
    !"99999" %in% mh_balanced$countyfp, nrow(mh_balanced) == nrow(mh_counts))
mh_zero_fit <- fepois(cl_mh_only_formula(quantity = TRUE), mh_balanced, vcov = ~countyfp, notes = FALSE)
stopifnot(length(coef(mh_zero_fit)) == 2L * (length(CL_VINTAGES) - 1L), all(is.finite(coef(mh_zero_fit))))
# State x vintage FE absorb state-specific vintage shocks that load on zone composition.
mh_states <- CJ(state = 1:3, wind_zone = 1:3, county = 1:4, year_constr = CL_VINTAGES)
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
    stopifnot(length(b) == length(CL_VINTAGES) - 1L, max(abs(b - c(z2 = log(2), z3 = log(.5))[[key]] * (v >= 1994))) < 1e-6)
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
    stopifnot(length(b) == length(CL_VINTAGES) - 1L, max(abs(b - c(z2 = .2, z3 = -.1)[[key]] * (v >= 1994))) < 1e-8)
}
mh_state_prices <- mh_states[rep(seq_len(.N), each = 4)][, statefp := substr(countyfp, 1, 2)]
mh_state_prices[, year_sale := rep(2000:2003, times = .N / 4)]
mh_state_prices[, log_price := 10 + county/20 + .03 * (year_sale - 2000) +
    as.integer(statefp) * (year_constr - 1993) / 10 + .2 * post * z2 - .1 * post * z3]
mh_state_price_fit <- feols(cl_mh_only_formula(state = TRUE), mh_state_prices, vcov = ~countyfp, notes = FALSE)
for (key in c("z2", "z3")) {
    b <- coef(mh_state_price_fit)[grepl(paste0(":", key, "$"), names(coef(mh_state_price_fit)))]
    v <- as.integer(sub("year_constr::([0-9]+):.*", "\\1", names(b)))
    stopifnot(length(b) == length(CL_VINTAGES) - 1L, max(abs(b - c(z2 = .2, z3 = -.1)[[key]] * (v >= 1994))) < 1e-8)
}
# Price ladder: a county x vintage shock common to both types biases only columns 1-2;
# the DDD columns difference it out through the site-built Zone x post terms. A state x
# vintage shock specific to MH biases only columns 1 and 3. Column 4 absorbs both.
ladder <- CJ(state = 1:3, wind_zone = 1:3, county = 1:4, year_constr = CL_VINTAGES, mh = 0:1)
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
        p <- coef(feols(cl_mh_static_formula(k), sub(d2), notes = FALSE))
        target <- p[if (k <= 2) c("post_z2", "post_z3") else c("post_mh_z2", "post_mh_z3")]
        max(abs(target - truth))
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
# Separate count outcomes: large negative MH effects and small positive SB
# substitution effects must be recovered separately, rather than differenced.
count_truth <- list(MH = c(-.2, -.8), SB = c(.01, .02))
count_fixture <- function(state_shock = 0) {
    d <- copy(ladder)
    d[, homes := exp(5 + county / 10 + mh + .02 * (year_constr - 1993) * (1 + mh) +
        fifelse(mh == 1, count_truth$MH[1], count_truth$SB[1]) * post_z2 +
        fifelse(mh == 1, count_truth$MH[2], count_truth$SB[2]) * post_z3 +
        state_shock * state * (1 + mh) * (year_constr - 1993) / 10)]
    d
}
ladder_fits <- cl_mh_static_fits(count_fixture(), quantity = TRUE)
for (k in 1:4) {
    expected <- count_truth[[if (k <= 2) "MH" else "SB"]]
    stopifnot(max(abs(coef(ladder_fits$fits[[k]]) - expected)) < 1e-6)
}
state_count_fits <- cl_mh_static_fits(count_fixture(1), quantity = TRUE)
for (k in c(2L, 4L)) {
    expected <- count_truth[[if (k == 2) "MH" else "SB"]]
    stopifnot(max(abs(coef(state_count_fits$fits[[k]]) - expected)) < 1e-6)
}
stopifnot(abs(coef(state_count_fits$fits[[3]])[["post_z3"]] - count_truth$SB[2]) > .01)
ladder_tex <- tempfile(fileext = ".tex")
cl_mh_static_table(ladder_fits, ladder_tex, quantity = TRUE)
ladder_lines <- readLines(ladder_tex)
stopifnot(sum(grepl("^ *Zone II \\$\\\\times\\$ post", ladder_lines)) == 1L,
    sum(grepl("^ *Zone III \\$\\\\times\\$ post", ladder_lines)) == 1L,
    any(grepl("Site-built", ladder_lines, fixed = TRUE)),
    any(grepl("Outcome:", ladder_lines, fixed = TRUE)),
    !any(grepl("County $\\times$ vintage", ladder_lines, fixed = TRUE)),
    ladder_fits$counties == 32L)

cat("MH-only price and quantity event studies recover known zone effects, absorb state vintage shocks, and preserve zero counts.\n")
cat("Price ladder absorbs its target shocks; separate MH and SB count regressions recover substitution effects.\n")

# Size controls recover the known premium when size changes with treatment;
# the DDD permits different hedonic slopes by housing type.
set.seed(941)
size_fixture <- ladder[rep(seq_len(.N), each = 2L)]
size_fixture[, year_sale := rep(2000:2001, times = .N / 2)]
size_fixture[, `:=`(log_living_area = 7 + .4 * post_mh_z3 + rnorm(.N, sd = .2),
    log_lot_size = 9 + .2 * post_mh_z2 + rnorm(.N, sd = .3))]
size_fixture[, log_price := 10 + county / 10 + .2 * mh + .03 * year_sale +
    .02 * year_constr * (1 + mh) + .2 * post_mh_z2 - .1 * post_mh_z3 +
    (.4 + .2 * mh) * log_living_area + (.3 - .1 * mh) * log_lot_size]
size_fixture[, valid_size := TRUE]
size_fixture[seq_len(10), `:=`(valid_size = FALSE, log_lot_size = NA_real_)]
size_fits <- cl_price_static_fits(size_fixture)
for (k in c(3L, 6L)) {
    b <- coef(size_fits$fits[[k]])
    target <- b[if (k == 3L) c("post_z2", "post_z3") else c("post_mh_z2", "post_mh_z3")]
    stopifnot(max(abs(target - c(.2, -.1))) < 1e-7,
        nobs(size_fits$fits[[k]]) == nobs(size_fits$common_sample[[paste0("common_sample_", k)]]))
}
stopifnot(nobs(size_fits$fits[[2]]) > nobs(size_fits$fits[[3]]),
    nobs(size_fits$fits[[5]]) > nobs(size_fits$fits[[6]]),
    abs(coef(size_fits$fits[[2]])[["post_z3"]] + .1) > .05)
size_tex <- tempfile(fileext = ".tex")
cl_mh_static_table(size_fits, size_tex)
size_lines <- readLines(size_tex)
stopifnot(any(grepl("Size controls", size_lines, fixed = TRUE)),
    sum(grepl("^ *Zone II \\$\\\\times\\$ post *&", size_lines)) == 1L,
    sum(grepl("^ *Zone III \\$\\\\times\\$ post \\$\\\\times\\$ MH *&", size_lines)) == 1L,
    !any(grepl("County $\\times$ vintage", size_lines, fixed = TRUE)))
cat("Six-column price table recovers size-adjusted premiums and compares identical retained samples.\n")

# Levels table: caps are type-specific percentiles, and the ladder recovers
# known dollar premiums from the winsorized outcome.
source("program/estimate-corelogic/corelogic-price-sample.R")
level_fixture <- copy(size_fixture)
level_fixture[, sale_price_2000 := exp(11 + rnorm(.N)) + 5e4 * mh]
caps <- cl_price_level_winsor(level_fixture)
for (m in 0:1) {
    p <- level_fixture[mh == m, sale_price_2000]
    q <- quantile(p, c(.01, .99), names = FALSE)
    stopifnot(isTRUE(all.equal(level_fixture[mh == m, price_level_w], pmin(pmax(p, q[1]), q[2]))),
        isTRUE(all.equal(unlist(caps[mh == m, .(p_low, p_high)], use.names = FALSE), q)))
}
stopifnot(sum(caps$capped_low) > 0, sum(caps$capped_high) > 0)
level_fixture[, price_level_w := 1e5 + 1e3 * county + 2e4 * mh + 500 * year_sale +
    300 * year_constr * (1 + mh) + 4e3 * post_z3 + 6e3 * post_mh_z2 - 3e3 * post_mh_z3 +
    (1e3 + 500 * mh) * log_living_area + (800 - 200 * mh) * log_lot_size]
level_fits <- cl_price_static_fits(level_fixture, outcome = "price_level_w")
stopifnot(max(abs(coef(level_fits$fits[[3]])[c("post_z2", "post_z3")] - c(6e3, 1e3))) < 1e-4,
    max(abs(coef(level_fits$fits[[6]])[c("post_z2", "post_z3", "post_mh_z2", "post_mh_z3")] -
    c(0, 4e3, 6e3, -3e3))) < 1e-4)
level_tex <- tempfile(fileext = ".tex")
cl_mh_static_table(level_fits, level_tex, digits = "r0")
cat("Levels table winsorizes within housing type and recovers known dollar premiums.\n")

# Expanded timing study: early cohorts and a pre-Andrew reference must recover
# both a 1993 information shock and an additional 1994 regulatory shock.
timing <- CJ(state = 1:3, wind_zone = 1:3, county = 1:4, year_constr = 1986:1999)
timing[, countyfp := sprintf("%02d%d%02d", state, wind_zone, county)]
timing[, mh_homes := exp(5 + county / 10 + state * (year_constr - 1991) / 20 +
    (wind_zone == 2) * (-.1 * (year_constr >= 1993) - .2 * (year_constr >= 1994)) +
    (wind_zone == 3) * (-.3 * (year_constr >= 1993) - .5 * (year_constr >= 1994)))]
timing_panel <- cl_mh_count_panel(timing, years = 1986:1999)
timing_fit <- fepois(cl_mh_only_formula(quantity = TRUE, state = TRUE, reference = 1991L),
    timing_panel, vcov = ~countyfp, notes = FALSE)
stopifnot(nrow(timing_panel) == 14L * uniqueN(timing$countyfp),
    length(coef(timing_fit)) == 26L, !any(grepl("::1991:", names(coef(timing_fit)))))
for (key in c("z2", "z3")) {
    b <- coef(timing_fit)[grepl(paste0(":", key, "$"), names(coef(timing_fit)))]
    v <- as.integer(sub("year_constr::([0-9]+):.*", "\\1", names(b)))
    truth <- if (key == "z2") -.1 * (v >= 1993) - .2 * (v >= 1994) else
        -.3 * (v >= 1993) - .5 * (v >= 1994)
    stopifnot(max(abs(b - truth)) < 1e-6)
}
cat("Expanded 1986-1999 study with 1991 reference recovers distinct 1993 and 1994 shocks.\n")
