# NFIP Take-Up Denominators

## Motivation

The current NFIP take-up appendix estimates effects on policy counts by housing type and construction vintage. This is not yet a take-up rate because the denominator is missing: the total number of homes of each vintage, type, and location at a given moment. This matters directly for the post-1994 comparison, since the ratio of manufactured-home shipments to site-built construction changed after the HUD code reform. Raw NFIP policy counts can therefore rise either because more manufactured homes were insured or because there were more manufactured homes in the relevant vintage cells.

The goal is to construct an approximate housing-stock denominator for the 2009--2023 NFIP policy panel, ideally by location, construction vintage, and housing type.

## Proposed Strategy

Use decennial or near-decennial stock measures as anchors and assign annual NFIP policy years to nearby stock anchors. For policy years before 2010, use the 2010 stock by vintage, location, and type. For policy years around or after 2020, use the 2020 stock. For intermediate years, either use the nearest anchor or interpolate between 2010 and 2020.

This is defensible as an approximation because housing is durable, so the number of homes in a given vintage bin changes slowly relative to annual insurance decisions. The strategy is a meaningful improvement over raw policy counts. However, it should be framed as an approximate denominator strategy, not as a clean annual housing-stock panel.

The main concern is that manufactured homes are less durable and more movable than site-built homes. County-level manufactured-home vintage stocks can change through demolition, relocation, park closure, replacement, or reclassification. These forces are unlikely to make the exercise useless, but they do mean the take-up results should probably remain in the appendix unless the denominator is built out more carefully.

## Census Data Availability

The 2000 decennial SF3 file has the best historical cross-tab for this purpose. The existing script `program/import/import-census.R` uses table `HCT006`, "Tenure by Year Structure Built by Units in Structure." This table gives occupied housing units by tenure, vintage, and structure type, including mobile homes. The current import uses it to construct county-by-vintage manufactured-home counts for:

- `1980_1989`
- `1990_1994`
- `1995_1998`
- `1999_2000`

For 2010 and 2020, the same SF3-style decennial long-form table is not available for the mainland U.S. in the same way. The best API source is the ACS 5-year detailed table:

```r
listCensusMetadata(
  name = "acs/acs5",
  vintage = 2010,
  type = "variables",
  group = "B25127"
)

listCensusMetadata(
  name = "acs/acs5",
  vintage = 2020,
  type = "variables",
  group = "B25127"
)
```

ACS table `B25127` is "Tenure by Year Structure Built by Units in Structure." It is available in the 2010 ACS 5-year detailed tables and the 2020 ACS 5-year detailed tables.

This table is useful, but it has three important limitations relative to 2000 SF3 `HCT006`:

1. The universe is occupied housing units. This is consistent with the current 2000 `HCT006` workflow, but it is not the full physical stock including vacant units.

2. The relevant structure category is "Mobile home, boat, RV, van, etc." rather than mobile homes alone. This is broader than the manufactured-home definition used in the NFIP data. The mismatch may be small in many places, but it could matter in coastal and flood-prone counties.

3. The construction-vintage bins are coarse. For 2010 ACS, the useful bins include groups such as `Built 2000 or later`, `Built 1980 to 1999`, `Built 1960 to 1979`, and older bins. For 2020 ACS, the table includes bins such as `Built 2020 or later`, `Built 2000 to 2019`, and `Built 1980 to 1999`. These bins do not directly split the treatment-relevant 1990s vintages into pre- and post-1994 groups.

The 2010 `dec/sf1` and 2020 `dec/dhc` or `dec/sdhc` products do not appear to solve the denominator problem for the U.S. county or tract panel. They contain basic housing and tenure counts, but not the full stock-by-vintage-by-structure-type cross-tab needed for the preferred take-up denominator. Some 2020 Island Areas datasets contain year-built and units-in-structure tables, but those are not relevant for the mainland U.S. NFIP analysis.

## Recommended Empirical Options

### Option 1: ACS-Bin Take-Up Rates

Aggregate NFIP policy counts into the ACS `B25127` vintage bins and estimate policy rates per occupied housing unit by location, housing type, and broad construction-vintage bin.

This is the cleanest use of the observed denominator. The cost is that it gives up the sharp 1994 treatment split, because `B25127` is too coarse around the reform.

### Option 2: Raked Treatment-Bin Denominator

Use 2000 SF3 `HCT006` to estimate the within-county distribution of 1990s manufactured-home stock across `1990_1994`, `1995_1998`, and `1999_2000`. Then use those shares to split broader 2010 and 2020 ACS `B25127` stock totals.

This preserves the treatment-relevant split but requires a stronger assumption: the within-county vintage distribution from 2000 remains informative for later observed stocks. This assumption is plausible for durable site-built housing, but more fragile for manufactured homes.

### Option 3: Stock-Flow Denominator

Construct a stock-flow panel. Start from the 2000 SF3 vintage stock, add later manufactured-home placements from the Manufactured Housing Survey, add site-built construction from building permits, and calibrate county totals to 2010 and 2020 ACS `B25127`.

This is more work but probably the most defensible if the take-up result becomes central. It also aligns naturally with the rest of the paper, which already uses MHS placements and building permits.

## Recommended Path

Start with Option 1 or Option 2 as an appendix robustness exercise. The immediate next step is to write an import script that pulls ACS `B25127` for 2010 and 2020, creates a county-by-vintage-by-type denominator file, and prints the exact variable mapping for review.

Suggested output:

- `derived/census2010-acs-stock-county-vintage-type.Rds`
- `derived/census2020-acs-stock-county-vintage-type.Rds`

The import should retain both estimates and margins of error if feasible. Even if the first estimation pass ignores MOEs, keeping them in the derived file will make it easier to assess which county-vintage-type cells are too noisy.

The final appendix should be explicit that the denominator is based on occupied stock, that ACS combines mobile homes with boats/RVs/vans, and that the 1994 treatment split requires either aggregation to coarser ACS bins or an allocation assumption.
