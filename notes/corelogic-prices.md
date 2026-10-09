# CoreLogic vintage price estimates

## Current specification: 1994 retained

October 8 correction: **keep 1994 as its own partially treated cohort in every
annual vintage profile**. The reference remains the joint 1992–1993 cohort.
The updated sample retains all 1984–1999 construction vintages, with 1994 freely
estimated rather than removed or assigned an assumed treatment fraction.

The static summaries also retain these sales, adding a separate `MH × 1994`
coefficient while comparing fully post-reform 1995–1999 vintages with 1984–1993.
The 1994 indicator is included in snapshot size balance too.

The full input now contains 13,411,259 sales (472,020 MH). The main county-type
2000–2023 specification uses 11,532,210 sales after singleton removal, including
25,349 MH transactions from the 1994 cohort before singleton removal.
Its dynamic 1994 coefficient is **+1.41%**, with county-clustered 95% interval
**[+0.16%, +2.68%]**, relative to the joint 1992–1993 MH/site-built vintage contrast.
The static fully post-reform contrast is +2.13% [0.57%, 3.73%]; the transition
cohort is not folded into that coefficient.

![Vintage profiles retaining 1994](../output/corelogic/prices-1994-v1-20261008/vintage_prices.png)

[PDF vintage profile](../output/corelogic/prices-1994-v1-20261008/vintage_prices.pdf)
and [common-sample size comparison](../output/corelogic/prices-1994-v1-20261008/vintage_prices_size.pdf).
The gray band identifies the partially treated 1994 cohort. Every non-reference
construction year, including 1994, has an estimated point and interval.

Rivanna job 21089019 completed in 7m56s with about 14.6 GiB peak memory; private results are at
`/scratch/chv7bg/manufactured-code/corelogic-results/prices-1994-v1-20261008`.
Aggregate outputs are under `output/corelogic/prices-1994-v1-20261008/`.
The existing private build already retained these sales; estimation now uses
`eligible_sale` plus the construction/sale-date check instead of the legacy
`analysis_ready` flag that excluded 1994. Synthetic tests recover a distinct
1994 effect and the later-cohort effect using the production formulas.

## Earlier run: 1994 omitted (superseded)

Estimated on Rivanna October 8, 2026. Slurm job 21084781 completed in 5m49s,
with about 13.4 GiB peak memory. The verified private build is
`/scratch/chv7bg/manufactured-code/corelogic/continental-v2-20261008`; estimates
and lean fitted models remain in
`/scratch/chv7bg/manufactured-code/corelogic-results/prices-v1-20261008`.
Only aggregate tables and figures were copied locally.

The initial results do not show a stable positive vintage price premium.
The sign changes with geography, calendar coverage, and size controls. That
makes composition and within-county sorting central to the next analysis.

## Specification and sample

Outcome is log land-inclusive sale price, deflated to 2000 dollars with the
build's annual CPI-U reference. Annual deflation does not affect the vintage
coefficients with county × sale-year fixed effects. Classification uses the
derived MH indicator. Original construction vintages are 1984–1999; preferred
estimates omit 1994. Original vintage never falls back to the 2023 assessor year.

The annual model is

    log(price) ~ MH × construction-vintage indicators
                 | county × sale year + MH + construction vintage.

The county-type version replaces the common MH intercept with county × MH
fixed effects. Annual MH interactions jointly omit 1992 and 1993. The displayed
percentage contrasts are `100 * (exp(beta) - 1)`; intervals transform the
county-clustered log-coefficient intervals. Fixed-effect singletons are removed
by fixest. This is a vintage profile, not an event-time analysis.

The full preferred input has 12,508,952 sales, including 442,767 MH sales, in
2,431 counties. The county-type 2000–2023 specification uses 10,770,104 sales
after singleton removal (386,428 MH sales before removal). All cohorts have
been built by 2000, reducing mechanical differences in possible sale dates.
The 2023 delivery ends in August, so 2023 is partial. Observations receive
equal transaction weight in this first pass.

## Post-vintage contrasts

These are separate regressions replacing annual MH interactions with
`MH × 1(vintage >= 1994)`, retaining annual construction-vintage effects.
Preferred comparisons are therefore 1995–1999 versus 1984–1993. They do not
equal the arithmetic mean of the plotted annual coefficients.

| Specification | Contrast (%) | 95% interval (%) | Sales used |
|---|---:|---:|---:|
| County × sale year, 1990–2023 | -2.43 | [-5.47, 0.71] | 12,505,164 |
| Add county × type, 1990–2023 | 0.34 | [-1.42, 2.13] | 12,505,004 |
| County × sale year, 2000–2023 | -0.23 | [-3.25, 2.88] | 10,770,259 |
| Add county × type, 2000–2023 | 2.11 | [0.55, 3.70] | 10,770,104 |
| Size-data common sample, no size controls | 1.32 | [-0.21, 2.87] | 10,616,132 |
| Same sample, floor area and lot controls | -1.28 | [-2.34, -0.20] | 10,616,132 |
| Exclude Florida, county × type, 2000–2023 | 2.90 | [1.24, 4.58] | 9,091,557 |
| Documented consideration only, county × type, 2000–2023 | -0.02 | [-8.21, 8.91] | 1,324,547 |
| Include 1994, county × type, 2000–2023 | 2.01 | [0.56, 3.48] | 11,532,210 |
| Vintages 1990–1997, county × type, 2000–2023 | 2.79 | [1.40, 4.21] | 4,821,680 |

Size controls are log building area, log lot area, and their squares. Valid
areas are 200–10,000 building sq ft and 100–4,356,000 lot sq ft. This first
pass pools area slopes across types; interactions and alternative area definitions
are part of the next robustness work. No sale-price trimming was applied.
The documented-price sample has only 20,280 MH sales before singleton removal
and 229 represented counties; its broad interval and different coverage do not
establish an absence of a premium.

## Annual profiles and initial amenity balance

![Initial vintage price profiles](../output/corelogic/prices-v1-20261008/vintage_prices.png)

[PDF figure](../output/corelogic/prices-v1-20261008/vintage_prices.pdf).
With county × type effects and 2000–2023 sales, the 1995 profile is +0.95%
(interval -0.60% to 2.52%); 1996–1998 are approximately +2.4% to +3.3%; 1999
is +1.75% (interval -0.59% to 4.15%). Earlier profiles are not flat: 1984 and
1986 are around +3.3%, whereas 1988 and 1990 are about -2.2%. This does not
support reading the post coefficient as an isolated reform jump.

![Common-sample size adjustment](../output/corelogic/prices-v1-20261008/vintage_prices_size.png)

[PDF size-adjustment figure](../output/corelogic/prices-v1-20261008/vintage_prices_size.pdf).
The shift from +2.11% in the full later-sales sample to +1.32% on the size-data
sample is a sample-composition change. The shift from +1.32% to -1.28% on that
same sample is the association with conditioning on measured building/lot size.
Neither is an identified causal decomposition.

Applying the same post-interaction equation to snapshot size on the common sample
gives 0.0353 log points for building area (about +3.6%, interval +2.3% to +4.9%)
and 0.2225 log points for lot area (about +24.9%, interval +17.9% to +32.3%).
These are differential MH vintage contrasts relative to the site-built vintage
pattern, after county × year, county × type, and vintage effects. They are not
raw comparisons of later with earlier MH alone.

The larger lot contrast motivates testing both land amenities and physical
hazard sorting. Area and geocodes come from the 2023 snapshot, not observations
verified at each historical sale. Adjustment can reflect later changes and
survival; current snapshot agreement does not establish historical measurement.
Prices include land and therefore cannot be compared directly to new-home
manufacturing compliance costs.

## Next work and reproducibility

The [robustness plan](../PLAN_CORELOGIC_ROBUSTNESS.md) prioritizes single/double
wide and richer amenity balance, coordinate validation, fine-geography price
comparisons, and coast/elevation/surge/floodplain exposure within county. It
specifies common-sample comparisons, overlap reporting, and temporal limitations.
No physical risk joins or hurricane damage regressions have been run yet.
Initial price estimates pool HUD wind zones; policy-zone comparisons await a
reconciled wind-zone reference rather than assuming unmatched counties are zone I.
The subsequent [wind-zone triple-difference analysis](corelogic-windzone.md)
now supplies that comparison using a reconstructed and audited reference.

`program/estimate/estimate-corelogic-prices.R` requires Slurm, a complete build
manifest, and a passed persisted-artifact verification. The job accepts
`CORELOGIC_BUILD` and a new `CORELOGIC_RESULTS` directory; see
`program/estimate/corelogic-prices.slurm`. The initial result manifest preserves
the exact estimation code hash; that job's source is archived privately under
`source-v1/` in its results directory. The current script uses the project's
linear estimation-script style, with figures in its own plotting section and
shared setup in `program/lib/corelogic-setup.R`. The tested price formulas live
in `program/lib/corelogic-prices.R`. Each run archives these source files and
their hashes. Fitted
models remain private. Aggregate CSVs include all annual coefficients, post
coefficients, vintage/sale-year support, and snapshot size balance.

`make test-corelogic` passes the sample-screen fixtures and a synthetic known-truth
test of both the static and annual price formulas. The estimation job identified
every intended non-reference cohort in every specification. Confidence intervals
are county-clustered; no multiple-testing correction was applied to this initial
descriptive price profile.

Cleanup validation (2026-10-09): Rivanna job 21119448 reran every specification
against the same verified build, writing privately to
`/scratch/chv7bg/manufactured-code/corelogic-results/prices-refactor-v1-20261009`.
Comparison job 21119463 matched all five aggregate CSVs to the 1994-retaining
run within numerical tolerance (`1e-8`); both PNG figures were byte-identical.
The synthetic formula checks also passed.
