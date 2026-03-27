# Research proposal: The Returns to Climate Adaptation in Manufactured Housing

## Core idea

The 1994 HUD wind standards reform is a natural experiment in mandatory adaptation investment. Hurricane Andrew (August 1992) destroyed 97% of manufactured homes in Dade County, FL, versus 11% of site-built homes. HUD responded with a three-zone wind classification (70/100/110 mph) effective July 1994, requiring structural overhauls — steel strapping, impact-rated windows, upgraded sheathing fastening — only for manufactured homes (MH) in coastal Zone II/III counties.

The cost side is estimated: treated (Zone II/III) states saw real MH prices rise ~10% relative to Zone I control states, with the premium decaying over ~8 years (possibly reflecting manufacturer standardization to the higher spec everywhere). The benefit side — damage avoided when subsequent hurricanes hit — is unestimated and is the core empirical contribution of this paper.

**Target journals:** Journal of Urban Economics, Journal of Housing Economics

---

## Identification design

The key advantage is a comparison group (site-built homes) in the *same location* that faced the same storms but was not subject to the rule change. This motivates a **triple difference**:

1. **MH vs. site-built** — only MH was regulated by the HUD Code change
2. **Zone II/III vs. Zone I counties** — only coastal counties required upgraded standards
3. **Post-1994 vintage vs. pre-1994 vintage MH** — within Zone II/III, pre-1994 homes were noncompliant; post-1994 homes were compliant

The third dimension is particularly clean: within a treated county hit by the same storm, pre- and post-1994 MH differ only in compliance status. This collapses confounds from location selection, owner income, and unobserved county characteristics.

The 2004 Florida hurricane season (Charley, Frances, Ivan, Jeanne) and 2005 season (Katrina, Rita, Wilma) serve as near-ideal "tests" — major landfalls in Zone II/III states after a full decade of post-rule construction. Post-2004 field surveys already document that no post-1994 MH suffered serious structural damage in Florida; the paper would put numbers on that claim.

**Note on the price decay:** If manufacturers standardized to Zone II/III specs everywhere by ~2002, Zone I "control" homes also received the upgrade, muddying the cross-zone benefit comparison for the 2004-2005 storms. The within-Zone-II/III vintage comparison is cleaner for this reason.

---

## Data

### Cost side (already estimated)
- State-year MH price and placements panel, 1980–2013 (`sample-state.Rds`)
- TWFE event study: ~10% price increase in treated states, decaying ~8 years post-1994

### Benefit side (to be assembled)

| Source | What it measures | MH identified? |
|--------|-----------------|----------------|
| FEMA Individual Assistance (IA) registrants (OpenFEMA) | Per-household disaster grants; covers structural wind damage | Yes — housing type collected |
| FEMA NFIP claims (OpenFEMA) | Insurance payouts; covers wind-driven water damage | Yes — occupancy type field |
| FEMA HMGP buyout data | Total-loss proxy (post-disaster buyouts) | MH over-represented |
| NOAA HURDAT2 / IBTrACS | Hurricane track and county-level max wind speed | n/a — storm intensity instrument |
| American Housing Survey | Housing vintage, characteristics, self-reported damage | Yes, small sample |
| CoreLogic / Verisk (private) | Property-level insurance claims | Yes |

**Key data limitation:** NFIP covers flooding, not pure wind damage. FEMA IA better captures wind-related structural losses but grant amounts reflect means-testing, not pure damage. The paper should use both and note the measurement tradeoff. For the sharpest estimates, county-level maximum wind speed from IBTrACS is the instrument for storm exposure.

---

## Empirical strategy

### Stage 1 (already done): Cost estimation
TWFE event study on log real MH price, treated × event-time interactions, state and year FEs, clustered by state. Sample 1985–2002.

### Stage 2: Benefit estimation

**Specification:**
```
Y_iht = α_c + γ_t + β_1 (Post1994_h) + β_2 (MH_i)
      + β_3 (Post1994_h × MH_i) + X_it'δ + ε_iht
```

where:
- `i` = household/property, `h` = housing vintage (pre/post 1994), `t` = storm event
- `Y` = FEMA IA grant amount, NFIP claim amount, or indicator for any claim
- `α_c` = county fixed effects (absorbs location quality, baseline storm exposure)
- `γ_t` = storm fixed effects (absorbs variation in storm severity across events)
- `Post1994_h × MH_i` = the compliant MH indicator; β_3 is the damage-reduction estimate
- `X_it` = distance from storm track, max wind speed at county centroid (IBTrACS)

Sample: Zone II/III counties that experienced at least one named hurricane landfall 1994–2012.

### Stage 3: Cost-benefit

Translate cost estimate to per-unit dollar terms (price premium × average unit value). Compare to expected damage reduction (β_3 × baseline claim rate × claim amount), discounted over the relevant horizon. Compute implied cost-benefit ratio.

---

## Additional questions

1. **Did insurance markets price in the safety improvement?** If MH insurance premiums fell in Zone II/III after 1994, that's revealed-preference evidence the market recognized the benefit — and narrows the externality justification for the mandate.

2. **Why did the price premium decay?** Manufacturer standardization is the leading hypothesis. If true: (a) the Zone I "treatment" eventually received the upgraded product for free, which has implications for optimal regulatory design; (b) scale economies in safety investment may justify minimum standards even absent consumer information failures.

3. **Distributional effects.** MH residents are disproportionately lower-income and more likely to lack insurance. A regulation that protects them from catastrophic disaster loss at ~10% price premium has progressive welfare implications worth quantifying.

---

## Related literature

- Boustan et al. (2020, AEJ:AE) — flood insurance and disaster costs
- Meltzer & Grunberg (various) — HUD Code effects on MH markets
- Simonsohn & Loomes — building codes and house prices
- Kahn (2005, JUE) — building codes and earthquake losses (direct precursor)
- Hornbeck (2012, AER) — adaptation to natural disasters
- Gallagher (2014, AEJ:AE) — learning from natural disasters and flood insurance takeup
