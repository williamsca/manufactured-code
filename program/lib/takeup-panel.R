# County stock grid is the sampling frame; policies/claims supply counts.
# Neither the presence of a policy nor the availability of a tract row can
# determine which eligible homes enter the exposure denominator.
build_takeup_panel <- function(policies, claims, stock, periods, binw = 2L,
                               years_per_period = 5L) {
    bin_year <- function(y) ifelse(y <= 1993L,
        1994L - binw - ((1993L - y) %/% binw) * binw,
        1994L + ((y - 1994L) %/% binw) * binw)
    key <- c("countyfp", "year_constr", "mh")
    stopifnot(data.table::uniqueN(stock, by = key) == nrow(stock),
              !anyNA(stock$homes_n), all(stock$homes_n >= 0))
    eligible <- data.table::copy(stock[homes_n > 0 & year_constr != 1994L])
    stopifnot(nrow(eligible) > 0L)
    p <- merge(policies[period_loss %in% periods], eligible[, ..key], by = key)
    c <- merge(claims[period_loss %in% periods], eligible[, ..key], by = key)
    stopifnot(all(p$policies_n >= 0), all(c$claims_n >= 0))
    p[, period_constr := bin_year(year_constr)]
    c[, period_constr := bin_year(year_constr)]
    eligible[, period_constr := bin_year(year_constr)]
    cell_key <- c("countyfp", "period_loss", "period_constr", "mh")
    num_p <- p[, .(policies_n = sum(policies_n),
                  mand_n = sum(mandatory_purchase_policy_n)), by = cell_key]
    num_c <- c[, .(claims_n = sum(claims_n)), by = cell_key]
    stock_cols <- intersect(c("homes_n", "homes_flat_n", "homes_occupied_n"),
                            names(eligible))
    den <- eligible[, lapply(.SD, sum),
                    by = .(countyfp, period_constr, mh), .SDcols = stock_cols]
    grid <- den[, .(period_loss = periods), by = .(countyfp, period_constr, mh)]
    cell <- merge(grid, den, by = c("countyfp", "period_constr", "mh"))
    cell <- merge(cell, num_p, by = cell_key, all.x = TRUE)
    cell <- merge(cell, num_c, by = cell_key, all.x = TRUE)
    for (v in c("policies_n", "mand_n", "claims_n"))
        data.table::set(cell, which(is.na(cell[[v]])), v, 0)
    stopifnot(sum(cell$policies_n) == sum(p$policies_n),
              sum(cell$claims_n) == sum(c$claims_n),
              nrow(cell) == nrow(den) * length(periods),
              data.table::uniqueN(cell, by = cell_key) == nrow(cell))
    cell[, `:=`(geo = countyfp, statefp = substr(countyfp, 1L, 2L),
                post1994 = as.integer(period_constr >= 1994L))]
    cell[, post_mh := post1994 * mh]
    cell[, log_home_yrs := log(homes_n * years_per_period)]
    if ("homes_flat_n" %in% names(cell))
        cell[, log_home_yrs_flat := log(homes_flat_n * years_per_period)]
    # A zero-policy cell contributes to per-home rates, but has no exposure
    # for claims per policy. Exclude it only from that outcome's fit.
    cell[, log_policy_yrs := fifelse(policies_n > 0, log(policies_n), NA_real_)]
    cell[, `:=`(nonmand_n = policies_n - mand_n,
                claim_rate = fifelse(policies_n > 0, claims_n / policies_n, NA_real_),
                policies_per_1k_homes_yr = 1000 * policies_n / (homes_n * years_per_period),
                claims_per_1k_homes_yr = 1000 * claims_n / (homes_n * years_per_period))]
    stopifnot(all(cell$nonmand_n >= 0))
    cell[]
}
