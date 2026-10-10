# manufactured-code

CoreLogic licensed records are built and estimated on Rivanna. See
[build documentation](notes/corelogic-databuild.md) and the
[research plan](PLAN_CORELOGIC.md). `make test-corelogic` runs synthetic sample,
price, wind-zone, share, and tract-sorting checks.

The current price analysis uses sales in 2000–2023, construction vintages
1989–1999, 1993 as the annual reference, and 1994–1999 as static treatment.
There are no measured covariates. National vintage profiles and wind-zone
triple differences compare county effects with added census-tract effects
on the same tract-covered sample. County clustering is primary.

The estimation scripts are in `program/corelogic/` and run on Rivanna through
one launcher, `program/corelogic/corelogic.slurm`. From the repo root, after
committing and pushing:

```bash
./run_remote.sh corelogic                              # tracts, prices, windzone, share
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
and repoints `<name>/current` to it. Prices and wind zones read
`tracts/current` unless `CORELOGIC_TRACTS` is set. Only CSV, PDF, PNG, and JSON
files are exported; parquet files, fitted models, and archived source stay on
Rivanna.

Only current aggregate tables and figures are kept locally under
`output/corelogic/prices/`, `output/corelogic/windzone/`, and
`output/corelogic/share/`. Licensed lookup files and fitted models stay private.
The analysis scripts produce one national vintage-price figure and pooled and
separate-zone triple-difference figures, in PDF and PNG.

The parallel MH-share analysis uses surviving 2023 dwelling parcels with one
observation per home, not the sale sample. Its effects are percentage points.

Current specifications and results: [prices](notes/corelogic-prices.md),
[wind zones](notes/corelogic-windzone.md), and [MH shares](notes/corelogic-share.md).
