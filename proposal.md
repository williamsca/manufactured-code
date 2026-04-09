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

**3. Selection into flood insurance.** Post-1994 MH owners may differ from pre-1994 owners in unobserved ways (income, risk aversion, information). This could affect both the probability of holding NFIP coverage and the composition of claims. The new policy-composition checks suggest this is not a simple "safer insureds" story. Relative to pre-1994 MH, post-1994 MH policies have higher replacement cost and higher building/contents coverage, a higher share in FEMA Special Flood Hazard Areas (SFHAs), and a higher mandatory-purchase share. Those shifts would tend to increase expected NFIP payments, not lower them. Post-1994 MH are also more likely to be classified as elevated buildings, which goes in the opposite direction and is consistent with genuine mitigation. Primary-residence share is essentially unchanged across vintages.

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
- Replacement cost, building/contents coverage, elevated-building share, SFHA share, primary-residence share, and mandatory-purchase share (composition checks)

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

#### Event study (main figure)

The event study is the primary visual. It imposes no functional form on the vintage profile, which matters because treatment onset is gradual: the HUD standard took effect mid-1994, so 1994–1995 vintages are partially treated (pipeline inventory built to old specs). The event study captures these treatment dynamics naturally — flat pre-trend, gradual onset, and growing effect — in a way that an RD plot with a forced sharp break cannot.

The event study also serves as the nonparametric complement to the diff-in-disc estimate below: it shows the full shape of the vintage profile without parametric assumptions.

**Claim-level specification:**
```
Y_it = α_{c(i),t} + δ_m + Σ_k β_k (1[constr_period = k] × MH_i) + ε_it
```
where:
- `Y` = net building payment, net contents payment, damage amounts
- `α_{c(i),t}` = tract × loss-period FE (absorbs location and storm severity)
- `δ_m` = MH indicator FE (absorbs time-invariant MH/site-built differences)
- `β_k` = MH-specific vintage effects relative to 1993; post-1994 coefficients are the treatment effect

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

#### Difference-in-discontinuities (baseline estimate)

The diff-in-disc specification addresses the age-vintage confound directly by controlling for smooth vintage effects via polynomials in construction year. It estimates the MH-specific jump at 1994 net of these trends:

```
Y_it = α_{c(i),t} + δ MH_i
     + f_SB(v_i) + f_MH(v_i) × MH_i
     + γ Post94_i + β (Post94_i × MH_i) + ε_it
```
where:
- `v_i = year_built_i − 1994` is the running variable (centered at the cutoff)
- `f_SB(v)`, `f_MH(v)` are linear polynomials estimated **separately on each side** of the cutoff. Type-specific polynomials allow MH and site-built to have different depreciation profiles.
- `α_{c(i),t}` = county × loss-year FE (absorbs location and storm severity)
- `Post94_i = 1[year_built ≥ 1994]`; γ captures any common break at 1994 (placebo — small and insignificant in practice)
- **β is the treatment effect**: the MH-specific discontinuity at 1994, net of smooth vintage trends and any common break

Uses annual construction year (not binned). The RD estimate is likely attenuated: since the HUD standard took effect mid-1994, the 1994–1995 vintages are partially treated (pipeline inventory), and the forced sharp-break assumption averages over these transition years. This makes β a conservative lower bound relative to the full-treatment effect visible in later event-study coefficients. TBD which specification to lead with — the diff-in-disc is more rigorous on the age confound but less intuitive and likely attenuated; the event study is more transparent about treatment dynamics but relies on the site-built comparison to rule out age.

### Stage 3: Cost-benefit (to be done)

**Private cost-benefit:** Translate the price premium to per-unit dollar cost (~$4–7k). Compare to expected damage reduction over the home's lifetime: (baseline flood probability) × (damage reduction per event). This likely yields a ratio below 1 using flood damage alone — the regulation doesn't fully pay for itself through the NFIP channel.

**Lower-bound interpretation:** The HUD code targeted wind resilience, not flood protection. Flood damage reductions are a spillover benefit. If even the "wrong channel" generates substantial savings, the total return (including wind, displacement, and uninsured losses) is higher.

**Insurance value for credit-constrained households:** MH residents are disproportionately low-income, credit-constrained, and uninsured against flood risk. For these households, the certainty-equivalent value of avoiding catastrophic loss exceeds the expected value. The HUD code acts as built-in insurance — upfront premium (higher price), automatic payout (home doesn't collapse) — without annual premiums, take-up friction, or moral hazard. Even if the expected cost-benefit ratio is close to 1, the welfare value for risk-averse, liquidity-constrained agents may be substantially higher.

**MVPF framing:** Since this is a regulatory mandate (not a government transfer), the net fiscal cost is approximately zero. Any positive WTP implies MVPF → ∞, meaning the mandate dominates subsidy-based alternatives on a per-dollar-of-government-cost basis. This is a one-line result, not a framework — but worth noting.

### Stage 4: Insurance access and the value of NFIP take-up

The HUD code reform did not just make manufactured homes more resilient — it made them insurable. Prior to 1994, manufactured homes that did not meet HUD anchoring and tie-down standards were generally ineligible for NFIP coverage. The 1994 reform brought MH into compliance with the structural and installation requirements that NFIP underwriting demanded, opening the flood insurance market to a population that had been effectively excluded. This section develops a framework for valuing the resulting increase in NFIP take-up.

#### Evidence on the insurance access channel

The Poisson event study on policy counts shows that post-1994 MH vintages have dramatically more NFIP policies than pre-1994 vintages, relative to site-built homes: coefficients of 0.34 (1994 bin), 0.51 (1996), and 0.80 (1998) in log points, implying 40–120% increases. The MH share of all policies also rises sharply at 1994, with annual coefficients growing from near zero to +0.5–0.9 percentage points by the late 1990s. Both series show flat pre-trends. These results are consistent with the code reform unlocking insurance access for a previously excluded housing type.

The composition of the new policies reinforces this interpretation. Post-1994 MH policies are more concentrated in SFHAs (+4–5 pp), more likely to face mandatory purchase requirements (+1 pp), and carry higher building and contents coverage. These are not low-risk households selecting into cheap coverage — they are flood-exposed households gaining access to a market they were previously locked out of.

#### Framework: welfare value of insurance access

The welfare value of moving a household from uninsured to insured can be analyzed using the Baily (1978)–Chetty (2006) sufficient-statistics approach. Two formulations are available:

**Consumption-drop formulation.** The value of insurance is proportional to the consumption drop $\Delta c / c$ that households experience in the bad state (disaster loss) absent coverage, scaled by risk aversion $r$. For MH households with median income ~$30K and housing wealth ~$50K, an uninsured total loss implies $\Delta c / c$ on the order of 0.5–1.0. At $r = 2$–3, the certainty-equivalent cost of bearing this risk is large relative to actuarially fair premiums.

Calibration sources for $\Delta c / c$:
- Deryugina, Kawano, and Levitt (2017) track post-hurricane income trajectories using tax data; their estimates for low-income households provide a credible lower bound.
- FEMA Individual Assistance records document the gap between total losses and compensated amounts (NFIP payout + FEMA grant + SBA loan) — the uncompensated residual is the consumption hit.
- Back-of-envelope: for an uninsured MH household, the full home value (~$50K) is at risk. Even partial damage of $10K implies $\Delta c / c \approx 0.33$ for a $30K-income household with no savings buffer.

**Demand elasticity formulation (Chetty and Finkelstein 2013).** Instead of measuring the consumption drop directly, the welfare value of coverage can be recovered from the elasticity of insurance demand with respect to price. If demand is inelastic — households do not drop coverage in response to premium increases — then willingness-to-pay for coverage substantially exceeds the premium, implying large consumer surplus.

Potential sources of identifying variation for the demand elasticity:
- Cross-sectional premium variation from flood zone designation (SFHA boundary), CRS community discounts, and coverage-level choices within post-1994 MH.
- NFIP premium reforms under HFIAA 2014, which changed subsidy structures and could trace out a demand curve for MH policies — though this is largely a post-sample exercise.
- The mandatory purchase requirement at the SFHA boundary creates a sharp discontinuity in effective price (infinite price of non-compliance inside, market price outside) that reveals the take-up margin.

The consumption-drop approach is more feasible with current data. The demand-elasticity approach requires premium variation that is exogenous to risk, which is harder to isolate within the existing NFIP sample.

#### Moral hazard considerations

The standard concern with expanding insurance access is moral hazard: coverage may induce riskier behavior, either through location choice (extensive margin) or housing type composition (intensive margin).

**Extensive margin (location choice).** Flood insurance makes risky locations cheaper to occupy, potentially drawing more settlement into floodplains. This channel is well-studied in the NFIP literature (Kousky et al.) and estimates of the elasticity of development to NFIP subsidies are available for calibration. Importantly, this channel is generic to all housing types, not MH-specific.

**Intensive margin (housing type composition).** If MH is fundamentally riskier conditional on location, NFIP access could tilt the stock toward the riskier type. However, the direction of moral hazard likely runs *against* MH. The NFIP subsidy scales with insured value: a $250K site-built home benefits far more from underpriced flood insurance than a $50K singlewide. The premium-to-value ratio is much less favorable for MH (~2.4% of home value vs. ~0.8% for site-built at typical premiums), so the distortion to location and type choice from NFIP subsidies is overwhelmingly a site-built phenomenon. Furthermore, the MHS placements null (no quantity response in treated states) bounds the total placement margin: if total MH shipments didn't change, the reallocation across locations is limited.

**Code-as-moral-hazard-solution.** In the Baily-Chetty framework, the optimal benefit level trades off consumption smoothing against moral hazard ($\varepsilon$). The HUD code effectively sets $\varepsilon \approx 0$ for the construction-quality margin: compliance is mandatory, verified at the factory, and embedded in the home before the insurance decision is made. The household cannot "un-build" the structural improvements in response to coverage. By eliminating the main moral hazard channel that prevented insurers from serving MH, the code makes actuarially fair pricing feasible and the welfare case for coverage unambiguous.

#### Building codes and insurance as complements

The standard result from Ehrlich and Becker (1972) is that self-protection and market insurance are substitutes: investing in precaution reduces the value of insurance. The MH setting inverts this relationship. Pre-1994, manufactured homes were simultaneously the riskiest housing stock and the least insurable — too vulnerable for NFIP to underwrite at any affordable price, and too cheap for the NFIP subsidy to meaningfully offset location risk. The code reform made homes both more resilient (reducing expected losses to insurable levels) and more insurable (satisfying NFIP underwriting requirements). The two channels are complements, not substitutes: resilience is a *prerequisite* for market participation.

The welfare gain from the reform therefore has two multiplicative components:
1. **Direct resilience benefit:** $\Delta L \approx$ $4–7K per flood event (estimated from claims data).
2. **Market-creation benefit:** Moves households from zero coverage to positive coverage, eliminating the uninsured consumption drop for covered events.

For a household with $c = $30K and $r = 2$–3, moving from "uninsured $10K loss" to "insured $5K loss with $250 deductible" generates a welfare gain that far exceeds the $5K difference in expected damage. The certainty-equivalent value of that transition scales with $r \cdot (\Delta c / c)^2$, not linearly in the expected damage reduction.

#### The counterfactual cost of compliance for pre-1994 homes

Any welfare calculation comparing insured post-1994 MH to uninsured pre-1994 MH must confront the question: what would it cost to bring a pre-1994 manufactured home into compliance with the HUD standard (and thus NFIP eligibility)? If retrofit costs are low, then the insurance access channel reflects a bureaucratic/informational barrier rather than a genuine economic constraint, and the welfare gain from the code is smaller (the homes could have been cheaply upgraded and insured). If retrofit costs are high — approaching or exceeding the home's value — then pre-1994 homes were genuinely uninsurable, and the code reform created value by embedding compliance in new construction at much lower marginal cost than retrofit.

Relevant considerations:
- **Anchoring and tie-down systems.** The primary NFIP-relevant upgrade is proper anchoring to resist wind uplift and lateral forces. Retrofit anchoring for an existing MH is feasible but costly: industry estimates range from $3–8K depending on soil conditions, home size, and local requirements. For a $20–30K pre-1994 singlewide, this represents 10–40% of home value.
- **Structural upgrades.** The HUD code required reinforced roof-to-wall connections, upgraded sheathing fastening, and (in Zone III) impact-rated windows. These are integrated into the manufacturing process at modest marginal cost but are difficult and expensive to retrofit on an existing structure. Full structural retrofit is likely uneconomic for most pre-1994 MH.
- **Verification and certification.** Even if physical upgrades were performed, there is no standard certification pathway for bringing a pre-1994 MH into HUD Code compliance after manufacture. The code applies at the point of production, not as a retrofit standard. This creates a permanent institutional barrier: pre-1994 homes cannot be reclassified regardless of actual condition.

This last point is important. The insurance access barrier is not purely about physical risk — it is also about *verifiability*. The HUD label certifying code compliance is affixed at the factory. There is no equivalent post-hoc certification for retrofitted homes. This means the code reform's insurance-access benefit is *exclusively* available through new construction: it cannot be replicated by retrofitting the existing stock. The welfare value of the code therefore includes the option value of a credible, low-cost compliance signal that private retrofit markets cannot provide.

Data on retrofit costs:
- HUD Manufactured Housing Consensus Committee (MHCC) reports on installation standards.
- FEMA P-85 and the Manufactured Housing Institute (MHI) guidance on anchoring and tie-down systems.
- State-level retrofit mandate programs (e.g., Florida's post-Andrew requirements for MH in mobile home parks) may provide revealed-cost estimates.
- The NFIP claims data themselves: comparing damage outcomes for pre-1994 MH that were vs. were not elevated (the `elevated_share` variable) provides indirect evidence on the value of partial compliance through siting improvements, though elevation is not the same as full structural retrofit.

---

## Additional questions

1. **Did insurance markets price in the safety improvement?** If MH insurance premiums fell in Zone II/III after 1994, that's revealed-preference evidence the market recognized the benefit. In the current NFIP panel, policy cost per policy does not fall after 1994 even though elevated-building share rises, perhaps because post-1994 MH also have higher coverage levels and are more concentrated in SFHAs.

2. **Why did the price premium persist (or did it decay)?** The proposal initially hypothesized manufacturer standardization by ~2002, but the price event study shows a persistent premium through 2003. Extending the sample window would help resolve this.

3. **Distributional effects.** MH residents are disproportionately lower-income and more likely to lack insurance. A regulation that protects them from catastrophic disaster loss at ~10% price premium has progressive welfare implications. Low NFIP take-up among MH may reflect that MH often don't qualify for conventional mortgages (which require flood insurance as a lending condition), so the take-up channel that drives site-built coverage doesn't operate.

4. **Quantity effects.** The placement event studies based on the Manufactured Housing Survey data shows imprecise null effects. This would be a direct test of the private cost-benefit: if prices rose but placements didn't fall, then regulation's benefits likely exceed its cost. But can't reject null of fairly large declines (or increases) given large standard errors. Perhaps motivates a quantification of the benefits using NFIP data. Separately, policies and claims increase for post-1994 MH vintages in the NFIP data, perhaps due to new eligibility for flood insurance. That still raises a selection concern, but the direction of the observed composition shifts is informative: post-1994 MH policyholders are not simply a lower-risk insured group. They insure more expensive structures, carry more coverage, are more likely to be in SFHAs, and are more likely to face mandatory purchase requirements. The main offsetting change is that they are also more likely to be elevated buildings, which is plausibly part of the treatment channel rather than a confound.

---

## TODO

### Data and measurement
- [X] Test 2-year construction vintage bins: do results hold with tract × loss-period FEs? If yes, this is the preferred aggregation (more pre-periods for trend assessment while maintaining geographic precision). If not, lead with annual + county × loss-year FEs and show 3-year + tract FEs as robustness.
- [ ] Plot site-built vintage coefficients separately (not just the MH interaction) to demonstrate no break at 1994 for the comparison group.
- [X] Show annual-vintage event study (with county × loss-year FEs) to demonstrate sharpness of the break at 1994.
- [ ] Run unweighted regressions as robustness check (current cell-level specs weight by policies or claims).

### Identification and robustness
- [ ] Bandwidth sensitivity for diff-in-disc: narrow from 1985–2002 to 1990–1998, 1988–2000.
- [ ] Quadratic polynomial robustness for diff-in-disc.
- [ ] Donut test: restrict to 1990–1998 vintages to minimize the age gap.
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
