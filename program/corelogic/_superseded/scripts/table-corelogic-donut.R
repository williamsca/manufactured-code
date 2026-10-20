# Four-column appendix table from exported aggregate estimates only.
library(here)
library(data.table)

source(here("program", "estimate-corelogic", "paper-results.R"))
root <- CL_PAPER_COMPARISON
columns <- data.table(column = 1:4,
    analysis = c("prices", "prices", "quantities", "quantities"),
    outcome = c("price", "price", "count", "count"),
    sample = rep(c("baseline", "donut"), 2))

read_column <- function(k) {
    spec <- columns[k]
    path <- file.path(root, spec$sample, spec$analysis)
    manifest <- jsonlite::fromJSON(file.path(path, "manifest.json"))
    expected_build <- if (spec$sample == "baseline") "continental-v3-20261020" else
        "continental-donut-50mi-20261020"
    stopifnot(manifest$status == "complete", basename(manifest$build) == expected_build)
    if (spec$analysis == "prices") {
        stopifnot(identical(manifest$sale_window, c(2000L, 2023L)),
            isTRUE(manifest$existing_homes_only),
            identical(manifest$construction_window, c(1985L, 1999L)))
    }
    x <- fread(file.path(path, "mh_static_ladder.csv"))[
        specification == "ladder_2" & term %in% c("post_z2", "post_z3")]
    stopifnot(nrow(x) == 2L, !anyDuplicated(x$term),
        all(is.finite(x$estimate)), all(is.finite(x$se) & x$se > 0),
        uniqueN(x$n) == 1L, uniqueN(x$counties) == 1L)
    # The baseline appendix columns must reproduce the main paper's column (2).
    if (spec$sample == "baseline") {
        main <- fread(file.path(CL_PAPER_RESULTS, spec$analysis, "mh_static_ladder.csv"))[
            specification == "ladder_2" & term %in% x$term]
        setorder(main, term)
        setorder(x, term)
        stopifnot(isTRUE(all.equal(x[, .(term, estimate, se, n, counties)],
            main[, .(term, estimate, se, n, counties)], check.attributes = FALSE)))
    }
    x[, `:=`(column = k, outcome = spec$outcome, sample = spec$sample,
        zone = as.integer(sub("post_z", "", term)))]
    x[, .(column, outcome, sample, zone, estimate, se, p, n, counties, pct)]
}

# Both samples must use identical analysis code and public county references.
for (analysis in c("prices", "quantities")) {
    hashes <- lapply(c("baseline", "donut"), function(sample) {
        m <- jsonlite::fromJSON(file.path(root, sample, analysis, "manifest.json"))
        h <- unlist(m$code_reference_md5)
        setNames(h, basename(names(h)))
    })
    stopifnot(identical(hashes[[1]], hashes[[2]]))
}
build <- jsonlite::fromJSON(here("output", "corelogic",
    "continental-donut-50mi-20261020", "manifest.json"))
stopifnot(build$status == "complete", isTRUE(build$donut$enabled), build$donut$miles == 50)

estimates <- rbindlist(lapply(columns$column, read_column))
fwrite(estimates, file.path(root, "static-appendix.csv"))
cell <- function(z, field) {
    x <- estimates[zone == z][order(column)]
    if (field == "estimate") {
        stars <- fifelse(x$p < .01, "***", fifelse(x$p < .05, "**",
            fifelse(x$p < .10, "*", "")))
        return(paste0(sprintf("%.3f", x$estimate),
            fifelse(nzchar(stars), paste0("$^{", stars, "}$"), "")))
    }
    sprintf("(%.3f)", x$se)
}
row <- function(label, values) paste0(label, " & ", paste(values, collapse = " & "), " \\\\")
sizes <- estimates[zone == 2][order(column)]
tab <- c(
    "\\begin{tabular}{lcccc}", "\\toprule",
    " & \\multicolumn{2}{c}{Log MH sale price} & \\multicolumn{2}{c}{Surviving MH count} \\\\",
    "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}",
    row("", c("(1)", "(2)", "(3)", "(4)")),
    row("Sample", rep(c("Baseline", "Doughnut"), 2)), "\\midrule",
    row("Zone II $\\times$ post", cell(2, "estimate")), row("", cell(2, "se")),
    row("Zone III $\\times$ post", cell(3, "estimate")), row("", cell(3, "se")),
    "\\midrule", row("State $\\times$ vintage FE", rep("Yes", 4)),
    row("County $\\times$ sale-year FE", c("Yes", "Yes", "---", "---")),
    row("County FE", c("---", "---", "Yes", "Yes")),
    row("Size controls", c("No", "No", "---", "---")),
    row("Estimator", c("OLS", "OLS", "PPML", "PPML")),
    "\\midrule", row("Observations", format(sizes$n, big.mark = ",", trim = TRUE)),
    row("Counties", format(sizes$counties, big.mark = ",", trim = TRUE)),
    "\\bottomrule", "\\end{tabular}")
writeLines(tab, file.path(root, "static-appendix.tex"))
message("Wrote static-appendix.tex and static-appendix.csv")
