# Research proposal: The Returns to Climate Adaptation in Manufactured Housing

## Core idea

The 1994 HUD wind standards reform is a natural experiment in mandatory adaptation investment. Hurricane Andrew (August 1992) destroyed 97% of manufactured homes in Dade County, FL, versus 11% of site-built homes. HUD responded with a three-zone wind classification (70/100/110 mph) effective July 1994, requiring structural overhauls — steel strapping, impact-rated windows, upgraded sheathing fastening — only for manufactured homes (MH) in coastal Zone II/III counties.

**Cost side (estimated):** Treated (Zone II/III) states saw real MH prices rise ~10–14% relative to Zone I control states, emerging immediately in 1994 and persisting through at least 2003 (no clear decay in the current sample window). On a mean MH price of ~$40–50k, this implies a per-unit cost of ~$4–7k.

**Benefit side (estimated):** Using NFIP claims data, post-1994 MH experience $4–7k lower building damage payments per claim, $1–2k lower contents payments, and ~0.02 fewer claims per policy, all relative to site-built homes in the same tract hit by the same flood. These estimates capture the flood-damage channel only — a lower bound on total benefits, since the HUD code targeted wind resilience, not flooding.

**Target journals:** Journal of Urban Economics, Journal of Housing Economics

---

## Identification design

### What we estimate

The primary specification exploits two sources of variation:

1. **MH vs. site-built** — only MH was regulated by the HUD Code change
2. **Post-1994 vintage vs. pre-1994 vintage** — within a flood event, newer MH were built to the upgraded standard; older MH were not

This is a **double difference** in vintage × housing type. Tract × loss-period fixed effects ensure we compare only units exposed to the same flood in the same location. The site-built comparison group absorbs secular changes in construction quality, storm severity, and neighborhood characteristics, isolating the MH-specific break at 1994.

### Why not the spatial (wind zone) dimension?

The proposal initially envisioned a triple-diff adding Zone II/III vs. Zone I. We drop this dimension in the NFIP analysis for power: MH account for <10,000 claims in the NFIP data, and further splitting by wind zone leaves cells too thin. The state-level price analysis retains the spatial comparison (treated vs. untreated states).

If manufacturers standardized to Zone II/III specs everywhere by ~2002 (the price-decay hypothesis), the spatial dimension is muddied for post-2002 storms anyway. The vintage × housing type comparison does not depend on geographic variation in the standard.

### Threats to identification

**1. Age-vintage confound (primary concern).** Pre-1994 homes are mechanically older at the time of any given storm. They may perform worse due to depreciation, deferred maintenance, or material obsolescence — not because the HUD code improved the post-1994 stock. This is the standard challenge with any vintage-based design.

Defenses:
- **Triple-diff with site-built (main spec).** If site-built homes show no comparable vintage break at 1994, the age channel is unlikely to explain the MH result. The `i(period_constr, mh)` interaction isolates the MH-specific break, but we should also plot site-built vintage coefficients separately to show the absence of a break.
- **Parametric age controls.** Include flexible functions of home age or year-built bins. The HUD code effect should appear as a discrete jump at 1994, not a smooth age gradient.
- **Donut around 1994.** Restrict to 1990–1998 vintages so the age gap is small (≤8 years) and depreciation differences are minimal.

**2. Secular improvement in MH construction.** If MH quality was trending upward independent of the regulation, the post-1994 estimates capture both the rule change and the trend. The pre-trend in the event study is the primary diagnostic. The 3-year-binned pre-trends look flat for building and contents payments; the claims-per-policy plot shows a slight (insignificant) dip at 1988 that merits discussion.

**3. Selection into flood insurance.** Post-1994 MH owners may differ from pre-1994 owners in unobserved ways (income, risk aversion, information). This could affect both the probability of holding NFIP coverage and the composition of claims. No changes in average cost per policy or replacement cost per policy across vintages is reassuring — it suggests the insured population isn't shifting.

**4. Assessed value denominator.** Damage shares (damage / building value) show little within-tract × loss-year variation in assessed values, making the share results nearly mechanical given the level results. The level results are more informative.

---

## Data

### Cost side (estimated)
- State-year MH price and placements panel, 1985–2003 (`sample-mhs.Rds`)
- Source: Census Bureau Manufactured Housing Survey
- TWFE event study: ~10–14% price increase in treated states post-1994, state and year FEs, clustered by state

### Benefit side (estimated)

| Source | What it measures | Unit of observation | MH identified? |
|--------|-----------------|---------------------|----------------|
| FEMA NFIP claims (OpenFEMA) | Insurance payouts for flood damage | Claim | Yes — floor count field (5 = MH) |
| FEMA NFIP policies (OpenFEMA) | Active flood insurance coverage | Policy-year | Yes — same coding |

**Sample construction:** Claims restricted to 1985–2002 construction vintage, post-1994 loss years. Construction years binned into 3-year periods (1985, 1988, 1991, 1994, 1997, 2000). Loss years binned into 5-year periods. Balanced panel at the tract × loss-period × MH × construction-period cell level.

**Key variables:**
- Building/contents damage amounts and NFIP payments (levels)
- Damage as share of assessed building value (%)
- Claims per policy (extensive margin)
- Replacement cost and policy cost per policy (composition checks)

**Auxiliary data (available but not yet used):**

| Source | What it adds |
|--------|-------------|
| FEMA Individual Assistance (OpenFEMA) | Per-household disaster grants; captures wind damage |
| NOAA IBTrACS | Hurricane track and county-level max wind speed |
| CoreLogic / Verisk (private) | Property-level insurance claims |

---

## Empirical strategy

### Stage 1: Cost estimation (done)

TWFE event study on log real MH price:
```
log(P_st) = α_s + γ_t + Σ_k β_k (1[year = k] × treated_s) + ε_st
```
State and year FEs, clustered by state. Sample: 1985–2003, excluding AK/HI.

### Stage 2: Benefit estimation (done, being refined)

**Claim-level specification (main):**
```
Y_it = α_{c(i),t} + δ_m + Σ_k β_k (1[constr_period = k] × MH_i) + ε_it
```
where:
- `i` = claim, `t` = loss period, `c(i)` = census tract
- `Y` = net building payment, net contents payment, damage amounts
- `α_{c(i),t}` = tract × loss-period FE (absorbs location and storm severity)
- `δ_m` = MH indicator FE (absorbs time-invariant MH/site-built differences)
- `β_k` = MH-specific vintage effects relative to 1991; post-1994 coefficients are the treatment effect

**Cell-level specification (rates):**
```
Y_ct = α_{c,t} + δ_m + Σ_k β_k (1[constr_period = k] × MH_c) + ε_ct
```
- `Y` = claims per policy, replacement cost per policy, policy cost per policy
- Weighted by number of policies in cell

**MH share specification:**
```
ShareMH_ct = α_{c,t} + Σ_k γ_k 1[constr_period = k] + ε_ct
```
- `ShareMH` = MH claims / total claims (or MH policies / total policies)
- Weighted by total claims; tests whether MH's share of claims falls for post-1994 vintages

### Stage 3: Cost-benefit (to be done)

**Private cost-benefit:** Translate the price premium to per-unit dollar cost (~$4–7k). Compare to expected damage reduction over the home's lifetime: (baseline flood probability) × (damage reduction per event). This likely yields a ratio below 1 using flood damage alone — the regulation doesn't fully pay for itself through the NFIP channel.

**Lower-bound interpretation:** The HUD code targeted wind resilience, not flood protection. Flood damage reductions are a spillover benefit. If even the "wrong channel" generates substantial savings, the total return (including wind, displacement, and uninsured losses) is higher.

**Insurance value for credit-constrained households:** MH residents are disproportionately low-income, credit-constrained, and uninsured against flood risk. For these households, the certainty-equivalent value of avoiding catastrophic loss exceeds the expected value. The HUD code acts as built-in insurance — upfront premium (higher price), automatic payout (home doesn't collapse) — without annual premiums, take-up friction, or moral hazard. Even if the expected cost-benefit ratio is close to 1, the welfare value for risk-averse, liquidity-constrained agents may be substantially higher.

**MVPF framing:** Since this is a regulatory mandate (not a government transfer), the net fiscal cost is approximately zero. Any positive WTP implies MVPF → ∞, meaning the mandate dominates subsidy-based alternatives on a per-dollar-of-government-cost basis. This is a one-line result, not a framework — but worth noting.

---

## Additional questions

1. **Did insurance markets price in the safety improvement?** If MH insurance premiums fell in Zone II/III after 1994, that's revealed-preference evidence the market recognized the benefit. No evidence of premium changes in cost-per-policy so far.

2. **Why did the price premium persist (or did it decay)?** The proposal initially hypothesized manufacturer standardization by ~2002, but the price event study shows a persistent premium through 2003. Extending the sample window would help resolve this.

3. **Distributional effects.** MH residents are disproportionately lower-income and more likely to lack insurance. A regulation that protects them from catastrophic disaster loss at ~10% price premium has progressive welfare implications. Low NFIP take-up among MH may reflect that MH often don't qualify for conventional mortgages (which require flood insurance as a lending condition), so the take-up channel that drives site-built coverage doesn't operate.

---

## Related literature

- Boustan et al. (2020, AEJ:AE) — flood insurance and disaster costs
- Meltzer & Grunberg (various) — HUD Code effects on MH markets
- Kahn (2005, JUE) — building codes and earthquake losses (direct precursor)
- Hornbeck (2012, AER) — adaptation to natural disasters
- Gallagher (2014, AEJ:AE) — learning from natural disasters and flood insurance takeup
- Hendren & Sprung-Keyser (2020, QJE) — MVPF framework for policy evaluation
- Deryugina (2017, AEJ:EP) — fiscal costs of hurricanes
- Currie & Walker (2011, QJE) — environmental regulation and health (mandate cost-benefit template)

---

## TODO

### Data and measurement
- [ ] Test 2-year construction vintage bins: do results hold with tract × loss-period FEs? If yes, this is the preferred aggregation (more pre-periods for trend assessment while maintaining geographic precision). If not, lead with annual + county × loss-year FEs and show 3-year + tract FEs as robustness.
- [ ] Plot site-built vintage coefficients separately (not just the MH interaction) to demonstrate no break at 1994 for the comparison group.
- [ ] Show annual-vintage event study (with county × loss-year FEs) to demonstrate sharpness of the break at 1994.
- [ ] Run unweighted regressions as robustness check (current cell-level specs weight by policies or claims).

### Identification and robustness
- [ ] Donut test: restrict to 1990–1998 vintages to minimize the age gap.
- [ ] Parametric age control: add flexible function of home age and test whether the 1994 break survives.
- [ ] Pre-trend test: estimate linear vintage slope on pre-1994 data and test whether the post-1994 break exceeds the extrapolated trend.
- [ ] Investigate the 1988 dip in claims-per-policy pre-trend — is it driven by specific storms or tracts?

### Cost-benefit
- [ ] Compute baseline flood probability for MH in Zone II/III over a 30-year horizon.
- [ ] Back-of-envelope: (damage reduction per event) × (probability of event) × (home lifetime) vs. price premium.
- [ ] Investigate FEMA Individual Assistance data for wind-damage estimates (the targeted channel).
- [ ] Literature review on consumption smoothing / insurance value for low-income disaster victims to calibrate welfare multiplier.

### Paper
- [ ] Draft introduction and framing: "Does mandated climate adaptation pay for itself?"
- [ ] Determine whether the price premium decays — extend MHS sample past 2003 if data available.
- [ ] Decide on a title: current working title focuses on "returns to adaptation"; alternatives could emphasize the insurance/welfare angle.
