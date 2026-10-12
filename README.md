# manufactured-code

CoreLogic licensed records are built and estimated on Rivanna. See
[build documentation](notes/corelogic-databuild.md) and the
[research plan](PLAN_CORELOGIC.md). `make test-corelogic` runs synthetic sample,
price, wind-zone, share, and tract-sorting checks.

The current price analysis uses sales in 2000–2023 and construction vintages
1989–1999. Annual II-minus-I and III-minus-I price triple differences use 1993
as the reference. A static III-minus-I LaTeX table compares baseline, tract
fixed effects, and tract effects plus log lot/living area on a common sample.
Static treatment starts in 1994. Inference clusters by county.

The estimation scripts are in `program/corelogic/` and run on Rivanna through
one launcher, `program/corelogic/corelogic.slurm`. From the repo root, after
committing and pushing:

```bash
./run_remote.sh corelogic                              # tracts, prices, share
./run_remote.sh corelogic estimate-corelogic-prices.R  # one script
```

`run_remote.sh` resets the Rivanna checkout (`~/manufactured-code`) to
`origin/main`, submits the job, waits, checks its final state, and downloads
the exported aggregates into `output/corelogic/<name>/`. It refuses to run if
local `program/corelogic`, `program/lib`, or `program/tests` differ from
`origin/main`. The Slurm file pins the verified build, Property Basic source,
and public reference directory; export `CORELOGIC_BUILD`, `CORELOGIC_PB_SOURCE`,
`CORELOGIC_REFERENCE`, or `CORELOGIC_TRACTS` locally to override them. Each
script first runs its synthetic check, then writes all output to a new private
directory `/scratch/chv7bg/manufactured-code/corelogic-results/<name>/<job id>/`
and repoints `<name>/current` to it. Prices read `tracts/current` unless `CORELOGIC_TRACTS` is set. Shares assign
tracts to the full surviving inventory from the pinned Property Basic snapshot.
Only CSV, PDF, PNG, JSON, and LaTeX files are exported; parquet files, fitted models, and archived source stay on
Rivanna.

Only current aggregate tables and figures are kept locally under
`output/corelogic/prices/` and `output/corelogic/share/`. Licensed lookup files and fitted models stay private.
The price figure shows the two separate-zone triple differences in PDF and PNG.
The redundant standalone windzone estimator has been removed.

The parallel MH-share analysis uses surviving 2023 dwelling parcels with one
observation per home, not the sale sample. Its effects are percentage points.
Its static III-minus-I LaTeX table compares baseline and tract effects on a
common tract-covered inventory sample, without size controls. Both regression
tables are generated with `fixest::etable()`, with default stars and standard
errors and no table notes. Additional MH-only event studies compare prices and
surviving-home counts across zones, without a site-built comparison.

Current specifications and results: [prices](notes/corelogic-prices.md) and
[MH shares](notes/corelogic-share.md).
