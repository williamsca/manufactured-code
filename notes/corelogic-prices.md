# CoreLogic vintage prices

The current analysis uses **2000–2023 sales**, construction vintages
**1989–1999**, and **1993 as the annual reference**. Static treatment includes
1994–1999, including the partially treated 1994 cohort. The outcome is log
land-inclusive sale price. There are no measured covariates.

The county specification contains county × sale-year, county × housing-type,
and construction-vintage fixed effects. The tract specification adds an
additive census-tract fixed effect. Annual coefficients interact MH with each
non-reference vintage; static coefficients interact MH with post treatment.
Percentage effects use `100 * (exp(beta) - 1)`, with county-clustered 95%
intervals. Transactions receive equal weight.

The tract assignment uses the pinned 2023 Property Basic snapshot's
10-character numeric census ID: county FIPS plus its first six tract digits.
It is joined by parcel ID, requiring agreement between sale and snapshot
county. Missing, incomplete, and invalid IDs remain unmatched. The dictionary
does not identify the census boundary vintage; this is snapshot geography,
not verified geography at each sale. The private lookup covers 4,906,030 of
4,973,259 distinct sale-sample parcels (98.65%) in 58,929 tracts.

The estimator fits the county model on all eligible sales (`county`), the
county model on tract-covered sales (`county_common`), and the model with
added tract effects on tract-covered sales (`tract`). The figure compares the
last two, avoiding a comparison between different tract-coverage samples.
Fixed-effect singleton removal is reported in the coefficient tables.

Current outputs are in `output/corelogic/prices/`: `vintage_prices.pdf` and its
PNG copy, static and annual coefficient CSVs, sample counts, tract coverage,
and the run manifest. Only current results are retained. Fitted models and
licensed records remain on Rivanna.

Run `./run_remote.sh corelogic prepare-corelogic-tracts.R` to refresh the
private lookup, then `./run_remote.sh corelogic estimate-corelogic-prices.R`,
which reads the latest lookup (`tracts/current`). The build must be complete and pass persisted-artifact
verification. The run archives its source code and input-reference hashes.
`make test-corelogic` includes known-truth tests of the vintage formulas and
tract sorting.

## Current results

| Specification | Post contrast (%) | 95% interval (%) | Sales |
|---|---:|---:|---:|
| county | 2.83 | [1.36, 4.32] | 8,112,916 |
| county_common | 2.96 | [1.53, 4.42] | 8,019,622 |
| tract | 3.79 | [2.73, 4.85] | 8,015,555 |

Adding tract effects reduces the static log-coefficient standard error by 27.2%.
The county-common and tract models share 8,022,780 input sales; their different
estimation counts reflect 4,067 additional singleton observations removed by
tract effects. Rivanna job 21148617 completed successfully.
