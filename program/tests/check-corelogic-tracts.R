# Synthetic tract effects are correlated with vintage composition through weights.
library(data.table)
library(fixest)
source("program/lib/corelogic-prices.R")
source("program/lib/corelogic-ddd.R")
x <- CJ(wind_zone = 1:3, county = 1:6, tract = 1:3, mh = 0:1,
    year_constr = 1989:1999, year_sale = 2000:2003)
x[, countyfp := sprintf("%02d%03d", wind_zone, county)]
x[, tractfp := paste0(countyfp, sprintf("%06d", tract))]
x[, `:=`(post_mh = mh * (year_constr >= 1994), mh_tr = mh * (wind_zone >= 2),
    mh_z2 = mh * (wind_zone == 2), mh_z3 = mh * (wind_zone == 3),
    homes = 1 + 20 * (tract == 3 & mh == 1 & year_constr >= 1994))]
x[, `:=`(post_mh_tr = post_mh * (wind_zone >= 2), post_mh_z2 = post_mh * (wind_zone == 2),
    post_mh_z3 = post_mh * (wind_zone == 3))]
x[, log_price := 10 + .3 * tract + .02 * year_sale - .5 * mh + .1 * post_mh + .01 * year_constr]
fe <- "countyfp^year_sale + countyfp^mh + year_constr"
m <- feols(cl_price_formula(paste(fe, "+ tractfp"), dynamic_fit = FALSE), x, weights = ~homes, notes = FALSE)
stopifnot(abs(coef(m)[["post_mh"]] - .1) < 1e-8)
baseline <- feols(cl_price_formula(fe, dynamic_fit = FALSE), x, weights = ~homes, notes = FALSE)
stopifnot(abs(coef(baseline)[["post_mh"]] - .1) > .05)
x[, log_price := log_price + .06 * post_mh_z2 - .02 * post_mh_z3 + .01 * wind_zone * year_constr]
for (dynamic in c(FALSE, TRUE)) {
    m <- feols(cl_ddd_formula(TRUE, dynamic, tract = TRUE), x, weights = ~homes, notes = FALSE)
    if (!dynamic) stopifnot(max(abs(coef(m)[c("post_mh", "post_mh_z2", "post_mh_z3")] - c(.1,.06,-.02))) < 1e-8)
    else for (key in c("mh", "mh_z2", "mh_z3")) {
        b <- coef(m)[grepl(paste0(":", key, "$"), names(coef(m)))]
        v <- as.integer(sub("year_constr::([0-9]+):.*", "\\1", names(b)))
        stopifnot(length(b) == 10, max(abs(b - c(mh=.1,mh_z2=.06,mh_z3=-.02)[[key]] * (v>=1994))) < 1e-8)
    }
}
cat("Tract FE recover price effects under tract sorting across housing vintages.\n")
