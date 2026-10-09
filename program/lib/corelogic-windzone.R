# Reconstruct HUD zones on a verified current + historical county universe.
# Lists: 24 CFR 3280.305(c)(2), official 2020 edition, pp. 57-58:
# https://www.govinfo.gov/content/pkg/CFR-2020-title24-vol5/pdf/CFR-2020-title24-vol5-subtitleB.pdf
# They match research-database's eCFR named lists. geo_county v2026-09-02 also
# contains historical Dade 12025, assigned III separately from Miami-Dade 12086.
# Alaska/territories excluded: this workstream is continental US and DC.
cl_windzone_counties <- function(geo) {
    library(data.table)
    g <- copy(as.data.table(geo))
    stopifnot(all(c("countyfp", "statefp", "name") %in% names(g)), !anyDuplicated(g$countyfp))
    g <- g[as.integer(statefp) <= 56 & !statefp %in% c("02", "15")]
    normalize <- function(x) {
        x <- toupper(x)
        x <- sub("^(COUNTY OF|PARISH OF|CITY OF|TOWN OF|CITY-PARISH OF|CONSOLIDATED GOVERNMENT OF)\\s+", "", x)
        x <- sub("^[A-Z][A-Z ]*-(EAST |WEST |NORTH |SOUTH )", "\\1", x)
        x <- sub("\\s+(CITY AND BOROUGH|CENSUS AREA|MUNICIPALITY|COUNTY|PARISH|BOROUGH|CITY)$", "", x)
        trimws(gsub("\\s+", " ", gsub("[.'-]", "", x)))
    }
    entries <- list(
        list("01", 2L, "Baldwin,Mobile"),
        list("13", 2L, "Bryan,Camden,Chatham,Glynn,Liberty,McIntosh"),
        list("22", 2L, "Acadia,Allen,Ascension,Assumption,Calcasieu,Cameron,East Baton Rouge,East Feliciana,Evangeline,Iberia,Iberville,Jefferson Davis,Lafayette,Livingston,Pointe Coupee,St. Helena,St. James,St. John the Baptist,St. Landry,St. Martin,St. Tammany,Tangipahoa,Vermilion,Washington,West Baton Rouge,West Feliciana"),
        list("23", 2L, "Hancock,Washington"),
        list("25", 2L, "Barnstable,Bristol,Dukes,Nantucket,Plymouth"),
        list("28", 2L, "George,Hancock,Harrison,Jackson,Pearl River,Stone"),
        list("37", 2L, "Beaufort,Brunswick,Camden,Chowan,Columbus,Craven,Currituck,Jones,New Hanover,Onslow,Pamlico,Pasquotank,Pender,Perquimans,Tyrrell,Washington"),
        list("45", 2L, "Beaufort,Berkeley,Charleston,Colleton,Dorchester,Georgetown,Horry,Jasper,Williamsburg"),
        list("48", 2L, "Aransas,Brazoria,Calhoun,Cameron,Chambers,Galveston,Jefferson,Kenedy,Kleberg,Matagorda,Nueces,Orange,Refugio,San Patricio,Willacy"),
        # Princess Anne consolidated into Virginia Beach in 1963, before our vintages.
        list("51", 2L, "Chesapeake,Norfolk,Portsmouth,Virginia Beach"),
        list("12", 3L, "Broward,Charlotte,Collier,Miami-Dade,Franklin,Gulf,Hendry,Lee,Martin,Manatee,Monroe,Palm Beach,Pinellas,Sarasota"),
        list("22", 3L, "Jefferson,Lafourche,Orleans,Plaquemines,St. Bernard,St. Charles,St. Mary,Terrebonne"),
        list("37", 3L, "Carteret,Dare,Hyde"))
    named <- rbindlist(lapply(entries, function(e) data.table(statefp = e[[1]],
        wind_zone = e[[2]], name_norm = normalize(strsplit(e[[3]], ",", fixed = TRUE)[[1]]))))
    g[, name_norm := normalize(name)]
    matches <- merge(named, g, by = c("statefp", "name_norm"), all.x = TRUE)
    if (anyNA(matches$countyfp) || nrow(matches) != nrow(named) || anyDuplicated(matches$countyfp))
        stop("HUD named county match failed or became ambiguous")
    g[, wind_zone := 1L]
    g[statefp == "12", wind_zone := 2L]
    g[matches, on = "countyfp", wind_zone := i.wind_zone]
    historical_dade <- g[countyfp == "12025"]
    if (nrow(historical_dade)) {
        stopifnot(nrow(historical_dade) == 1L, normalize(historical_dade$name) == "DADE")
        g[countyfp == "12025", wind_zone := 3L]
    }
    stopifnot(g[wind_zone == 2, .N] == 144L,
        g[wind_zone == 3, .N] == 25L + nrow(historical_dade),
        g[statefp == "12", .N] == 67L + nrow(historical_dade), !anyDuplicated(g$countyfp))
    g[, .(countyfp, wind_zone, statefp, name)]
}
