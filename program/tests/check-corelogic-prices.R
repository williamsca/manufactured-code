# Synthetic records only: exercise the production price formulas against known truth.
library(data.table)
library(fixest)
source("program/lib/corelogic-prices.R")
set.seed(1994)
x <- CJ(countyfp = sprintf("%05d", 1:12), mh = 0:1,
        year_constr = 1984:1999, year_sale = 2000:2005)
x[, post_mh := mh * as.integer(year_constr >= 1995)]
x[, mh_1994 := mh * (year_constr == 1994)]
x[, log_sqft := rnorm(.N) + .4 * post_mh]
x[, log_price := 10 + as.integer(countyfp)/20 + .03 * (year_sale - 2000) +
    .01 * (year_constr - 1992) - .8 * mh + .12 * post_mh + .06 * mh_1994 + .25 * log_sqft]
fe <- "countyfp^year_sale + countyfp^mh + year_constr"
s <- feols(cl_price_formula(fe, "+ log_sqft", FALSE), x, vcov = ~countyfp, notes = FALSE)
stopifnot(abs(coef(s)[["post_mh"]] - .12) < 1e-8,
          abs(coef(s)[["mh_1994"]] - .06) < 1e-8,
          abs(coef(s)[["log_sqft"]] - .25) < 1e-8)
m <- feols(cl_price_formula(fe, "+ log_sqft"), x, vcov = ~countyfp, notes = FALSE)
b <- coef(m)[grepl("^year_constr::", names(coef(m)))]
v <- as.integer(sub("year_constr::([0-9]+):mh", "\\1", names(b)))
stopifnot(length(b) == 14, all(abs(b - (.12 * (v >= 1995) + .06 * (v == 1994))) < 1e-8),
          !any(v %in% c(1992,1993)))
cat("CoreLogic price formulas recover known static and annual vintage effects.\n")
