# This script imports shipments, placements, and prices of manufactured
# homes from the Census Bureau's Survey of Manufactured Housing.

rm(list = ls())
library(here)
library(data.table)
library(readxl)

readRenviron(here(".Renviron"))
data_path <- Sys.getenv("DATA_PATH")

dt_states <- fread(file.path(data_path, "crosswalk", "states.txt"))[
    , .(statefp, state_name)
]

clean_state_name <- function(x) {
    x <- trimws(as.character(x))
    x[x == "Dist. of Columbia"] <- "District of Columbia"
    x
}

coerce_numeric <- function(x) {
    x <- trimws(as.character(x))
    x[x %in% c("", "NA", "S", "Z", "X")] <- NA_character_
    suppressWarnings(as.numeric(x))
}

import_state_shipments_annual <- function() {
    mhs_annual <- file.path(
        data_path, "data", "census-mhs", "annual_shipmentstostates.xlsx"
    )
    dt <- as.data.table(read_xlsx(
        mhs_annual,
        skip = 4,
        .name_repair = "minimal"
    ))

    dt <- dt[!grepl("Totals|Pending", State) & !is.na(State)]
    dt[, State := clean_state_name(State)]

    year_cols <- setdiff(names(dt), "State")
    for (col in year_cols) {
        set(dt, j = col, value = coerce_numeric(dt[[col]]))
    }

    dt <- melt(
        dt,
        id.vars = "State",
        variable.name = "year",
        value.name = "shipments",
        variable.factor = FALSE
    )

    dt[, year := as.integer(year)]
    dt <- merge(
        dt,
        dt_states,
        by.x = "State",
        by.y = "state_name",
        all.x = TRUE
    )

    stopifnot(nrow(dt[is.na(statefp)]) == 0L)

    setnames(dt, "State", "state_name")
    setcolorder(dt, c("statefp", "state_name", "year", "shipments"))
    dt[order(statefp, year)]
}

import_state_shipments_monthly <- function() {
    mhs_monthly <- file.path(
        data_path, "data", "census-mhs", "monthly_shipmentstostates.xlsx"
    )
    sheets <- excel_sheets(mhs_monthly)

    rbindlist(lapply(sheets, function(sheet) {
        dt <- as.data.table(read_xlsx(
            mhs_monthly,
            sheet = sheet,
            col_names = FALSE,
            .name_repair = "minimal"
        ))
        setnames(dt, paste0("V", seq_len(ncol(dt))))

        block_starts <- which(trimws(as.character(dt[4])) == "Single- Section")
        month_blocks <- lapply(block_starts, function(start_col) {
            list(
                single = start_col,
                multi = start_col + 1L,
                total = start_col + 2L,
                floors = start_col + 3L
            )
        })

        dt <- dt[6:.N]
        dt[, state_name := clean_state_name(V1)]
        dt <- dt[
            !is.na(state_name) &
            !grepl("Dest\\. Pending|Total", state_name)
        ]

        value_cols <- setdiff(names(dt), c("V1", "state_name"))
        for (col in value_cols) {
            set(dt, j = col, value = coerce_numeric(dt[[col]]))
        }

        cols_single <- names(dt)[as.integer(unlist(lapply(month_blocks, `[[`, "single")))]
        cols_multi <- names(dt)[as.integer(unlist(lapply(month_blocks, `[[`, "multi")))]
        cols_total <- names(dt)[as.integer(unlist(lapply(month_blocks, `[[`, "total")))]
        cols_floors <- names(dt)[as.integer(unlist(lapply(month_blocks, `[[`, "floors")))]

        out <- dt[, .(state_name)]
        out[, year := as.integer(sheet)]

        out[, shipments_single := dt[
            , rowSums(.SD, na.rm = TRUE),
            .SDcols = cols_single
        ]]
        out[, shipments_double := dt[
            , rowSums(.SD, na.rm = TRUE),
            .SDcols = cols_multi
        ]]
        out[, shipments := dt[
            , rowSums(.SD, na.rm = TRUE),
            .SDcols = cols_total
        ]]
        out[, shipment_floors := dt[
            , rowSums(.SD, na.rm = TRUE),
            .SDcols = cols_floors
        ]]

        out
    }), use.names = TRUE, fill = TRUE)
}

import_shipments_national <- function() {
    dt_long <- as.data.table(read_xlsx(
        file.path(data_path, "data", "census-mhs", "shiphist.xlsx"),
        skip = 2,
        col_names = FALSE,
        .name_repair = "minimal"
    ))
    setnames(dt_long, paste0("V", seq_len(ncol(dt_long))))

    current_year <- NA_integer_
    annual_totals <- vector("list", nrow(dt_long))
    idx <- 0L

    for (i in seq_len(nrow(dt_long))) {
        label <- trimws(as.character(dt_long$V1[i]))

        if (grepl("^[0-9]{4}", label)) {
            current_year <- as.integer(sub("^([0-9]{4}).*$", "\\1", label))
            next
        }

        if (grepl("^Total", label) && !is.na(current_year)) {
            idx <- idx + 1L
            annual_totals[[idx]] <- data.table(
                year = current_year,
                shipments = as.integer(round(1000 * coerce_numeric(dt_long$V2[i])))
            )
        }
    }

    dt_long <- rbindlist(annual_totals[seq_len(idx)])

    mhs_annual <- file.path(
        data_path, "data", "census-mhs", "annual_shipmentstostates.xlsx"
    )
    dt_recent <- as.data.table(read_xlsx(
        mhs_annual,
        skip = 4,
        .name_repair = "minimal"
    ))
    dt_recent <- dt_recent[grepl("Totals", State)]
    year_cols <- setdiff(names(dt_recent), "State")

    for (col in year_cols) {
        set(dt_recent, j = col, value = coerce_numeric(dt_recent[[col]]))
    }

    dt_recent <- melt(
        dt_recent,
        id.vars = "State",
        variable.name = "year",
        value.name = "shipments",
        variable.factor = FALSE
    )
    dt_recent <- dt_recent[!is.na(shipments)]
    dt_recent[, year := as.integer(year)]
    dt_recent <- dt_recent[year > max(dt_long$year), .(year, shipments = as.integer(shipments))]

    rbindlist(list(dt_long, dt_recent), use.names = TRUE)[order(year)]
}

import_nat_status_monthly <- function() {
    dt <- as.data.table(read_xlsx(
        file.path(data_path, "data", "census-mhs", "mhstabsplcstat.xlsx"),
        sheet = "Manufactured Homes Status",
        col_names = FALSE,
        .name_repair = "minimal"
    ))
    setnames(dt, paste0("V", seq_len(ncol(dt))))

    current_year <- NA_integer_
    out <- vector("list", nrow(dt))
    idx <- 0L

    for (i in seq_len(nrow(dt))) {
        label <- trimws(as.character(dt$V1[i]))

        if (grepl("^[0-9]{4}$", label)) {
            current_year <- as.integer(label)
            next
        }

        if (!is.na(current_year) && grepl("^[A-Za-z]", label)) {
            idx <- idx + 1L
            out[[idx]] <- data.table(
                year = current_year,
                month = label,
                shipments = coerce_numeric(dt$V2[i]),
                placements = coerce_numeric(dt$V4[i]),
                shipments_single = coerce_numeric(dt$V10[i]),
                placements_single = coerce_numeric(dt$V12[i]),
                shipments_double = coerce_numeric(dt$V18[i]),
                placements_double = coerce_numeric(dt$V20[i])
            )
        }
    }

    rbindlist(out[seq_len(idx)])
}

import_nat_prices_monthly <- function() {
    dt <- as.data.table(read_xlsx(
        file.path(data_path, "data", "census-mhs", "mhstabavgsls.xlsx"),
        sheet = "Average Sales Price",
        col_names = FALSE,
        .name_repair = "minimal"
    ))
    setnames(dt, paste0("V", seq_len(ncol(dt))))

    current_year <- NA_integer_
    out <- vector("list", nrow(dt))
    idx <- 0L

    for (i in seq_len(nrow(dt))) {
        label <- trimws(as.character(dt$V1[i]))

        if (grepl("^[0-9]{4}$", label)) {
            current_year <- as.integer(label)
            next
        }

        if (!is.na(current_year) && grepl("^[A-Za-z]", label)) {
            idx <- idx + 1L
            out[[idx]] <- data.table(
                year = current_year,
                month = label,
                avg_sales_price = coerce_numeric(dt$V2[i]),
                avg_sales_price_single = coerce_numeric(dt$V3[i]),
                avg_sales_price_double = coerce_numeric(dt$V4[i])
            )
        }
    }

    rbindlist(out[seq_len(idx)])
}

weighted_mean_safe <- function(value, weight) {
    keep <- !is.na(value) & !is.na(weight) & weight > 0
    if (!any(keep)) {
        return(NA_real_)
    }
    sum(value[keep] * weight[keep]) / sum(weight[keep])
}

sum_or_na <- function(x) {
    if (all(is.na(x))) {
        return(NA_real_)
    }
    sum(x, na.rm = TRUE)
}

import_nat_status_and_prices_recent <- function() {
    dt_status_monthly <- import_nat_status_monthly()
    dt_price_monthly <- import_nat_prices_monthly()

    dt_status_annual <- dt_status_monthly[
        ,
        .(
            shipments = sum_or_na(shipments),
            placements = sum_or_na(placements),
            shipments_single = sum_or_na(shipments_single),
            placements_single = sum_or_na(placements_single),
            shipments_double = sum_or_na(shipments_double),
            placements_double = sum_or_na(placements_double)
        ),
        by = year
    ]

    dt_price_annual <- merge(
        dt_price_monthly,
        dt_status_monthly[, .(
            year, month,
            shipments, shipments_single, shipments_double
        )],
        by = c("year", "month"),
        all = FALSE
    )[
        ,
        .(
            avg_sales_price = round(weighted_mean_safe(avg_sales_price, shipments)),
            avg_sales_price_single = round(weighted_mean_safe(
                avg_sales_price_single, shipments_single
            )),
            avg_sales_price_double = round(weighted_mean_safe(
                avg_sales_price_double, shipments_double
            ))
        ),
        by = year
    ]

    merge(dt_status_annual, dt_price_annual, by = "year", all = TRUE)
}

import_hist_state_or_nat <- function(file, value_stub, scale = 1) {
    skip_n <- if (grepl("avgslsprice", file)) 3 else 2

    dt <- as.data.table(read_xlsx(
        file.path(data_path, "data", "census-mhs", file),
        skip = skip_n,
        col_names = FALSE,
        .name_repair = "minimal"
    ))

    years <- seq(2013, 1980, -1)
    types <- c("tot", "single", "double")
    value_names <- as.vector(rbind(
        paste0(years, "_tot"),
        paste0(years, "_single"),
        paste0(years, "_double")
    ))

    setnames(dt, c("region", "state_name", value_names))

    dt[, name := clean_state_name(fifelse(
        is.na(state_name) | trimws(state_name) == "",
        region,
        state_name
    ))]

    keep_names <- c("United States", dt_states$state_name)
    dt <- dt[name %in% keep_names]

    dt <- melt(
        dt,
        id.vars = "name",
        measure.vars = value_names,
        variable.name = "year_type",
        value.name = "value",
        variable.factor = FALSE
    )

    dt[, value := coerce_numeric(value) * scale]
    dt[, c("year", "type") := tstrsplit(year_type, "_", fixed = TRUE)]
    dt[, year := as.integer(year)]

    dt <- dcast(dt, name + year ~ type, value.var = "value")
    setnames(
        dt,
        c("tot", "single", "double"),
        paste0(value_stub, c("", "_single", "_double"))
    )

    dt
}

print_coverage <- function(dt, label) {
    cat("\n", label, "\n", sep = "")
    cat("Rows:", format(nrow(dt), big.mark = ","), "\n")

    if ("statefp" %in% names(dt)) {
        cat("States:", uniqueN(dt$statefp), "\n")
    }

    if ("year" %in% names(dt)) {
        year_rng <- dt[!is.na(year), range(year)]
        cat("Years:", year_rng[1], "-", year_rng[2], "\n")
    }

    core_vars <- setdiff(names(dt), c("statefp", "state_name", "year"))
    coverage <- vapply(core_vars, function(v) sum(!is.na(dt[[v]])), numeric(1))
    print(data.table(variable = names(coverage), non_missing = as.integer(coverage)))
}

# Build state-year data ----
dt_ship_state_annual <- import_state_shipments_annual()
dt_ship_state_monthly <- import_state_shipments_monthly()

dt_ship_state <- merge(
    dt_ship_state_annual,
    dt_ship_state_monthly,
    by = c("state_name", "year"),
    all = TRUE
)
dt_ship_state <- merge(
    dt_ship_state,
    dt_states,
    by = "state_name",
    all.x = TRUE,
    suffixes = c("", "_match")
)
dt_ship_state[is.na(statefp), statefp := statefp_match]
dt_ship_state[, statefp_match := NULL]
dt_ship_state[, shipments := fifelse(!is.na(shipments.x), shipments.x, shipments.y)]
dt_ship_state[, c("shipments.x", "shipments.y") := NULL]
setcolorder(
    dt_ship_state,
    c("statefp", "state_name", "year", "shipments", "shipments_single",
      "shipments_double", "shipment_floors")
)

dt_place_state <- import_hist_state_or_nat("place_hist.xlsx", "placements", scale = 1000)
dt_place_state <- dt_place_state[name != "United States"]
setnames(dt_place_state, "name", "state_name")

dt_price_state <- import_hist_state_or_nat("avgslsprice_hist.xlsx", "avg_sales_price")
dt_price_state <- dt_price_state[name != "United States"]
setnames(dt_price_state, "name", "state_name")

dt_state_year <- Reduce(function(x, y) merge(x, y, by = c("state_name", "year"), all = TRUE), list(
    dt_ship_state,
    dt_place_state,
    dt_price_state
))

dt_state_year[, state_name := clean_state_name(state_name)]
dt_state_year <- merge(
    dt_state_year,
    dt_states,
    by = "state_name",
    all.x = TRUE,
    suffixes = c("", "_match")
)
dt_state_year[is.na(statefp), statefp := statefp_match]
dt_state_year[, statefp_match := NULL]

stopifnot(nrow(dt_state_year[is.na(statefp)]) == 0L)

setcolorder(dt_state_year, c(
    "statefp", "state_name", "year",
    "shipments", "shipments_single", "shipments_double", "shipment_floors",
    "placements", "placements_single", "placements_double",
    "avg_sales_price", "avg_sales_price_single", "avg_sales_price_double"
))
setorder(dt_state_year, statefp, year)

# Build national-year data ----
dt_ship_nat <- import_shipments_national()
dt_nat_recent <- import_nat_status_and_prices_recent()
dt_place_nat <- import_hist_state_or_nat("place_hist.xlsx", "placements", scale = 1000)[
    name == "United States", .(year, placements, placements_single, placements_double)
]
dt_price_nat <- import_hist_state_or_nat("avgslsprice_hist.xlsx", "avg_sales_price")[
    name == "United States", .(year, avg_sales_price, avg_sales_price_single, avg_sales_price_double)
]

dt_nat_year <- Reduce(function(x, y) merge(x, y, by = "year", all = TRUE), list(
    dt_ship_nat,
    dt_nat_recent,
    dt_place_nat,
    dt_price_nat
))
dt_nat_year[, shipments := fifelse(!is.na(shipments.x), shipments.x, shipments.y)]
dt_nat_year[, placements := fifelse(!is.na(placements.x), placements.x, placements.y)]
dt_nat_year[, placements_single := fifelse(
    !is.na(placements_single.x), placements_single.x, placements_single.y
)]
dt_nat_year[, placements_double := fifelse(
    !is.na(placements_double.x), placements_double.x, placements_double.y
)]
dt_nat_year[, avg_sales_price := fifelse(
    !is.na(avg_sales_price.x), avg_sales_price.x, avg_sales_price.y
)]
dt_nat_year[, avg_sales_price_single := fifelse(
    !is.na(avg_sales_price_single.x), avg_sales_price_single.x, avg_sales_price_single.y
)]
dt_nat_year[, avg_sales_price_double := fifelse(
    !is.na(avg_sales_price_double.x), avg_sales_price_double.x, avg_sales_price_double.y
)]
dt_nat_year[, c(
    "shipments.x", "shipments.y",
    "placements.x", "placements.y",
    "placements_single.x", "placements_single.y",
    "placements_double.x", "placements_double.y",
    "avg_sales_price.x", "avg_sales_price.y",
    "avg_sales_price_single.x", "avg_sales_price_single.y",
    "avg_sales_price_double.x", "avg_sales_price_double.y"
) := NULL]
setcolorder(dt_nat_year, c(
    "year",
    "shipments", "shipments_single", "shipments_double",
    "placements", "placements_single", "placements_double",
    "avg_sales_price", "avg_sales_price_single", "avg_sales_price_double"
))
setorder(dt_nat_year, year)

print_coverage(dt_state_year, "State-year manufactured housing data")
print_coverage(dt_nat_year, "National manufactured housing data")

# export ----
saveRDS(dt_state_year, here("derived", "mhs-state-year.Rds"))
saveRDS(dt_nat_year, here("derived", "mhs-national-year.Rds"))
