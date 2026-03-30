# Constructs a county-level crosswalk of HUD wind zone designations from
# 24 CFR § 3280.305(c)(2), the Manufactured Home Construction and Safety
# Standards. Wind Zone I is the residual (all counties not listed in II or III).
#
# Notes on known gaps:
#   - "Princess Anne" (VA, WZ2): consolidated into Virginia Beach in 1963;
#     no 2021 census entry. Mapped here to Virginia Beach's pid6.
#   - Alaska "coastal regions" (WZ3): defined by the ANSI/ASCE 7-88 isotach
#     map, not by county boundaries. Not included.
#   - Florida WZ2: eCFR specifies "all counties except WZ3"; expanded here
#     using the census crosswalk.
#   - Hawaii WZ3: eCFR specifies "entire state"; expanded here using the
#     census crosswalk.

rm(list = ls())
library(here)
library(data.table)
library(readxl)
library(rvest)
library(stringr)

readRenviron(here(".Renviron"))
data_path <- Sys.getenv("DATA_PATH")

# =====================================================================
# 1. Download and parse 24 CFR § 3280.305 wind zone county lists
# =====================================================================

url <- paste0(
  "https://www.ecfr.gov/current/title-24/chapter-XX/part-3280",
  "/subpart-D/section-3280.305"
)
# eCFR blocks requests without a browser-like User-Agent; download via curl
tmp_html <- tempfile(fileext = ".html")
system2(
  "curl",
  args = c(
    "-sL", shQuote(url),
    "-H", shQuote("User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"),
    "-H", shQuote("Accept: text/html"),
    "--max-time", "30",
    "-o", shQuote(tmp_html)
  )
)
html <- read_html(tmp_html)

paras       <- html |> html_elements("p")
para_titles <- paras |> html_attr("data-title")

idx_wz2  <- which(para_titles == "3280.305(c)(2)(ii)")
idx_wz3  <- which(para_titles == "3280.305(c)(2)(iii)")
# grepl() returns FALSE (not NA) for NA inputs, avoiding min(integer(0))
idx_stop <- min(which(
  grepl("3280\\.305\\(c\\)\\(2\\)\\(iv\\)|3280\\.305\\(c\\)\\(3\\)", para_titles)
))

# Parse paragraphs of the form "<em>StateName:</em> county1, county2, ..."
# Returns a list of (state, county_text) pairs.
parse_zone_entries <- function(paras, from_idx, to_idx) {
  result <- list()
  for (i in seq(from_idx + 1L, to_idx - 1L)) {
    p      <- paras[[i]]
    em     <- html_element(p, "em")
    em_txt <- html_text2(em)
    if (is.na(em_txt) || !str_detect(em_txt, ":$")) next
    state <- str_remove(em_txt, ":$") |> str_trim()
    # Skip non-state headings ("Local governments:", "States and Territories:")
    if (str_detect(state, regex("governments|Territories", ignore_case = TRUE))) next
    county_text <- str_remove(html_text2(p), fixed(em_txt)) |> str_trim()
    result[[length(result) + 1L]] <- list(state = state, county_text = county_text)
  }
  result
}

wz2_entries <- parse_zone_entries(paras, idx_wz2, idx_wz3)
wz3_entries <- parse_zone_entries(paras, idx_wz3, idx_stop)

# Split a comma/and-separated county string into individual names.
parse_counties <- function(text) {
  text <- str_remove(text, "^(Parishes|Cities) of\\s+")
  text <- str_remove(text, "\\.$")
  # Normalize Oxford-comma "X, and Y" -> "X, Y" before splitting
  text <- str_replace_all(text, ",\\s+and\\s+", ", ")
  parts <- str_split(text, ",\\s+| and ")[[1L]]
  parts <- str_trim(parts)
  parts[nchar(parts) > 0L]
}

build_zone_dt <- function(entries, wind_zone) {
  rbindlist(lapply(entries, function(e) {
    if (e$state == "Florida" && str_detect(e$county_text, "^All counties")) {
      # Expanded later from the census crosswalk
      return(data.table(state = "Florida", name_ecfr = "ALL_EXCEPT_WZ3"))
    }
    data.table(state = e$state, name_ecfr = parse_counties(e$county_text))
  }))[, wind_zone := wind_zone]
}

dt_wz2 <- build_zone_dt(wz2_entries, "II")
dt_wz3 <- build_zone_dt(wz3_entries, "III")

# Hawaii: entire state is WZ3 (States/Territories subparagraph) — expand later
dt_wz3 <- rbindlist(list(
  dt_wz3,
  data.table(state = "Hawaii", name_ecfr = "ALL", wind_zone = "III")
))

dt_ecfr <- rbindlist(list(dt_wz2, dt_wz3))

# =====================================================================
# 2. Load the census Government Units crosswalk
# =====================================================================

xwalk_path <- file.path(
  data_path, "crosswalk", "census-govt-units", "2021",
  "Govt_Units_2021_Final.xlsx"
)

dt_xwalk <- as.data.table(read_excel(xwalk_path, sheet = "General Purpose"))
setnames(dt_xwalk, names(dt_xwalk), tolower(names(dt_xwalk)))
setnames(dt_xwalk,
  old = c("census_id_pid6", "unit_name", "unit_type",
          "state", "fips_state", "fips_county", "county"),
  new = c("id_pid6", "unit_name", "unit_type",
          "state_abbrev", "fips_state", "fips_county", "county_field")
)
dt_xwalk[, id_pid6 := as.character(id_pid6)]
dt_xwalk <- dt_xwalk[is_active == "Y"]

# County-equivalent units:
#  (a) Standard county units
dt_county_units <- dt_xwalk[unit_type == "1 - COUNTY"]

#  (b) Virginia independent cities (listed in WZ2 as "Cities of ...")
dt_va_cities <- dt_xwalk[
  unit_type == "2 - MUNICIPAL" & state_abbrev == "VA" &
    str_detect(unit_name, "^CITY OF ")
]

#  (c) Louisiana consolidated city-parishes / independent cities that have no
#      separate UNIT_TYPE "1 - COUNTY" entry: East Baton Rouge, Terrebonne,
#      and Orleans (City of New Orleans)
dt_la_consol <- dt_xwalk[
  unit_type == "2 - MUNICIPAL" & state_abbrev == "LA" &
    (str_detect(unit_name, "CITY-PARISH OF|CONSOLIDATED GOVERNMENT OF") |
       unit_name == "CITY OF NEW ORLEANS")
]

#  (d) Nantucket, MA: the county and the Town of Nantucket are coextensive;
#      the census crosswalk lists it as UNIT_TYPE "3 - TOWNSHIP"
dt_nantucket <- dt_xwalk[unit_name == "TOWN OF NANTUCKET"]

#  (e) City and County of Honolulu: no separate UNIT_TYPE "1 - COUNTY" entry
dt_honolulu <- dt_xwalk[unit_name == "CITY AND COUNTY OF HONOLULU"]

dt_match_units <- rbindlist(
  list(dt_county_units, dt_va_cities, dt_la_consol, dt_nantucket, dt_honolulu),
  fill = TRUE
)[, .(id_pid6, unit_name, unit_type, state_abbrev, fips_state, fips_county, county_field)
][, countyfp := paste0(
    str_pad(fips_state,  2, pad = "0"),
    str_pad(fips_county, 3, pad = "0")
  )
][, c("fips_state", "fips_county") := NULL]

# State name -> abbreviation lookup
state_abbrev_map <- c(
  Alabama = "AL", Alaska = "AK", Florida = "FL", Georgia = "GA",
  Hawaii = "HI", Louisiana = "LA", Maine = "ME", Massachusetts = "MA",
  Mississippi = "MS", "North Carolina" = "NC", "South Carolina" = "SC",
  Texas = "TX", Virginia = "VA"
)

# =====================================================================
# 3. Normalize names for matching
# =====================================================================

norm <- function(x) {
  x |>
    str_to_upper() |>
    # Remove leading unit-type prefix
    str_remove("^(COUNTY OF|PARISH OF|CITY OF|TOWN OF|CITY-PARISH OF|CONSOLIDATED GOVERNMENT OF)\\s+") |>
    # City-parish names take the form "CityName-CountyName" (e.g.
    # "BATON ROUGE-EAST BATON ROUGE"): keep the county part
    str_replace("^[A-Z][A-Z ]*-(EAST |WEST |NORTH |SOUTH )", "\\1") |>
    str_remove_all("[.\\-']") |>
    str_squish()
}

# Corrections for eCFR names that differ from census unit names after
# normalization (spelling differences, consolidations, renames)
ecfr_corrections <- c(
  "VERMILLION"  = "VERMILION",   # LA WZ2 (census: "VERMILION")
  "LA FOURCHE"  = "LAFOURCHE",   # LA WZ3 (census: "LAFOURCHE")
  "TERRABONNE"  = "TERREBONNE",  # LA WZ3 (census: "TERREBONNE")
  "ORLEANS"     = "NEW ORLEANS", # LA WZ3 (consolidated as City of New Orleans)
  "DADE"        = "MIAMIDADE"    # FL WZ3 (renamed Miami-Dade in 1997)
)

dt_match_units[, name_norm := norm(unit_name)]

dt_ecfr[, name_norm    := norm(name_ecfr)]
dt_ecfr[, state_abbrev := state_abbrev_map[state]]
dt_ecfr[
  name_norm %in% names(ecfr_corrections),
  name_norm := ecfr_corrections[name_norm]
]

# Princess Anne (VA) was consolidated into Virginia Beach in 1963 and has no
# 2021 census entry; omit it from the crosswalk (documented in script header)
dt_ecfr <- dt_ecfr[name_ecfr != "Princess Anne"]

# =====================================================================
# 4. Expand Florida WZ2 and Hawaii WZ3 from the census crosswalk
# =====================================================================

# Florida WZ3 normalized names (to exclude from WZ2 expansion)
fl_wz3_norms <- dt_ecfr[state == "Florida" & wind_zone == "III", name_norm]

fl_wz2 <- dt_match_units[
  state_abbrev == "FL" & unit_type == "1 - COUNTY" &
    !name_norm %in% fl_wz3_norms,
  .(state = "Florida", name_ecfr = county_field, wind_zone = "II", id_pid6, countyfp)
]

hi_all <- dt_match_units[
  state_abbrev == "HI",
  .(state = "Hawaii", name_ecfr = county_field, wind_zone = "III", id_pid6, countyfp)
]

# Remove placeholder rows before merging
dt_ecfr_merge <- dt_ecfr[
  !(state == "Florida" & wind_zone == "II") &
    !(state == "Hawaii")
]

# =====================================================================
# 5. Merge with census crosswalk to get id_pid6
# =====================================================================

dt_merged <- merge(
  dt_ecfr_merge,
  dt_match_units[, .(state_abbrev, name_norm, id_pid6, countyfp)],
  by = c("state_abbrev", "name_norm"),
  all.x = TRUE
)

# Report unmatched entries
unmatched <- dt_merged[is.na(id_pid6)]
if (nrow(unmatched) > 0L) {
  warning(
    "Unmatched eCFR entries (check spellings or crosswalk):\n",
    paste(unmatched[, paste0("  ", state, ": ", name_ecfr)], collapse = "\n")
  )
}

# =====================================================================
# 6. Assemble and validate final crosswalk
# =====================================================================

dt_final <- rbindlist(list(
  dt_merged[, .(name_ecfr, id_pid6, countyfp, wind_zone)],
  fl_wz2[,   .(name_ecfr, id_pid6, countyfp, wind_zone)],
  hi_all[,   .(name_ecfr, id_pid6, countyfp, wind_zone)]
))

setorder(dt_final, wind_zone, name_ecfr)

# Sanity checks
stopifnot(
  "Missing id_pid6 after merge" =
    !any(is.na(dt_final$id_pid6)),
  "Duplicate pid6 within wind zone" =
    !anyDuplicated(dt_final[, .(id_pid6, wind_zone)]),
  "A county appears in more than one zone" =
    !anyDuplicated(dt_final[, .(id_pid6)])
)

cat(sprintf(
  "Wind zone crosswalk: %d counties total (%d WZ2, %d WZ3)\n",
  nrow(dt_final),
  dt_final[wind_zone == "II",  .N],
  dt_final[wind_zone == "III", .N]
))

# =====================================================================
# 7. Save
# =====================================================================

out_path <- file.path(data_path, "derived", "ecfr-windzone.csv")
fwrite(dt_final, out_path)
cat("Saved to", out_path, "\n")
