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

Submit `program/estimate/corelogic-tracts.slurm` to prepare the private snapshot
tract lookup. Set `CORELOGIC_BUILD`, a new `CORELOGIC_RESULTS` directory, and
`CORELOGIC_PB_SOURCE` to the pinned Property Basic source directory. Then submit
`corelogic-prices.slurm` and `corelogic-windzone.slurm`, setting `CORELOGIC_TRACTS`
to the completed lookup directory; the wind-zone job also needs
`CORELOGIC_REFERENCE`. All jobs require Slurm and a complete verified build.

Only current aggregate tables and figures are kept locally under
`output/corelogic/prices/`, `output/corelogic/windzone/`, and
`output/corelogic/share/`. Licensed lookup files and fitted models stay private.
The analysis scripts produce one national vintage-price figure and pooled and
separate-zone triple-difference figures, in PDF and PNG.

The parallel MH-share analysis uses surviving 2023 dwelling parcels with one
observation per home, not the sale sample. Submit `corelogic-share.slurm` with
the build, results, and reference inputs. Its effects are percentage points.

Current specifications and results: [prices](notes/corelogic-prices.md),
[wind zones](notes/corelogic-windzone.md), and [MH shares](notes/corelogic-share.md).
