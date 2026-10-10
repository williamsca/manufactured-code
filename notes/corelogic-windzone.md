# CoreLogic wind-zone price triple differences

The current analysis uses **2000–2023 sales**, construction vintages
**1989–1999**, and **1993 as the annual reference**. Static treatment begins
in 1994. There are no measured covariates. The outcome is log land-inclusive
sale price; effects use `100 * (exp(beta) - 1)`.

The pooled static equation contains MH × post and MH × post × 1(zone >= II),
with county × sale-year, county × housing-type, and zone × annual construction
vintage fixed effects. Its triple difference compares the MH/site-built
post-versus-pre vintage pattern in zones II/III with that in zone I.
The separate-zone parameterization substitutes II-minus-I and III-minus-I
interactions. Annual profiles replace post with vintage indicators, omitting
1993 only. Lower-order terms remain in every model.

The tract specification adds additive census-tract fixed effects. As in the
[national price analysis](corelogic-prices.md), the figure compares county and
tract models using the same tract-covered input sample, with singleton removal
reported separately. County clustering is primary; static exports also include
state-clustered sensitivity intervals. The limited zone-III state support
remains relevant to inference.

County zones are reconstructed from the published county lists in the official
2020 edition of 24 CFR 3280.305(c)(2), matched to the pinned county reference.
The lookup includes historical Dade County as zone III, leaves unknown FIPS
unmatched, and asserts 144 zone-II counties and 25 zone-III counties plus the
historical Dade alias. Reconciliation and unmatched-county audits are exported.
Current siting zone is not a verified original design-zone label.

Current outputs are in `output/corelogic/windzone/`:
`vintage_ddd.pdf` displays pooled II/III-minus-I profiles, and
`vintage_ddd_byzone.pdf` displays separate II-minus-I and III-minus-I profiles.
Both compare county and tract effects without covariates; PNG copies, static
and annual coefficient tables, support audits, and a run manifest accompany
them. Only current results are retained. Fitted models and licensed records
remain private on Rivanna.

Submit `corelogic-windzone.slurm` with `CORELOGIC_BUILD`, `CORELOGIC_RESULTS`,
`CORELOGIC_REFERENCE`, and `CORELOGIC_TRACTS`. `make test-corelogic` recovers
known static/annual wind-zone effects and tests tract sorting. Price profiles
remain descriptive: a causal interpretation requires comparable untreated
MH/site-built vintage patterns across zones.

The parallel [MH-share analysis](corelogic-share.md) measures shares of
surviving snapshot homes, with effects in percentage points.

## Current results

County-clustered static contrasts on tract-covered input sales:

| Comparison | County effects (%) | County 95% interval (%) | Add tract effects (%) | Tract 95% interval (%) |
|---|---:|---:|---:|---:|
| II/III minus I | -2.39 | [-5.66, 1.00] | 0.95 | [-1.70, 3.68] |
| II minus I | -3.35 | [-6.91, 0.34] | 0.70 | [-2.21, 3.70] |
| III minus I | 3.46 | [-0.31, 7.38] | 2.47 | [-2.15, 7.32] |

Tract effects reduce the pooled static standard error by 21.9% and the
zone-II standard error by 21.8%, but increase the zone-III standard error
by 24.3%. There is no clear nonzero static contrast in any of the tract
zone specifications. County-common and tract estimation counts are 8,019,622
and 8,015,555, respectively, reflecting additional fixed-effect singletons.
Rivanna job 21148618 completed successfully; the tract lookup job was 21143386.
