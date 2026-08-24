# Migrating `program/import/` onto the research-database framework

Status: **plan, not yet implemented.** Written 2026-08-21.

Target: retire `$DATA_PATH` from this project's import layer and read curated
parquet from `research-database` through its R client (`rd_read()`,
`rd_con()`, `rd_curated_path()`), keeping `derived/*.Rds` as the project's own
artifact layer.

Sibling repo assumed at `/workplace/wicolia/research-database` (referred to
below as `$RD_HOME`).

---

## 1. What the framework actually provides

`research-database` curates source data into versioned parquet under
`s3://<RD_BUCKET>/<tier>/curated/<dataset_id>/<version>/`, mirrored into a
local cache at `$RD_CACHE` (default `~/.cache/research-data`). A dataset's
contract — field names, types, descriptions, keys, provenance — lives in
`$RD_HOME/catalog/datasets/<dataset_id>.yml`.

The R client is *sourced*, not installed:

```r
source(file.path(RD_HOME, "client", "r", "load_all.R"))
rd_load_client(file.path(RD_HOME, "client", "r"))
```

Relevant surface (`$RD_HOME/client/r/R/`):

| function | what it does |
|---|---|
| `rd_read(id, ..., cols=, version=, tier=)` | reads a dataset to a `data.table`; `...` equality filters and `cols` both pushed into the parquet scan |
| `rd_path(id, version=, tier=)` | resolved parquet glob, for writing your own SQL against `rd_con()` |
| `rd_con()` | bare DuckDB connection |
| `rd_latest_version(id)` | newest local version, pulling from S3 on a cache miss |
| `rd_curated_path(id, version)` | local directory for one version |
| `rd_sync(id)` | force S3 → cache materialization |
| `rd_datasets()`, `rd_dict(id)`, `rd_provenance(id)` | catalog discovery |
| `rd_countyfp()`, `rd_placefp()`, `rd_check_id()` | canonical zero-padded FIPS constructors |

`rd_read()`'s pushdown, `rd_path()` and `RD_HOME` are all newer than `main` —
see the prerequisite note in §2.

**Local cache is already populated** (verified 2026-08-21): every dataset this
project needs is present under `~/.cache/research-data/public/curated/`,
including `fema_nfip_claims` (v2026-08-15, 220 MB, 2.72M rows) and
`fema_nfip_policies` (v2026-08-15, 5.0 GB). Note that `aws` is not currently
authenticated in this sandbox, so any *new* dataset pull will fail until
`AWS_PROFILE=research-database` credentials are live; existing cache reads work
offline.

---

## 2. Client prerequisites — both resolved upstream

Both blockers this plan originally identified have been fixed in
`research-database` and pushed to branch **`client-pushdown-rd-home`**
(commit `8f26997`, branched off `main`).

> **Prerequisite for all work below.** The local `research-database` checkout
> must have that branch merged or checked out — it was left on
> `asslgf-dictionary-1992` (unrelated in-progress work) with the client code at
> its pre-fix state. Either merge the branch to `main` and pull, or
> `git checkout client-pushdown-rd-home` in that repo. Without it `rd_path()`
> does not exist and `RD_HOME` is ignored, and every script below fails.

### 2.1 The client is repo-rooted; this project is a different repo

`rd_repo_root()` was literally `here::here()`. Sourced from inside
`manufactured-code` it resolved to *this* repo, so everything reading the
catalog off disk broke: `rd_dict()`, `rd_datasets()`, `rd_provenance()`,
`rd_recipe()`, `rd_validate()`, and — less obviously —
`rd_countyfp()`/`rd_placefp()`/`rd_check_id()`, which read
`catalog/conventions/identifiers.yml` through it. It failed loudly ("No dataset
contract at …"), not silently.

`rd_read()`, `rd_con()`, `rd_path()`, `rd_sync()`, `rd_latest_version()` never
touched the repo root — they resolve off `RD_CACHE`/`RD_BUCKET` — so the data
path was always fine. Only the catalog and ID helpers broke.

**Fixed upstream:** `rd_repo_root()` now honours `RD_HOME` before falling back
to `here::here()`, and rejects an `RD_HOME` with no `catalog/` rather than
silently using it. Setting `RD_HOME` in `.Renviron` (§4) is all this project
needs; no `rd_repo_root()` override, no shim.

Verified end to end from this repo: with `RD_HOME` set, `here::here()` is
`manufactured-code` while `rd_repo_root()` is `research-database`, and
`rd_datasets()` (26), `rd_dict("census_bps")` (5 fields, 100% coverage),
`rd_provenance()`, `rd_countyfp()` and `rd_check_id()` all resolve.

Still add `program/import/rd-client.R`, now just a loader so each script needs
one line rather than four:

```r
# Loads the research-database R client from the checkout named by RD_HOME.
# RD_HOME also points the client's own catalog lookups at that checkout
# (rd_repo_root()), which is why no override is needed here.
library(here)
readRenviron(here(".Renviron"))

rd_home <- Sys.getenv("RD_HOME")
if (!nzchar(rd_home)) stop("RD_HOME is not set; see program/import/UPDATE.md §4")

source(file.path(rd_home, "client", "r", "load_all.R"))
rd_load_client(file.path(rd_home, "client", "r"))
```

Every migrated script starts with `source(here("program", "import", "rd-client.R"))`.

### 2.2 `rd_read()` used to materialize the whole table — fixed upstream

**Resolved 2026-08-21 in `research-database`, branch `client-pushdown-rd-home`
(commit `8f26997`).** `rd_read()` previously issued `SELECT * FROM
read_parquet(...)` and applied its `...` filters **in R afterwards**, so neither
the predicate pushdown its docstring claimed nor any column projection actually
happened. `fema_nfip_policies` is 74M rows x 89 columns; upstream's own
`rd_validate()` carries a comment recording that a full `rd_read()` on it
OOM-killed the validation process at 90 GB RSS.

What changed in `client/r/R/read.R`:

- `...` filters compile to a SQL `WHERE`, with `IN` for vectors and an explicit
  `IS NULL` branch so `NA` still matches the way R's `%in%` did.
- new `cols =` argument projects columns in the scan.
- new exported `rd_path(dataset_id, version, tier)` returns the resolved parquet
  glob, for callers writing their own SQL against `rd_con()`. This also replaced
  four hand-rolled copies of the same `file.path(rd_curated_path(...),
  "*.parquet")` expression (`rd_read`, `rd_validate`, `build/validate.R`,
  `build/build-catalog.R`).
- 16 new tests in `client/r/tests/testthat/` (`test-read.R`, `test-config.R`);
  21 in the suite overall, all passing.

Measured on `fema_nfip_claims`: an unfiltered read is 2.72M x 85 at 1398 MB /
10 s; projecting the 20 columns this project needs and filtering to 1994-2023
gives 1.93M x 20 at 210 MB / 1.3 s.

**Consequence for this project:** the small dimension and panel tables
(`geo_state`, `geo_county`, `census_bps`, `census_mhs_*`) can use plain
`rd_read()`, ideally with `cols =`. The NFIP databuild still uses `rd_con()` +
`read_parquet(rd_path(id))` and pushes filters, expressions and the `GROUP BY`
into SQL — `rd_read()`'s equality filters cannot express `YEAR()`, the MH `CASE`,
the policy midpoint-date arithmetic, the `rated_flood_zone` regexp, or the
aggregation, and materializing the ungrouped intermediate is exactly what to
avoid. That is what `databuild-nfip.R` already does against `fema.duckdb`, so the
change is a path swap plus a rename, not a restructure.

**Two things to know when writing the new code:**

- *Row order is not guaranteed once a filter is passed.* DuckDB scans row groups
  in parallel, so a filtered `rd_read()` returns the same rows in an arbitrary
  order; an unfiltered read still comes back in file order. Verified: filtered
  `census_bps` matched the old result exactly as a set, but not in sequence.
  `setorder()` wherever a derived artifact's row order should be stable — this
  project's `saveRDS()` outputs are diffed during verification (§7.2), so it
  matters here.
- *This is verified feasible, not assumed.* Against the local cache on
  2026-08-21: claims under the project's exact filters give 1,842,522 rows
  (25,798 MH), loss years 1994-2023, sub-second; the full policy pre-aggregation
  (5 GB scan, 1983-1999 vintages, midpoint-year assignment) gives 15,813,327 rows
  over 68,107 tracts in **3.5 s**. The `$DATA_PATH/derived/fema.duckdb`
  dependency can go away with no performance regression.

## 3. Dataset mapping

| current input | source today | replacement | status |
|---|---|---|---|
| `data/census-bps/BPS_Compiled_File.csv` | `$DATA_PATH` | `census_bps` | **1:1 available** |
| `data/census-mhs/*.xlsx` (7 files) | `$DATA_PATH` | `census_mhs_state_year`, `census_mhs_national_year` | **1:1 available** |
| `crosswalk/states.txt` | `$DATA_PATH` | `geo_state` | **1:1 available** |
| `derived/fema.duckdb` `nfip_claims` | `$DATA_PATH` | `fema_nfip_claims` | **available, schema changed — see §5.5** |
| `derived/fema.duckdb` `nfip_policies` | `$DATA_PATH` | `fema_nfip_policies` | **available, schema changed — see §5.5** |
| `crosswalk/census-govt-units/2021/Govt_Units_2021_Final.xlsx` | `$DATA_PATH` | `geo_county` (name→FIPS) | **substitute, changes results — see §5.4** |
| `crosswalk/bls-cpi/SeriesReport-*.xlsx` | `$DATA_PATH` | *none yet* | **gap — see §6.1** |
| Census 2000 SF3 H030 / HCT006 | Census API (not `$DATA_PATH`) | *none* | **stays as-is — see §6.2** |
| eCFR § 3280.305 wind zone lists | scraped live | `ecfr_wind_zone` | **1:1 available (2026-08-24) — see §6.3** |

---

## 4. Environment and Makefile changes

`.Renviron` (gitignored) gains:

```
RD_HOME=/workplace/wicolia/research-database
RD_CACHE=/home/wicolia/.cache/research-data     # optional; this is the default
RD_BUCKET=research-database-williamsca
AWS_PROFILE=research-database
# DATA_PATH stays only until §6.1 (CPI) is resolved
```

`README.md` / `notes/specs.md` §7 both currently say `make data` requires
`$DATA_PATH`. After this migration that caveat narrows to "requires `$RD_HOME`,
a populated `$RD_CACHE` (or AWS credentials to fill it), a Census API key, and
network access to eCFR" — and, until §6.1 lands, `$DATA_PATH` for CPI alone.
Update both, plus the `data:` target comment in `Makefile`.

`make data` run order is unchanged. `import-mhs.R` disappears from it (§5.2).

---

## 5. Per-script plan

### 5.1 `import-bps.R` → delete, fold into consumers

The entire script reduces to `rd_read("census_bps")`. `census_bps` is
`class: derived` upstream and already does exactly what this script does: series
1 and 6 only, summed across reporting jurisdictions within a county, PR/VI
excluded (verified: no `statefp > 56` rows), 1980–2025, 3,082 counties, with a
proper zero-padded VARCHAR `countyfp`/`statefp`.

Column rename to absorb: upstream calls the total `permits`, this project calls
it `permits_tot`. Upstream's `validate.R` **rejects** the `_tot` suffix as a
matter of convention, so rename locally rather than trying to change the
catalog.

Two consumers read `derived/permits-co.Rds`:

- `databuild-mhs.R:96-101` — replace `readRDS()` with `rd_read("census_bps")`;
  **delete** the `formatC(as.integer(statefp), width = 2, flag = "0")` line, now
  a no-op on an already-padded string.
- `databuild-nfip.R:291-292` — same; **delete** the
  `formatC(as.integer(countyfp), width = 5, flag = "0")` line. This one matters:
  the old `countyfp` was the arithmetic `1000 * state + county` integer that
  `identifiers.yml` exists to prohibit.

Then delete `import-bps.R` and its `Makefile` line.

### 5.2 `import-mhs.R` → delete (516 lines)

`census_mhs_state_year` and `census_mhs_national_year` are upstream `derived`
datasets built by `program/census/mhs/derive.R` from the same seven MHS
workbooks this script parses by hand. Field names already match this project's:
`shipments`, `shipments_single`, `shipments_double`, `shipment_floors`,
`placements`, `placements_single`, `placements_double`, `avg_sales_price`,
`avg_sales_price_single`, `avg_sales_price_double`.

One schema difference: **`census_mhs_state_year` carries no `state_name`.**
Names live in `geo_state` (`statefp`, `stusab`, `name`) per the framework's
"names in one place" rule. `derived/sample-mhs.Rds` must keep `state_name`
because `program/descriptives/map.R:31` and `program/estimate/estimate-mhs.R:252`
both read it — so `databuild-mhs.R` joins `geo_state` and renames `name` →
`state_name`.

New column to be aware of: `survey_era` (`"pre_2014"` / `"2014_present"`) flags
the August 2014 placement-methodology break. This project's MHS window is
1985–2003, entirely `pre_2014`, so it is informational here — but it is worth
asserting `all(dt$survey_era == "pre_2014")` in the sample build so a future
window extension trips rather than silently splices two definitions.

Coverage check (1985–2003, verified): 969 state-years, 51 states, 97 missing
`avg_sales_price` and 88 missing `placements` cells — state-level placements and
price stop after 2013 upstream, which is outside this window.

Delete `import-mhs.R`, `derived/mhs-state-year.Rds`,
`derived/mhs-national-year.Rds`, and the `Makefile` line.

### 5.3 `databuild-mhs.R` → rewrite the import block

```r
source(here("program", "import", "rd-client.R"))

dt_state <- rd_read("geo_state")[, .(statefp, state_name = name)]

dt <- merge(rd_read("census_mhs_state_year"), dt_state, by = "statefp")
dt <- dt[!statefp %in% c("02", "15") & year %between% c(year_min, year_max)]

dt_perm_state <- rd_read("census_bps")[
  , .(permits_sf = sum(permits_sf, na.rm = TRUE)), by = .(statefp, year)]
```

Note the AK/HI filter moves from `state_name` to `statefp` — same rows, but it
no longer depends on a name string that now arrives from a join.

`str_pad(statefp, ...)` at line 73 becomes a no-op and should be deleted.
The `dt_stock`/`dt_intensity` block still reads
`derived/census2000-mh-county-vintage.Rds` and `derived/ecfr-windzone.csv` —
unchanged (§6.2, §6.3).

CPI still comes from `derived/cpi-bls.csv` until §6.1 lands.

### 5.4 `import-ecfr-windzone.R` → replace the crosswalk half

**Done, and then superseded (2026-08-24).** The `geo_county` rewrite below
landed as Chunk 3 (`notes/LOG.md`, commit `4bb3bbd`). Since then
`research-database` has adopted this exact crosswalk upstream as
`ecfr_wind_zone` (`program/ecfr/wind-zones/download.R`+`import.R`,
essentially this section's plan ported onto the framework's download/import
split) — see `notes/LOG.md`'s 2026-08-24 update. `import-ecfr-windzone.R` is
now deleted; `databuild-mhs.R`/`databuild-nfip.R` read `rd_read("ecfr_wind_zone",
version = ECFR_WIND_ZONE_VERSION)` directly. The rest of this section is kept
for its record of *why* the match target changed (still accurate — that
reasoning moved with the script), not as a live plan.

The eCFR scrape and county-name parsing (lines 25–100) stay verbatim — no
curated dataset holds 24 CFR § 3280.305. What changes is what the parsed names
are matched *against*.

Today: `Govt_Units_2021_Final.xlsx` "General Purpose" sheet, matching all active
general-purpose jurisdictions (counties *and* municipalities) by normalized
name, then collapsing to county by `max(wind_zone)`.

Proposed: `rd_read("geo_county")` — `countyfp`, `name`, `statefp` — joined to
`geo_state` for `stusab`. This is a **simplification with real consequences**,
so treat it as a change to be validated, not a drop-in:

- The `max(wind_zone)` collapse over jurisdictions disappears; matching is
  already at county grain. Sub-county municipalities named in the eCFR (mostly
  Louisiana parish-city consolidations) no longer route through a jurisdiction
  table.
- The NYC-borough fallback in `databuild-nfip.R:277` (`statefp == "36"` →
  zone 1) exists because consolidated city-county governments are missing from
  the COG file. `geo_county` has all five boroughs, so this fallback should
  become unnecessary — verify before deleting it.
- Several hand corrections change or become unnecessary. Spot-checked against
  `geo_county` on 2026-08-21: `Orleans` → `Orleans Parish` (22071) matches
  directly, so the `"ORLEANS" = "NEW ORLEANS"` correction can go; `Lafourche
  Parish` (22057), `Terrebonne Parish` (22109), `Vermilion Parish` (22113) all
  resolve, so those three corrections survive as spelling fixes only;
  `Virginia Beach city` (51810) is present, so the Princess Anne note stands
  unchanged. `DADE` → `MIAMIDADE` still needed.
- `geo_county` carries 23 deprecated/superseded rows plus 11 unverified
  historical codes with a placeholder `[unverified historical FIPS code]` name
  (see its `notes`). Filter to `is_current == TRUE` for name matching, or the
  placeholder names will pollute the normalization.
- Florida-all-except-WZ3 and Hawaii-entire-state expansions still work, now
  keyed on `statefp` rather than `state_abbrev` + `unit_type == "1 - COUNTY"`.

`norm()` keeps most of its prefix-stripping but must also strip the *suffixes*
`geo_county` carries and the COG file did not: ` COUNTY`, ` PARISH`, ` CITY`,
` BOROUGH`, ` CENSUS AREA`, ` MUNICIPALITY`, ` CITY AND BOROUGH`.

**Acceptance gate:** the rewritten script must produce a
`derived/ecfr-windzone.csv` that is diffed county-by-county against the current
one before it is adopted. Any county whose `wind_zone` moves needs a one-line
justification in `notes/LOG.md`. Do not adopt a version with unexplained
differences — this crosswalk defines treatment for both the MHS and NFIP
designs.

### 5.5 `databuild-nfip.R` → repoint both SQL queries

Structurally unchanged: the two big `dbGetQuery()` calls stay, the balanced-panel
construction stays. The connection and the column names change.

```r
source(here("program", "import", "rd-client.R"))

con <- rd_con()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

glob_claims   <- rd_path("fema_nfip_claims", version = NFIP_VERSION)
glob_policies <- rd_path("fema_nfip_policies", version = NFIP_VERSION)
```

then `FROM nfip_claims` → `FROM read_parquet('<glob_claims>')`, and likewise for
policies. `rd_path()` calls `rd_latest_version()`, which pulls from S3 on a cache
miss — so a fresh machine works, and `RD_OFFLINE=1` turns a miss into an error
rather than a 5 GB download.

**Pin the version.** `rd_latest_version()` silently adopts a newer snapshot
whenever one appears in the cache or in S3. For a paper's headline numbers that
is a reproducibility hazard. Record the version explicitly in
`project-params.R`:

```r
NFIP_VERSION <- "v2026-08-15"
```

and pass it through, as above.
Bumping it becomes a deliberate, logged act.

#### Claims field mapping

| current SQL (v2 camelCase) | curated column | note |
|---|---|---|
| `countyCode` | `countyfp` | already 5-digit zero-padded VARCHAR; NULL for 2.3% of all rows |
| `censusTract` | `tractfp` | **now derived from v3's 12-digit `censusGeoid`, first 11 chars**; NULL for 5.0% |
| `censusBlockGroupFips` | `census_block_group_geoid` | 12-digit; the `bgfp` column is unused downstream — drop it |
| `yearOfLoss` | `year_of_loss` | |
| `originalConstructionDate` | `original_construction_date` | DATE |
| `numberOfFloorsInTheInsuredBuilding` | `number_of_floors_in_the_insured_building` | `== 5` is contract-documented as "Manufactured (mobile) home or travel trailer on foundation" |
| `netBuildingPaymentAmount` | `net_building_payment_amount` | |
| `buildingDamageAmount` | `building_damage_amount` | |
| `buildingPropertyValue` | `building_property_value` | |
| `contentsDamageAmount` | `contents_damage_amount` | |
| `netContentsPaymentAmount` | `net_contents_payment_amount` | |
| `contentsPropertyValue` | `contents_property_value` | |
| `totalBuildingInsuranceCoverage` | `total_building_insurance_coverage` | |
| `totalContentsInsuranceCoverage` | `total_contents_insurance_coverage` | |
| `waterDepth` | `water_depth` | |
| `elevatedBuildingIndicator` | `elevated_building_indicator` | BOOLEAN |
| `buildingReplacementCost` | `building_replacement_cost` | |
| `ratedFloodZone` | `rated_flood_zone` | |
| `primaryResidenceIndicator` | `primary_residence_indicator` | BOOLEAN |
| `occupancyType` | `occupancy_type` | |
| `state` | `state` | unchanged |

Because `countyfp`/`tractfp` are pre-built, the `AND TRY_CAST(LEFT(censusTract, 2)
AS INT) <= 56` guard can become `AND TRY_CAST(LEFT(tractfp, 2) AS INT) <= 56`
(kept — it still catches territory tracts) and `substr(tractfp, 1, 5)` at line
252 could be replaced by the table's own `countyfp`. **Do not** make that second
swap silently: FEMA's `countyfp` is "the primary county" for a claim and can
disagree with the tract's own county on multi-county projects. Keeping
`substr(tractfp, 1, 5)` preserves current behavior; changing it is a separate,
diffed decision.

#### Policies field mapping

| current SQL | curated column | note |
|---|---|---|
| `censusTract` | `tractfp` | |
| `countyCode` | `countyfp` | |
| `numberOfFloorsInInsuredBuilding` | `number_of_floors_in_insured_building` | **no "the"** — differs from the claims table's name, which is a genuine FEMA inconsistency preserved by the mechanical snake_casing |
| `originalConstructionDate` | `original_construction_date` | |
| `policyEffectiveDate` / `policyTerminationDate` | `policy_effective_date` / `policy_termination_date` | DATE |
| `buildingReplacementCost` | `building_replacement_cost` | |
| `policyCost` | `policy_cost` | |
| `totalBuildingInsuranceCoverage` | `total_building_insurance_coverage` | |
| `totalContentsInsuranceCoverage` | `total_contents_insurance_coverage` | |
| `elevatedBuildingIndicator` | `elevated_building_indicator` | |
| `primaryResidenceIndicator` | `primary_residence_indicator` | |
| `mandatoryPurchaseFlag` | `mandatory_purchase_flag` | |
| `ratedFloodZone` | `rated_flood_zone` | |
| `propertyState` | `property_state` | |

Also available and worth noting: `policy_count` (a single RCBAP row insures
multiple units). The current `COUNT(*) AS policies_n` counts *transactions*, not
insured units. That is a pre-existing modelling choice, not a migration issue —
but the curated contract documents the distinction explicitly, so it is now
answerable and should be recorded in `notes/specs.md` either way.

#### ⚠ This is a data-vintage change, not just a rename

`fema.duckdb` was built from OpenFEMA **v2** (`FimaNfipClaims`). The curated
datasets are **v3** (`NfipClaims`), snapshotted 2026-08-15. Per the catalog
notes, v2 is frozen as of 2026-06-01 and is scheduled for removal 2026-10-15, so
migrating is not optional in the long run — but v3 also replaced separate
`censusTract`/`censusBlockGroupFips` fields with one 12-digit `censusGeoid`, and
carries a later snapshot of a continuously-restated source. **Claim counts,
tract coverage, and every headline estimate can move.** Budget for that
explicitly (§7), and do not fold this migration into a commit that also changes
a specification.

### 5.6 `databuild-welfare.R` → no change

Reads only `derived/nfip-balanced.Rds` and
`derived/census2000-mh-county-vintage.Rds`, both project artifacts. It inherits
whatever §5.5 does upstream of it.

### 5.7 `import-census.R` → no change

Already `$DATA_PATH`-free: it calls the Census API via `censusapi` with
`CENSUS_KEY` from `.Renviron`. See §6.2.

---

## 6. What the framework does not cover

### 6.1 CPI — the one remaining `$DATA_PATH` dependency

`import-cpi.R` reads a hand-downloaded BLS workbook from
`$DATA_PATH/crosswalk/bls-cpi/`. There is no `bls_cpi` catalog entry.
`research-database` has a near-identical `program/import-cpi-bls.R` (same
workbook, same reshape) but it is unmigrated Phase-3a code writing to
`here("derived")` with no contract, and `bls_cpi` + `rd_deflate()` sit under
Phase 3b, not started.

Options, in preference order:

1. **Contribute `bls_cpi` upstream.** Modest: a `download-cpi-bls.R`, a rewrite
   of `import-cpi-bls.R` onto `rd_write()`, and
   `catalog/datasets/bls_cpi.yml`. Then `import-cpi.R` deletes and both projects
   share one deflator. This is the right answer and unblocks
   `$DATA_PATH` retirement entirely.
2. **Vendor the workbook.** Commit the BLS series to `program/import/` or a
   small `data/` and read it with `here()`. Removes `$DATA_PATH` immediately but
   duplicates a source the framework will eventually own.
3. **Leave as-is.** `$DATA_PATH` survives for one file.

Note the framework's stated principle (`modernization-plan.md` §6.4): indices
are data, deflation is a function, deflated values are project artifacts. This
project's `cpi / cpi[year == DISCOUNT_YEAR]` rebasing is exactly the
project-side step that principle expects — so only the raw index moves
upstream, not the rebasing.

### 6.2 Census 2000 SF3 (H030, HCT006)

No decennial dataset in the catalog. `import-census.R` already needs no
`$DATA_PATH`, so it stays. Longer term it is a natural `materialization: recipe`
candidate upstream (script + parameters, materialized on demand), but that is
out of scope here.

### 6.3 eCFR § 3280.305 wind zones — resolved 2026-08-24, contributed upstream

Superseded: this section argued for keeping the scrape local since the HUD
wind-zone map was this paper's own research design, not shared
infrastructure. That call reversed once asked for at the database level —
`research-database` now curates it as `ecfr_wind_zone` (a scraped-at-build-time
dataset via `download.R`/`import.R`, not the `catalog/seeds/` route this
section anticipated — the eCFR page is a scriptable source like any other,
per `principles.md` §1). See §5.4 and `notes/LOG.md`'s 2026-08-24 entry.

### 6.4 Government Units crosswalk

`asslgf_gov_xwalk` carries `id_pid6`, `countyfp`, `name`, `type_code` and is the
closest thing to the COG file — but it is built from the ASSLGF PID/GID
crosswalk for finance-panel joins, not from `Govt_Units_2021_Final.xlsx`, and
its `countyfp` is NULL for state-level units. `geo_county` (§5.4) is the better
match target. Do not substitute `asslgf_gov_xwalk` here.

---

## 7. Verification

Every step below is a hard gate, in order. The project's own convention
(`CLAUDE.md`): uniqueness on the correct IDs, consistency across fields,
missing values.

1. **Snapshot the baseline first.** On a machine with `$DATA_PATH`, run the
   current `make data` and archive `derived/` intact. Without this snapshot
   there is nothing to diff against and the migration is unverifiable.
2. **Per-artifact diff.** For each of `permits-co.Rds`, `mhs-state-year.Rds`,
   `ecfr-windzone.csv`, `nfip-claims.Rds`, `nfip-balanced.Rds`,
   `sample-mhs.Rds`, `welfare-county-vintage.Rds`: compare row counts, key
   uniqueness, and column-wise `summary()` old vs new. Write a short table of
   differences into `notes/LOG.md`.
3. **ID conformance.** Assert `all(rd_check_id(dt$countyfp, "countyfp"))` and
   the `tractfp` equivalent on every migrated artifact — this is the check that
   would have caught the `1000 * state + county` integer countyfp.
4. **Expect three artifacts to move, and know why.**
   - `ecfr-windzone.csv` — different match target (§5.4).
   - `nfip-claims.Rds` / `nfip-balanced.Rds` — v2 → v3 (§5.5).
   - Anything downstream of those.
   `permits-co`, `mhs-state-year`, and `sample-mhs` should be **byte-identical
   up to column naming and ordering**. If they are not, stop: something in the
   upstream derivation differs from this project's and needs reconciling before
   proceeding.
5. **`make estimates` and `make test`.** The fake-data harness in
   `program/tests/` has no external data dependency and must still pass. Then
   regenerate every table/figure and check against `notes/specs.md`.
6. **`notes/specs.md` + `paper.Rmd`.** Any headline number that moves gets
   updated in both, in the same commit, per the project's PROCESS rule.

---

## 8. Sequencing

Split into three commits so a regression is bisectable. Do not combine them.

**Chunk 1 — plumbing and the clean swaps (no numbers should move).**
`program/import/rd-client.R`; `.Renviron`; delete `import-bps.R` and
`import-mhs.R`; rewrite `databuild-mhs.R`'s import block; update `Makefile`,
`README.md`, `notes/specs.md` §7. Gate: `sample-mhs.Rds` diffs clean (§7.4) and
`make estimates` reproduces the MHS tables exactly.

**Chunk 2 — NFIP onto curated parquet.** Rewrite `databuild-nfip.R`; pin
`NFIP_VERSION`. Gate: §7.2 diff written up, `make estimates` rerun, every moved
number reconciled in `notes/specs.md`. Expect this chunk to move the headline
estimates; that is the point of isolating it.

**Chunk 3 — wind zone crosswalk.** Rewrite `import-ecfr-windzone.R` onto
`geo_county`. Gate: county-by-county diff of `ecfr-windzone.csv`, every moved
county justified, NYC fallback in `databuild-nfip.R` deleted only after it is
shown to be dead.

**Deferred:** CPI (§6.1). Decide between contributing `bls_cpi` upstream and
vendoring the workbook; `$DATA_PATH` cannot be fully retired until then.

---

## 9. Open questions

1. ~~`bls_cpi` upstream or vendored?~~ **Resolved** — contributed upstream
   (§6.1, `notes/LOG.md` 2026-08-21 update).
2. ~~Adopt `geo_county` for wind-zone matching, or keep the COG file?~~
   **Resolved** — `geo_county` adopted (Chunk 3), then the whole crosswalk
   contributed upstream as `ecfr_wind_zone` (§5.4/§6.3, `notes/LOG.md`
   2026-08-24 update).
3. **`policies_n`: transactions or `policy_count`?** (§5.5) Pre-existing choice,
   now documented upstream and therefore answerable.
4. **Pin or float the NFIP snapshot version?** Recommended: pin (§5.5).
5. ~~Upstream `RD_HOME` support in `rd_repo_root()`?~~ **Resolved** — done in
   `client-pushdown-rd-home` alongside the `rd_read()` fix (§2). The only
   remaining action is merging that branch; see the prerequisite note in §2.
