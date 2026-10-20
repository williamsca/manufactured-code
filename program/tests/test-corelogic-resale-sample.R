# Exercise the production SQL on fake transfers around the sale-window bounds.
testthat::test_that("CoreLogic price sample excludes construction-year sales", {
    library(data.table)
    source(here::here("program", "estimate-corelogic", "corelogic-mh-only.R"), local = TRUE)
    source(here::here("program", "estimate-corelogic", "corelogic-price-sample.R"), local = TRUE)
    input <- tempfile("corelogic-resale-")
    dir.create(file.path(input, "sales"), recursive = TRUE)
    manifest <- list(min_vintage = 1985L, max_vintage = 1999L)
    con <- DBI::dbConnect(duckdb::duckdb())
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
    quote_path <- function(x) paste0("'", gsub("'", "''", x, fixed = TRUE), "'")
    read_corelogic <- function(sql) as.data.table(DBI::dbGetQuery(con, sql))
    transfers <- CJ(year_constr = CL_VINTAGES,
        year_sale = c(1998L, 1999L, 2000L, 2023L, 2024L))
    transfers[, `:=`(countyfp = "12086", clip = as.character(.I), mh = 1L,
        sale_price_2000 = 50000, eligible_sale = TRUE,
        date_sale = as.Date(paste0(year_sale, "-07-01")))]
    DBI::dbWriteTable(con, "transfers", transfers)
    DBI::dbExecute(con, paste("COPY transfers TO",
        quote_path(file.path(input, "sales", "fixture.parquet")), "(FORMAT PARQUET)"))
    # Use the test's in-memory reader while executing the production function.
    environment(cl_price_sample) <- environment()
    sample <- cl_price_sample()
    testthat::expect_equal(nrow(sample), 2L * length(CL_VINTAGES))
    testthat::expect_setequal(sample$year_sale, c(2000L, 2023L))
    testthat::expect_true(all(sample$year_sale > sample$year_constr))
})
