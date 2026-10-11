# CoreLogic vintage prices

The current analysis uses **2000–2023 sales**, construction vintages
**1989–1999**, and **1993 as the annual reference**. Static treatment includes
1994–1999, including the partially treated 1994 cohort. The outcome is log
land-inclusive sale price. There are no measured covariates or tract fixed
effects, and the price script does not require a tract lookup.

Treatment follows `estimate-corelogic-share.R`: counties in HUD wind zones
II/III are treated and zone I counties are untreated. The same audited county
crosswalk is joined to sales; unmatched counties are reported and omitted.
All six models use the same matched sale sample with equal transaction weights.
Inference clusters by county; percentage contrasts use `100 * (exp(beta) - 1)`.

The four panels in `vintage_prices.pdf` and its PNG copy are:

- **National: county-adjusted:** the MH–site-built vintage log-price gap relative
  to its 1993 value. This remains a vintage × housing-type DiD, with county ×
  sale-year, county × housing-type, and construction-vintage fixed effects.
- **II/III minus I:** the triple difference in that vintage × type gap for
  treated counties relative to zone I, estimated with a pooled treatment term.
- **II minus I** and **III minus I:** separate triple differences from a joint
  model with both zone-specific treatment terms.

The DDD models include county × sale-year and county × housing-type fixed
effects, **zone × construction-vintage fixed effects**, and the common
**MH × construction-vintage interactions**. The triple interactions are
MH × treated-zone × construction-vintage. These lower-order terms absorb
zone-specific vintage price patterns common to both housing types and MH
vintage price patterns common to all zones. Annual coefficients are relative
to 1993. Static models retain annual zone × vintage effects and include both
MH × post and MH × treated-zone × post.

The national panel is an overall adjusted type × vintage contrast; the common
MH × vintage coefficient in either DDD model instead describes the zone I
baseline. Only the additional treated-zone coefficients enter the DDD panels.
The vertical line marks the 1994 cutoff and shading marks the partially
treated 1994 cohort. Construction vintage is the treatment clock, not sale year.

Outputs are in `output/corelogic/prices/`: `vintage_prices.pdf` and PNG,
`vintage_coefficients.csv`, `post_coefficients.csv`, sample counts, zone/type
support, county crosswalk, unmatched counties, and the run manifest. Coefficient
CSVs retain the lower-order MH effects as well as the triple interactions, with
`national_*`, `pooled_*`, and `separate_*` specification identifiers. Fitted
models and licensed records remain on Rivanna.

Run `./run_remote.sh corelogic estimate-corelogic-prices.R` after syncing the
code to origin/main. The build must be complete and pass persisted-artifact
verification. The run archives its source code and input-reference hashes.
`make test-corelogic` includes known-truth tests of national, pooled, and
zone-specific price formulas, lower-order vintage confounding, and partial
1994 treatment.

## Current results

Rivanna job 21183887 completed on October 10, 2026 using an isolated snapshot
of the edited local code. Source hashes were checked against the local files
before replacing the aggregate outputs. The matched sample contains 8,115,942
input sales in 2,419 counties; each model retains 8,112,916 sales after fixed-effect
singleton removal.

| Static specification | Contrast (%) | County-clustered 95% interval (%) |
|---|---:|---:|
| National, county adjusted (DiD) | 2.83 | [1.36, 4.32] |
| II/III minus I (DDD) | -2.17 | [-5.45, 1.24] |
| II minus I (DDD) | -3.22 | [-6.78, 0.46] |
| III minus I (DDD) | 4.25 | [0.29, 8.35] |

The annual DDD profiles show pre-1994 differences, including a positive 1989
contrast for zone II. These are relevant to evaluating parallel vintage trends;
the static coefficients alone do not establish a causal regulatory effect.
