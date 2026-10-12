# Synthetic records only: exercise the production price formulas against known truth.
library(data.table)
library(fixest)
source("program/lib/corelogic-prices.R")
set.seed(1994)
x <- CJ(countyfp = sprintf("%05d", 1:12), mh = 0:1,
        year_constr = 1989:1999, year_sale = 2000:2005)
x[, post_mh := mh * as.integer(year_constr >= 1994)]
x[, log_sqft := rnorm(.N) + .4 * post_mh]
x[, log_price := 10 + as.integer(countyfp)/20 + .03 * (year_sale - 2000) +
    .01 * (year_constr - 1992) - .8 * mh + .12 * post_mh + .25 * log_sqft]
fe <- "countyfp^year_sale + countyfp^mh + year_constr"
s <- feols(cl_price_formula(fe, "+ log_sqft", FALSE), x, vcov = ~countyfp, notes = FALSE)
stopifnot(abs(coef(s)[["post_mh"]] - .12) < 1e-8,
          abs(coef(s)[["log_sqft"]] - .25) < 1e-8)
m <- feols(cl_price_formula(fe, "+ log_sqft"), x, vcov = ~countyfp, notes = FALSE)
b <- coef(m)[grepl("^year_constr::", names(coef(m)))]
v <- as.integer(sub("year_constr::([0-9]+):mh", "\\1", names(b)))
stopifnot(length(b) == 10, all(abs(b - (.12 * (v >= 1994))) < 1e-8),
          !any(v == 1993), 1992 %in% v, 1994 %in% v)
cat("CoreLogic price formulas recover known static and annual vintage effects.\n")
# A half-sized 1994 response remains annual, but is pooled into the static effect.
x[, log_price := log_price - .25 * log_sqft - .06 * mh * (year_constr == 1994)]
s <- feols(cl_price_formula(fe, dynamic_fit = FALSE), x, notes = FALSE)
stopifnot(abs(coef(s)[["post_mh"]] - .11) < 1e-8)
m <- feols(cl_price_formula(fe), x, notes = FALSE)
stopifnot(abs(coef(m)[["year_constr::1994:mh"]] - .06) < 1e-8,
    abs(coef(m)[["year_constr::1995:mh"]] - .12) < 1e-8)
cat("Partial 1994 treatment attenuates the static contrast while remaining annual.\n")

# The price entry point now also uses the shared DDD formulas.
source("program/tests/check-corelogic-ddd.R")
m <- feols(cl_ddd_formula(dynamic = TRUE, controls = "+ area"), x, notes = FALSE)
b <- coef(m)[grepl(":mh_tr$", names(coef(m)))]
v <- as.integer(sub("year_constr::([0-9]+):.*", "\\1", names(b)))
stopifnot(length(b) == 10, max(abs(b - .11 * (v >= 1994))) < 1e-8)
# A partially treated 1994 cohort remains separate in each DDD profile.
x[, log_price := log_price - .055 * mh_tr * (year_constr == 1994)]
m <- feols(cl_ddd_formula(dynamic = TRUE, controls = "+ area"), x, notes = FALSE)
stopifnot(abs(coef(m)[["year_constr::1994:mh_tr"]] - .055) < 1e-8,
    abs(coef(m)[["year_constr::1995:mh_tr"]] - .11) < 1e-8)
cat("Price DDD profiles recover pooled annual effects and partial 1994 treatment.\n")

# Fully collapsed pre/post table recovers DDD under tract and size confounding.
q <- CJ(wind_zone = 1:3, county = 1:4, mh = 0:1, post = 0:1,
    year_sale = 2000:2003, tract = 1:3)
q[, countyfp := sprintf("%02d%03d", wind_zone, county)]
q[, tractfp := paste0(countyfp, sprintf("%06d", tract))]
q[, `:=`(post_mh = post * mh, post_mh_z2 = post * mh * (wind_zone == 2),
    post_mh_z3 = post * mh * (wind_zone == 3))]
q[, `:=`(log_lot = rnorm(.N) + .4 * post_mh_z3,
    log_living = rnorm(.N) - .2 * post_mh_z2)]
q[, log_price := 10 + county / 20 + .03 * (year_sale - 2000) - .8 * mh +
    .2 * wind_zone * post + .07 * post_mh + .11 * post_mh_z2 - .04 * post_mh_z3 +
    .12 * tract + .15 * log_lot + .3 * log_living]
f <- cl_ddd_formula(by_zone = TRUE, controls = "+ log_lot + log_living",
    tract = TRUE, annual_vintage = FALSE)
stopifnot(!grepl("year_constr", deparse(f), fixed = TRUE))
m <- feols(f, q, vcov = ~countyfp, notes = FALSE)
stopifnot(max(abs(coef(m)[c("post_mh", "post_mh_z2", "post_mh_z3", "log_lot", "log_living")] -
    c(.07, .11, -.04, .15, .3))) < 1e-8, identical(obs(m), seq_len(nrow(q))))
cat("Static pre/post DDD recovers tract- and size-adjusted known effects.\n")

source("program/tests/check-corelogic-mh-only.R")
