# Known truth has both MH-vintage shifts and zone-vintage shifts: dropping either
# lower-order interaction must not be allowed to contaminate the triple difference.
library(data.table); library(fixest)
source("program/lib/corelogic-ddd.R")
set.seed(3280)
x <- CJ(wind_zone = 1:3, county = 1:8, mh = 0:1,
    year_constr = 1984:1999, year_sale = 2000:2004)
x[, countyfp := sprintf("%02d%03d", wind_zone, county)]
x[, `:=`(mh_z2 = mh * (wind_zone == 2), mh_z3 = mh * (wind_zone == 3),
    mh_tr = mh * (wind_zone >= 2), post = as.integer(year_constr >= 1995))]
x[, `:=`(post_mh = mh * post, post_mh_z2 = mh_z2 * post,
    post_mh_z3 = mh_z3 * post, post_mh_tr = mh_tr * post)]
x[, `:=`(mh_1994=mh * (year_constr==1994), mh_1994_tr=mh_tr * (year_constr==1994),
    mh_1994_z2=mh_z2 * (year_constr==1994), mh_1994_z3=mh_z3 * (year_constr==1994))]
x[, area := rnorm(.N) + post_mh_z2]
x[, log_price := 10 + county/20 + .03 * (year_sale - 2000) - .8 * mh +
    .05 * wind_zone * (year_constr - 1992) + .2 * wind_zone * post +
    .07 * post_mh + .11 * post_mh_z2 - .04 * post_mh_z3 + .03 * mh_1994 + .08 * mh_1994_z2 - .02 * mh_1994_z3 + .3 * area]
m <- feols(cl_ddd_formula(TRUE, FALSE, "+ area"), x, notes = FALSE)
stopifnot(max(abs(coef(m)[c("mh_1994","mh_1994_z2","mh_1994_z3")] - c(.03,.08,-.02))) < 1e-8)
stopifnot(max(abs(coef(m)[c("post_mh","post_mh_z2","post_mh_z3")] - c(.07,.11,-.04))) < 1e-8)
m <- feols(cl_ddd_formula(TRUE, TRUE, "+ area"), x, notes = FALSE)
for (key in c("mh", "mh_z2", "mh_z3")) {
    b <- coef(m)[grepl(paste0(":",key,"$"),names(coef(m)))]
    v <- as.integer(sub("year_constr::([0-9]+):.*", "\\1", names(b)))
    truth <- c(mh = .07, mh_z2 = .11, mh_z3 = -.04)[[key]] * (v >= 1995) + c(mh=.03,mh_z2=.08,mh_z3=-.02)[[key]] * (v==1994)
    stopifnot(length(b) == 14, max(abs(b-truth)) < 1e-8)
}
# Binary treated case has a common extra response in II and III.
x[, log_price := log_price + .15 * post_mh_z3 + .10 * mh_1994_z3]
m <- feols(cl_ddd_formula(FALSE, FALSE, "+ area"), x, notes = FALSE)
stopifnot(abs(coef(m)[["post_mh_tr"]] - .11) < 1e-8, abs(coef(m)[["mh_1994_tr"]] - .08) < 1e-8)
cat("CoreLogic DDD formulas recover known binary, zone-specific and annual effects.\n")
