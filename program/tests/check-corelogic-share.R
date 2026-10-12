# Exercise the production share formulas without loading licensed records.
library(data.table)
library(fixest)
expressions <- parse("program/corelogic/estimate-corelogic-share.R")
for (e in expressions) {
    if (is.call(e) && identical(e[[1]], as.name("<-")) && identical(e[[2]], as.name("forms"))) eval(e)
}
stopifnot(exists("forms"), length(forms) == 6)
x <- CJ(county = 1:8, wind_zone = 1:3, year_constr = 1989:1999)
x[, countyfp := sprintf("%02d%03d", wind_zone, county)]
x[, `:=`(homes = 1000 + county * 20, post = as.integer(year_constr >= 1994),
    tr = as.integer(wind_zone >= 2), z2 = as.integer(wind_zone == 2), z3 = as.integer(wind_zone == 3))]
x[, `:=`(post_tr = post * tr, post_z2 = post * z2, post_z3 = post * z3)]
x[, share := .2 + county/1000 + wind_zone/100 + .02 * post]
m <- feols(forms$national_static, x, weights = ~homes, notes = FALSE)
stopifnot(abs(coef(m)[["post"]] - .02) < 1e-8)
m <- feols(forms$national_dynamic, x, weights = ~homes, notes = FALSE)
stopifnot(length(coef(m)) == 10, abs(coef(m)[["year_constr::1992"]]) < 1e-8,
    abs(coef(m)[["year_constr::1994"]] - .02) < 1e-8)
x[, share := share + .001 * (year_constr - 1993) + .03 * post_z2 - .01 * post_z3]
m <- feols(forms$separate_static, x, weights = ~homes, notes = FALSE)
stopifnot(max(abs(coef(m) - c(.03,-.01))) < 1e-8)
m <- feols(forms$separate_dynamic, x, weights = ~homes, notes = FALSE)
for (key in c("z2", "z3")) {
    b <- coef(m)[grepl(paste0(":",key,"$"), names(coef(m)))]
    v <- as.integer(sub("year_constr::([0-9]+):.*", "\\1", names(b)))
    stopifnot(length(b) == 10, max(abs(b - c(z2=.03,z3=-.01)[[key]] * (v>=1994))) < 1e-8)
}
x[, share := share + .04 * post_z3]
for (id in c("pooled_static", "pooled_dynamic")) {
    m <- feols(forms[[id]], x, weights = ~homes, notes = FALSE)
    if (id == "pooled_static") stopifnot(abs(coef(m)[["post_tr"]] - .03) < 1e-8)
    else {
        b <- coef(m); v <- as.integer(sub("year_constr::([0-9]+):.*", "\\1", names(b)))
        stopifnot(length(b) == 10, max(abs(b - .03 * (v>=1994))) < 1e-8)
    }
}
cat("CoreLogic share formulas recover national and zone contrasts in share units.\n")

source("program/lib/corelogic-share.R")
y <- CJ(county = 1:8, wind_zone = 1:3, tract = 1:3, post = 0:1)
y[, `:=`(countyfp = sprintf("%02d%03d", wind_zone, county), homes = 1000 + county * 20)]
y[, tractfp := paste0(countyfp, sprintf("%06d", tract))]
y[, `:=`(post_z2 = post * (wind_zone == 2), post_z3 = post * (wind_zone == 3))]
y[, share_pp := 20 + county/10 + wind_zone + 2 * post + tract/2 + 3 * post_z2 - post_z3]
a <- feols(cl_share_static_formula(), y, weights = ~homes, notes = FALSE)
b <- feols(cl_share_static_formula(tract = TRUE), y, weights = ~homes, notes = FALSE)
stopifnot(max(abs(coef(a)[c("post_z2", "post_z3")] - c(3,-1))) < 1e-8,
    max(abs(coef(b)[c("post_z2", "post_z3")] - c(3,-1))) < 1e-8)
# The weighted cell model equals an unweighted home-level indicator regression.
y[, mh_homes := as.integer(round(homes * share_pp / 100))]
y[, share_pp := 100 * mh_homes / homes]
homes <- y[, .(mh = c(rep(100, mh_homes), rep(0, homes - mh_homes))),
    by = .(countyfp, tractfp, post, post_z2, post_z3)]
m <- feols(cl_share_static_formula(tract = TRUE), y, weights = ~homes, notes = FALSE)
individual <- feols(mh ~ post_z2 + post_z3 | countyfp + post + tractfp, homes, notes = FALSE)
stopifnot(max(abs(coef(m) - coef(individual))) < 1e-8)
cat("Static share tables recover known pp effects and parcel-level weighting.\n")

source("program/tests/check-corelogic-mh-only.R")
