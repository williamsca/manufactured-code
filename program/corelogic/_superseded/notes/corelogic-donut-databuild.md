## Zone I spillover doughnut (2026-10-19)

`--donut-miles=50` builds a separate sample excluding every Zone I county
whose minimum polygon-to-polygon distance to any Zone II/III county is at most
50 statute miles. Distances use spherical geometry, cross state boundaries,
and include proximity across water. This retains all treated counties and drops
225 Zone I counties. Minimum boundary distance is conservative: a county is
removed even if only its closest edge is within the buffer. The bandwidth is
a design choice, not an estimated plant delivery radius; 25 and 100 miles are
natural sensitivity checks (137 and 409 excluded counties, respectively).
Omitting the option preserves the original sample;
`--donut-miles=0` instead excludes touching/intersecting controls.

The shared helper `program/lib/corelogic-donut.R` uses Census 2020 1:5,000,000
cartographic county boundaries. This vintage preserves the Connecticut county
FIPS used by CoreLogic, rather than the planning-region FIPS in 2024 geography.
HUD labels come from `cl_windzone_counties()`, the corrected classification used
by the CoreLogic estimators, including the historical Dade code in the build's
zone crosswalk. Thus the doughnut is defined independently of transaction
prices, construction vintages, and the set of states selected for a build.

The exclusion filters both property and transfer inputs before cohort selection
and pair construction, for MH and site-built observations alike. All four saved
panels exclude these counties. Each build saves the complete public county list,
distances and exclusion flags in `audit/donut_counties.csv`, the corrected zone
crosswalk, and the bandwidth and method in `manifest.json`. Named runs launched
through `corelogic.slurm` also verify the saved panels, including zero surviving
records in excluded counties.

```bash
sbatch program/import/corelogic.slurm --donut-miles=50 \
  --run-id=continental-donut-50mi-20261019 \
  --reference-dir=/scratch/chv7bg/manufactured-code/public-reference
```

`program/descriptives/map.R` adds
`output/descriptives/map-corelogic-windzone-donut.pdf` and its public county CSV.
Retained Zone I counties are blue, excluded controls gray, and Zones II/III retain
their red fills. Set `CORELOGIC_DONUT_MILES` to change the mapped bandwidth.
`CORELOGIC_COUNTY_GEOMETRY` can point to a staged copy of the 2020 county file
for either script, avoiding downloads inside the allocation.

The continental 50-mile build completed as Slurm job `21602898` in 5 minutes
28 seconds, including persisted-panel verification. Its private artifacts are
at `/scratch/chv7bg/manufactured-code/corelogic/continental-donut-50mi-20261019`.
Verification passed all original sample rules and found zero excluded-county
records in properties, transfers, sales, or pairs. The job used an isolated code
snapshot under `/scratch/chv7bg/manufactured-code/donut-runs/` and preserved the
remote checkout. Aggregate summaries, the public county list and manifests are
saved locally in `output/corelogic/continental-donut-50mi-20261019/`.
All 49 states/DC passed verification. The retained sample has 465,425 eligible
MH sales (baseline: 494,221) and 12,587,899 eligible site-built sales (baseline:
13,218,377). The downloaded county exclusion list matches the map exactly.

## Historical Property Basic snapshots (Q1 panel)

Built by `program/import-corelogic-snapshots/` (Slurm: `import-corelogic-snapshots.slurm`; launch with `./run_remote.sh import-corelogic-snapshots`). Licensed panel stays at `/scratch/chv7bg/manufactured-code/corelogic-snapshots/panel/current/panel.parquet`; only aggregate CSV/JSON come back to `output/import-corelogic-snapshots/{panel,tabulate}/`.

- **Source:** `/project/crebe_hufl_corelogic/historic_property/`. One zip per state per snapshot index holding one pipe-delimited `.txt` (~210 columns). The 2024 delivery (`20240814/`, plus index 15 in `20240814/151041/`, delivery date 20240815, file names contain a space) is used. The 2023 delivery (`20230817`, indices 01–14, some states missing) is a subset and is not used.
- **Snapshots:** 15 annual snapshots, tax years 2008–2022. The zip index is *not* chronological: index 1 = tax year 2022, …, 14 = 2009, 15 = 2008. The panel dates each snapshot by its modal `TAX YEAR`. Nothing exists after tax year 2022: the curated 2023 Property Basic (`cl_property_basic/v2026-10-07`) is identical to index 1 (max assessor update 2023-03-30).
- **Panel:** key (`clip`, `snap_idx`); fields: `year_built`, `effective_year_built` (values outside 1700–2100 set to missing), land use, property indicator, MH indicator, improvement/land/total value, tax year, assessor update date, `previous_clip`. Counties (configurable): Lee 12071, Charlotte 12015, Bay 12005, Gulf 12045, Maricopa AZ 04013 (Zone I comparison). 27,825,589 rows.
- **Checks (job 21432406):** no missing state×snapshot zips; rows read = rows written for every zip; 154,750 rows with null `clip` excluded (counted in `check-null-clip.csv`); 0 duplicate (`clip`, snapshot) keys.
- **Clip stability:** `clip` is unique within snapshot. Adjacent-snapshot match rates are in `tab-clip-match.csv`. `PREVIOUS CLIP` is essentially never populated, so there is no linkage across clip changes; a replaced structure on the same parcel keeps its `clip`.
- **Data-quality caveats:** The MH indicator is unusable before ~2016 (Lee flags ~145k parcels, mostly condos, before 2016 vs ~17.5k after; Bay none before 2014; Maricopa none before 2015). The tabulations define MH as land use 137, which is stable except Lee (zero parcels in 2009–10) and Maricopa (22k in 2008–11, 17.3k in 2012, ~19k later). Assessor update date is missing in the first three snapshots in Bay. Maricopa effective year is ~3% populated. `year_built` after the snapshot year: Lee 38,697, Maricopa 9,174 rows. Effective year before `year_built`: Bay 68, Gulf 34 rows.
