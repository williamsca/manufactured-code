# manufactured-code

Effects of the 1994 HUD wind standard for manufactured homes on prices,
quantities, and flood damage. The paper is `paper.Rmd`; every exhibit and
quoted number it uses comes from `output/`, and every scalar is loaded through
`program/load-results.R`.

## Layout

| Code | Output | What |
|---|---|---|
| `program/import/` | `derived/` | Data builds (CPI, Census, MHS, stock imputation, NFIP, CoreLogic build) |
| `program/descriptives/` | `output/descriptives/` | Wind-zone map, NFIP summary statistics, state wind-zone intensity |
| `program/estimate-mhs/` | `output/mhs/` | State TWFE on the Manufactured Housing Survey: price-index and placement event studies, static table of the other price/quantity outcomes, section-type table |
| `program/estimate-nfip/` | `output/nfip/` | Claim-level damage (event study + static), policy composition, take-up, wind-zone triple difference |
| `program/estimate-corelogic/` | `output/corelogic/{prices,quantities}/` | MH-only price and surviving-quantity event studies and static ladders (Rivanna only) |
| `program/cost-benefit/` | `output/cost-benefit/` | Benefit-cost ratio and the HUD forecast comparison; combine the MHS price effect with the NFIP damage effects |
| `program/tests/` | | Fake-data checks (`make test`, `make test-corelogic`) |

Each folder holds its entry scripts (`estimate-*.R`) next to the helper files
they source. `program/lib/` holds only `corelogic-sample.R`, which the CoreLogic
import uses.

`program/estimate-nfip/estimate-nfip-mh-only.R` is work in progress and not in
the paper (`make nfip-mh-only`, writes `output/nfip/mh-only/`; see
`notes/nfip-mh-only.md`).

## Running

```bash
make estimates   # descriptives, MHS, NFIP, cost-benefit (local)
make test
make paper.pdf
make slides.pdf  # regenerates output/slide-numbers.tex first
```

## CoreLogic (Rivanna)

CoreLogic licensed records are built and estimated on Rivanna. See the
[build documentation](notes/corelogic-databuild.md). From the repo root, after
committing and pushing:

```bash
./run_remote.sh estimate-corelogic                                   # prices, then quantities
./run_remote.sh estimate-corelogic estimate-corelogic-prices.R       # one script
```

`run_remote.sh` resets the Rivanna checkout (`~/manufactured-code`) to
`origin/main`, submits `program/estimate-corelogic/estimate-corelogic.slurm`,
waits, checks its final state, and downloads the exported aggregates into
`output/corelogic/<name>/`. It refuses to run if local
`program/estimate-corelogic` or `program/tests` differ from `origin/main`. The
Slurm file pins the verified build, Property Basic source, and public reference
directory; export `CORELOGIC_BUILD`, `CORELOGIC_PB_SOURCE`, or
`CORELOGIC_REFERENCE` locally to override them. Each script first runs its
synthetic check, then writes all output to a new private directory
`/scratch/chv7bg/manufactured-code/corelogic-results/<name>/<job id>/` and
repoints `<name>/current` to it. Only CSV, PDF, PNG, JSON, and LaTeX files are
exported; parquet files and fitted models stay on Rivanna.

The price job also reads `hud-benefit-2000.csv` from the public reference
directory. Build it with `Rscript program/import/databuild-hud-benefit.R` and copy
it once (again after any change to its inputs):
`rsync derived/hud-benefit-2000.csv chv7bg@login.hpc.virginia.edu:/scratch/chv7bg/manufactured-code/public-reference/`

`Rscript program/estimate-corelogic/replot-corelogic.R` redraws the CoreLogic
figures locally from the exported coefficient files.
