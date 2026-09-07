# Take-up reconstruction, September 7, 2026

The fixed effects are unchanged: county × five-year calendar period, housing
type, and vintage bin in the dynamic model; the static model replaces the
vintage terms with a post-1994 main effect and post-1994 × MH interaction.
No county × housing-type effects were added to the baseline. State clustering
is retained. Per-home outcomes use a log home-year offset; claims per policy
uses observed policy exposure.

## Corrections

1. Replace all non-mobile occupied housing with occupied one-unit attached or
   detached housing, using Census 2000 HCT006. Keep MH separately.
2. Form the sampling frame from positive Census-imputed stock, crossed with
   all three policy periods. Join counts, including zeros. Previously the
   panel was selected on positive policy counts. Aggregate claims directly
   from the claims sample so a missing policy/tract row cannot erase a claim.
3. Adjust occupied stocks for vacancy using H030 all-unit counts divided by
   all-vintage occupied HCT006 counts, separately by county and housing type.
   **Assumption:** within a county/type, vacancy is independent of vintage.
   There is no direct all-unit vintage-by-type count in these tables. This
   is an adjustment, not an observation of vacant homes by vintage.

Annual placement/permit shares and full-bin normalization are unchanged.
1994 is excluded from both sides; the 1999–March 2000 bin gives 2000 a 3/12
weight. The stock remains fixed at 2000; differential subsequent attrition
and vacancy remain limitations. State clustering does not remove systematic
imputation bias.

## Results

Percentage changes; confidence intervals use 1.96 state-clustered standard errors.

| Outcome | Previous | Revised | Revised 95% CI |
|---|---:|---:|---:|
| Policies per home | +0.7% | +22.8% | +4.3% to +44.5% |
| Claims per home | +19.2% | +42.5% | +15.7% to +75.5% |
| Claims per policy | +6.0% | +6.4% | −3.5% to +17.3% |

The staged policies-per-home estimates are +0.7%, +12.7%, +19.3%, and +22.8%
for the previous construction, matched occupied single-family denominator,
full stock grid, and vacancy-adjusted full grid, respectively. The +19.3%
occupied-stock result has a 95% interval of −0.2% to +42.7%; significance at
5% therefore depends on the vacancy adjustment. All three previous estimates
are reproduced to numerical precision before applying the corrections.

The full input grid has 147,555 cells, including 78,555 with zero policies.
After Poisson removes all-zero fixed-effect groups and singletons, the
policies-per-home fit uses 130,981 cells (previously 68,438). The matched
sample contains 11,947,662 policy terms, one fewer than before because of
the type-matched positive-stock restriction. Claims per home includes
121,330 claims, compared with 121,184 in the previous positive-policy-row
construction. Claims per policy requires positive policy exposure and is
therefore estimated on a different set of cells.

The positive take-up contrast is not evidence of crowd-out. It is not by
itself proof of a causal insurance-demand response to the building standard:
stock allocation, vacancy, survival, and the vintage profile still matter.
The three Poisson coefficients need not add because their exposures and
estimating samples differ.

## Reproduction and files

- `program/import/import-census-takeup.R` downloads 39 Census variables and
  writes `derived/census2000-takeup-source.csv` and the new vintage anchor.
  It leaves the original occupied-MH anchor for MHS/welfare unchanged.
- Run `program/import/impute-stock.R`, then
  `program/estimate/estimate-nfip.R`; no raw NFIP download is required.
- `program/lib/takeup-panel.R` constructs the production panel and is tested
  directly by `program/tests/test-take-up-imputation.R`.
- `program/estimate/audit-takeup-revision.R BEFORE_STOCK_PATH` reconstructs
  all four stages. This session's old stock is preserved at
  `/tmp/takeup-before/stock-county-vintage.Rds`.
- Full precision estimates, standard errors, intervals, and sample counts:
  `output/results/takeup-revision.csv`; take-up vintage coefficients:
  `output/results/takeup-revision-vintages.csv`.
