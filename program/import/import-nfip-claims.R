# Import and clean NFIP claims for continental US counties
#
# Inputs:  $DATA_PATH/data/fema-nfip/FimaNfipClaimsV2.parquet
#          $DATA_PATH/crosswalk/states.txt
# Outputs: derived/nfip-claims.Rds   (claim-level, filtered + labelled)

rm(list = ls())
library(here)
library(arrow)
library(dplyr)   # arrow lazy-eval uses dplyr verbs
library(data.table)
library(lubridate)

data_path <- Sys.getenv("DATA_PATH")
if (nchar(data_path) == 0) stop("DATA_PATH environment variable is not set.")
fema_dir  <- file.path(data_path, "data", "fema-nfip")

# state crosswalk
dt_state <- fread(
    file.path(data_path, "crosswalk", "states.txt"), keepLeadingZeros = TRUE)

# ---------------------------------------------------------------------------
# import ----
# ---------------------------------------------------------------------------

pf <- open_dataset(file.path(fema_dir, "FimaNfipClaimsV2.parquet"))

keep_cols <- c(
    # identifiers / geography
    "state", "countyCode", "censusBlockGroupFips", "censusTract",
    # "censusTract", "latitude", "longitude",
    # storm / event
    "yearOfLoss", "dateOfLoss", # "eventDesignationNumber", "ficoNumber",
    # property
    "occupancyType", "originalConstructionDate",
    "numberOfFloorsInTheInsuredBuilding",   # 5 = MH; 1-3 = site-built
    # "locationOfContents",
    # damage / payment amounts
    "netBuildingPaymentAmount", "buildingDamageAmount",
    "totalBuildingInsuranceCoverage",
    "buildingDeductibleCode",  "buildingPropertyValue",
    "contentsDamageAmount",    "netContentsPaymentAmount",
    "contentsPropertyValue", "totalContentsInsuranceCoverage"
    # claim flags
    # "causeOfDamage", "floodZoneCurrent", "primaryResidenceIndicator"
)

dt_raw <- pf |>
    select(all_of(keep_cols)) |>
    filter(numberOfFloorsInTheInsuredBuilding %in% c(1L, 2L, 3L, 5L),
           !is.na(yearOfLoss),
           !is.na(state),
           !state %in% c("AS", "GU", "VI", "PR", "AK", "HI"),
           !is.na(countyCode),
           !is.na(censusTract)) |>
    collect() |>
    as.data.table()

message(sprintf(
    "Loaded %d claims (%d MH [floors==5], %d site-built [floors 1-3])",
    nrow(dt_raw),
    dt_raw[numberOfFloorsInTheInsuredBuilding == 5L, .N],
    dt_raw[numberOfFloorsInTheInsuredBuilding %in% c(1L, 2L, 3L), .N]))

# ---------------------------------------------------------------------------
# merge state ----
# ---------------------------------------------------------------------------
setnames(dt_raw, "countyCode",            "countyfp")
setnames(dt_raw, "censusBlockGroupFips", "bgfp")
setnames(dt_raw, "censusTract",         "tractfp")
dt_raw[, statefp := substr(tractfp, 1, 2)]

dt_raw <- dt_raw[statefp <= 56]

# conflicts between 'state' and 'countyCode' in NFIP; take countyCode
# as ground truth
dt_raw$state <- NULL
dt_raw <- merge(
    dt_raw, dt_state[, .(state, statefp)], all.x = TRUE, by = "statefp")

stopifnot(nrow(dt_raw[is.na(state)]) == 0L)

# ---------------------------------------------------------------------------
# define event study variables ----
# ---------------------------------------------------------------------------

# MH indicator
dt_raw[, mh := as.integer(numberOfFloorsInTheInsuredBuilding == 5L)]

# vintage year
dt_raw[, year_constr := year(originalConstructionDate)]

# homes built on/after HUD wind-standard change date (July 13, 1994)
dt_raw[, post1994 := as.integer(year_constr > 1994L)]

# ---------------------------------------------------------------------------
# sanity checks ----
# ---------------------------------------------------------------------------

# missing construction year
dt_raw[, missing_construction := as.integer(is.na(originalConstructionDate))]
message(sprintf(
    "Missing originalConstructionDate: %d of %d claims (%.1f%%)",
    dt_raw[missing_construction == 1L, .N],
    nrow(dt_raw),
    100 * dt_raw[missing_construction == 1L, .N] / nrow(dt_raw)
))

# post1994 shares by MH status
dt_raw[, .(
    n_claims      = .N,
    pct_post1994  = mean(post1994, na.rm = TRUE),
    pct_missing   = mean(missing_construction)
), by = .(mh)] |> print()

dt_raw <- dt_raw[missing_construction == 0L]

damage_cols <- c(
    "netBuildingPaymentAmount", "buildingDamageAmount",
    "buildingPropertyValue",
    "contentsDamageAmount",     "netContentsPaymentAmount",
    "contentsPropertyValue", "totalBuildingInsuranceCoverage",
    "totalContentsInsuranceCoverage"
)

# convert decimal128 columns to numeric
for (col in damage_cols) {
    if (col %in% names(dt_raw)) {
        dt_raw[[col]] <- as.numeric(dt_raw[[col]])
    }
}

setnames(dt_raw,
    damage_cols,
    c("net_building_pmt", "building_damage", "building_value",
      "contents_damage",  "net_contents_pmt", "contents_value",
      "building_covg",    "contents_covg")
)

setnames(dt_raw, "yearOfLoss", "year_loss")

saveRDS(dt_raw, here("derived", "nfip-claims.Rds"))
message(sprintf("Saved %d claims to derived/nfip-claims.Rds", nrow(dt_raw)))
