# CoreLogic extension: vintage price effects and hurricane resilience

Draft for review — October 7, 2026. This is a research and implementation plan; no CoreLogic extraction or estimation has been run for this draft.

Implementation instructions accepted October 8: use CoreLogic's derived `mobile_home_indicator == "Y"` to identify parcels containing MH. Land-use codes remain diagnostic and sample-screening fields, not an alternative MH definition. All source scans, research panels and analysis for this workstream run on Rivanna; only aggregate results and diagnostics return locally. Current implementation and build outcomes are recorded in `notes/corelogic-databuild.md`.

## 1. What this would add to the paper

CoreLogic could extend the paper in two useful directions:

1. **Market valuation of the 1994 reform.** Apply the NFIP construction-vintage design to transaction prices: compare the price difference between older and newer manufactured homes (MH) with the corresponding difference for site-built homes sold in the same local market and period. Add the HUD wind-zone comparison to distinguish a general MH vintage premium from the premium associated with the binding wind standard.
2. **Differential hurricane losses in property value.** Use repeat sales to compare a property's price before and after a hurricane, then ask whether the storm-induced change differs between pre- and post-1994 MH relative to the same vintage contrast for site-built homes. This directly addresses hurricanes, the hazard the regulation was designed for, and does not condition on NFIP participation or filing a flood claim.

The first analysis measures a resale/property-value premium, rather than the cost of manufacturing a new home measured by MHS. The second initially measures **differential hurricane effects on transaction values**. Interpreting those effects as physical damage requires additional assumptions: prices also reflect repairs, rebuilding, land value, changed risk beliefs, insurance availability, and local demand. Keep that distinction in the paper even if the hurricane results are compelling.

Recommended sequence: establish coverage and historical classification; estimate the vintage price profile; pilot repeat sales for a few storms; expand only if support and selection diagnostics justify it. The hurricane analysis is the larger potential contribution, but also has the harder feasibility and identification requirements.

## 2. Sources and access

The referenced database is at `/mnt/storage/research-database` in this workspace, rather than `../research-database`. I reviewed its [README](../../research-database/README.md), the [Property Basic contract](../../research-database/catalog/datasets/cl_property_basic.yml), the [Owner Transfer contract](../../research-database/catalog/datasets/cl_owner_transfer.yml), the [field dictionary](../../research-database/catalog/dictionaries/corelogic_fields.csv), the [code dictionary](../../research-database/catalog/dictionaries/corelogic_values.csv), and the October 7 handoff in the [CoreLogic modernization plan](../../research-database/program/corelogic/PLAN.md). Database links use this machine's actual checkout location.

| Source | Relevant content | Important limitation |
|---|---|---|
| `cl_property_basic` | One row per `clip`; current property type, construction year, characteristics, coordinates, assessed/market/appraised values and their land/improvement components | A **20230817 current-state snapshot**, not an annual assessor panel |
| `cl_owner_transfer` | Transfer history keyed by `owner_transfer_composite_transaction_id`; `clip` repeats; dates, prices, transaction flags, and historical property attributes | Historical depth/completeness remain to be profiled by county and year |
| `ecfr_wind_zone` | County HUD wind-zone assignments already used for MHS and NFIP | Siting zone proxies for the home's applicable manufacturing standard; relocation and misclassification remain possible |
| New storm exposure input | Storm identity, impact date, wind exposure and, where feasible, flood/surge exposure | Must be added and versioned; the CoreLogic dictionaries do not supply hurricane damage |

Both CoreLogic datasets are licensed, nonredistributable, and **hosted on Rivanna**, under `RD_CACHE_HOSTED=/scratch/chv7bg/research-database`; they are not mirrored to S3. The current contracts select the August 2023 delivery, registered under raw snapshot `2026-10-07`. Full builds/validation were still pending in the handoff reviewed for this plan. Verify completion rather than interpreting the existence of a contract as availability. Later deliveries through August 2026 are retained but not imported; the 2026 Property Basic NC archive is incomplete. The 2023 delivery provides no post-2023 sales and limited follow-up for recent storms.

Use the research-database client from a project checkout on Rivanna:

```r
# Configuration belongs in the job environment or .Rprofile.
# RD_HOME must identify the research-database checkout on that machine.
source(file.path(Sys.getenv("RD_HOME"), "client", "r", "load_all.R"))
rd_load_client()

rd_dict("cl_property_basic")
rd_dict("cl_owner_transfer")

# Set these to completed, validated FULL versions before reading data.
pb_path <- rd_path("cl_property_basic", version = CORELOGIC_PB_VERSION,
                   tier = "licensed")
ot_path <- rd_path("cl_owner_transfer", version = CORELOGIC_OT_VERSION,
                   tier = "licensed")
con <- rd_con()
# Run projected, filtered SQL scans and joins against these parquet paths.
```

Pin the two version strings, delivery date, dictionary provenance, storm source version, and existing `ECFR_WIND_ZONE_VERSION` in project parameters. Do not use automatic latest-version resolution: a partial-state test version can sort after a full version. Read only needed columns, filter in DuckDB, and materialize small project panels on the host. Keep record-level extracts out of git and public outputs; transfer only appropriate research outputs under the license. This draft does not require remote access, so no Rivanna jobs have been submitted.

Mortgage Basic and Building Permit are deferred upstream. The available permit dictionary describes Status History, whereas the delivered product is a different table. Do not make permits, repair costs, or mortgage-linked outcomes prerequisites for the first implementation.

## 3. Build the property/transaction sample carefully

### Fields and coding rules

The following names and code meanings come from the committed dictionaries, rather than the older filtered CoreLogic scripts.

| Task | Fields and initial rule |
|---|---|
| Link records | `clip`; retain `previous_clip`, county/APN identifiers and `composite_property_linkage_key` for documented linkage diagnostics |
| Identify MH historically | Owner Transfer `mobile_home_indicator == "Y"`, the CoreLogic-derived parcel flag requested for implementation; retain `land_use_code_static` (`137` mobile home, `138` manufactured home) as a diagnostic |
| Identify site-built comparison homes | `property_indicator_code_static == "10"` (single-family residence), excluding MH and conflicting/multi-unit uses; residential indicator as corroboration |
| Avoid park/land-only transactions | Exclude land-use `135` mobile-home lot, `136` mobile-home park, `454` vacant mobile home from the dwelling-price sample; preserve these records for conversion/selection diagnostics |
| Original vintage | Owner Transfer `actual_year_built_static`; Property Basic `year_built` as a separately flagged fallback, not an automatic substitute for historical classification |
| Renovation/replacement diagnostics | `effective_year_built_static`, Property Basic `effective_year_built`, type changes and building counts; these are not treatment vintages |
| Sale price and timing | Owner Transfer `sale_amount`, `sale_derived_date`, `sale_derived_recording_date`, and retained raw date strings |
| Market transaction screen | `primary_category_code == "A"` (arms length); corroborate `interfamily_related_indicator`, deed categories, full/partial consideration and ownership flags |
| Exclude bundled interests | `multi_or_split_parcel_code`, `partial_interest_indicator`, `ownership_transfer_percentage`; distinguish missing flags from confirmed eligibility |
| Separate transaction groups | `new_construction_indicator`, `resale_indicator`, foreclosure/REO and short-sale flags |
| Location and characteristics | Property Basic parcel-level coordinates, with block-level coordinates flagged as lower precision; size, lot area, rooms, `number_of_buildings`, `number_of_units`, and use codes |
| Assessor valuation checks | `market_*_value`, `assessed_*_value`, `appraised_*_value`, `*_value_calculated`, `calculated_value_source_code`, `assessed_year`, refresh/certification dates |

Identify MH using the derived mobile-home indicator, per the October 8 implementation instruction. Tabulate disagreements with land-use codes, but do not substitute land-use codes for an absent indicator. A mobile-home indicator means a MH is present on a property, which need not mean the sale price covers that home alone. Property Basic building codes can distinguish single/double wide (`RM1`/`RM2`) where populated; manufactured/modular construction labels alone are insufficient to identify HUD-regulated MH. Do not require PRIND `10` for all MH without checking how counties code them.

Transaction screening should use an explicit code whitelist. For example, `sale_type_code == "F"` means full sale price and `"P"` partial price; neither is an arms-length flag. Blank multi-parcel flags are not a published affirmative single-parcel code. Check their interpretation and missingness in the data before applying the final rule. Deed code definitions can be ambiguous, so use deed category and other flags jointly. Keep foreclosure/REO sales separately: automatically discarding them after a storm could remove an outcome of damage.

Preserve transfers without a current Property Basic match. Otherwise vanished structures/parcels and renumbered properties disappear before selection can be assessed. Use `clip` as the primary join; evaluate `previous_clip` mappings for one-to-one consistency, chronology, splits and merges before extending links. Do not combine parcels just because a predecessor ID or an address matches. Transaction keys, not `clip` plus sale date, define raw record uniqueness; distinguish duplicate documents from genuine same-day transfers.

### Timing, vintage, and representativeness

Start with the paper's continental-US, 1984–1999 construction window and county wind-zone crosswalk. **Keep construction year 1994 in the dynamic analysis as its own partially treated cohort**, per the October 8 implementation correction. Plot annual vintages normalized to 1992–1993. Static summaries compare 1995–1999 with 1984–1993 while retaining a separate MH × 1994 term and its zone interactions, rather than assigning the transition cohort full treatment or dropping it. Treat the 1999 endpoint as a sensitivity choice: also exclude Florida's 1999 cohort and use narrower windows, since the paper identifies additional Florida installation rules as a confound.

For storms, freeze type and original vintage from a **pre-storm transfer**. Compare them with post-storm records rather than letting a replacement's newer vintage recode an originally untreated home as treated. The transfer dictionary explicitly records original year built and several type fields at receipt of the transaction, making this preferable to assigning the 2023 property attributes to every historical sale. Assess how reliably those historical fields are populated. Never silently replace original vintage with effective vintage: effective year can reflect renovation, and some counties only supply that field.

Use derived sale date as the main transaction date when valid, with recording date as sensitivity and a flag for any fallback. Date definitions can precede the actual transfer, so exclude a buffer around storm impact and check date/recording lags. Partial dates stored in `*_raw` may support annual vintage-price analysis but cannot reliably place a sale immediately before or after a hurricane. Batch dates are internal identifiers, not sale dates. Deflate dollar summaries using the project's CPI-U/2000 convention; calendar fixed effects absorb common inflation in log-price regressions. Do not deflate sale prices using a local HPI and then estimate the local hurricane effect that the HPI might remove.

CoreLogic may disproportionately observe MH sold with land and miss park homes/chattel transactions. Audit this explicitly using land-use codes, land/improvement values and external MH-stock counts. Describe the target population as observed MH property transactions until coverage demonstrates more. A price for land plus structure is not comparable dollar-for-dollar to MHS's unit price.

## 4. Analysis A: the construction-vintage price profile

Let `v_i` be original construction year, `M_i` the MH indicator, and `p_it` a positive arms-length transaction price. First estimate the direct analogue of the NFIP vintage specification:

\[
\log p_{it}=\alpha_{c(i),t}+\delta M_i+\lambda_{v_i}
+\sum_{k\notin\{1992,1993\}}\beta_k M_i1\{v_i=k\}
+X_i'\gamma+\epsilon_{it}.
\]

Here `t` is sale year, with county × quarter fixed effects where transaction support permits. Begin with the county × year version; then add county × type intercepts and finer location controls to test sensitivity to geographic composition. County × period effects compare homes sold in the same market and time, rather than claims exposed to the same flood. They do not remove differences in neighborhoods within a county.

Report the static MH × post-1994 coefficient **retaining full original-vintage fixed effects**, rather than replacing the common vintage profile with just a pre/post dummy. Plot all cohorts and test pre-reform differential gradients and placebo cutoffs. Estimate Zone II/III and Zone I profiles separately, then a pooled MH × post-vintage × high-wind-zone contrast with all lower-order terms, including zone-specific vintage profiles and type intercepts. Split II and III if supported. Zone I is especially useful for removing general MH vintage changes, but can differ in depreciation, land markets and risk demand.

Use log prices as the primary scale because MH and site-built prices differ markedly in level, the same concern motivating proportional NFIP specifications. As a sensitivity, estimate conditional mean price using PPML on eligible positive-price sales; zero/non-sale records are not genuine zero-price observations. Use fitted counterfactual predictions for dollar valuation and uncertainty, rather than treating a log coefficient times an arbitrary mean as an expected dollar effect.

Show a minimally adjusted version first, followed by size/lot controls and comparable-neighborhood restrictions. Current quality/condition, current assessed improvement values and post-storm renovations can be outcomes of treatment or damage; exclude them from the main controls. Cross-sectional current-snapshot characteristics are less defensible for historical sales than verified transaction-time characteristics. Restrict a contemporary-sales robustness sample if necessary. Single/double-wide splits are secondary, conditional on credible classification.

Interpret a premium as capitalization of the whole cohort-specific housing bundle: durability, amenities, financing, land complementarity and expected risk. Similar premiums across wind zones or a smooth pre-1994 gradient would weaken attribution to the wind standard. The cohort profile also mixes age/depreciation with reform exposure; the site-built and Zone I comparisons, not construction year alone, supply identification. Repeat-sale property fixed effects cannot identify the time-invariant level premium by themselves.

Use new-construction flags, if historical coverage permits, to estimate a separate first-sale vintage profile. That sample is closer to the MHS cost question, but land-inclusive prices and changed amenities still prevent interpreting the entire premium as compliance cost. Do not replace the MHS headline with CoreLogic resale prices.

## 5. Analysis B: hurricane effects using repeat sales

### Storm definition and initial sample

Create a storm × county table with stable storm IDs, local impact dates, exposure measures, wind zones, overlap flags and usable observation windows. Choose inclusion rules using exposure and sample counts before inspecting treatment coefficients. Candidate pilots include 2004–2005 events and older isolated events with adequate historical sales. Treat storms close together, including Florida's 2004 sequence, as a special overlap problem; they may require season-level treatment rather than claiming a separate effect for each storm. Expand to later storms only when follow-up in the August 2023 delivery is sufficient. Recent events cannot share the same long-run horizon as older events.

Use NOAA/NHC best tracks and Tropical Cyclone Reports for dates and storm reconstruction. HURDAT2 contains six-hourly track/intensity records and wind radii beginning in 2004; those radii support exposure screening, but are not a measured parcel-level local wind field. Document interpolation, overland exposure assumptions and missingness. Prefer a validated local wind-footprint source for intensity effects if one is available. See the [NHC archive](https://www.nhc.noaa.gov/data/?O=D) and [HURDAT2 format documentation](https://www.nhc.noaa.gov/data/hurdat/hurdat2-format-nov2019.pdf).

A hurricane county declaration can corroborate exposure, but should not define wind severity. Distinguish hurricane impact from wind-only damage: estimate combined effects first, then wind-dominant/inland and flood/surge-exposed subsamples when suitable footprint data exist. Current flood-zone proxies alone cannot establish that a historical property was not flooded.

Start with sales in a three-year pre-storm and three-year post-storm window, excluding an initial ±90-day buffer; report ±30/180-day buffers and shorter/longer windows where feasible. Require a valid pre-storm sale and at least one subsequent eligible sale for the repeat-sale price sample. Treat these as provisional window choices for the pilot, then lock them before expansion. Track holding periods, exclude structures built after impact, and censor event windows at subsequent material storms or explicitly model them. This is an event-window sample, not a balanced annual price panel.

### Estimand and fixed effects

The target within an exposed storm-county is:

\[
\theta=\big[\Delta\log p_{MH,new}-\Delta\log p_{MH,old}\big]
-\big[\Delta\log p_{SB,new}-\Delta\log p_{SB,old}\big],
\]

where `new` refers to construction vintage after the reform, not the sale year, and `Δ` is the price change around the storm. A positive estimate means newer MH retain more value relative to older MH than the analogous site-built vintage comparison. Storm timing adds another difference to the paper's vintage/type design.

For an isolated storm, estimate at the transaction level with property fixed effects. In a pooled event stack, use **property × storm fixed effects**:

\[
\log p_{ist}=a_{is}+\alpha_{s,c(i),t}
+\eta_{s,c(i),v_i}H_{ist}+\rho_{s,c(i)}M_iH_{ist}
+\theta M_iP_iH_{ist}+\epsilon_{ist},
\]

where `H` indicates a sale after storm impact and `P=1{vintage>=1995}`. Keep 1994, with separate transition-cohort × post-storm and MH × transition-cohort × post-storm terms (or a full annual-vintage dynamic specification). `α` is storm × county × calendar-quarter (or year when sparse). The `η` terms allow the post-storm response to differ by original vintage **within storm-county**; `ρ` allows a different MH response within storm-county. The remaining interaction identifies the differential vintage response of MH. Time-invariant MH, vintage and their interaction are absorbed by `a_is`. Merely adding time-invariant vintage controls to a repeat-sale regression would accomplish nothing: the relevant controls are **vintage × post-storm** or vintage × event-time terms.

Start with a pooled `θ`, allowing storm-specific estimates where support permits. Do not include saturated storm-county × vintage × type × post fixed effects: those absorb the desired treatment contrast. Sparse cells may require coarser vintage bins or pooled lower-order responses; report the resulting identifying restriction and cell support rather than letting the estimator silently drop the design's comparison groups.

Extend to an event study by replacing `H` with relative-time bins and interacting each bin with vintage, MH, and MH × post-reform vintage, keeping the same spatial/event lower-order controls. Pre-storm coefficients test whether treated cohorts already had different appreciation paths. Suggested post bins are 3–12 months, 1–2 years and 2–3 years, with wider bins if needed. Distinguish this **calendar-time storm event study** from the **construction-vintage event study** in Analysis A. Also replace `M×P×H` with `M×1{v=k}×H` to show whether storm responses break at the reform rather than change smoothly with vintage; normalize to 1992–1993.

For a transparent paired-sales presentation, use the closest valid pre-storm and first valid post-storm sale per property/event and display the four group changes. Fit the corresponding differenced transaction model, evaluating calendar fixed effects at both endpoints, so unequal holding periods do not become unequal inferred damage. Do not divide returns by holding years as the main outcome: the hurricane is a discrete event. Compare first post-sale estimates with all eligible sales and explain which horizon each measures. Cap/reweight repeated participation so frequently sold homes and multiply stacked sales do not dominate inadvertently.

### Separate storm effects from ordinary depreciation

Within exposed storm-counties, identification requires that absent the hurricane, the MH vintage appreciation gap would have evolved like the site-built gap, conditional on the fixed effects. Property fixed effects remove fixed quality; they do not remove type-specific depreciation or contemporaneous vintage-specific demand shifts.

Add two complementary checks:

- **Unaffected/low-exposure comparison markets:** build comparable event windows in counties outside the material footprint and estimate the exposed-minus-control difference in `θ`, including all lower-order interactions. This is a fourth difference: storm time × housing type × reform vintage × exposure. Choose controls with similar pre-event type/vintage appreciation profiles and avoid places with large displacement/reconstruction spillovers.
- **Wind-zone contrast:** compare hurricane-exposed Zone II/III and Zone I estimates, allowing zone-specific lower-order responses. The additional MH × reform-vintage × post-storm × zone effect is a stronger test of the regulatory mechanism, but requires common hazard support. Do not interpret a contrast driven entirely by severe coastal storms in one zone and weak inland exposure in another as code stringency.

Use exposure intensity interactions only after checking overlap across all four housing groups and zones. Finer spatial matching/tract controls and location-specific hazard measures should address different siting within a storm-county; county fixed effects alone do not equate actual wind, surge or flood exposure.

### Repairs, resale selection, and destruction

The repeat-sale sample omits homes that never resell, including potentially destroyed MH. A post-storm sale may be a repaired or completely replaced structure. This could make apparent resilience a consequence of selective survival or reinvestment.

Construct a separate **pre-storm observed-property frame**, based on historical transfers, without requiring a post sale or a current Property Basic match. It is still not the complete historical housing stock. Report by housing type × vintage × storm exposure:

- Probability/time to any subsequent transfer and to an eligible market sale; transaction volumes, prices, holding periods and distressed transfers.
- Post-transfer changes to original/effective year built, housing type, vacant use and building counts; current-snapshot match rates, predecessor links and observed parcel splits/merges.
- Selection into exact-date, clean-classification and stable-structure samples, including every exclusion's contribution to the four comparison groups.

Freeze pre-storm treatment for the overall observed-property outcomes. Flag changed structures as a rebuilding/conversion outcome. A stable-structure repeat-sale specification is useful as a secondary estimand among observed continuing structures; excluding replacement cases after impact is itself selection and must not become the sole result. These datasets alone cannot reliably label a never-resold or unmatched home as destroyed. Historical assessor rolls or independent damage/imagery would be needed to establish that.

Weighting on pre-storm characteristics may address observed differences in resale selection, but cannot recover prices for destroyed or never-sold homes under arbitrary selection. Present sensitivity/bounds only with their assumptions stated. Do not claim unconditional damage avoided if this problem remains unresolved.

Report short- and medium-run effects separately. A disappearing discount is consistent with repair or recovery and does not imply there was no initial loss; a persistent discount may reflect changed risk perceptions. Independent physical-damage or repair evidence would strengthen a damage interpretation, but is an extension rather than a required data product assumed to exist.

### Inference

Cluster the vintage-price analysis by county, with state-cluster sensitivity consistent with wind-zone/regulatory concerns. For pooled hurricane estimates, allow dependence across counties within a storm and over repeated storms within a county; use county/storm multiway clustering when cluster counts support it. Report leave-one-storm-out results and storm/state contributions. A large number of transactions cannot substitute for independent storms. With a small pilot, show event-specific intervals and use small-cluster methods only when their assumptions are credible; do not rely on conventional storm-cluster asymptotics with a handful of events.

## 6. Complementary uses and welfare interpretation

Property Basic's land/improvement components can help characterize how much of MH property value is land and whether price results differ in structure-intensive properties. Use these as descriptive/secondary outcomes with assessment-source and county controls. Its single 2023 snapshot cannot identify assessor value drops around earlier hurricanes. Later 2024–2026 snapshots could eventually support a recent annual assessment panel, after upstream import and checks for timing, reassessment, replacement and stable IDs; they do not create historical rolls for older storms.

CoreLogic also offers an independent composition check on MH vintage, location, size and observed property stock. Compare those patterns with NFIP's insured sample, but do not substitute surviving 2023 stock for historical storm exposure or annual insurance take-up denominators. No exact NFIP parcel linkage is assumed; use aligned geography/vintage comparisons first.

Keep the existing insured-flood welfare calculation intact until a hurricane-dollar interpretation is defensible. The price premium may already capitalize expected future resilience benefits. A hurricane price response may include flood losses also measured by NFIP, or repair expenditure not remaining in the sale price. Adding the premium or hurricane price effect to the existing flood benefit would risk double counting. If later evidence supports a physical loss interpretation, convert predicted proportional effects using pre-event counterfactual values and an explicit hazard-frequency model, with uncertainty; state which losses and population are covered. Otherwise report the hurricane results as market-value resilience alongside the NFIP estimates, without forcing them into the benefit-cost ratio.

## 7. Implementation stages and review deliverables

| Stage | Project work | Deliverable / decision |
|---|---|---|
| 0. Confirm source readiness | Verify full host builds and validation, pin versions, inspect relevant codes/dates and unmatched records | Availability manifest; no extraction based on partial builds |
| 1. Feasibility audit | Projected SQL extracts for candidate counties; profile sales over time, MH definitions, original vintages, historical/current agreement and transaction screens | County-year and storm-county four-group support tables; historical classification/missingness report |
| 2. Vintage prices | National price profile, local-market specifications, wind-zone contrast and narrow-window/placebo checks | Main vintage figure, zone figure and specification table; decide whether reform attribution is credible |
| 3. Hurricane pilot | A few events with usable overlap-free windows; repeat-sale and pre-storm frame construction | Event-specific price/selection plots, counts, detectable-effect calculations, and explicit feasibility decision |
| 4. Pooled hurricanes | Lock event/window rules, add event-time/vintage profiles, exposure/zone comparisons and selection sensitivities | Pooled effect and heterogeneity tables; assessment of damage versus market-value interpretation |
| 5. Paper integration | Add source/sample descriptions and results; consider welfare only after resolving interpretation | Reviewable paper additions and reproducible outputs |

Proposed project files, following the current import/estimate/output organization:

- `program/import/databuild-corelogic.R`: property/transfer screens, historical classification, geography/zone joins, audit tables, filtered transaction panel.
- `program/import/databuild-corelogic-storms.R`: versioned storm joins, pre-event frame, eligible windows and repeat-sale/event stacks.
- `program/lib/corelogic-sample.R`: shared coding rules and exclusion reasons; avoid separate definitions in the two analyses.
- `program/estimate/estimate-corelogic-prices.R` and `estimate-corelogic-hurricanes.R`: estimates, diagnostics, tables and figures.
- Private project artifacts under a configured host directory; aggregate outputs under `output/corelogic/`, with source/sample manifests. Add Make targets only once inputs and host execution are settled.

Before promoting the hurricane design, simulate a small transaction panel with known effects and realistic irregular sale timing. Verify that the estimator recovers a zero effect under common vintage depreciation and county shocks, recovers a planted MH reform-vintage storm effect, and handles overlaps/replacement flags as intended. Test linkage uniqueness, frozen pre-storm treatment and date exclusions directly. This is more informative than reproducing the regression formula in a test.

Feasibility is not just total MH count. Report eligible properties in each of MH/SB × old/new within each storm-county, how many actually identify each coefficient after fixed effects, event-time support, concentration by event/state, and precision under the intended clustering. If the saturated storm-county design lacks support, present a clearly labeled coarser pilot or stop the pooled causal interpretation; do not silently broaden vintage/transaction definitions to obtain significance.

## 8. Choices for review

My defaults are: resale capitalization as the first deliverable; a hurricane **market-value** effect as the initial second estimand; original historical vintage frozen before impact; all construction cohorts including 1994, with the transition cohort estimated separately; and the paper's 1984–1999 vintage window with narrower/Florida-endpoint checks. Land-inclusive transactions remain a defined research population rather than a proxy for all manufactured homeowners.

The main decision after the coverage audit is whether enough pre-storm MH transactions have trustworthy historical vintages and subsequent sales to support the within-storm-county contrast. If they do, the repeat-sale extension is worth pursuing even before it can be interpreted as physical damage. If they do not, the vintage-price and composition analyses remain useful, while unconditional hurricane damage would require another historical property/damage source.
