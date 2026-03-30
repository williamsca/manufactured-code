# Constructs a county-level crosswalk of HUD wind zone designations from
# 24 CFR § 3280.305(c)(2), the Manufactured Home Construction and Safety
# Standards. Wind Zone I is the residual (all counties not listed in II or III).
#
# Notes on known gaps:
#   - "Princess Anne" (VA, WZ2): consolidated into Virginia Beach in 1963;
#     no 2021 census entry. Mapped here to Virginia Beach's pid6.
#   - Alaska "coastal regions" (WZ3): defined by the ANSI/ASCE 7-88 isotach
#     map, not by county boundaries. NOT INCLUDED.
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
    data.table(state = e$state, name_ecfr = parse_counties(e$county_text))
  }))[, wind_zone := wind_zone]
}

dt_wz2 <- build_zone_dt(wz2_entries, 2)
dt_wz3 <- build_zone_dt(wz3_entries, 3)

dt_ecfr <- rbindlist(list(dt_wz2, dt_wz3))

# all Florida counties except those in WZ3 are in WZ2; assign them later
dt_ecfr <- dt_ecfr[!(state == "Florida" & wind_zone == 2)]

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

# state name <-> abbreviation crosswalk
dt_states <- fread(file.path(data_path, "crosswalk", "states.txt"))

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

dt_xwalk[, countyfp := paste0(
  str_pad(fips_state,  2, pad = "0"),
  str_pad(fips_county, 3, pad = "0")
)]
dt_xwalk[, name_norm := norm(unit_name)]
dt_xwalk <- dt_xwalk[, .(
  id_pid6, unit_name, name_norm, state_abbrev, countyfp, unit_type)]

dt_ecfr[, name_norm    := norm(name_ecfr)]
dt_ecfr <- merge(
  dt_ecfr, dt_states[, .(state_abbrev = state, state = state_name)],
  by = "state", all.x = TRUE
)

dt_ecfr[, state := NULL]

dt_ecfr[
  name_norm %in% names(ecfr_corrections),
  name_norm := ecfr_corrections[name_norm]
]

# Princess Anne (VA) was consolidated into Virginia Beach in 1963 and has no
# 2021 census entry; omit it from the crosswalk (documented in script header)
dt_ecfr <- dt_ecfr[name_ecfr != "Princess Anne"]

# =====================================================================
# 5. Merge with census crosswalk to get id_pid6
# =====================================================================

dt_merged <- merge(
  dt_ecfr,
  dt_xwalk,
  by = c("state_abbrev", "name_norm"),
  all = TRUE
)

# check unmatched entries
unmatched <- dt_merged[is.na(id_pid6)]
if (nrow(unmatched) > 0L) {
  warning(
    "Unmatched eCFR entries (check spellings or crosswalk):\n",
    paste(unmatched[, paste0("  ", state_abbrev, ": ", name_ecfr)], collapse = "\n")
  )
}

stopifnot(uniqueN(dt_merged$id_pid6) == nrow(dt_merged[!is.na(id_pid6)]))

dt_merged[
  state_abbrev == "FL" & unit_type == "1 - COUNTY" & is.na(wind_zone),
  wind_zone := 2
]

dt_merged[state_abbrev == "HI", wind_zone := 3]

dt_merged[is.na(wind_zone), wind_zone := 1]

# exclude AK (only coastal regions in WZ3)
dt_merged <- dt_merged[!state_abbrev == "AK"]

# collapse by county: take maximimum wind zone of all jurisdictions
# in the county
dt_final <- dt_merged[, .(wind_zone = max(wind_zone)),
  by = .(countyfp)]

# =====================================================================
# 6. Assemble and validate final crosswalk
# =====================================================================

setorder(dt_final, wind_zone, countyfp)

cat(sprintf(
  "Wind zone crosswalk: %d counties total (%d WZ2, %d WZ3)\n",
  nrow(dt_final),
  dt_final[wind_zone == 2,  .N],
  dt_final[wind_zone == 3, .N]
))

# =====================================================================
# 7. Save
# =====================================================================

out_path <- file.path(data_path, "derived", "ecfr-windzone.csv")
fwrite(dt_final, out_path)
cat("Saved to", out_path, "\n")
