# NFIP claims data: useful fields for the HUD wind standards analysis

## Mechanism / damage intensity controls

- **`waterDepth`** — depth of flood water in inches. Critical omitted variable: post-1994 MH may sort into lower-elevation parcels (more flooding), so controlling for water depth separates structural integrity from flood exposure.
- **`floodCharacteristicsIndicator`** (1=Velocity Flow, 3=Wave Action vs. 2=Ponding) — wave action and velocity flow are the mechanisms most relevant to hurricane structural loading. Stratifying by this sharpens the story: the HUD wind standards *should* reduce damage most under wave action/velocity, not ponding.
- **`causeOfDamage`** — code 1 (tidal overflow/storm surge) and 4 (rainfall accumulation) let you separate hurricane-driven from non-hurricane claims. Your identification relies on hurricanes; filtering or stratifying by `causeOfDamage` in {1, 2} makes the sample more internally consistent.

## Normalize damage to value

- **`buildingPropertyValue`** / **`buildingReplacementCost`** — the current outcomes (`net_building_pmt`, `building_damage`) are in raw dollars. Post-1994 MH may differ in insured value, so `damage / property_value` is a cleaner outcome. Construct `damage_share := building_damage / buildingReplacementCost`.
- **`totalBuildingInsuranceCoverage`** — same logic: `net_building_pmt / totalBuildingInsuranceCoverage` is coverage-normalized payout, insulating the outcome from coverage selection.
- **`replacementCostBasis`** (R=replacement cost vs. A=actual cash value) — older MH are settled on actual cash value (depreciated), which mechanically reduces payout. This is a confounder if pre-1994 vintage and post-1994 vintage differ on this field. At minimum include as a control; ideally restrict to one settlement type.

## Mechanism identification (wind vs. water)

- **`nonPaymentReasonBuilding`** code 16 = "Not insured, wind damage" — when a claim is *denied* because the damage was attributed to wind, that's direct evidence the structural failure was wind-driven. Creating an indicator `denied_wind := (nonPaymentReasonBuilding == "16")` gives you an outcome that is cleanly tied to the HUD wind standard mechanism, not flood depth. This is the sharpest way to test the specific mechanism.

## Better storm fixed effects

- **`floodEvent`** / **`eventDesignationNumber`** / **`ficoNumber`** — these identify named catastrophe events. Using these as FEs (instead of `period_loss` bins) is cleaner: two storms in the same year-period can have very different tracks and intensities.

## Additional outcome: ICC payments

- **`iccCoverage`** / **`amountPaidOnIncreasedCostOfComplianceClaim`** — ICC pays for bringing damaged structures into compliance with current ordinances (elevation, mitigation). If post-1994 MH are already code-compliant, they should require less ICC spend after a loss. This is a distinct outcome from repair cost and could be a slide on its own.

## MH identification cross-check

- **`buildingDescriptionCode`** == 18 ("Manufactured (Mobile) Home") and **`numberOfFloorsInTheInsuredBuilding`** == 5 ("Manufactured/mobile home on foundation") — useful to validate the `mh` indicator. The "on foundation" distinction also matters because anchored MH should perform better under wind, so `numberOfFloorsInTheInsuredBuilding == 5` vs. not could be a heterogeneity cut.

---

## Summary priority table

| Field | Use | Priority |
|---|---|---|
| `waterDepth` | Control for flood intensity | High |
| `floodCharacteristicsIndicator` | Stratify wave action vs. ponding | High |
| `causeOfDamage` | Restrict to storm surge/overflow events | High |
| `buildingPropertyValue` / `buildingReplacementCost` | Normalize damage outcomes | High |
| `nonPaymentReasonBuilding` == 16 | Wind-damage denial as outcome | High |
| `floodEvent` / EDN | Better storm FEs | Medium |
| `totalBuildingInsuranceCoverage` | Coverage-normalize payouts | Medium |
| `replacementCostBasis` | Control/restrict settlement type | Medium |
| `amountPaidOnIncreasedCostOfComplianceClaim` | Additional outcome | Medium |
| `numberOfFloorsInTheInsuredBuilding` == 5 | Foundation heterogeneity | Low |
