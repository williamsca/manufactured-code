# CoreLogic databuild

Implementation started October 8, 2026. This workstream runs on Rivanna. No
licensed source records or research panels are copied to the local machine;
local outputs are aggregate diagnostics and eventual tables/figures only.

## Inputs and definitions

- Property Basic and Owner Transfer: full `v2026-10-07` curated builds of the
  `20230817` delivery. Both passed upstream `rd_validate` with no errors or
  warnings. Source totals are 114,032,245 properties and 271,394,803 transfers.
- The curated files are hosted under `RD_CACHE_HOSTED` on Rivanna. The script
  resolves paths through the research-database client and verifies full source
  manifests, rather than selecting a latest or partial version.
- **MH means `mobile_home_indicator == "Y"`**, CoreLogic's derived field for a
  parcel containing a mobile home. Owner Transfer supplies the historical
  indicator; Property Basic supplies the current-snapshot indicator separately.
  Land-use codes are retained for diagnostic cross-tabs and dwelling screens.
  Unflagged mobile/manufactured land-use codes do not become MH by substitution.
- Site-built comparisons require the single-family property indicator (`10`),
  no MH indicator, and no mobile-home/park/lot land-use conflict. Blank MH
  indicators are admitted for this explicitly single-family comparison group;
  they are not globally interpreted as an affirmative site-built flag.
- Original transfer-time construction vintage defines treatment. Effective
  construction year and snapshot year are retained as separate diagnostics;
  the latter is never a silent treatment-vintage fallback.
- Initial cohort is the paper's 1984–1999 original vintages. A parcel enters the
  transfer frame if any historical classified MH/single-family record or the
  current snapshot falls in that window. **All transfer histories for those
  parcel IDs remain in the frame**, including later replacement structures,
  non-market transfers, missing dates and current-snapshot nonmatches.
- Main sale-year window is 1990–2023; 2023 is partial. Nominal treatment is
  vintage >=1994; preferred analysis flags exclude the mixed 1994 cohort. The
  sales artifact keeps 1994. **The October 8 correction retains 1994 in the
  primary price analyses:** estimators use `eligible_sale` plus the construction/
  sale-date check, rather than the persisted legacy `analysis_ready` flag. The
  transition cohort gets its own coefficient; no source rebuild is required.

## Screens and artifacts

`program/lib/corelogic-sample.R` holds the production SQL rules.
`program/import/databuild-corelogic.R` builds each requested state in DuckDB,
then releases its intermediate tables before proceeding to the next state.
This bounds memory without loading either full source into R.

Each uniquely named private run directory contains:

- `properties/`: current MH-indicator/single-family parcel inventory, including
  snapshot values, coordinates and original/effective vintage. This inventory
  is not a historical survivor-independent housing stock.
- `transfers/`: complete histories for the selected parcel cohort, joined
  **left** to the current snapshot, with historical/current classification and
  screening flags. No predecessor-ID or address matching is assumed.
- `sales/`: positive-price arms-length deeds with full/confirmed/verified or
  blank consideration codes, no flagged multi-parcel or partial interest,
  no related-party flag, a usable date and original vintage in the paper's
  window. Dwelling screens exclude park/lot/vacant/commercial uses and known
  multiple-building properties. Distressed and same-day ambiguous transfers
  remain in `transfers` but do not enter this main sales sample. Explicit partial,
  unknown and other unsupported consideration codes are excluded. Separate
  `consideration_documented`, `eligible_sale_strict` and `analysis_ready_strict`
  flags retain the documented-code sensitivity sample.
- `pairs/`: consecutive screened market transfers, with original classification
  at both dates. The pre-sale vintage must be in the window; later original
  vintage/type need not remain the same. Changed structures and distressed
  pairs remain visible; separate flags identify a non-distressed dwelling sample
  with unchanged recorded type/vintage, and a documented-code sensitivity sample
  at both endpoints. Unchanged records are a proxy, not proof of no structural
  change. These are **repeat-sale readiness pairs**, not
  storm-assigned observations or hurricane damage estimates.
- `audit/`: aggregate source geography, indicator/land-use cross-tabs, original
  vintage coverage, overlapping exclusion counts, transaction-code patterns,
  snapshot disagreement, price distributions, county/year/vintage sale support
  and repeat-sale support/change diagnostics.
- `manifest.json`: requested states and full/partial coverage, pinned source
  metadata, resolved CPI version, screening expressions, code hashes,
  start/end timestamps and completion status. A failed job leaves status
  `running`; consumers must require `complete`.

Sale date prefers the derived deed date, with a recording-date fallback explicitly
flagged. Neither is the internal transaction batch date. Real prices use annual
CPI-U rebased to 2000. All same-day cohort transfers are counted before screening;
ambiguous parcel/date groups are excluded rather than arbitrarily retaining a row.
Blank multi-parcel/partial-interest fields and missing ownership percentage are
admitted provisionally, with their missingness audited. This is a screening choice,
not evidence that blank means confirmed full ownership. No price winsorization is
applied until source distributions are reviewed.

County joins use canonical zero-padded source `countyfp` and the project's pinned
HUD wind-zone crosswalk when the curated reference cache is available. An explicit
`--reference-dir` bundle is supported for the initial audit when the host lacks
S3 access: `geo_state.parquet`, `ecfr-windzone.csv`, and `cpi-bls.csv`. These public
files are staged on Rivanna; all joins and summaries still run there. Their hashes
are recorded, and the manifest explicitly labels the legacy project references
rather than claiming they are the pinned curated wind-zone/CPI versions. Refresh
the wind-zone reference before estimation. The source's contemporaneous geography convention remains
visible; unresolved zone matches are audited rather than imputed. Regular transfer
files are checked for missing/cross-state county codes. Usable mainland records in
the source's `NULL` state file are included according to their county code.

## Execution

The databuild requires `SLURM_JOB_ID` and refuses local execution. It also refuses
an existing run directory, preventing a pilot from overwriting a full build.
The Slurm launcher runs the synthetic SQL checks before scanning licensed data.

On a Rivanna compute allocation, with this project staged/checked out:

```bash
sbatch program/import/corelogic.slurm --states=FL --run-id=pilot-fl \
  --reference-dir=/scratch/chv7bg/manufactured-code/public-reference
sbatch program/import/corelogic.slurm --run-id=continental-20261008 \
  --reference-dir=/scratch/chv7bg/manufactured-code/public-reference
```

Or from an existing allocation:

```bash
make data-corelogic CORELOGIC_ARGS='--states=FL,NC --run-id=pilot-fl-nc'
```

Environment: `RD_HOME` points at the host research-database checkout;
`RD_CACHE_HOSTED` points at its hosted curated store; `CORELOGIC_OUTPUT_ROOT`
names the private project artifact root. The launcher defaults to
`/scratch/chv7bg/manufactured-code/corelogic` for this user and requests 8 CPUs,
64 GB RAM and six hours. The launcher loads Rivanna's AWS CLI module for public
cache fills when credentials are available. DuckDB is limited to 40 GB and can spill to the private
run directory. Aggregate `audit/` CSVs and the manifest may return locally;
the four record-level parquet directories stay on Rivanna.

## Verification and build outcomes

The synthetic fixture checks the actual production joins and screens: unmatched
current parcels stay in the sample; effective year is not substituted for
original vintage; land-use alone does not assign MH; ambiguous same-day transfers
do not become sales; CPI/date fallback works; and a post-storm-style replacement
does not recode the pre-sale treatment. It passed locally with synthetic data only.
No existing paper estimates have been rerun or changed.

The first successful Florida pilot was job `21064260`, run
`pilot-fl-v6-20261008`: 36 seconds including setup, about 6 GB peak RSS. It created
the four panels and audited the source flag and all screens. Setup failures before
that run exposed a client-loader default, a missing public cache/AWS access,
the delivered `calculated_value_source_indicator` column alias and numeric
transaction indicators; those are addressed in the implementation.

The initial continental build (job `21064283`, run `continental-20261008`)
completed all 49 states/DC in about four minutes and produced 7 GB of private
panels. Its deliberately strict documented-consideration screen yielded 23,964
preferred MH sales and 6,130 preferred MH repeat-sale pairs. This is an audit
build, not the final main sample.

The host-side `program/descriptives/audit-corelogic.R` pass (job `21064476`)
identified the main screening issue: Florida has 103,331 otherwise preferred MH
sales with a blank consideration code, compared with 1,749 with a documented
code. The blank field is common on positive-price arms-length deeds, not simply
a proxy for transactions without a price. The final main screen therefore admits
blank consideration codes with all other screens retained and exports strict
sensitivity flags. This was a data-availability correction, not a treatment-effect
search: no reform or hurricane coefficients have been estimated.

The revised continental build is job `21064853`, run
`continental-v2-20261008`, stored at
`/scratch/chv7bg/manufactured-code/corelogic/continental-v2-20261008`.
It completed all 49 states/DC in 4 minutes 44 seconds, with about 55 GB peak RSS
and 8.1 GB of private artifacts. This is the current main build.

| Saved sample | MH | Site-built |
|---|---:|---:|
| Historical transfer records in cohort frame | 3,418,239 | 43,623,375 |
| Eligible sales, including the 1994 sensitivity cohort | 494,221 | 13,218,377 |
| Preferred sales, excluding 1994 and invalid construction/sale timing | 442,767 | 12,066,185 |
| Preferred sales with documented consideration code | 23,964 | 1,669,124 |
| Repeat-sale readiness pairs, including changed/distressed cases | 239,652 | 6,598,493 |
| Preferred pairs with unchanged recorded type/vintage, excluding 1994/distress | 119,704 | 4,660,293 |
| Preferred pairs with documented codes at both endpoints | 6,094 | 500,779 |

These are sale/pair counts, not distinct homes, and are not restricted to a
particular hurricane footprint. In addition to the MH/site-built transfer counts,
the frame retains 1,675,218 transfers with unknown/changed classification. The
four saved panels contain 48,716,832 transfers, 13,712,598 eligible sales and
6,838,145 readiness pairs in total; the parcel inventory is a separate snapshot.

Host-side verification (`program/tests/verify-corelogic-build.R`, job `21066147`)
passed: every artifact directory has all 49 expected state files; persisted row
and sample counts agree with the build summaries; MH assignment always follows
the derived Y flag; and vintage/date/strict-sample/pair-treatment rules have zero
violations. The synthetic SQL checks also passed on the host before the build.

Current-snapshot vintage disagrees with the historical original vintage on
411,760 MH transfer records, so assigning the snapshot year to historical sales
would materially change the design. The build retains historical original
vintage and keeps 14,036 MH transfer records without a current snapshot match.
These quantities describe records in the selected frame, not population rates
of replacement or destruction. The zero observed disagreements between the
derived MH flags where comparable do not establish the timing of the flag:
unlike several transfer fields, `mobile_home_indicator` is not explicitly named
`_static`. Confirm its historical/update semantics before interpreting type
changes or survival around hurricanes.

Only small aggregate summaries, the source/build manifest and verification output
return to `output/corelogic/continental-v2-20261008/` locally. All four parquet
panels, detailed support tables and subsequent analysis stay on Rivanna. The
public references remain the explicitly staged legacy project bundle; the
wind-zone mapping still needs reconciliation/refresh before estimation. Hurricane
exposure joins and estimation are subsequent stages; no reform or hurricane
coefficients have been estimated in this workstream yet.
