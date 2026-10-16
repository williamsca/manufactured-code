# Formulas for the county x vintage-bin quantity design; shared with
# program/tests/test-census-quantity.R. Columns 1-2 take MH rows only, 3-4 both
# types: (1) county + bin FE; (2) county + state x bin; (3) county x type +
# county x bin + type x bin; (4) state x bin x type in place of type x bin.
# `ref` is the omitted vintage bin in the dynamic version.
ladder_formula <- function(k) {
    rhs <- if (k <= 2) "post_z2 + post_z3" else "post_mh_z2 + post_mh_z3"
    fe <- switch(k,
        "countyfp + bin",
        "countyfp + statefp^bin",
        "countyfp^mh + countyfp^bin + mh^bin",
        "countyfp^mh + countyfp^bin + statefp^bin^mh")
    as.formula(paste("homes ~", rhs, "|", fe))
}
dynamic_formula <- function(k, ref = "1990_1994") {
    rhs <- if (k <= 2) sprintf("i(bin, z2, ref = '%s') + i(bin, z3, ref = '%s')", ref, ref)
           else sprintf("i(bin, z2_mh, ref = '%s') + i(bin, z3_mh, ref = '%s')", ref, ref)
    fe <- switch(k,
        "countyfp + bin",
        "countyfp + statefp^bin",
        "countyfp^mh + countyfp^bin + mh^bin",
        "countyfp^mh + countyfp^bin + statefp^bin^mh")
    as.formula(paste("homes ~", rhs, "|", fe))
}
