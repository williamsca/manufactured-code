# CoreLogic vintage prices: amenities and within-county location

October 8, 2026. This extends [the CoreLogic plan](PLAN_CORELOGIC.md).
All licensed records, geocodes, spatial joins, and regressions stay on Rivanna.
Only aggregate diagnostics, coefficient tables, and figures return locally.

The [initial estimates](notes/corelogic-prices.md) show substantial specification
sensitivity: the county-type 2000–2023 contrast is +2.1%, but on the common
size-data sample it moves from +1.3% without controls to -1.3% with building/lot
area controls. Snapshot building and lot area have positive differential MH
post-vintage contrasts. The priority is therefore to establish measurement timing,
MH format, and geographic sorting before interpreting a policy premium.

## Question and estimand

Do post-reform manufactured homes sell at a higher price relative to site-built
homes of the same construction vintage, and how much of that pattern reflects
different housing amenities or locations within the same county?

The first outcome is log land-inclusive sale price. MH classification uses
CoreLogic's derived `mobile_home_indicator == "Y"`; original construction year
defines vintage. Preferred cohorts are all years 1984–1999, including the
partially treated 1994 cohort, with 1992 and 1993 jointly omitted in the annual
profile. The dynamic model estimates 1994 freely. A static post coefficient
compares 1995–1999 with 1984–1993 while retaining a separate MH × 1994 coefficient
(and zone interactions in the triple difference). It is a descriptive resale capitalization contrast; it does not
by itself identify the manufacturing cost of compliance or the value of reduced
hurricane damage. A smooth relative vintage gradient also produces a positive
post coefficient.

Initial specifications absorb county × sale-year and construction-year effects,
then add county × home-type effects. Sales from 2000 onward give every cohort a
common opportunity to appear. The documented-price sample, narrower 1990–1997
cohorts, and Florida exclusion are reported separately; all retain 1994 as its
own transition cohort.
The initial geographic scope is the continental US and DC. Wind-zone contrasts
require reconciling the legacy reference with the research-database contract;
unmatched counties must not silently become zone I.
The [initial wind-zone triple differences](notes/corelogic-windzone.md) now use
an audited reconstructed reference. Their broad-cohort contrast is negative,
but becomes approximately zero with 1990–1997 cohorts; amenity and risk balance
should therefore be tested as triple-difference profiles as well as pooled ones.

For a characteristic or hazard measure X, run the same annual-vintage equation:

    X = MH × vintage coefficients + county × sale-year FE
        + county × home-type FE + vintage FE + error.

Plot coefficients relative to the joint 1992–1993 reference, and estimate the
post interaction using the same fixed effects. For binary characteristics,
report percentage points; for continuous ones, report natural units and
standardized effects. These are composition diagnostics, not causal effects of
the reform on amenities. Also show MH-only within-county vintage profiles so a
site-built change cannot conceal MH sorting.

## 1. Coverage and composition before adding controls

Build a private one-row-per-CLIP characteristic table and attach it to the sales
sample. Audit uniqueness, coordinate precision, county containment, source dates,
and coverage by home type, vintage, state, sale year, and snapshot agreement.
Produce counts of county × vintage × type and of each county's pre/post MH
support. Check recording-date fallback and price-code coverage by vintage.

Use both the transaction-weighted sales sample and a parcel-weighted version
(inverse number of qualifying sales per CLIP). Present a one-sale-per-parcel
check with a prespecified selection rule, such as earliest qualifying sale in
2000–2023. Snapshot inventory balance is a separate check on properties present
in 2023; it does not recover demolished homes or historical stocks.

Every sequential adjustment must have a no-controls regression on exactly the
same observations. Separate coefficient movement due to sample loss from movement
due to conditioning. Report missingness itself as an outcome. For category
fields, retain unknown separately unless the dictionary explicitly establishes
that blank means absence. Avoid broad multiple imputation as a first pass.

## 2. Amenities: project actual fields before rebuilding the sample

The existing private sales artifact already contains snapshot universal building
square footage, lot square footage, land/improvement values, original/effective
snapshot years, and parcel/block coordinates. Initial size regressions use valid
building area 200–10,000 sq ft and lot area 100–4,356,000 sq ft; vary these bounds
and report exclusions. Square footage is a source-selected universal area, not
necessarily living area.

Extend the Property Basic projection from the pinned 20230817 delivery with the
following fields, using the [published dictionary](../../research-database/catalog/dictionaries/corelogic_fields.csv)
and [code lists](../../research-database/catalog/dictionaries/corelogic_values.csv):

| Dimension | Fields and first diagnostic |
|---|---|
| Size and layout | `universal_building_square_feet_source_indicator_code`, `living_square_feet_all_buildings`, `bedrooms_all_buildings`, `number_of_bathrooms`, `total_bathrooms_all_buildings`; separate area definitions and primary-building versus all-building counts |
| MH format | `building_code`, `building_improvement_code`; RM1 single wide and RM2 double wide; unknown remains separate; codes describe format and never replace the derived MH classification |
| Ordinary amenities | `air_conditioning_code`, `heating_type_code`, `garage_code`, `number_of_parking_spaces`, `pool_indicator`, `fireplace_indicator`; inspect actual code support and missingness before collapsing categories |
| Construction and updates | `building_quality_code`, `building_improvement_condition_code`, `construction_type_code`, `foundation_type_code`, `roof_cover_code`, `roof_type_code`, `effective_year_built`; keep these in a separate block because they may reflect compliance, durability, repairs, or renovation |
| Assessor timing | `last_assessor_update_date`, `taxroll_certification_date`, assessment year and value-source indicator; establish the timing of each snapshot observation |

Start with annual-vintage balance plots for log floor area, log lot area,
double-wide share, bedrooms/baths, and central-air/garage/pool indicators.
Show distributions as well as means for area and lot size. Check whether the
1994–1995 transition is a discrete change or part of a longer trend.

Then estimate prices sequentially: no controls on the matched sample; size and
layout (flexible log area/lot terms or bins); MH format and ordinary amenities;
and a separately labeled construction/quality block. Permit size slopes to vary
by home type and verify within-single-wide/within-double-wide results where
support allows. Reweight pre/post MH to overlapping amenity distributions within
county or narrow regional markets as a complementary diagnostic. Trim only
unsupported covariate regions by a stated rule and publish retained shares.

The 2023 snapshot is later than most sales. These controls can therefore be
post-sale, post-storm, or survivor-selected. Compare recent 2018–2023 sales,
unchanged recorded type/vintage, and no effective-year revision; none proves the
amenities were present at sale. Treat historical controls as credible only after
confirming timing with the provider or importing genuinely dated observations.
Owner Transfer fields labeled static and agreement with the snapshot do not
establish historical measurement. Confirm the derived MH indicator's timing too.

## 3. Within-county risk and neighborhood location

Use parcel coordinates first, with block coordinates in a separately flagged
sensitivity sample. Check sign convention, bounding boxes, point-in-county
consistency, repeated coordinates, and precision. Keep invalid or missing points
as missing; geocode quality may itself vary by vintage. County mismatches require
boundary-vintage reconciliation rather than an arbitrary nearest-county change.

Join locations once per CLIP on compute nodes, in state/tile batches with spatial
indexes. Store layer version, date, CRS, resolution, coverage, match method, and
distance from ambiguous boundaries. Public layers can be cached directly on
Rivanna without a public research-database cache or AWS credentials.

Prioritize these measures:

1. **Physical geography:** distance to shoreline and inland water, elevation,
   and slope. Use a pinned coastline/hydrography source and
   [USGS 3DEP terrain data](https://www.usgs.gov/3d-elevation-program/about-3dep-products-services).
   Coastal proximity is both a potential amenity and a hazard correlate: show
   its direction without assuming that nearer means uniformly worse.
2. **Storm surge:** membership/depth in fixed hurricane-category scenarios from
   [NHC national SLOSH surge maps](https://www.nhc.noaa.gov/nationalsurge/).
   These are scenario inundation measures, not annual probabilities or observed
   storm losses. Preserve modeled dry, outside-domain, and missing distinctions.
3. **Floodplain:** special flood hazard area, coastal V versus A zones, and
   0.2% floodplain membership from the
   [FEMA National Flood Hazard Layer](https://coast.noaa.gov/digitalcoast/data/flood.html).
   NFHL contains current effective mapping for covered areas; unmapped is not
   safe. Current maps diagnose present physical sorting and are not necessarily
   maps available to buyers in earlier sale years. Add historically effective
   maps where feasible before claiming contemporaneous perceived risk.
4. **Wind exposure:** independently modeled local hurricane wind exposure or a
   prespecified pre-reform historical wind climatology. A tract hazard-frequency
   field from the [FEMA NRI documentation](https://www.fema.gov/sites/default/files/documents/fema_national-risk-index_technical-documentation.pdf)
   is a coarse preliminary check, after verifying its geography and aggregation.
   Do not use the composite Risk Index or expected dollar loss as a pure physical
   hazard control: exposure, asset values, loss ratios, and social vulnerability
   enter those measures. County-only risk has no within-county identifying power.

Map tract or 1–5 km grid IDs for finer-market comparisons. Start with tract ×
sale-year plus county × type effects, then tract × type where there is support;
alternatively use grid × sale-period effects or close-neighbor matching within
county and a distance caliper. Compare no-controls and fine-geography estimates
on the retained overlap sample. Report MH/site-built and pre/post support,
discarded observations, and residual hazard differences at each resolution.
Do not use ZIP codes as a substitute for verified physical proximity.

Plot within-county MH vintage profiles for each hazard measure, estimate
post interactions relative to site-built profiles, and test the amenity and
hazard blocks jointly. Predefine a small primary set (floor area, double-wide
share, coastal distance, elevation, surge exposure, and mapped floodplain).
Use family-wise or false-discovery adjustment for the larger diagnostic set.
Emphasize magnitudes and uncertainty rather than a sequence of isolated p-values.

## 4. Price identification checks after the balance work

Re-estimate the vintage profile with amenities, fine geography, and both jointly,
always reporting common-sample counterparts. Compare zone I with zones II/III
only after the county crosswalk is audited, including all lower-order zone ×
vintage and zone × MH terms. Zone I is an unchanged-standard comparison, not a
zero-hurricane-risk population.

Inspect 1984–1993 relative gradients and use narrow symmetric cohorts around
1994, retaining the transition cohort with its own coefficient. Fit prespecified MH-specific smooth vintage
trends and placebo cutoffs in earlier cohorts. A trend extrapolation is sensitive
to functional form; show linear and modest alternatives and do not select the
one giving the largest post effect. Separately address Florida's later tie-down
changes with exclusion and cohort restrictions. Compare transaction and parcel
weights, documented-price codes, date definitions, stable recorded structures,
and price-tail screens chosen from audited distributions.

Sale year, construction year, and building age are mechanically linked.
Unrestricted age, year, and vintage effects cannot all identify a reform effect.
Parcel fixed effects absorb permanent vintage/type; repeat sales can address
storm-related changes but do not independently identify the level vintage premium.

For the later hurricane workstream, freeze treatment, amenities, and location
at the pre-storm sale wherever genuinely dated measurements exist. Match or
condition on realized local wind/surge exposure within storm × county, then
compare vintage × type damage responses. Do not control for post-storm repairs
or post-storm assessed improvements. Repeat-sale price changes may reflect
neighborhood effects and selection into resale as well as structural damage.

## Deliverables and order

1. Initial vintage figure, post-interaction table, sample support, and available
   snapshot size balance; document measurement timing and geographic scope.
2. Private amenities extension and coverage audit; annual balance figures;
   same-sample price comparisons and MH-format checks.
3. Coordinate audit and fine-geography price comparison, followed by physical
   hazard joins and risk balance. Begin with exposed coastal counties for the
   expensive spatial joins, then expand coverage using the same definitions.
4. Combined robustness table and revised interpretation: explain which component
   is supported by overlap, which is attenuated by conditioning, and which remains
   unresolved. Keep total capitalization and amenity/structure-conditioned
   contrasts distinct; attenuation is not an identified causal decomposition.

Each stage saves a private manifest and aggregate coverage/diagnostics. The
hazard joins and richer amenity controls above are planned work, not completed
results from the initial vintage estimation.
