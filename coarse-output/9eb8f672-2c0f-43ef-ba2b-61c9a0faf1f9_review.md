# The Returns to Climate Adaptation in Manufactured Housing

**Date**: 04/20/2026
**Domain**: social_sciences/economics
**Taxonomy**: academic/working_paper
**Filter**: Active comments

---

## Overall Feedback

Here are some overall reactions to the document.

**Outline**

The paper studies an important policy question and has a promising empirical setting: a national manufactured-housing code change, rich NFIP microdata, and a clear cost-benefit motivation. The central empirical claim, however, currently asks the data to do more than the design can support. The largest issues are the counterfactual for post-1994 manufactured homes, the interpretation of NFIP claim payments as physical damage reductions, and the gap between a wind-standard reform and a flood-loss welfare claim.

The paper has a strong topic and a potentially valuable contribution because manufactured housing is both policy-relevant and under-studied in climate adaptation work. The use of construction vintages, county-period comparisons, policy records, and price data is a sensible starting point. At present, though, the causal interpretation and welfare framing are not yet tight enough for a top economics venue.

**The main vintage design does not yet isolate the HUD standard from manufactured-home cohort changes**

Equation (2) identifies the benefit effect from manufactured-home-specific breaks in the construction-vintage profile after 1994, relative to site-built homes in the same county-loss period. That comparison is vulnerable because post-1994 manufactured homes may differ from earlier manufactured homes in buyer composition, park location, installation practices, financing, value, and flood-zone placement for reasons unrelated to the HUD wind standard. Section 5.3 documents large post-1994 shifts in replacement cost, coverage, SFHA status, and elevation, which means the treated cohorts are not compositionally stable around the reform. The claim that most of these shifts work against the result is too quick: higher replacement cost or coverage can mechanically raise potential payments, but newer, higher-value insured manufactured homes may also be located in better-managed parks, on better lots, or owned by households more able to mitigate and maintain them. This matters because the paper's main contribution is causal, not merely descriptive. A stronger revision should add direct balance and selection tests using pre-loss policy characteristics, estimate specifications controlling flexibly for replacement cost, coverage, elevation, SFHA, mandatory-purchase status, and tract-level risk, and show results within narrower geographic and market cells where manufactured-home siting is more comparable across vintages.

**Site-built homes are an imperfect counterfactual for manufactured homes of the same vintage**

The identifying assumption in Section 4.2 is that vintage effects in flood damage would have evolved similarly for manufactured and site-built homes absent the HUD reform. That is a demanding assumption. Site-built homes of the same construction vintage in the same county-period can differ sharply from manufactured homes in elevation, foundation type, floodplain location, replacement value, local building-code regime, access to mitigation grants, mortgage requirements, and insurance coverage. County \times loss-period fixed effects absorb broad storm severity, but they do not equalize flood depth, surge exposure, first-floor elevation, drainage, or park-level clustering. The tract \times loss-period robustness in Table 4 helps, but the post-1994 coefficients shrink meaningfully and lose precision for the 1994 and 1996 bins, so it does not fully settle the concern. The paper should add alternative comparison groups that are closer to the treated units: pre- versus post-1994 manufactured homes within treated wind zones, manufactured homes in zone II/III versus zone I states with explicit state-by-vintage controls, or comparisons within mobile-home parks or very fine flood-risk geographies if possible. The revision should also report whether the effect survives controls for flood-zone designation, elevation status, replacement cost, coverage limits, and local code exposure of site-built homes.

**The mechanism from a wind standard to lower flood damage is underdeveloped**

The institutional discussion in Section 2.1 describes a wind-resistance reform involving steel strapping, sheathing fastening, and impact-rated windows, while the main benefit estimates in Section 5.2 use flood damage and NFIP payments. The paper needs a clearer mechanism for why a wind standard should reduce insured flood losses. Some channels are plausible: better anchoring could reduce movement during storm surge, stronger walls may reduce envelope failure, and installation changes may correlate with elevation or siting. But those are not the same channel, and some would imply that the effect is partly due to installation or siting practices rather than factory-built structural upgrades. Section 5.3 states that elevation is plausibly part of the treatment channel because the HUD Code encouraged improved siting and installation practices, yet Section 2.1 frames the reform as a federal construction standard and the cost analysis treats the price increase as production-cost compliance. The revision should separate structural, installation, and siting mechanisms. At minimum, show results with and without elevated buildings, by flood type or flood zone where available, by damage share rather than dollars, and for outcomes that should respond differently if the channel is flood depth versus structural integrity.

**NFIP claims condition on insurance and claiming, so the benefit estimates are not population effects**

Section 2.2 acknowledges that NFIP take-up is lower among manufactured homeowners, and Table 1 shows manufactured homes are only 2.4% of claims despite being a much larger share of the housing stock. The main damage estimates in Section 5.2 are therefore effects among insured homes that file claims, not effects on all manufactured homes exposed to floods. That distinction is central because the abstract and conclusion frame the HUD standard as built-in catastrophe insurance for low-income and underinsured households. The appendix on NFIP take-up shows raw post-1994 policy counts rise sharply for manufactured homes, but then states that the result is hard to interpret because the denominator is missing. That means selection into the insured-claim sample remains unresolved. A revision should either narrow the claim to insured claimants or build a denominator using MHS placements, ACS housing stocks, FEMA policy counts, or county-vintage housing inventories to estimate take-up and claim rates. The paper should also decompose the effect into claim frequency and payment conditional on claim, because lower payments per claim have a different welfare interpretation from fewer damaging flood events.

**Payments and reported damages may not measure physical loss reductions**

The paper moves between building damage, net building payment, and welfare benefits, but the NFIP variables reflect insurance accounting as well as physical loss. Table 2 reports effects on building damage, net building payment, damage as a share of assessed value, contents damage, and net contents payment, yet the text sometimes treats these as direct reductions in real resource losses. NFIP payments and reported damages can be affected by coverage limits, deductibles, depreciation, replacement-cost rules, policy type, adjuster behavior, and whether the loss exceeds insured value. Section 5.3 shows that post-1994 manufactured homes have higher replacement cost and higher coverage, which changes the mapping from physical damage to payments and may also change the probability that damages are capped. The paper should make the outcome hierarchy explicit: physical loss, adjusted damage estimate, payment, and uninsured residual are different objects. A useful fix would be to estimate effects on capped-payment indicators, payment-to-coverage ratios, damage-to-replacement-cost ratios, deductible-adjusted outcomes where possible, and the probability of zero or very small payments among claims. The cost-benefit section should use the outcome that best approximates real damage, not simply the one with the cleanest statistical result.

**The cost estimate may capture more than regulatory compliance costs**

Equation (1) compares manufactured-home prices in states containing wind zones II or III to zone I states around 1994, and Section 5.1 interprets the roughly $5,000 price increase as the per-unit compliance cost. That interpretation needs more support. Treated states are concentrated in hurricane-prone coastal and southern markets, where demand, dealer markups, transport costs, financing, model mix, and local economic conditions may have changed differently in the 1990s. The paper also says the reform applied uniformly to all manufactured homes nationwide, while the cost design defines treatment by states containing wind zones II or III. Those two statements need reconciliation: if all homes faced some federal code change, the treated-control contrast identifies differential exposure to higher wind-zone requirements, not the full reform. The quantity result in Figure 3 does not solve this because unchanged placements are consistent with offsetting demand changes or compositional upgrading, as the paper itself notes. A revision should document the exact regulatory treatment by wind zone, use model or shipment mix if available, test sensitivity to excluding partial-zone states, and compare price effects by the share of shipments actually placed in zones II/III. The welfare calculation should then label the $5,000 as a price incidence estimate, not necessarily an engineering compliance cost.

**The welfare calculation is too thin for the policy claims**

Section 6.1 computes a present value of about $1,600 in expected flood benefits against a $5,000 upfront price increase, then the abstract says the flood channel alone recovers a substantial share of the upfront cost and the conclusion describes the reform as cost-effective. The arithmetic supports a more cautious claim: the measured insured flood channel recovers roughly one-third of the estimated price increase under the stated assumptions. The gap may be closed by wind benefits, uninsured losses, displacement costs, risk aversion, or fiscal spillovers, but those are asserted rather than estimated. This matters because the paper's title and framing are about returns to climate adaptation, not only reduced NFIP payments per claim. The revision should present a disciplined welfare table with annual flood probabilities, discount rates, home lifetimes, alternative claim-rate denominators, uncertainty intervals, and break-even wind or uninsured-loss benefits needed to justify the cost-effectiveness claim. It should also distinguish private returns to homeowners, fiscal returns to NFIP/FEMA, and social returns, since the incidence of the $5,000 price increase and the benefits need not fall on the same households.

**The paper overstates implications for low-income and uninsured households**

The abstract and conclusion emphasize that the HUD standard protects low-income manufactured-home residents who often lack disaster insurance. The empirical evidence, however, comes from NFIP policyholders and claimants, who are likely more selected and more financially connected than uninsured manufactured-home residents. Section 2.2 explicitly says chattel-financed manufactured homes are often outside the mandatory purchase requirement, and Table 1 reports low mandatory-purchase shares. Without data on uninsured households, renters in manufactured-home parks, chattel borrowers, or households receiving FEMA Individual Assistance, the paper cannot yet show that the measured benefits accrue to the population highlighted in the framing. This is a framing problem as much as an identification problem. The revision should either scale back the equity claim or add evidence on distributional incidence: link the estimates to county or tract income, manufactured-home park concentration, policy take-up, IA claims, or ACS measures of tenure and poverty. A convincing version would show whether insured-claim benefits are larger in poorer places and whether the reform reduced post-disaster losses for households outside NFIP.

**No direct evidence on the targeted wind benefits**

The paper studies a wind-standard reform, but the measured benefit side is almost entirely flood damage. The text acknowledges that wind losses and uninsured losses are omitted, yet the title and conclusion still make a broader claim about returns to climate adaptation and benefits beyond the targeted hazard. That claim needs at least one disciplined computation for the targeted wind channel, even if it is not the main empirical design. A natural addition would use wind-heavy events with limited flooding, such as the 2004 Florida hurricane season or tornado events studied in the manufactured-housing safety literature, and compare post-1994 and pre-1994 manufactured-home damage, IA claims, or fatalities in HUD wind zones II/III. If event-level wind damage data are unavailable, the paper should compute the wind-loss reduction needed for the reform to break even and benchmark it against published estimates from Dehring and Halek, Simmons and Sutter, or Grosskopf.

**No worked disaster case with measured hazard intensity**

The main estimates average across many flood events, but the paper never shows what the result looks like in a concrete flood with known exposure intensity. That leaves readers without a check that the estimated payment reduction corresponds to lower damage at a given flood depth rather than differences in which claims enter the sample. A useful worked case would take one major event with rich inundation data, such as Hurricane Katrina, Hurricane Harvey, or Hurricane Ian, merge NFIP claims to FEMA flood-depth or surge grids at tract or parcel-scale geography, and estimate damage-depth curves separately for manufactured and site-built homes by construction vintage. The key computation would show whether post-1994 manufactured homes have lower building damage at the same approximate flood depth, flood zone, elevation status, and replacement-cost bin. This would not replace the main design, but it would make the central empirical object much easier to interpret.

**Affordability incidence of the mandate is missing**

The paper treats the $5,000 price increase as the upfront cost, but the policy argument concerns low-income and credit-constrained manufactured-home households. For that population, the relevant cost is not only present value; it is also financing, access, and who is priced out. The current quantity event study shows no detectable aggregate placement decline, but that does not settle whether marginal buyers shifted to older units, rented lots instead of buying, used more expensive chattel credit, or bore higher monthly payments. The paper should add an incidence calculation that translates the $5,000 price effect into monthly payments under typical chattel-loan terms and compares that burden with the expected annual flood benefit. A stronger version would use MHS shipment or ACS tenure data to test whether post-1994 treated states saw changes in manufactured-home ownership among low-income households, or estimate bounds on consumer surplus using plausible demand elasticities.

**Limited comparison to prior building-code evidence**

The paper cites the adaptation and building-code literature, but it does not formally show how its estimates compare with existing code-effectiveness estimates. That comparison matters because the contribution is framed as new evidence on whether mandated adaptation pays for itself. Readers need to know whether a $5,000 cost and a $7,000 per-claim flood-loss reduction are large or small relative to earlier estimates for Florida building codes, coastal codes, wildfire mitigation, and manufactured-home wind standards. A useful addition would be a short calibration table placing this paper beside Dehring and Halek, Simmons et al., Baylis and Boomhower, and Simmons and Sutter, using common units such as upfront cost, annual expected loss reduction, present-value benefit-cost ratio, and hazard channel. The paper should also state which prior result is recovered or extended: for example, whether the manufactured-housing wind-standard evidence implies larger returns than site-built coastal code reforms because the baseline vulnerability of manufactured homes is higher.

**Recommendation**: major revision. The paper has a promising setting and a meaningful question, but the current design does not yet pin down whether the post-1994 damage reduction is caused by the HUD wind standard rather than changing composition, siting, insurance selection, or claims-accounting differences. The welfare and policy conclusions also run ahead of the measured NFIP claim effects.

**Key revision targets**:

1. Strengthen the benefit-side identification by adding closer comparison groups, finer geographic or flood-risk controls, and specifications that condition on pre-loss policy characteristics, replacement cost, coverage, SFHA status, and elevation.
2. Resolve the insured-claim selection problem by estimating or bounding NFIP take-up, claim frequency, and payment conditional on claim using an external denominator for manufactured-home stocks or placements.
3. Clarify the mechanism linking the 1994 wind standard to flood-loss reductions, with tests separating structural upgrades from elevation, installation, siting, and flood-depth exposure.
4. Rework the cost estimate so it cleanly reflects differential exposure to HUD wind-zone requirements rather than broader treated-state price movements or model-quality changes.
5. Replace the back-of-envelope welfare discussion with a transparent cost-benefit table that reports assumptions, uncertainty ranges, break-even omitted benefits, and separate private, fiscal, and social returns.

**Status**: [Pending]

---

## Detailed Comments (23)

### 1. Common Vintage Effects Are Missing From The Benefit Specification

**Status**: [Pending]

**Quote**:
> The primary benefit-side specification is an event study that imposes no functional form on the vintage profile:
> 
> $Y_{it}=\alpha_{c(i),t}+\delta_{m}+\sum_{k}\beta_{k}(\mathbf{1}[\nu_{i}=k]\times\text{MH}_{i})+\varepsilon_{it}$ (2)
> 
> where $Y_{it}$ is the outcome for claim $i$ (e.g., building damage), $\alpha_{c(i),t}$ is a county $\times$ loss-period fixed effect absorbing location-specific storm severity, $\delta_{m}$ is a manufactured housing indicator absorbing
> 
> <!-- PAGE BREAK -->
> 
> time-invariant differences between housing types, $\text{MH}_{i}$ is an indicator for manufactured homes, and $\nu_{i}$ is the construction vintage bin of home $i$. The coefficients $\beta_{k}$ capture the manufactured-home-specific vintage profile relative to the 1992 reference bin. Post-1994 coefficients are the treatment effects.
> 
> Identification relies on a parallel trends assumption in the vintage profile of outcomes between manufactured and site-built homes in the absence of the HUD code reform. In other words, homes built at different times may experience different levels of flood damage due to changes in construction quality, storm severity, or intra-county location, but these vintage effects should be the same for manufactured and site-built homes.

**Feedback**:
The stated identification argument is a difference-in-differences over construction vintage: common vintage effects may exist, but manufactured homes should not have a different vintage profile absent the HUD reform. Equation (2) does not include those common vintage effects. Under the paper's own description, an untreated outcome would naturally include a term such as $\lambda_{\nu_i}$ shared by manufactured and site-built homes. Without it, the manufactured-by-vintage coefficients can absorb ordinary vintage differences rather than deviations from the site-built vintage profile. Add $+\lambda_{\nu_i}$ to Equation (2), omit the 1992 manufactured-by-vintage interaction explicitly, and describe $\beta_k$ as manufactured-home-specific deviations from the common construction-vintage profile. That revision would align the equation with the identifying assumption stated in the text.

---

### 2. Coverage And Replacement Cost Do Not Establish A Conservative Bias

**Status**: [Pending]

**Quote**:
> The composition shifts work against the main result. Relative to pre-1994 manufactured homes, post-1994 manufactured home policies have higher replacement cost ($20–30,000), higher building coverage ($8–14,000 per policy), and higher contents coverage ($1,000 per policy). Post-1994 manufactured homes are also more concentrated in SFHAs (2–7 percentage points higher). These shifts would all tend to increase expected NFIP payments, not lower them, making the damage reduction estimates conservative.

**Feedback**:
This paragraph moves too quickly from observed policy characteristics to the direction of bias. Higher SFHA exposure plausibly raises expected losses. Higher coverage limits are different: for a claim, increasing the coverage limit affects payments only when the loss would otherwise be capped, and it does not mechanically raise reported building damage. Replacement cost is also ambiguous. If damage scales with property value, it can raise dollar losses; if it proxies for newer or better-maintained homes, it can point the other way. The claim that all of these shifts make the estimates conservative needs either a capped-payment analysis, a damage-to-replacement-cost analysis, or more cautious wording. A cleaner sentence would say that several composition shifts could raise expected losses, but the table alone does not determine the sign of selection for the main damage outcomes.

---

### 3. Conclusion Overstates Cost Effectiveness Relative To The Reported Calculation

**Status**: [Pending]

**Quote**:
> For the 22 million Americans living in manufactured homes—disproportionately low-income, credit-constrained, and underinsured—these findings have direct policy relevance. The HUD standard provides catastrophe protection to a population that private insurance markets largely fail to reach. As climate change intensifies hurricane and flood risk, the returns to mandated adaptation investment in this housing sector are likely growing. The results suggest that building code reform
> 
> <!-- PAGE BREAK -->
> 
> can be a cost-effective tool for protecting populations from disaster losses, with benefits that extend well beyond the targeted hazard.

**Feedback**:
The cost-benefit calculation reports a present value of roughly $1,600 in expected flood damage reduction against a roughly $5,000 price increase. That is an economically meaningful partial return, but it is not by itself a cost-effectiveness result. The remaining case depends on wind losses, uninsured losses, displacement costs, risk aversion, or fiscal spillovers, which the paper discusses but does not estimate directly. The conclusion should draw that boundary. For example: "The results suggest that building code reform can generate meaningful disaster-loss reductions, and the full return may be larger once wind losses, uninsured losses, and other unmeasured benefits are accounted for." That wording preserves the policy point without asking the measured flood channel to carry more than it can.

---

### 4. Population Claim Goes Beyond The NFIP Claim Sample

**Status**: [Pending]

**Quote**:
> For the 22 million Americans living in manufactured homes—disproportionately low-income, credit-constrained, and underinsured—these findings have direct policy relevance. The HUD standard provides catastrophe protection to a population that private insurance markets largely fail to reach. As climate change intensifies hurricane and flood risk, the returns to mandated adaptation investment in this housing sector are likely growing. The results suggest that building code reform
> 
> <!-- PAGE BREAK -->
> 
> can be a cost-effective tool for protecting populations from disaster losses, with benefits that extend well beyond the targeted hazard.

**Feedback**:
The institutional logic is plausible: a construction standard applies whether or not a household buys insurance. The empirical evidence, however, is measured among NFIP-insured claimants, and the paper itself emphasizes that manufactured homeowners have low NFIP take-up. Readers will notice the gap between the population highlighted here and the population observed in the main estimates. The sentence should separate the institutional claim from the evidence. A more defensible version would be: "Because the HUD standard applies at construction, it may provide protection even for households that private insurance markets do not reach, although the estimates in this paper are measured among NFIP-insured claimants."

---

### 5. Per-Claim Damage Reduction Is Stated Inconsistently

**Status**: [Pending]

**Quote**:
> The 1994 HUD wind standard reform raised manufactured home prices by roughly $5,000 and reduced flood damage by $7,000 per claim. Even through this single channel, the expected damage reduction recovers a meaningful share of the compliance cost over a home’s lifespan.

**Feedback**:
The conclusion should be more precise about the object being summarized. Earlier text reports almost $6,000 lower building damage payments per claim, Table 2 reports several outcomes in thousands of dollars, and Section 6 combines roughly $5,000 in building damage with $2,000 in contents damage to get $7,000 per flood event. The phrase "reduced flood damage by $7,000 per claim" blurs building damage, contents damage, payments, and physical losses. This matters because the next sentence moves from per-claim estimates to lifetime expected benefits. State the pieces separately: the reform is associated with about $5,000 lower building damage and about $2,000 lower contents damage per claim under the baseline estimates, which imply roughly $1,600 in expected present-value flood benefits under the paper's claim-rate and discounting assumptions.

---

### 6. HUD Code Scope Is Too Broad

**Status**: [Addressed]

**Quote**:
> The vulnerability of manufactured homes to extreme weather prompted a major regulatory response. In 1994, HUD revised the Manufactured Home Construction and Safety Standards—the federal building code governing all factory-built housing—to impose wind resistance requirements.

**Feedback**:
The phrase "all factory-built housing" is too broad for the institutional claim the paper needs. The HUD manufactured-home code governs manufactured homes; modular and other factory-built units are generally built to state or local building codes. This distinction matters because the empirical contrast is between manufactured homes and site-built homes, not between factory-built and non-factory-built housing. Revise the phrase to "the federal building code governing manufactured homes." That is narrower and better supports the identification discussion that follows.

---

### 7. Wind-Zone Requirements Are Not Uniform Nationwide

**Status**: [Pending]

**Quote**:
> The preemption of local codes is a distinctive feature of the manufactured housing market. Site-built homes are subject to state and local building codes, which vary substantially across jurisdictions and are enforced through local permitting and inspection processes. Manufactured homes, by contrast, must meet a single federal standard. This institutional feature is central to the identification strategy: the 1994 reform applied uniformly to all manufactured homes nationwide, while leaving site-built homes unaffected.

**Feedback**:
The paragraph correctly emphasizes federal administration and preemption, but the last sentence conflates a national code with uniform treatment intensity. The same section says the reform created a three-zone wind classification system and imposed particular upgrades for homes sited in high-wind zones. That distinction matters for the cost design, which defines treated states by overlap with wind zones II or III. A better formulation would be: "the 1994 reform was implemented through the federal HUD Code for manufactured homes, with wind-resistance requirements varying by HUD wind zone, while site-built homes remained governed by state and local codes."

---

### 8. Window Requirement Appears Overstated

**Status**: [Pending]

**Quote**:
> In 1994, HUD revised the Manufactured Home Construction and Safety Standards—the federal building code governing all factory-built housing—to impose wind resistance requirements. The reform created a three-zone wind classification system and required structural upgrades including steel strapping, upgraded sheathing fastening, and impact-rated windows for homes sited in high-wind zones.

**Feedback**:
The examples should track the actual wind provisions closely, since they anchor the reader's understanding of what the reform changed. Steel strapping and upgraded fastening fit the wind-resistance discussion. "Impact-rated windows" is more specific and appears stronger than the manufactured-home window requirements, which concern design around openings and protection from wind pressures rather than a blanket mandate for impact-rated windows. Consider replacing the list with "stronger anchoring and strapping, upgraded sheathing and fastening schedules, and wind-pressure requirements for components and cladding in high-wind zones." That wording preserves the mechanism without overstating a particular feature.

---

### 9. Chattel-Loan Exemption Is Stated Too Broadly

**Status**: [Pending]

**Quote**:
> The National Flood Insurance Program provides federally backed flood insurance to property owners in participating communities. Flood insurance is mandatory for properties with federally backed mortgages in FEMA-designated Special Flood Hazard Areas (SFHAs). However, manufactured homes are frequently financed with chattel loans (personal property loans secured by the home but not the land), which are exempt from the mandatory purchase requirement. As a result, NFIP take-up among manufactured homeowners is substantially lower than among site-built homeowners in comparable flood zones.

**Feedback**:
The institutional point is important, but the wording makes the chattel-loan channel sound categorical. The mandatory purchase requirement turns on federally regulated or federally connected lending and the covered security property, not simply on whether the financing is labeled chattel rather than mortgage. The paper can make the same substantive point more accurately: many manufactured-home chattel loans are outside the lending channels that trigger mandatory flood-insurance purchase, which can reduce mandatory-purchase exposure and NFIP take-up. Recast the sentence along those lines instead of saying chattel loans are exempt as a class.

---

### 10. Post-Reform Cohorts Are Reduced-Form Exposure Effects

**Status**: [Pending]

**Quote**:
> The coefficients $\beta_{k}$ capture the manufactured-home-specific vintage profile relative to the 1992 reference bin. Post-1994 coefficients are the treatment effects.
> 
> Identification relies on a parallel trends assumption in the vintage profile of outcomes between manufactured and site-built homes in the absence of the HUD code reform. In other words, homes built at different times may experience different levels of flood damage due to changes in construction quality, storm severity, or intra-county location, but these vintage effects should be the same for manufactured and site-built homes. I support this assumption by showing flat pre-trends in the event study specification across a broad range of claim-level and cell-level outcomes.
> 
> I expect the treatment effect to grow with later construction cohorts as compliance rates increase. Because of lags between production and installation, some units with post-1994 construction dates may have been manufactured before the regulation went into effect in July of 1994.

**Feedback**:
The text first labels post-1994 coefficients as treatment effects, then explains why construction vintage is an imperfect proxy for actual exposure to the rule. If some units in the early post-reform bins were produced before July 1994, the coefficient is a cohort contrast based on construction vintage, not the average effect of verified regulatory compliance. That is still useful, but it should be named accurately. Replace "Post-1994 coefficients are the treatment effects" with "Post-1994 coefficients are reduced-form cohort effects of exposure to the reform, with early post-reform bins potentially attenuated by production-installation lags and incomplete compliance."

---

### 11. Annual Price Data Cannot Identify Anticipation

**Status**: [Pending]

**Quote**:
> Prices diverge sharply in 1994, with treated states experiencing a $5000 increase that stabilizes by 1995 and persists through the end of the sample. The price effect is economically large, corresponding to an 13% increase in the price.
> 
> The immediacy of the effect is consistent with the regulation raising production costs: manufacturers anticipated the July 1994 effective date and adjusted pricing accordingly.

**Feedback**:
The annual event study can show that the break occurs in the implementation year. It cannot tell whether prices moved before the July 1994 effective date or after the rule began to bind, because the 1994 coefficient mixes both parts of the year. The behavioral claim about anticipation therefore goes beyond the timing evidence. A safer version would say: "The 1994 break is consistent with prices adjusting around the July 1994 effective date; with annual price data, the estimate does not by itself distinguish anticipatory pricing from pass-through after implementation."

---

### 12. Persistent Premium Does Not Identify The Cost Structure

**Status**: [Pending]

**Quote**:
> The immediacy of the effect is consistent with the regulation raising production costs: manufacturers anticipated the July 1994 effective date and adjusted pricing accordingly. The persistence of the premium through 2000 suggests that the regulation caused persistently higher variable costs rather than a one-time fixed cost to redesign models and re-arrange production lines.
> 
> Figure 3 shows the corresponding event study for log placements. There is no detectable effect on the quantity of manufactured homes shipped to treated states. The point estimates are small and imprecise, centered around zero, and statistically insignificant throughout the post-period. This null result on quantities, combined with the positive price effect, is consistent with two possibilities: either demand for MH is relatively inelastic, so that the price change had little effect on equilibrium quantities; or the demand curve simultaneously shifted outwards due to the increased value of the improved construction, offsetting the higher price.

**Feedback**:
A persistent price premium is consistent with higher marginal production costs, but it does not isolate that explanation. It could also reflect fixed redesign costs amortized over many units, quality upgrading, market power, or demand-side valuation of the improved construction. The next paragraph itself raises the possibility of a demand shift, which makes the variable-cost interpretation too sharp. Revise the sentence to say that the persistence of the premium shows the price gap was not a one-year implementation spike, while the source of that premium remains a supply-and-demand interpretation rather than something pinned down by the price path alone.

---

### 13. Null Placements Do Not Pin Down Demand Elasticity

**Status**: [Pending]

**Quote**:
> Figure 3 shows the corresponding event study for log placements. There is no detectable effect on the quantity of manufactured homes shipped to treated states. The point estimates are small and imprecise, centered around zero, and statistically insignificant throughout the post-period. This null result on quantities, combined with the positive price effect, is consistent with two possibilities: either demand for MH is relatively inelastic, so that the price change had little effect on equilibrium quantities; or the demand curve simultaneously shifted outwards due to the increased value of the improved construction, offsetting the higher price.

**Feedback**:
The placement result should be described as imprecise evidence on quantities, not as a basis for a demand-elasticity interpretation. In a standard supply-cost increase with unchanged downward-sloping demand, quantity would fall unless demand is very inelastic; with noisy estimates, a modest decline may simply be hard to detect. The text can still say the data do not show a large placement decline. But the inference should be softer: the estimates are consistent with a small decline in placements, relatively inelastic demand, or an outward demand shift from the improved construction.

---

### 14. Tract Controls Do Not Rule Out Within-Tract Exposure Differences

**Status**: [Pending]

**Quote**:
> Table 4 compares the two specifications. The tract-level estimates are very similar in magnitude to the county-level baseline, with modestly wider confidence intervals reflecting the smaller sample sizes within tracts. The agreement across geographic controls supports the identifying assumption that vintage effects are not confounded by within-county variation in flood exposure.

**Feedback**:
The robustness exercise is useful, but the final sentence overstates what tract-by-loss-period fixed effects can show. They remove average tract-level severity for a given flood period. They do not rule out within-tract differences such as manufactured homes being clustered in one park, newer units being placed on higher pads, or site-built homes occupying different parts of the same floodplain. Say instead that the estimates are not driven by exposure differences at the county-period level that are also captured by tract-period averages, while residual within-tract exposure differences by vintage and housing type remain possible.

---

### 15. Elevation Timing Needs To Be Tied To The Affected Cohorts

**Status**: [Pending]

**Quote**:
> The one composition shift that works in the direction of the main result is the elevated-building share, which rises by 5 percentage points for post-1998 construction vintages. Elevation is plausibly part of the treatment channel—the HUD Code encouraged improved siting and installation practices—rather than a confound. Primary-residence share is essentially unchanged across vintages.

**Feedback**:
The timing matters here. The reform is interpreted as affecting post-1994 construction cohorts, while the elevation increase described in this paragraph appears for post-1998 construction vintages. That means elevation may be part of the mechanism for later cohorts, but it cannot explain the earliest post-reform coefficients in the same way. The paragraph should say which estimates could be affected by elevation instead of treating it as a uniform channel for the entire post-1994 period.

---

### 16. Policy Panel Denominator Is Ambiguous In Zero-Claim Cells

**Status**: [Pending]

**Quote**:
> For the policy analysis, I construct a balanced panel at the county $\times$ loss-period $\times$ housing-type $\times$ construction-period level, including cells with zero claims. Each cell reports the total number of unique policies which were active at any time during the loss-period along with the average policy characteristics.

**Feedback**:
The phrase "including cells with zero claims" needs one more distinction. Cells with zero claims but positive active policies are well-defined: they have exposure but no realized claim. Cells with zero active policies are different; their claim rate denominator and average policy characteristics are undefined. This matters for the claim-rate calculation and for any weighted policy-characteristic regressions. Add a sentence stating whether zero-claim cells are retained only when at least one active policy exists, and how cells with zero active policies are treated in averages and exposure denominators.

---

### 17. Policy Tables Need A Clearly Defined Time Dimension

**Status**: [Pending]

**Quote**:
> Fixed-effects  |   |   |   |   |   |   |   |
> |  County-Loss period | Yes | Yes | Yes | Yes | Yes | Yes | Yes  |
> |  MH | Yes | Yes | Yes | Yes | Yes | Yes | Yes  |
> |  Fit statistics  |   |   |   |   |   |   |   |
> |  Observations | 65,145 | 65,145 | 65,145 | 65,145 | 65,145 | 65,145 | 65,145  |
> |  R2 | 0.43 | 0.55 | 0.73 | 0.91 | 0.90 | 0.79 | 0.72  |
> |  Dependent variable mean | 220.5 | 111.5 | 31.9 | 0.36 | 0.52 | 0.68 | 0.08  |
> 
> Clustered (County-Loss period) standard-errors in parentheses
> Signif. Codes: \*\*\*: 0.01, \*\*: 0.05, \*: 0.1
> Notes: Coefficients from Equation (2) estimated on the cell-level panel, with observations weighted by number of policies. Repl. cost, Bldg covg., and Contents covg. refer to the estimated replacement cost, building coverage amount, and contents coverage amount, respectively, and are reported in thousands of 2000 dollars. All other outcomes are fractions. Elevated indicates that the building satisfies the NFIP definition of an elevated building; SFHA indicates that the property is located in a Special Flood Hazard Area; Primary res. indicates that the home is a primary residence; and Mandatory indicates that flood insurance was required by the mortgage lender. Source: OpenFEMA policy data.

**Feedback**:
Table 3 uses policy characteristics, but the fixed-effect and clustering labels refer to "County-Loss period," a timing concept that is natural for claim records. If policy observations are organized by the same five-year periods used for losses, say that directly. If they are organized by policy year or calendar period, the table should use that label instead. This is not a cosmetic issue: the composition checks are used to evaluate selection, and readers need to know whether comparisons are being made across policy years, loss periods, construction-vintage cells, or some merged policy-claim structure. Rename the fixed effect and clustering unit to match the actual policy panel.

---

### 18. NFIP Take-Up Specification Inherits Undefined Loss-Period Notation

**Status**: [Pending]

**Quote**:
> Notes: Coefficients from Equation (2) estimated on the cell-level panel. Column (1) estimates a PPML model with total policies as the outcome. Source: OpenFEMA policy data.

**Feedback**:
The appendix says the policy-count PPML is estimated from Equation (2), but Equation (2) is written for claim-level outcomes with county-by-loss-period fixed effects. Total policies do not naturally have a loss period unless the policy panel has been assigned to the same period bins. The note should define the panel dimension explicitly. For example: "The policy panel is indexed by county, policy period, housing type, and construction-vintage bin; the specification replaces the county-by-loss-period fixed effects in Equation (2) with county-by-policy-period fixed effects." Without that clarification, the dependent-variable mean and identifying variation are hard to interpret.

---

### 19. Table 4 Omits The Clustering Level

**Status**: [Pending]

**Quote**:
> Table 4: Building Damage - Robustness
> 
> |  Model: | (1) | (2)  |
> | --- | --- | --- |
> |  Variables |  |   |
> |  MH ×νi=1986 | -2.3 | -1.6  |
> |   | (2.2) | (2.2)  |
> |  MH ×νi=1988 | 0.67 | 1.6  |
> |   | (1.5) | (2.3)  |
> |  MH ×νi=1990 | -1.8 | -0.72  |
> |   | (1.5) | (2.4)  |
> |  MH ×νi=1994 | -4.2*** | -2.9  |
> |   | (1.3) | (1.9)  |
> |  MH ×νi=1996 | -4.6*** | -3.2  |
> |   | (1.5) | (2.0)  |
> |  MH ×νi=1998 | -5.5*** | -3.4*  |
> |   | (1.7) | (1.9)  |
> |  Fixed-effects |  |   |
> |  County-Loss period | Yes |   |
> |  MH | Yes | Yes  |
> |  Census tract-Loss period |  | Yes  |
> |  Fit statistics |  |   |
> |  Observations | 192,779 | 192,779  |
> |  R2 | 0.13 | 0.20  |
> 
> Signif. Codes: \*\*\*: 0.01, \*\*: 0.05, \*: 0.1
> Notes: Coefficients from Equation (2) estimated on claim-level data. Column (1) uses county  $\times$  loss-period fixed effects (baseline). Column (2) replaces county with census tract  $\times$  loss-period fixed effects. Building damage values are in thousands of 2000 dollars. Source: OpenFEMA claims data.

**Feedback**:
Table 4 reports standard errors and significance stars but does not state the clustering level. That omission matters because the table's purpose is to compare inference under finer geography. Clustering at county-by-loss-period and clustering at tract-by-loss-period answer different dependence questions, especially once the fixed effect changes in column (2). Add a line such as "Clustered [specific unit] standard errors in parentheses" before the significance codes.

---

### 20. Reference Year Should Be Omitted In The Price Event Study

**Status**: [Pending]

**Quote**:
> $\log(P_{st})=\alpha_{s}+\gamma_{t}+\sum_{k}\beta_{k}(\mathbf{1}[\text{year}=k]\times\text{Treated}_{s})+\varepsilon_{st}$ (1)
> 
> where $P_{st}$ is the average real sales price of manufactured homes in state $s$ in year $t$, $\alpha_{s}$ and $\gamma_{t}$ are state and year fixed effects, and $\text{Treated}_{s}$ indicates states containing wind zones II or III. The coefficients $\beta_{k}$ trace out the price difference between treated and control states relative to the reference year 1993.

**Feedback**:
The text says the coefficients are relative to 1993, but the equation does not show the omitted interaction. With state fixed effects, the full set of treated-by-year interactions is collinear with the time-invariant treated-state indicator. Write the summation as $\sum_{k\ne 1993}\beta_k(\mathbf{1}[\text{year}=k]\times\text{Treated}_s)$, or otherwise state the normalization. This is a small notation fix, but it prevents confusion about how the event study is estimated.

---

### 21. Damage-Share Effects Are Percentage Points, Not Percent

**Status**: [Pending]

**Quote**:
> Table 2 presents supplementary outcomes on insurance payments and damage to the building’s contents. Column (3) shows effects on building damage as a share of its assessed value. Conditional on filing a claim, post-1994 manufactured homes tend to experience damage that is between 6% and 9% less as a proportion of their value than site-built homes of the same vintage. While the HUD wind standard raised prices, it decreased both absolute and relative flood damages. Contents damage and payments decline by roughly $2,000 and $1,000, respectively, consistent with improved the structural integrity.

**Feedback**:
Column (3) is reported as damage as a percentage of assessed value, so coefficients around -6 to -9 are percentage-point changes in the damage-to-value ratio, not percent changes. Those are different magnitudes. If the comparison group's damage share were 30 percent, a 6 percentage-point decline would be a 20 percent relative decline. Revise the sentence to say "6 to 9 percentage points lower as a share of assessed value."

---

### 22. Table 1 Damage Units Are Mislabeled

**Status**: [Pending]

**Quote**:
> |  Claim outcomes (1994–2023)  |   |   |
> |  Total claims | 6,167 | 250,677  |
> |  Building damage ($) | 13 | 40  |
> |  Contents damage ($) | 6 | 20  |
> 
> Notes: Summary statistics for the NFIP data by housing type. Panel A reports policy-level outcomes from the balanced panel (2009-2023), which covers policy years for homes with construction years 1986-1999; share variables (elevated building, SFHA, primary residence, mandatory purchase) and claim rate are weighted means using the number of policies as weights. Claim rate is the number of claims per policy-year. Panel B reports claim-level means from the full claims sample (1994-2023), restricted to the same construction year range. All nominal values are deflated to constant (2000) dollars. Source: FEMA OpenFEMA claims and policy data.

**Feedback**:
The entries appear to be in thousands of dollars, not dollars. Table 2 reports a dependent-variable mean of 39.3 for building damage and explicitly says those values are in thousands of 2000 dollars, which matches the site-built mean of 40 in Table 1. If Table 1 were literally in dollars, the mean building damage per site-built claim would be $40. Relabel the rows as "Building damage ($000s)" and "Contents damage ($000s)," and add to the notes that claim damage outcomes are reported in thousands of 2000 dollars.

---

### 23. Theory Prediction About Insurance Demand Is Too Strong

**Status**: [Pending]

**Quote**:
> The damage estimates in the main text condition on filing a claim and do not speak to whether the HUD code reform affected NFIP take-up. Standard theory predicts that self-protection and insurance are substitutes: households facing lower expected losses should demand less coverage (Ehrlich and Becker, 1972). This appendix examines whether the reform affected the number of NFIP policies held by manufactured homeowners.

**Feedback**:
The motivation for the appendix is useful, but the theoretical statement is too general. Lower expected losses from self-protection can reduce the value of insurance when coverage is costly, but the sign depends on loading, mandatory purchase rules, borrowing constraints, basis risk, and the insurance contract. With actuarially fair full insurance, for example, lower loss probability does not by itself imply lower optimal coverage. A more careful version would be: "In standard models, self-protection can reduce the private value of insurance when coverage is costly, so the reform could in principle lower voluntary NFIP demand."

---
