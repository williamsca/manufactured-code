# Shared geographic-coverage safeguard for merges against county/state
# crosswalks (wind zone, housing stock, ...).
#
# The 2026-08-24 Connecticut incident (notes/LOG.md): databuild-nfip.R
# merged the balanced panel onto ecfr_wind_zone with a default INNER join,
# then asserted `!anyNA(wind_zone)` on the result -- which can never fail,
# because an inner join can't produce an unmatched row with an NA in it; it
# just silently drops the row instead. That dropped all of Connecticut
# (~17,700 claims, ~1% of the sample) with no error. The fix is procedural,
# not just the one-off data fix: always LEFT join (all.x = TRUE) against a
# crosswalk, then call one of the checks below on the result.
#
# EXCLUDED_STATEFP documents the sample's own, intentional exclusions (see
# the "state NOT IN (...)" / "!statefp %in% ..." filters in
# databuild-nfip.R / databuild-mhs.R) so a coverage check can tell "known,
# upstream exclusion" from "silent drop to fail on."
EXCLUDED_STATEFP <- c("02", "15") # AK, HI - excluded from the sample by design

#' Fail loudly if a left-joined crosswalk column is NA for any row whose
#' FIPS code is outside EXCLUDED_STATEFP -- i.e. any row the sample itself
#' claims to cover. Use for merges that should have zero tolerance for
#' missingness (e.g. wind zone, which every in-scope county has).
#'
#' @param dt data.table, already left-joined against the crosswalk.
#' @param check_col column to test for NA (e.g. "wind_zone").
#' @param fips_col column holding a state/county/tract FIPS code (its first
#'   two characters are read as statefp).
#' @param label used in the error message, e.g. the calling script + merge.
assert_geo_coverage <- function(dt, check_col, fips_col, label) {
    statefp <- substr(dt[[fips_col]], 1, 2)
    bad <- dt[is.na(dt[[check_col]]) & !statefp %in% EXCLUDED_STATEFP]
    if (nrow(bad) > 0L) {
        bad_fips <- sort(unique(bad[[fips_col]]))
        stop(sprintf(
            paste0(
                "%s: %d row(s) unmatched on '%s' outside the sample's ",
                "documented exclusions (statefp %s). %d distinct %s ",
                "affected: %s%s\n",
                "A silent gap here is exactly how Connecticut's pre-2022 ",
                "county FIPS vanished from the NFIP sample with no error ",
                "on 2026-08-24 (notes/LOG.md) -- fix the crosswalk or the ",
                "merge, don't suppress this check."
            ),
            label, nrow(bad), check_col, paste(EXCLUDED_STATEFP, collapse = ", "),
            length(bad_fips), fips_col,
            paste(utils::head(bad_fips, 15), collapse = ", "),
            if (length(bad_fips) > 15) ", ..." else ""
        ))
    }
    invisible(TRUE)
}

#' Looser variant: fail only if a FIPS code (e.g. a whole county) has NO
#' non-NA rows at all for `check_col`, tolerating partial/expected sparsity
#' within a code (e.g. impute-stock.R's documented dropped-1994 gap) while
#' still catching a wholesale drop of every row for that code.
#'
#' @param key_col FIPS-level grouping column (e.g. "countyfp") -- coverage
#'   is assessed per distinct value of this column, not per row.
#' @param allow_fips FIPS codes to exempt from this check, each requiring a
#'   comment at the call site naming why (e.g. a county created after the
#'   crosswalk's reference vintage). Never use this to silence a code you
#'   have not individually investigated -- that is exactly the blind
#'   suppression this check exists to prevent.
assert_geo_coverage_any <- function(dt, check_col, fips_col, key_col, label,
                                     allow_fips = character(0)) {
    statefp <- substr(dt[[fips_col]], 1, 2)
    cov <- dt[!statefp %in% EXCLUDED_STATEFP, .(
        any_ok = any(!is.na(get(check_col)))
    ), by = key_col]
    bad <- sort(setdiff(cov[any_ok == FALSE][[key_col]], allow_fips))
    if (length(bad) > 0L) {
        stop(sprintf(
            "%s: %d distinct %s with NO non-NA '%s' at all (fully unmatched, not just sparse): %s%s",
            label, length(bad), key_col, check_col,
            paste(utils::head(bad, 15), collapse = ", "),
            if (length(bad) > 15) ", ..." else ""
        ))
    }
    invisible(TRUE)
}
