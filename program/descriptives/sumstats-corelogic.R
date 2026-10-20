# Descriptive table from the same public aggregates as the paper's estimates.
library(here)
library(data.table)
library(kableExtra)

sales <- fread(file.path(here("output", "corelogic"), "prices", "sample_by_vintage.csv"))
stock <- fread(file.path(here("output", "corelogic"), "quantities", "type_counts_by_vintage.csv"))
means <- fread(file.path(here("output", "corelogic"), "prices", "mh_price_summary.csv"))
sales[, post := as.integer(year_constr >= 1994L)]
stock[, post := as.integer(year_constr >= 1994L)]
counts <- function(x, variable) {
    y <- x[, .(value = sum(get(variable))), by = .(mh, post)]
    y <- y[order(-mh, post)]
    stopifnot(nrow(y) == 4L)
    formatC(y$value, format = "f", digits = 0, big.mark = ",")
}
tab <- data.table(item = c("Transactions", "Surviving homes"))
tab <- cbind(tab, as.data.table(rbind(counts(sales, "sales"), counts(stock, "homes"))))
for (z in 1:3) {
    x <- means[wind_zone == z][order(post)]
    stopifnot(identical(x$post, 0:1))
    for (field in c("mean_2000", "median_2000")) {
        label <- paste0(if (field == "mean_2000") "Mean" else "Median",
                        " MH price, Zone ", c("I", "II", "III")[z])
        row <- as.list(c(label, formatC(x[[field]] / 1000, format = "f", digits = 1), "---", "---"))
        names(row) <- names(tab)
        tab <- rbind(tab, as.data.table(row))
    }
}
writeLines(as.character(kbl(tab, format = "latex", booktabs = TRUE,
    col.names = c("", rep(c("Pre-1994", "Post-1994"), 2)),
    align = c("l", rep("r", 4))) |>
    add_header_above(c(" " = 1, "Manufactured" = 2, "Site-built" = 2))),
    here("output", "descriptives", "sumstats-corelogic.tex"))
