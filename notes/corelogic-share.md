# CoreLogic MH share by construction vintage

The October 9, 2026 specification uses construction vintages 1989–1999,
1993 as the annual reference, and 1994–1999 as the static post period.
`program/corelogic/estimate-corelogic-share.R` reads the verified build's
`properties/` inventory, not its sales. Each eligible dwelling parcel counts
once, whether or not it sold. The denominator is classified MH plus site-built
single-dwelling parcels, not all housing units or park residents. Snapshot
screens exclude park/commercial dwelling codes and known multi-building or
multi-unit parcels; missing building/unit counts are allowed. Unknown counties
are reported and omitted after joining the audited wind-zone crosswalk.

These are surviving 2023 snapshot homes classified by the snapshot's original
construction year. They cannot recover historical construction flows, homes
removed before the snapshot, or unrecorded homes on shared park parcels.

Raw shares are exported nationally and by zone for every vintage. The national
linear probability model has county fixed effects and annual vintage indicators
(or a single post indicator). The wind-zone comparison has county and annual
vintage fixed effects, with annual vintage × zone interactions (or post × zone).
It is a difference in share changes across zones: MH is now the outcome, so
there is no separate housing-type difference to take. Pooled II/III and separate
II and III parameterizations are both estimated. County-vintage share cells
receive parcel-count weights, yielding the parcel-level regression coefficients.
Inference clusters by county; effects and intervals are in percentage points.
The exported `n` counts regression cells, while `homes_input` counts homes.

Rivanna job 21208555 completed successfully on October 11, 2026. It analyzed
11,336,139 homes; the full-sample annual and static coefficients match the
previous run (21140980) to numerical precision.
Aggregate outputs: `output/corelogic/share/`.

| Static specification | Contrast (pp) | County-clustered 95% interval (pp) |
|---|---:|---:|
| National, county adjusted | 2.25 | [1.89, 2.61] |
| II/III minus I | -1.57 | [-2.53, -0.61] |
| II minus I | -0.81 | [-2.02, 0.39] |
| III minus I | -3.51 | [-4.64, -2.39] |

The national raw share rises from 8.56% for the 1993 vintage to 11.64% for
1999. Zone I rises from 8.38% to 11.65%, zone II from 11.94% to 14.63%,
and zone III falls from 3.87% to 2.51%. These endpoint comparisons differ
from the adjusted static regressions, which use every pre/post cohort.

Figures: `share_by_vintage.pdf` displays raw national and zone shares;
`share_vintage_coefficients.pdf` displays national county-adjusted and zone
comparison profiles relative to 1993. The “National: county-adjusted” panel
plots the annual vintage indicators from `share ~ i(year_constr, ref = 1993) |
countyfp`, weighted by homes. Each coefficient is an adjusted within-county
difference in MH share from the 1993 vintage, in percentage points. It pools
all matched wind zones and does not use a treated/untreated comparison.
PNG copies and aggregate CSVs accompany
them. No record-level licensed files are downloaded. The private run archives
source code and model objects and records input paths and source hashes.

`make test-corelogic` includes known-truth tests of all six share equations.
Run with `./run_remote.sh corelogic estimate-corelogic-share.R`.

## Static III-minus-I LaTeX table

`static_III_minus_I.tex` is generated with `fixest::etable()` and compares
baseline county effects with additive tract effects. There are no size controls.
The outcome is MH share in **percentage points**, so coefficients and standard
errors are already on the reported scale. This is a share DiD across zones;
housing type is the outcome rather than a third difference.

Both columns include county and pre/post fixed effects plus separate
zone II × post and zone III × post interactions. The displayed coefficient is
zone III × post, relative to zone I. Pre is 1989–1993; post is 1994–1999,
including the partially treated 1994 cohort. Zone II remains in the joint model.
The annual share models and figures continue to use all matched eligible homes.

The table uses the same tract-covered surviving inventory in both columns,
after tract-model singleton removal. Each tract-vintage share cell receives
its home count as the regression weight. The table distinguishes the number
of cells from the underlying number of homes. Inference clusters by county.

Tracts are assigned by joining the eligible inventory's parcel IDs and counties
to the pinned 2023 Property Basic snapshot, using the same validated numeric
census-ID rule as the price lookup. **The sale-only tract lookup is not used**:
homes that never sold remain eligible. The geography is snapshot geography,
not verified at the construction date. `tract_coverage.csv` reports coverage;
`static_support.csv` reports retained pre/post support, and
`static_coefficients.csv` retains both zone interactions and intervals.

The pinned Property Basic source is required for share estimation, in addition
to the verified build and county reference. The source archive and run manifest
record the snapshot manifest hash. `make test-corelogic` checks static tract
formulas and equality of weighted-cell and parcel-level coefficients.


The current static table uses 11,079,895 homes in 2,698 counties and 568,234
tract-vintage cells in each column (job 21208555). The III-minus-I estimate is
-3.483 pp (SE 0.569; 95% interval [-4.60, -2.37]) at baseline and -2.866 pp
(SE 0.317; 95% interval [-3.49, -2.24]) with tract effects. Both columns use the
same retained inventory; the new table differs from the earlier full-sample
static export because it conditions on tract coverage and uses a fully collapsed
pre/post lower-order effect.

The LaTeX table uses default `etable()` significance stars and standard errors,
with no notes in the table file. Explanations belong in the ultimate document.


## MH-only quantity event study

`mh_only_vintage_quantities.pdf` and its PNG copy show the vintage profile of
**MH counts**, separately comparing zone II and zone III with zone I. This is
not an MH share regression: there is no site-built outcome or denominator.
Counts come from the eligible surviving 2023 inventory, not transactions.
They measure the number of surviving homes by original construction year,
not historical construction flows or units subsequently removed.

Every county with at least one eligible MH home in 1989–1999 contributes all
11 vintage cells, including zero counts. Counties with no MH over the whole
window contain no information for a county-effect Poisson count model and
are omitted. The model uses Poisson pseudo-maximum likelihood with county and
vintage effects plus separate vintage × zone II and vintage × zone III
interactions, relative to 1993. There are no tract effects, size controls,
exposure denominator, or additional observation weights. Inference clusters
by county. Coefficients are converted to percentage count contrasts through
`100 * (exp(beta) - 1)`, rather than percentage points.

`mh_counts_by_county_vintage.csv` exports the balanced county-vintage aggregate
panel; `mh_counts_by_vintage.csv` reports aggregate MH counts and zero-cell
support by zone and vintage. `mh_only_vintage_coefficients.csv` retains the
count-model coefficients and intervals. The private model archive includes
the fitted Poisson model. Synthetic checks cover known count ratios, the
1993 reference, and retaining missing cohorts as zeros.

The MH count run (21208555) covers 1,165,546 homes in 2,455 counties and
27,005 county-vintage cells, including 3,082 zero-count cells. All 20
non-reference zone-vintage count interactions are identified. The existing
share coefficients are unchanged from the previous run.
