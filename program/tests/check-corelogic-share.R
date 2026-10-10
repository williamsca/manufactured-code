# Exercise the production share formulas without loading licensed records.
library(data.table)
library(fixest)
expressions <- parse("program/estimate/estimate-corelogic-share.R")
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
