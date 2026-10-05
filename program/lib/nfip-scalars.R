# Reads the NFIP scalar files written by the estimate-nfip-*.R scripts into one
# statistic/value table. A missing file or a statistic exported by two scripts
# is an error rather than a silent gap or duplicate.
NFIP_SCALAR_PARTS <- c("claims", "composition", "takeup", "windzone")

read_nfip_scalars <- function(parts = NFIP_SCALAR_PARTS) {
    files <- here::here("output", "results",
                        paste0("nfip-", parts, "-scalars.csv"))
    missing <- files[!file.exists(files)]
    if (length(missing)) stop("missing NFIP scalar file(s): ",
                              paste(basename(missing), collapse = ", "))
    sc <- data.table::rbindlist(lapply(files, data.table::fread))
    stopifnot(!anyDuplicated(sc$statistic))
    sc
}
