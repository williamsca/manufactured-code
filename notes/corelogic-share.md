# CoreLogic MH share by construction vintage

The October 9, 2026 specification uses construction vintages 1989–1999,
1993 as the annual reference, and 1994–1999 as the static post period.
`program/estimate/estimate-corelogic-share.R` reads the verified build's
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

Rivanna job 21140980 completed successfully. It analyzed 11,336,139 homes.
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
comparison profiles relative to 1993. PNG copies and aggregate CSVs accompany
them. No record-level licensed files are downloaded. The private run archives
source code and model objects and records input paths and source hashes.

`make test-corelogic` includes known-truth tests of all six share equations.
Submit `program/estimate/corelogic-share.slurm` with `CORELOGIC_BUILD`,
`CORELOGIC_REFERENCE`, and a new `CORELOGIC_RESULTS` directory.
