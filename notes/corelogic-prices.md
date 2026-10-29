# CoreLogic vintage prices

## County-by-vintage DDD and linked event study (October 29, 2026)

The fourth slide column adds county x construction-vintage fixed effects to
county x sale-year x type and state x vintage x type effects, without size
controls. The site-built zone x post terms are absorbed. The estimator exports
this fit as `mh_county_vintage.csv` and includes it in all four boxed slide
tables. DDD static columns use the observations retained under this stricter
FE specification so comparisons preserve N. The original six-column paper
ladder remains available. The appendix DDD event study uses `log_es_ddd.pdf`
(baseline and size-adjusted curves), with links in both directions from the
static slide.

## Common size-valid sample and slide exports (October 29, 2026)

Every price, area-outcome, event-study and no-Florida model now requires
positive, finite dedicated living area and lot size. The static ladders also
remove singletons under their most demanding fixed effects before fitting
any column: columns 1--3 share retained MH sales and columns 4--6 share
retained MH/site-built sales. Quantity estimates continue to count the full
stock, rather than conditioning that population on sale-size coverage.

The price estimator exports `mh_static_ladder_slides_1.tex` through `_3.tex`
directly from fitted models. These show models 2, 5 and 6, all visible on
every overlay, with a native `etable` box highlighting successive columns.
SEs appear beside estimates; unused FE rows disappear automatically. The
slide macro generator only handles quoted numbers, not table construction.


Rivanna job 22157275 completed both price and quantity estimation successfully.
The six-column log-price table has 294,529 retained MH sales in columns 1--3
and 8,709,195 retained MH/site-built sales in columns 4--6. The selected
Zone III premiums (columns 2, 5, 6) are 5.07%, 8.98%, and 7.33%. The revised
reference mean is $87,844.08; the adjusted premium converts to $6,437.57 in
2000 dollars. Table highlights were subsequently re-exported from this run's
saved fits to correct the first box's endpoint; estimates are unchanged.

## Paper dollar conversion and benefit comparison (October 16, 2026)

The price table now has three variants per design: common vintage effects,
state x vintage effects, and state x vintage effects plus log living area and
log lot size. Displayed columns 1--3 are MH DiDs; 4--6 are MH/SB DDDs. The DDD
allows size slopes to differ by housing type. Dedicated living area and lot
area come from the pinned 2023 Property Basic snapshot, matched by clip and
county. Positive finite values are required only in the adjusted columns;
there is no imputation or upper trimming. Snapshot size need not equal size at
sale, and conditioning on size may remove part of a regulatory response.

Rivanna job 21460694 completed the six-column analysis. The adjusted Zone III
coefficients are 0.04848 (SE 0.03836; +4.97%) for MH DiD and 0.05105
(SE 0.03261; +5.24%) for DDD. On the same retained observations, the respective
unadjusted effects are +5.19% and +6.80%. Adjusted sample sizes are 273,738
and 7,993,636. Coverage and common-sample comparison coefficients are exported
in `size_sample_coverage.csv` and `size_common_sample_coefficients.csv`.
All four original unadjusted estimates are unchanged and now occupy columns
1, 2, 4, and 5; headline premium ranges retain those four specifications.

The main dynamic price and quantity figures now use state x construction-year
fixed effects. `replot-corelogic.R` and both estimation entrypoints select the
`*_state_vintage_fe.csv` coefficient tables for `*_paper.pdf`; the comparison
figures continue to show both specifications. The paper's equations, figure
notes, and quoted dynamic coefficients use the same state-specific model.

The paper uses the mean transaction price of Zone III MH built in 1989--1993
as the dollar base: $90,508.7588 in 2000 dollars, from 5,358 transactions.
Multiplying this by `expm1(b)` for the four static Zone III coefficients gives
$6,804.52, $5,589.70, $2,086.52, and $7,576.94. These are illustrative
land-inclusive resale premiums, not identified upfront production costs.
The range across specifications is not a confidence interval.

`output/corelogic/prices/mh_price_summary.csv` contains the aggregate means
and medians by zone and pre/post vintage. The initial export was computed in
Rivanna Slurm job 21456739 using the sale filters in `cl_price_sample()`, the
continental-v2-20261008 build, and job 21416978's wind-zone crosswalk. It uses
the matched sample before fixed-effect singleton removal; all 299,681 MH
transactions are accounted for. `estimate-corelogic-prices.R` now produces
the same summary in future price runs. No licensed transaction records were
downloaded.

`program/cost-benefit/estimate-corelogic-comparison.R` generates the paper's
new table and scalars. It takes only the Zone III flood-benefit, discounting,
and CPI scalars from `hud-comparison-scalars.csv`; it does not use that file's
state-level price estimates. The existing zone-specific flood calculation
implies $970.69 in avoided damage, $255.16 in reduced NFIP payments, and
$715.53 in retained-loss benefits. Avoided damage is 14.27% of the baseline
resale premium and 12.81--46.52% across specifications. HUD forecasts in the
new table also refer to Zone III, using national pre-reform home-size shares.
Population differences between NFIP-insured homes and transacted homes on
owner-held land remain explicit in the paper. The MHS-based outputs remain
available for the appendix and other documents.

The analysis uses **2000–2023 sales**, construction vintages **1989–1999**,
and log land-inclusive sale price in 2000 dollars. Treatment follows
`estimate-corelogic-share.R`: HUD zones II and III are compared separately
with zone I using the same audited county crosswalk. Unmatched counties are
reported and omitted. Transactions receive equal weight; inference clusters
by county. Percentage contrasts use `100 * (exp(beta) - 1)`.

## Annual price figure

`vintage_prices.pdf` and its PNG copy contain only **II minus I** and
**III minus I**, from the joint zone-specific annual DDD model. Both panels
retain the full matched eligible sale sample; neither uses tract effects or
size controls. Construction year 1993 is the reference. The vertical line
marks the 1994 cutoff and shading marks the partially treated 1994 cohort.
The national and pooled-treated panels have been removed.

The model includes county × sale-year and county × housing-type fixed
effects, zone × annual construction-vintage fixed effects, common MH ×
vintage interactions, and separate MH × zone II × vintage and MH × zone III
× vintage interactions. The plotted coefficients are the last two sets.
**Zone II is included in the III-minus-I regression**, with its own separate
MH × vintage response. It is not pooled into the zone I reference. Its own zone-specific profile is absorbed by the zone II interactions; it does
not enter the untreated comparison group. In the controlled static model,
the size-control slopes are estimated jointly across zones.

## Static III-minus-I table

`static_III_minus_I.tex`, generated by `fixest::etable()`, reports three columns:

1. Baseline county effects.
2. Additive snapshot census-tract effects.
3. Tract effects plus log lot size and log living area.

These are fully collapsed pre/post construction-vintage regressions:
**pre is 1989–1993; post is 1994–1999**, including the partially treated 1994
cohort. Every column includes county × sale-year and county × housing-type
effects, zone × pre/post effects, and common MH × post plus separate
MH × zone II × post and MH × zone III × post interactions. The reported
coefficient is `post_mh_z3`. Zone II remains in the joint model.

All columns use the same estimation sample: valid tracts and positive, finite
lot and living area, followed by the controlled model's fixed-effect singleton
removal. This makes changes across columns reflect the specification rather
than observation availability. The annual figure continues to use the full
sale sample. The static table's baseline therefore need not equal the old
full-sample static estimate; its lower-order vintage effects also now use the
pre/post split rather than annual vintage effects.

Size controls are `land_square_footage` and
`living_square_feet_all_buildings` from the pinned 2023 Property Basic
snapshot, joined by parcel ID with county agreement. The latter is dedicated
living area, **not** source-selected `universal_building_square_feet`.
No upper trimming or imputation is applied. Tract assignments come from the
verified lookup for the same build. These geography and size measures describe
the snapshot, not necessarily the parcel at the time of sale.

The table reports log-price coefficients with the default `etable()` significance
stars and county-clustered standard errors, observation counts, fixed effects,
and controls. There are no confidence-interval rows or table notes; explanatory
text belongs in the document that includes the table.
It replaces the previous standalone PDF/Markdown/CSV table. The redundant
windzone estimation script and aggregate output folder have been removed;
this price estimator now handles the geographic triple differences.
`post_coefficients.csv` retains all three models' lower-order coefficients and
size-control slopes. `vintage_coefficients.csv` retains the annual common MH
and separate-zone coefficients. `static_sample_coverage.csv` reports tract and
size coverage by zone, housing type and pre/post; `static_support.csv` reports
support on the common estimation sample. Licensed records and model objects
remain on Rivanna.

Run `./run_remote.sh corelogic estimate-corelogic-prices.R` after syncing code
to origin/main. The verified build, pinned Property Basic snapshot, and verified
tract lookup are required. `make test-corelogic` includes known-truth checks
for annual DDDs and static pre/post DDDs with tract and size confounding.
The run archives its source code and records build, tract, snapshot and code
hashes. Annual pre-treatment differences should be assessed before interpreting
static estimates as causal regulatory effects.

## Current results

Rivanna job 21208555 completed on October 11, 2026 and generated the
`etable()` LaTeX version with default stars/SEs and no notes, plus the
MH-only event study. Price coefficients match job 21206095 to numerical
precision. The annual model has
8,115,942 input sales and retains 8,112,916; its coefficients match the
previous joint-zone annual model to numerical precision. Static complete-case
input contains 7,938,355 sales; after 7,133 singleton removals, all three columns
use exactly 7,931,222 sales in 2,144 counties. Source hashes were verified against
the local code before refreshing outputs.

| III-minus-I static specification | Effect (%) | 95% interval (%) |
|---|---:|---:|
| Baseline | 4.44 | [0.47, 8.57] |
| Add tract effects | 3.50 | [-1.41, 8.65] |
| Add tract effects and log lot/living area | 1.64 | [-1.94, 5.36] |

The corresponding log coefficients are 0.0434, 0.0344, and 0.0163, with
county-clustered standard errors 0.0198, 0.0248, and 0.0183. These differ from
the previously reported static III-minus-I contrast because the new table uses
a common tract-and-size-covered sample and fully collapsed pre/post effects.


## MH-only price event study

`mh_only_vintage_prices.pdf` and its PNG copy show zone II minus I and zone III
minus I using **MH sales only**, with no site-built comparison. The outcome is
log real sale price. The equation includes county × sale-year and construction-
vintage effects plus separate vintage × zone II and vintage × zone III
interactions, with 1993 omitted. No tract effects or size controls are included
in this added baseline event study. Transactions receive equal weight;
inference clusters by county. The MH-only price figure plots raw log-point
coefficients and confidence intervals, without exponentiating them. A coefficient
of 0.10 corresponds to about 10.52 percent. Annual CPI deflation to 2000 dollars
is redundant for these coefficients because county × sale-year effects absorb
the year-specific additive deflator in log prices.
These coefficients are geographic vintage DiDs within MH, rather than the
housing-type triple differences in `vintage_prices.pdf`.

`mh_only_vintage_coefficients.csv` retains the estimated interactions and
intervals; `mh_only_support.csv` reports MH sale support by zone and vintage.
The fitted MH-only model remains in the private model archive.

The MH-only run (21208555) has 299,681 input sales and retains 294,190 after
county-by-sale-year singleton removal. All 20 non-reference zone-vintage
interactions are identified. Both LaTeX tables passed a compilation check.
