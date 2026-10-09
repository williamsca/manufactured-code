# Exercise the production SQL joins on missing snapshot matches, replacement
# structures, ambiguous same-day transfers and the derived MH indicator.
library(DBI)
library(duckdb)
library(data.table)
library(here)
source(here("program", "lib", "corelogic-sample.R"))

local({
    con <- dbConnect(duckdb())
    on.exit(dbDisconnect(con, shutdown = TRUE))
    pb <- data.table(clip = c("stable", "replaced", "snapshot", "unflagged", "duplicate", "nonres"),
        mobile_home_indicator = c("Y", "Y", "Y", NA, "Y", "Y"),
        property_indicator_code = c("10", "10", "10", "10", "10", "20"),
        land_use_code = c("137", "138", "138", "137", "137", "137"),
        year_built = c(1995L, 2001L, 1990L, 1990L, 1990L, 1990L),
        effective_year_built = c(1995L, 2001L, 1990L, 1990L, 1990L, 1990L),
        parcel_level_latitude = 27, parcel_level_longitude = -81,
        block_level_latitude = 27, block_level_longitude = -81,
        universal_building_square_feet = 1000, land_square_footage = 4000,
        total_value_calculated = 100000, land_value_calculated = 20000,
        improvement_value_calculated = 80000, calculated_value_source_code = "M")
    ot <- data.table(clip = c("stable", "stable", "replaced", "replaced", "gone", "snapshot",
        "unflagged", "duplicate", "duplicate", "fallback", "nonres", "sb"),
        owner_transfer_composite_transaction_id = paste0("id", 1:12), countyfp = "12001",
        mobile_home_indicator = c("Y", "Y", "Y", "Y", "Y", "Y", NA, "Y", "Y", "Y", "Y", NA),
        property_indicator_code_static = c(rep("10", 10), "20", "10"),
        land_use_code_static = c("137", "137", "137", "138", "137", "138", "137", "137", "137", "137", "137", "100"),
        actual_year_built_static = c(1995L, 1995L, 1990L, 2001L, 1990L, NA, 1990L, 1990L, 1990L, 1990L, 1990L, 1990L),
        effective_year_built_static = 2005L, total_number_of_buildings = 1L,
        sale_derived_date = as.Date(c("2000-01-01", "2005-01-01", "2000-01-01", "2005-01-01", "2000-01-01",
            "2000-01-01", "2000-01-01", "2000-01-01", "2000-01-01", NA, "2000-01-01", "2000-01-01")),
        sale_derived_recording_date = as.Date("2000-01-15"), sale_amount = 100000,
        primary_category_code = "A", deed_category_type_code = "G", sale_type_code = "F",
        multi_or_split_parcel_code = NA_character_, partial_interest_indicator = NA_character_,
        ownership_transfer_percentage = 100L, interfamily_related_indicator = 0L,
        short_sale_indicator = 0L, foreclosure_reo_indicator = 0L, foreclosure_reo_sale_indicator = 0L)
    ot[owner_transfer_composite_transaction_id == "id2", sale_amount := 150000]
    blank <- copy(ot[clip == "gone"])
    blank[, `:=`(clip = "blank_code", owner_transfer_composite_transaction_id = "id13", sale_type_code = NA_character_)]
    partial <- copy(blank)
    partial[, `:=`(clip = "partial_code", owner_transfer_composite_transaction_id = "id14", sale_type_code = "P")]
    ot <- rbindlist(list(ot, blank, partial))
    dbWriteTable(con, "pb", as.data.frame(pb))
    dbWriteTable(con, "ot", as.data.frame(ot))
    dbWriteTable(con, "wind_zone", data.frame(countyfp = "12001", wind_zone = 2L))
    dbWriteTable(con, "cpi", data.frame(year = c(2000L, 2005L), cpi_ratio = c(1, 1.1)))
    cl_build_transfers(con, 1984L, 1999L, 1990L, 2023L)
    tr <- as.data.table(dbGetQuery(con, "SELECT * FROM transfers"))
    stopifnot(!("unflagged" %in% tr$clip))
    stopifnot(isTRUE(all.equal(tr[clip == "nonres", mh], 1L)))
    stopifnot(!(tr[clip == "nonres", dwelling]))
    stopifnot(!(tr[clip == "gone", pb_matched]))
    stopifnot(tr[clip == "gone", analysis_ready])
    stopifnot(tr[clip == "gone", analysis_ready_strict])
    stopifnot(tr[clip == "blank_code", analysis_ready])
    stopifnot(!tr[clip == "blank_code", analysis_ready_strict])
    stopifnot(!tr[clip == "partial_code", analysis_ready])
    stopifnot(isTRUE(all.equal(tr[clip == "snapshot", vintage_source], "snapshot_only")))
    stopifnot(!(tr[clip == "snapshot", eligible_sale]))
    stopifnot(!(any(tr[clip == "duplicate", eligible_sale])))
    stopifnot(isTRUE(all.equal(tr[clip == "fallback", date_source], "recording")))
    stopifnot(isTRUE(all.equal(tr[clip == "sb", mh], 0L)))
    stopifnot(isTRUE(all.equal(tr[clip == "gone", year_constr], 1990L))) # effective year is not original vintage
    stopifnot(isTRUE(all.equal(tr[owner_transfer_composite_transaction_id == "id2", sale_price_2000], 150000 / 1.1)))
    cl_build_pairs(con, 1984L, 1999L, 1990L, 2023L)
    pairs <- as.data.table(dbGetQuery(con, "SELECT * FROM pairs"))
    stopifnot(isTRUE(all.equal(nrow(pairs), 2L)))
    stopifnot(isTRUE(all.equal(pairs[clip == "stable", log_price_change], log(1.5))))
    stopifnot(pairs[clip == "stable", analysis_ready])
    stopifnot(isTRUE(all.equal(pairs[clip == "replaced", vintage_pre], 1990L)))
    stopifnot(isTRUE(all.equal(pairs[clip == "replaced", post1994_pre], 0L)))
    stopifnot(isTRUE(all.equal(pairs[clip == "replaced", vintage_post], 2001L)))
    stopifnot(!(pairs[clip == "replaced", stable_structure]))
    stopifnot(!(pairs[clip == "replaced", analysis_ready]))
})
