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
