# CoreLogic wind-zone triple differences

## Current specification: 1994 retained

October 8 correction: the dynamic profiles retain every cohort from 1984 to
1999, **including a freely estimated 1994 transition cohort**, relative to the
joint 1992–1993 reference. The gray band marks partial treatment in 1994.
Static summaries retain the same observations and give 1994 separate MH and
MH × zone interactions, rather than treating it as fully pre or fully post.
For the pooled static equation, add `MH × 1994` and
`MH × 1994 × 1(zone >= II)` to the post-interaction equation below.

The main 2000–2023 sample uses 11,532,210 sales after singleton removal. Its
1994 MH input is 19,328 sales in zone I, 5,180 in zone II, and 841 in zone III.
The dynamic 1994 contrasts, relative to the 1992–1993 reference, are:

| Comparison | 1994 coefficient (%) | County-clustered 95% interval (%) |
|---|---:|---:|
| Zones II/III minus I | 1.12 | [-1.68, 4.00] |
| Zone II minus I | 0.47 | [-2.55, 3.59] |
| Zone III minus I | 4.61 | [0.21, 9.21] |

The pooled 1994 coefficient is imprecise, while the III-minus-I point estimate
is larger. These are annual composition/price contrasts, not a prescribed
fraction of the later-cohort effect. The limited county/state support for III
still applies. The static fully post-reform DDD is -6.26% [-9.76%, -2.62%],
with 1994 retained as its own category.

![Annual DDD retaining 1994](../output/corelogic/windzone-1994-v1-20261008/vintage_ddd.png)

[PDF annual profile](../output/corelogic/windzone-1994-v1-20261008/vintage_ddd.pdf),
[common-sample size comparison](../output/corelogic/windzone-1994-v1-20261008/vintage_ddd_size.pdf),
and [separate-zone profiles](../output/corelogic/windzone-1994-v1-20261008/vintage_ddd_byzone.pdf).

Rivanna job 21089020 completed in 6m39s with about 18.1 GiB peak memory, with private results under
`/scratch/chv7bg/manufactured-code/corelogic-results/windzone-1994-v1-20261008`.
Aggregate outputs are under `output/corelogic/windzone-1994-v1-20261008/`.
The audited county mapping and the other sale screens are unchanged; the
persisted legacy flag excluding 1994 is replaced by `eligible_sale` plus the
construction/sale-date guard. Support tables distinguish pre, 1994 transition,
and fully post-reform cohorts. Synthetic tests recover a known partially
exposed cohort alongside the other annual and static effects.

## Earlier run: 1994 omitted (superseded)

This extends [the first vintage price analysis](corelogic-prices.md). All
licensed records and estimation remain on Rivanna. MH classification uses the
derived indicator; construction vintage is the original year. Cohorts are
1984–1999, excluding 1994, and the main sale window is 2000–2023.

## Initial results

Estimated October 8, 2026 on Rivanna, job 21087901. The completed run took
4m22s and used about 15.5 GiB peak memory. Private results are under
`/scratch/chv7bg/manufactured-code/corelogic-results/windzone-v5-20261008`;
the exact source files and reference hashes are saved with the manifest.

The pooled zones-II/III-minus-I estimate is negative, rather than a positive
relative price premium. It weakens to approximately zero with the narrower
1990–1997 construction cohorts. Zone II drives the broad-cohort result; zone III has a smaller,
imprecise contrast that changes sign after size adjustment. These are descriptive
contrasts, conditional on the vintage-pattern assumptions discussed below.

| Specification | II/III minus I (%) | County-clustered 95% interval (%) |
|---|---:|---:|
| All sales, 1990–2023 | -3.29 | [-7.56, 1.18] |
| Sales 2000–2023 | -6.13 | [-9.61, -2.51] |
| Common size-data sample, no size controls | -5.12 | [-8.63, -1.48] |
| Same sample, building/lot area controls | -5.99 | [-8.65, -3.26] |
| Exclude Florida, sales 2000–2023 | -5.22 | [-12.07, 2.17] |
| Restrict vintages to 1990–1997, sales 2000–2023 | -0.57 | [-3.71, 2.66] |

The main later-sales model uses 10,770,104 transactions after singleton removal;
the size specifications use the same 10,616,132 observations. Controls are log
floor area, log lot area, and their squares, with the same area screens as the
first price analysis. State-clustered inference for the main pooled contrast
gives an interval of [-9.26%, -2.89%]. The all-sales and Florida-exclusion
intervals are wider and include zero; the point estimates are not invariant to
calendar coverage, geography, or cohort window. The narrower-cohort contrast is
particularly important when interpreting a discrete 1994 reform effect.

| Specification | II minus I (%) | 95% interval (%) | III minus I (%) | 95% interval (%) |
|---|---:|---:|---:|---:|
| Sales 2000–2023 | -6.75 | [-10.44, -2.91] | -1.71 | [-8.78, 5.91] |
| Common size-data sample with area controls | -7.12 | [-9.84, -4.32] | 2.30 | [-2.61, 7.46] |

The pooled contrast is not an arithmetic average of the two separate contrasts;
it comes from a common-extra-response restriction. Nor is -6.13% the MH
post-vintage price contrast within the treated zones: it is that contrast relative
to the corresponding zone-I MH/site-built vintage pattern.

The later-sales input has 276,834 MH sales in zone I, 91,090 in zone II, and
18,504 in zone III. MH pre/post counts in III are 15,199/3,305; only 19/18
counties contribute to those respective groups. All three zone-III states are
represented. Site-built sales in III cover 22 counties. The sparse MH support
there is a substantive limitation beyond the number of transactions.

The documented-price-code sensitivity reverses the pooled contrast to +24.1%
(interval +6.9% to +44.0%), but retains only 137 treated MH transactions, all in
zone II (76 pre and 61 post), across three states. It contains no zone-III MH
transactions, so III-minus-I is explicitly flagged as unidentified. This
drastic coverage change prevents treating the strict sample as a comparable
national robustness check, while also underscoring the provisional treatment
of blank price codes in the main sample.

![Annual pooled DDD profile](../output/corelogic/windzone-v5-20261008/vintage_ddd.png)

The profile shows a large differential pattern before the reform: 1984 and
1985 cohorts are +11.7% and +13.3% relative to the joint 1992–1993 reference,
declining to +2.1% in 1990 and +0.2% in 1991. All 1995–1999 pooled annual
contrasts are near zero, with intervals including zero (1995 is -1.9%, 1996
and 1997 about +1.0%). Thus the negative broad-cohort static contrast mainly
compares the high earlier-cohort differential with later cohorts; it is not
evidence of a clear negative jump at the policy boundary. Area/lot adjustment
does not remove the early-cohort pattern in zone II.

[Annual DDD profile](../output/corelogic/windzone-v5-20261008/vintage_ddd.pdf),
[common-sample size comparison](../output/corelogic/windzone-v5-20261008/vintage_ddd_size.pdf),
and [separate-zone profiles](../output/corelogic/windzone-v5-20261008/vintage_ddd_byzone.pdf).
Aggregate coefficient and support tables are in the same local output directory;
fitted models and all licensed data remain in the corresponding private Rivanna
results directory.

## Estimand and specification

The contrast is the post-versus-pre MH price change relative to site-built
homes in zones II/III, minus that same relative vintage contrast in zone I.
The outcome is log land-inclusive sale price. The static pooled model is:

    log(price) = b_I * MH * post
               + b_DDD * MH * post * 1(zone >= II)
               + county x sale-year FE + county x home-type FE
               + wind-zone x construction-vintage FE + error.

Post means vintages 1995–1999; pre means 1984–1993. Zone-specific annual vintage
effects allow site-built vintage prices to differ freely across all three zones.
County × home-type effects absorb the MH × zone lower-order interaction and
county-specific MH/site-built price levels. County × sale-year effects absorb
zone levels and sale-time effects. The MH × post lower-order interaction is
explicitly retained. Thus the DDD coefficient is additional to zone I's relative
MH vintage contrast. The pooled model constrains the extra MH post response to
be common across zones II and III, while allowing separate zone × vintage effects.

A second parameterization replaces the pooled interaction with separate
MH × post × zone-II and MH × post × zone-III terms. Their coefficients are
II-minus-I and III-minus-I triple differences. Zone-specific MH contrasts are
linear combinations with the zone-I coefficient, with covariance accounted for.
Annual profiles replace post interactions with annual MH × vintage and
MH × vintage × zone interactions; 1992 and 1993 are jointly omitted.

Percentage contrasts transform the log coefficient with `100 * (exp(b) - 1)`.
They describe a ratio of relative price ratios, not a dollar compliance cost.
County-clustered 95% intervals are primary; state-clustered intervals are a
sensitivity check. Continental zone III has only 25 counties in Florida,
Louisiana, and North Carolina. State clustering alone does not solve inference
with only three states supporting that contrast.

## County mapping

The lookup is reconstructed from the county lists in the
[official 2020 edition of 24 CFR 3280.305(c)(2), pp. 57–58](https://www.govinfo.gov/content/pkg/CFR-2020-title24-vol5/pdf/CFR-2020-title24-vol5-subtitleB.pdf)
on the research-database `geo_county` v2026-09-02 universe, including historical
FIPS codes. The named lists match the current research-database eCFR contract;
this is an explicitly reconstructed reference, not a claimed download of curated
`ecfr_wind_zone` v2026-09-03.

Florida's unnamed counties are zone II; the 14 named Florida zone-III counties
remain III. Other recognized continental counties are residual zone I only
after every named zone-II/III county is matched uniquely. Dade and Miami-Dade
codes (12025 and 12086) are both assigned zone III; the pinned county dimension
contains the historical code as well as its successor. The
[Census county-change reference](https://www.census.gov/programs-surveys/geography/technical-documentation/county-changes.1990.html)
confirms that relationship. Historical Princess Anne is excluded because it merged into
Virginia Beach before these construction cohorts. Alaska, Hawaii, and territories
are outside this workstream. Assertions require 144 continental zone-II counties,
25 zone-III counties plus the historical Dade alias (26 FIPS codes), and all 67
Florida counties plus that alias. This corrects the residual assignment the
historical Dade row would otherwise receive. Unknown source FIPS codes
remain unmatched and are reported, rather than assigned zone I.

The job saves a full reconstructed lookup, a comparison with the legacy lookup,
an old/new sales-join cross-tab, unmatched county counts, and support by zone,
type, vintage, and pre/post group. Reference and source code hashes accompany
the results manifest.

Reconciliation also finds eight differing assignments in the old public bundle:
Duval FL belongs in II and Madison FL in II; Knox ME, Hinds MS, Polk NC, Karnes
TX, Marion TX, and Milam TX belong in I. The reconstructed classification
corrects these using the explicit published lists. The old bundle also omits
historical Dade and other recognized FIPS codes. Across the full preferred
sample, 128,210 site-built and 14 MH sales lacked an old zone match; all receive
a verified zone in the reconstructed reference. The earlier pooled price
analysis did not use wind zones, so these corrections do not change its estimates.

## Interpretation and next checks

A triple difference removes MH vintage changes common across wind zones. It
still requires the relative MH/site-built vintage pattern to have evolved
similarly across zones absent the reform. The annual profiles are therefore
essential: inspect earlier differential patterns rather than interpreting a
single post coefficient automatically as causal.

Use the [amenity and spatial robustness plan](../PLAN_CORELOGIC_ROBUSTNESS.md)
within this DDD design. In particular, compare prices on the same size-data
sample before and after area/lot controls, and test whether amenities or local
physical risk themselves exhibit a triple-difference vintage pattern. The
2023 assessor snapshot can reflect later renovation, repair, and survival.
Within-county risk sorting remains possible after county effects. Current siting
zone is not a verified original design-zone label, especially for relocated MH.

Further checks include MH × sale-year × zone effects, matched nearby markets,
parcel rather than transaction weights, and inference designed for limited
treated-state support. Those are extensions, not part of these initial estimates.

Implementation: `program/estimate/estimate-corelogic-windzone.R`, submitted with
`program/estimate/corelogic-windzone.slurm` and `CORELOGIC_BUILD`,
`CORELOGIC_RESULTS`, and `CORELOGIC_REFERENCE`. `make test-corelogic` includes
synthetic tests that recover known binary, separate-zone, and annual DDD effects
in the presence of both MH-vintage and zone-vintage changes.

The estimator includes its figures in a plotting section, as in
`estimate-nfip-claims.R`. It shares verified-input setup and coefficient exports
with the baseline price estimator through `program/lib/corelogic-setup.R`.
The wind-zone formula and crosswalk helpers remain in `program/lib/` for
independent checks. Each run archives the estimator and these shared sources.

Cleanup validation (2026-10-09): Rivanna job 21119449 reran all static and annual
specifications, writing privately to
`/scratch/chv7bg/manufactured-code/corelogic-results/windzone-refactor-v1-20261009`.
Comparison job 21119463 matched all eleven aggregate CSVs to the 1994-retaining
run within numerical tolerance (`1e-8`), including support and unidentified
contrasts; all three PNG figures were byte-identical. The synthetic DDD
checks also passed.
