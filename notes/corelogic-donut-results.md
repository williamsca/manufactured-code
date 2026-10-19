# CoreLogic: 50-mile doughnut versus original sample

Both price and quantity estimates were rerun on Rivanna on October 19, 2026.
Baseline job: `21603240` (2m 23s). Doughnut job: `21603241` (2m 39s).
Both completed successfully. The two runs use identical analysis code and public
county references, verified against their manifest hashes. The rerun baseline
static coefficients reproduce the previously saved estimates exactly.

The doughnut excludes all records in 225 Zone I counties whose minimum distance
to a Zone II/III county is at most 50 miles. All treated counties are retained.
The private input build is `continental-donut-50mi-20261019`; the baseline is
`continental-v2-20261008`. Neither the original result directories nor their
private `current` pointers were replaced.

## Main pooled effects

Effects are `100 * (exp(coefficient) - 1)`, relative to Zone I. All four rows
below use state by construction-vintage fixed effects. Prices also absorb
county by sale-year fixed effects; counts absorb county fixed effects. Standard
errors cluster by county. The post indicator includes construction vintages
1994–1999; the pre period is 1989–1993. Price estimates here have no size controls.
Count estimates are PPML on surviving 2023 MH dwelling parcels by construction
vintage, with zero county-vintage cells retained. These are not annual shipments
or initial production counts.

| Outcome and contrast | Original | 50-mile doughnut | Doughnut 95% CI | Original p | Doughnut p |
|---|---:|---:|---:|---:|---:|
| MH prices, Zone II versus I | +0.25% | −1.32% | [−6.80%, +4.48%] | 0.928 | 0.648 |
| MH prices, Zone III versus I | +6.18% | +4.50% | [−3.33%, +12.96%] | 0.117 | 0.268 |
| MH counts, Zone II versus I | −10.58% | −7.50% | [−16.01%, +1.87%] | 0.022 | 0.113 |
| MH counts, Zone III versus I | −49.67% | −47.70% | [−58.43%, −34.21%] | <0.001 | <0.001 |

Removing nearby controls slightly lowers the price estimates and attenuates the
MH count declines. The large Zone III count decline remains. The smaller Zone II
count decline becomes less precise and its confidence interval includes zero.
The price estimates do not reveal a larger premium after excluding nearby controls.

With living-area and lot-size controls, the MH price estimate changes from
−2.33% to −2.97% for Zone II and from +4.97% to +4.22% for Zone III. Both remain
statistically indistinguishable from zero. In the state-vintage-adjusted MH/SB
DDD with size controls, the corresponding estimates move from −1.54% to −2.14%
and from +5.24% to +4.52%; both also have confidence intervals including zero.

## Event-study timing

The state-vintage-adjusted price paths are very similar. For the 1994 vintage,
the Zone III price effect moves from +9.52% to +9.90% (doughnut p = 0.020),
relative to the 1993 reference vintage. For 1999 it moves from +6.11% to +4.82%
and remains imprecise. The initial price response and weaker later response
therefore remain visible in both samples.

The quantity paths also nearly overlap. With the 1991 reference vintage, the
Zone III effect is −42.64% versus −40.14% for 1995 and −51.57% versus −50.64%
for 1999. The late-cohort shortfall survives the exclusion. The pre-reform
patterns remain too: the Zone II 1993 coefficient is +16.40% in the doughnut
(p = 0.049). Changing the control geography does not resolve pre-period
differences or the interpretation of surviving stock as a proxy for production.

The estimates are consistent with the main Zone III pattern being robust to
removing the nearest controls. They do not establish that plant spillovers are
absent. No formal test of the difference between the two correlated estimates
has been performed.

## Samples and saved artifacts

The eligible analytical MH sale sample falls from 299,681 to 282,704 (−5.7%).
After fixed-effect singleton removal, the pooled MH price model uses 294,164
versus 277,654 sales and 1,613 versus 1,473 counties. The dynamic quantity panel
contains 1,380,391 versus 1,199,515 surviving MH parcels (−13.1%). The pooled
MH count model uses 2,455 versus 2,268 counties.

The aggregate results are under `output/corelogic/donut-comparison-20261019/`:

- `baseline/{prices,quantities}/` and `donut/{prices,quantities}/`: regression
  tables, support counts, figures and manifests.
- `static-comparison.csv`: all pooled specifications, confidence intervals and
  differences in point estimates. Changes in transformed effects are percentage
  points; `change_log_points` records the raw coefficient difference.
- `dynamic-effects-long.csv`: both state-vintage-adjusted event studies.
- `prices-event-study-comparison.pdf` and
  `quantities-event-study-comparison.pdf`: overlaid paths with 95% intervals.
- `compare.R`: the script creating the comparison tables and figures from the
  downloaded aggregate results.

Licensed records and fitted models remain on Rivanna under
`/scratch/chv7bg/manufactured-code/corelogic-results/donut-comparison-20261019/`.
