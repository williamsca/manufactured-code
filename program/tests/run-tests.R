# Fake-data verification harness. Run via `make test`.
# Each test-*.R file simulates data with a known DGP and checks that the
# production estimating equation recovers the truth (see notes/specs.md).

library(here)
library(testthat)

results <- test_dir(
    here("program", "tests"),
    stop_on_failure = FALSE,
    reporter  = "summary"
)

df <- as.data.frame(results)
if (any(df$failed > 0 | df$error)) {
    stop("make test: one or more fake-data tests failed.", call. = FALSE)
}
