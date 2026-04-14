---
title: The Returns to Climate Adaptation in Manufactured Housing
bibliography: manufactured-code.bib
author:
- name: Colin Williams
  affiliation: University of Virginia
  email: chv7bg@virginia.edu
date: \today
abstract: "Does mandated climate adaptation pay for itself? I study the 1994 HUD wind standard reform, which required structural upgrades to manufactured homes in hurricane-prone areas. Using claim and policy data from the National Flood Insurance Program (NFIP), I compare flood damage to manufactured and site-built homes of different construction vintages exposed to floods in the same Census tract and over the same period. Post-1994 manufactured homes experience roughly \\$5,000 lower building damage payments per claim relative to site-built homes. These reductions represent a spillover benefit: the regulation targeted wind resilience, not flooding. Contrary to economic theory, which suggests that prevention and insurance are substitutes, I also find substantial increases in flood insurance take-up, suggesting that the HUD code reform made it less costly for homeowners to comply with NFIP eligibility rules, such as anchoring and elevation standards. On the cost side, the reform raised manufactured home prices by about 14\\% (\\$4,000) in treated states. A back-of-envelope calculation suggests the flood channel alone recovers a substantial share of the upfront cost, and the total return---including wind damage, displacement, and the value of eligibility for federal flood insurance---is likely higher. For the 22 million Americans living in manufactured homes, many of whom are low-income and lack disaster insurance, the HUD standard lower risk and unlocks access to insurance markets that would otherwise be unavailable."
header-includes:
- \usepackage{lscape}
...

# Introduction

The U.S. experienced over 100 billion-dollar climate disasters over the five years before 2026, incurring damages of over \$600 billion dollars[^billion-dollar]. 

[^billion-dollar]: Climate Central. “U.S. Billion-Dollar Weather and Climate Disasters.” ClimateCentral.Org, 2026. \href{https://www.climatecentral.org/climate-services/billion-dollar-disasters/summary-stats}{https://www.climatecentral.org/climate-services/billion-dollar-disasters/summary-stats}.

This paper asks whether mandated adaptation investment pays for itself. The answer depends on the cost of compliance, in the form of additional construction costs; and the benefits, both directly in reduced disaster damage and indirectly through the self-insurance value of adaptation and eligibility for federal insurance. I estimate both.


Manufactured housing is the largest source of unsubsidized affordable housing in the United States. Approximately 22 million people live in manufactured homes, which account for roughly 10% of the housing stock and a much larger share in rural areas and the Southeast.[^mh-stats] These homes are disproportionately occupied by low-income households, and they are disproportionately exposed to natural disaster risk. Hurricane Andrew in 1992 destroyed 97% of manufactured homes in its path in Dade County, Florida, compared to 11% of site-built homes.

[^mh-stats]: Census Bureau, American Housing Survey. Manufactured homes are built in a factory and transported to a site, as distinct from site-built (stick-built) homes constructed on location.

The vulnerability of manufactured homes to extreme weather prompted a major regulatory response. In 1994, HUD revised the Manufactured Home Construction and Safety Standards---the federal building code governing all factory-built housing---to impose wind resistance requirements. The reform created a three-zone wind classification system (70, 100, and 110 mph design wind loads) and required structural upgrades including steel strapping, upgraded sheathing fastening, and impact-rated windows for homes sited in high-wind zones. Unlike local building codes for site-built homes, the HUD Code is a federal minimum standard that preempts state and local regulation.



On the cost side, I use the Census Bureau's Manufactured Housing Survey to estimate a difference-in-differences comparing manufactured home prices in states with HUD wind zones II and III (treated) to zone I states (control), before and after 1994. Prices in treated states rose 10--14% relative to controls, an increase of roughly \$4--5,000 on a base price of approximately \$45,000 (in 2000 dollars). The effect appears immediately in 1994 and persists through the end of the sample in 2000. There is no detectable effect on placements, though point estimates are imprecise. Taking the point estimates at face value, a price increase with no change in quantity is consistent with a world where households value the HUD-mandated improvements roughly at cost.

On the benefit side, I use NFIP flood insurance claims data to estimate the effect of the HUD standard on flood damage. The identification strategy exploits two sources of variation: manufactured versus site-built housing (only manufactured homes were subject to the HUD Code change), and post-1994 versus pre-1994 construction vintage (within a flood event, newer manufactured homes were built to the upgraded standard while older ones were not). Tract-by-loss-period fixed effects ensure comparisons are made only between homes exposed to the same flood in the same location. This is a double-difference in vintage and housing type: the site-built comparison group absorbs secular changes in construction quality and storm severity, isolating the manufactured-home-specific break at 1994.

Post-1994 manufactured homes experience \$4--7,000 lower net building payments per claim relative to pre-1994 manufactured homes, compared to the same vintage difference for site-built homes. The event study shows flat pre-trends and a sharp break at 1994 that grows with later construction cohorts, consistent with increasing compliance and refinement of building techniques. Contents payments decline by \$1--2,000 per claim. The difference-in-discontinuities estimate---which controls for smooth vintage trends via piecewise-linear polynomials in construction year---confirms a discrete manufactured-home-specific jump at 1994. Site-built homes show no comparable discontinuity.

These flood damage reductions are a spillover benefit. The HUD standard targeted wind resilience, not flood protection. If even the unintended channel generates savings of this magnitude, the total return---including the targeted wind damage channel, reduced displacement, and avoided uninsured losses---is likely substantially larger.

A back-of-envelope cost-benefit calculation illustrates the magnitudes. At a baseline annual flood claim probability for manufactured homes of roughly 1--2%, the expected present value of damage reduction over a 30-year home lifespan is on the order of \$1,500--4,000---a substantial fraction of the \$4--5,000 price premium, from the flood channel alone. This calculation understates the benefit because it excludes wind damage (the targeted channel), avoided displacement costs, reduced FEMA disaster assistance outlays, and the insurance value of damage reduction for credit-constrained households who cannot smooth consumption after catastrophic loss.

The welfare case for the HUD standard does not require the cost-benefit ratio to exceed one in expectation. Manufactured home residents are disproportionately low-income and credit-constrained. For these households, the certainty-equivalent value of avoiding catastrophic loss exceeds the expected value of damage reduction. The HUD standard functions as built-in catastrophe insurance: an upfront premium (higher purchase price) that pays out automatically (the home survives the storm) without annual premiums, take-up friction, or moral hazard. Low NFIP take-up among manufactured homeowners---who often hold chattel loans exempt from mandatory flood insurance purchase requirements---means that private insurance markets provide limited protection to this population. The regulation substitutes for a market that largely does not reach them.

This paper contributes to several literatures. First, it provides direct evidence on the returns to building code regulation for disaster resilience. @simmons_economic_2018 and @dehring_coastal_2013 study whether building code reforms in Florida for site-built homes improved resilience to hurricanes and find conflicting results... For manufactured housing, my result support a body of descriptive work examining the 1994 HUD code reform [@simmons_manufactured_2008; @kevin_r_grosskopf_manufactured_2005].

Methodologically, @baylis_mandated_2021 implement a similar study of wildfire building codes in California and find large benefits to mandatory adaptation, with fiscal spillovers and insurance value potentially justifying tighter building codes even in areas with moderate wildfire risk. This paper improves on their empirical strategy by exploiting the fact that manufactured homes are regulated federally, allowing me to disentangle building code reforms from general vintage effects. Specifically, I compare site-built and manufactured homes in the same area, exposed to the same floods, and built in the same year. My design builds on the across-vintage methodology used in the economics literature to study building codes more broadly [@jacobsen_are_2013; levinson_how_2016] and can be applied to any context where different housing types are subject to different regulatory bodies.

The remainder of the paper is organized as follows. Section 2 describes the institutional background and the 1994 HUD Code reform. Section 3 describes the data. Section 4 presents the empirical strategy. Section 5 reports the results. Section 6 discusses the cost-benefit implications and welfare interpretation. Section 7 concludes.


# Institutional Background

## Manufactured Housing and the HUD Code

Manufactured homes---factory-built structures transported to a home site on a permanent chassis---are regulated under the National Manufactured Housing Construction and Safety Standards Act of 1974. This law established the HUD Code, a federal construction standard that preempts all state and local building codes for manufactured housing. The HUD Code governs structural design, fire safety, energy efficiency, and installation requirements for every manufactured home sold in the United States.

The preemption of local codes is a distinctive feature of the manufactured housing market. Site-built homes are subject to state and local building codes, which vary substantially across jurisdictions and are enforced through local permitting and inspection processes. Manufactured homes, by contrast, must meet a single federal standard regardless of where they are sited. This institutional feature is central to the identification strategy: the 1994 reform applied uniformly to all manufactured homes nationwide, while leaving site-built homes unaffected.

## Hurricane Andrew and the 1994 Wind Standard Reform

Hurricane Andrew struck southern Florida on August 24, 1992, causing over \$27 billion in damage (1992 dollars). The storm exposed the extreme vulnerability of manufactured homes: 97% of manufactured homes in its direct path were destroyed, compared to 11% of site-built homes. The disparity prompted congressional hearings and an accelerated regulatory response from HUD [CITE FLORIDA CASE].

In 1994, HUD revised the wind resistance provisions of the HUD Code, effective for all homes manufactured after July 13, 1994. The reform established a three-zone wind map. Wind Zone I, with 70 mph design wind speed, is composed of interior states with low hurricane risk. Zones II and II, with 100 and 110 mph design wind speeds, respectively, cover coastal states with moderate to high hurricane exposure, including much of Florida and the Gulf Coast. 

The new standards required structural upgrades for homes destined for Zones II and III, including steel tie-down strapping, reinforced roof-to-wall connections, upgraded sheathing fastening schedules, and impact-resistant windows and doors in Zone III. These requirements added material and engineering costs to the production process. Manufacturers were required to label each home with its designated wind zone, and homes could not be sited in a zone exceeding their rated capacity.

The reform's timing and structure create useful variation for identification. The July 1994 effective date means that homes manufactured before mid-1994 were built to the old standard and homes manufactured after were built to the new one, though pipeline inventory means some 1994--1995 vintage homes may reflect the old standard. The spatial variation in treatment intensity (Zone I homes required minimal changes) supports the price analysis, while the vintage variation (pre- vs. post-1994 construction) supports the NFIP damage analysis.

## NFIP and Flood Insurance for Manufactured Homes

The National Flood Insurance Program provides federally backed flood insurance to property owners in participating communities. Flood insurance is mandatory for properties with federally backed mortgages in FEMA-designated Special Flood Hazard Areas (SFHAs). However, manufactured homes are frequently financed with chattel loans (personal property loans secured by the home but not the land), which are exempt from the mandatory purchase requirement. As a result, NFIP take-up among manufactured homeowners is lower than among site-built homeowners in comparable flood zones.

The NFIP data used in this paper record claims and policy information at the individual level, including a field identifying manufactured homes (floor count = 5). This allows direct comparison of flood damage outcomes between manufactured and site-built homes conditional on holding NFIP coverage. The selection into flood insurance coverage is a potential concern that I address through composition checks on the insured population.


# Data

## Cost Side: Manufactured Housing Survey

I estimate the price and quantity effects using a state-by-year panel from the Census Bureau's Manufactured Housing Survey (MHS), which reports average sales prices and placement counts by state. I focus on the period immediately around the HUD code change, 1988 - 1999. The treatment group consists of states containing HUD wind zones II or III; the control group is zone I states (see Figure \ref{map:treated-states}). I exclude Alaska and Hawaii.

## Benefit Side: NFIP Claims and Policies

The benefit-side analysis uses two datasets from FEMA's OpenFEMA platform: individual flood insurance claims and policy records. Claims data record the date of loss, construction year, building and contents damage amounts, NFIP payments, property characteristics, and census tract. Policy data record coverage amounts, premium, property characteristics, and flood zone designation. Both datasets include a field identifying manufactured homes.

I restrict the sample to homes with construction years between 1985 and 2000 and loss dates from 1994 onward. Construction years are binned into two-year periods anchored so that 1992--1993 is the last pre-treatment bin. Loss years are binned into five-year periods. For the cell-level analysis (claim rates, policy composition), I construct a balanced panel at the tract $\times$ loss-period $\times$ housing-type $\times$ construction-period level, including cells with zero claims.

### Final Sample

All nominal values are deflated to constant (2000) dollars using the CPI-U.

Table \ref{tab:sumstats-nfip} reports summary statistics for the NFIP data by construction vintage and housing type.


# Empirical Strategy

## Cost Estimation

I estimate the effect of the 1994 HUD standard on manufactured home prices using a two-way fixed effects event study:

\begin{equation}
\log(P_{st}) = \alpha_s + \gamma_t + \sum_k \beta_k (\mathbf{1}[\text{year} = k] \times \text{Treated}_s) + \varepsilon_{st}
\label{eq:event-study-cost}
\end{equation}

where $P_{st}$ is the average real sales price of manufactured homes in state $s$ in year $t$, $\alpha_s$ and $\gamma_t$ are state and year fixed effects, and $\text{Treated}_s$ indicates states containing wind zones II or III. The coefficients $\beta_k$ trace out the price difference between treated and control states relative to the reference year 1993. Standard errors are clustered by state.

## Benefit Estimation: Event Study

The primary benefit-side specification is an event study that imposes no functional form on the vintage profile:

\begin{equation}
Y_{it} = \alpha_{c(i),t} + \delta_m + \sum_k \beta_k (\mathbf{1}[\nu_i = k] \times \text{MH}_i) + \varepsilon_{it}
\label{eq:event-study-benefit}
\end{equation}

where $Y_{it}$ is the outcome for claim $i$ (e.g., building damage), $\alpha_{c(i),t}$ is a tract $\times$ loss-period fixed effect absorbing location-specific storm severity, $\delta_m$ is a manufactured housing indicator absorbing time-invariant differences between housing types, $\text{MH}_i$ is an indicator for manufactured homes, and $\nu_i$ is the construction vintage bin of home $i$. The coefficients $\beta_k$ capture the manufactured-home-specific vintage profile relative to the 1992 reference bin. Post-1994 coefficients are the treatment effects.

For cell-level outcomes (claims per policy, policy composition variables), regressions are weighted by the number of policies in the cell.

A break at 1994 with slightly larger effects for later cohorts is consistent with delayed compliance, as some units produced prior to the change may have waited at dealers before being installed on a site., as later cohorts had more time for full compliance and refinement of construction techniques.

# Results

## Cost Side: Manufactured Home Prices

Figure \ref{fig:es-price} presents the event study for log manufactured home prices. Prior to 1994, treated and control states follow parallel trends: the pre-treatment coefficients are small, precisely estimated, and statistically indistinguishable from zero. Prices diverge sharply in 1994, with treated states experiencing a 10--14 log-point increase that stabilizes by 1995 and persists through the end of the sample in 2000. In dollar terms, the price effect corresponds to roughly \$4--5,000 on a base price of approximately \$45,000 (2000 dollars).

The immediacy of the effect is consistent with the regulation raising production costs: manufacturers anticipated the July 1994 effective date and adjusted pricing accordingly. The persistence of the premium through 2000 suggests that the cost increase was not a temporary adjustment but reflected genuine ongoing compliance costs.

Figure \ref{fig:es-placements} shows the corresponding event study for log placements. There is no detectable effect on the quantity of manufactured homes shipped to treated states. The point estimates are small and imprecise, centered around zero, and statistically insignificant throughout the post-period. This null result on quantities, combined with the positive price effect, is consistent with a supply-side cost shock that was small enough relative to demand elasticity to be absorbed primarily through higher prices rather than reduced quantities.

## Benefit Side: Flood Damage

### Building Damage

Figure \ref{fig:es-building-damage} presents the main result: the event study for net building payment per claim. Pre-1994 construction-period coefficients are flat and close to zero, confirming parallel vintage trends between manufactured and site-built homes before the HUD standard took effect. Beginning with the 1994 construction cohort, manufactured homes experience sharply lower building payments relative to site-built homes. The effect grows with later construction cohorts, reaching approximately \$9,000 per claim for the 2000 vintage bin.

The growing magnitude across post-treatment cohorts is consistent with several mechanisms: increasing compliance as pipeline inventory cleared, refinement of construction techniques by manufacturers, and additional HUD Code updates that further strengthened standards in subsequent years. The pattern is not consistent with a simple age-depreciation story, which would predict a smooth gradient rather than a discrete break at 1994.

### Contents Damage and Claim Rates

Net contents payments per claim also decline for post-1994 manufactured homes, by approximately \$1--2,000 relative to the pre-1994 baseline. This effect is consistent with improved structural integrity reducing water intrusion and interior damage during flood events, though it is less precisely estimated than the building payment result.

Claims per policy---the extensive margin of flood damage---show a small negative effect for post-1994 manufactured homes, on the order of 0.001 fewer claims per policy. This estimate is not statistically significant at conventional levels, reflecting the noisiness of the extensive margin in a relatively small manufactured home sample. The direction is consistent with improved construction reducing the probability of a flood event generating a compensable claim, but the intensive margin (damage per claim) is the dominant channel.

## Selection and Composition

A concern with the vintage-based design is that post-1994 manufactured home policyholders may differ systematically from pre-1994 policyholders, and that these compositional differences rather than construction quality drive the damage results. Table \ref{tab:composition} reports the full set of policy composition event studies.

The composition shifts work against the main result. Relative to pre-1994 manufactured homes, post-1994 manufactured home policies have higher replacement cost (\$66--102,000), higher building coverage (\$4--14,000 per policy), and higher contents coverage (\$1.5--2.8,000 per policy). Post-1994 manufactured homes are also more concentrated in SFHAs (2--5 percentage points higher) and more likely to face mandatory purchase requirements (1 percentage point higher). These shifts would all tend to increase expected NFIP payments, not lower them, making the damage reduction estimates conservative.

The one composition shift that works in the direction of the main result is the elevated-building share, which rises by 5 percentage points for post-1998 construction vintages. Elevation is plausibly part of the treatment channel---the HUD Code encouraged improved siting and installation practices---rather than a confound. Primary-residence share is essentially unchanged across vintages.


# Discussion

## Cost-Benefit

The cost and benefit estimates can be combined in a back-of-envelope calculation. The per-unit compliance cost is approximately \$4--5,000, paid once at purchase. The per-event damage reduction is \$4--7,000 in building payments and \$1--2,000 in contents payments, for a total of roughly \$5--9,000 per flood event.

The expected benefit depends on the probability of experiencing a flood. Among manufactured homes in the NFIP data, the baseline claim rate is approximately 0.01--0.02 claims per policy-year. Over a 30-year home lifespan (a conservative estimate for manufactured homes), the expected number of flood events is 0.3--0.6. At \$5--9,000 per event, the expected present value of flood damage reduction is roughly \$1,500--4,000 (undiscounted) or \$1,000--3,000 at a 3% discount rate.

This calculation implies the flood channel alone recovers roughly 25--75% of the upfront compliance cost. Several factors make this a lower bound on the total return:

The HUD standard targeted wind resilience, not flood protection. The flood damage reductions estimated here are a spillover benefit. The targeted wind damage channel---reduced structural failure during hurricanes---likely generates larger savings, but I cannot estimate it with NFIP data alone.

NFIP payments are capped by coverage limits and subject to deductibles. Total economic losses from flood events exceed insured losses, particularly for manufactured homeowners with low coverage or no coverage at all.

Manufactured homes that sustain severe damage often become uninhabitable, forcing residents into temporary housing or permanent displacement. Reduced damage from improved construction standards avoids these costs, which are borne primarily by residents and FEMA disaster assistance programs.

When manufactured homes are destroyed in presidentially declared disasters, FEMA's Individual Assistance program provides grants for temporary housing and home repair. Reduced damage to post-1994 manufactured homes likely reduces these federal outlays, though I do not estimate this channel directly.

## Welfare Interpretation

The expected cost-benefit ratio need not exceed one for the regulation to be welfare-improving. The relevant comparison is between the upfront cost (\$4--5,000) and the willingness-to-pay for damage reduction, which exceeds the expected value for risk-averse, credit-constrained households.

Manufactured home residents have median household incomes roughly half the national median and limited access to credit markets. For these households, a \$10,000 uninsured flood loss can trigger cascading financial consequences---lost housing, depleted savings, disrupted employment---that far exceed the direct property damage. The certainty-equivalent value of avoiding catastrophic loss is substantially higher than the expected value, particularly for households near subsistence.

The HUD standard functions as built-in catastrophe insurance with several advantages over market insurance. The "premium" is embedded in the purchase price and paid once, eliminating annual renewal decisions, lapse risk, and the take-up friction that depresses NFIP enrollment among manufactured homeowners. The "payout" is automatic---the home survives the storm---requiring no claims process. And the mechanism is free of moral hazard: a more durable home does not induce riskier behavior in the way that insurance coverage can.

## Threats to Identification

The primary threat to the vintage-based identification is the age-vintage confound: pre-1994 homes are mechanically older at the time of any storm, and may perform worse due to depreciation or material deterioration rather than the absence of the HUD Code improvements. Several pieces of evidence mitigate this concern.

First, the site-built comparison group shows no vintage break at 1994. If depreciation or age-related deterioration were driving the manufactured home results, we would expect a similar vintage gradient for site-built homes. The difference-in-discontinuities plots (Figure \ref{fig:rd-building-damage}) show a flat vintage profile for site-built homes, with the break appearing only for manufactured homes.

Second, the difference-in-discontinuities specification controls for smooth vintage trends via piecewise-linear polynomials in construction year, estimated separately by housing type. The treatment effect is identified from the discrete jump at 1994 net of these trends, which is difficult to reconcile with a smooth depreciation process.

Third, the timing and shape of the event study are consistent with the regulation and inconsistent with gradual aging. The break occurs precisely at the 1994 regulatory threshold, is initially modest (consistent with pipeline inventory diluting the first post-treatment cohort), and grows for later cohorts as compliance becomes complete. A depreciation story would predict a smooth gradient across all vintages, not a discrete jump at the regulatory cutoff.


# Conclusion

The 1994 HUD wind standard reform raised manufactured home prices by roughly \$4--5,000 and reduced flood damage payments by \$4--9,000 per claim, with the latter representing only the unintended flood spillover from a regulation targeting wind resilience. Even through this single channel, the expected damage reduction recovers a substantial share of the compliance cost over a home's lifespan.

For the 22 million Americans living in manufactured homes---disproportionately low-income, credit-constrained, and underinsured---these findings have direct policy relevance. The HUD standard provides catastrophe protection to a population that private insurance markets largely fail to reach. As climate change intensifies hurricane and flood risk, the returns to mandated adaptation investment in this housing sector are likely growing. The results suggest that building code reform is a cost-effective tool for protecting vulnerable populations from disaster losses, with benefits that extend well beyond the targeted hazard.

\clearpage

# Tables and Figures

\begin{figure}[htbp]
  \centering
  \caption{States Treated by the 1994 HUD Wind Standard}\label{fig:map-treated-states}
  \includegraphics[width=\textwidth]{output/descriptives/map-mhs-treated-states.pdf}
  \begin{flushleft}
  \begin{footnotesize}
  Notes: Treated states are those with any overlap with HUD wind zones II or III. Control states are wind zone I states. Alaska and Hawaii are excluded. Source: Census Bureau Manufactured Housing Survey and Census TIGER/Line state shapefiles.
  \end{footnotesize}
  \end{flushleft}
\end{figure}

\begin{table}[htbp]
  \centering
  \caption{NFIP Outcomes by Construction Vintage and Housing Type}\label{tab:sumstats-nfip}
  \begin{threeparttable}
    \input{output/descriptives/sumstats-nfip.tex}
    \begin{tablenotes}
      \item Notes: Cell-level weighted means from the NFIP balanced panel. Average building and contents payments are weighted by the number of claims; share variables (elevated building, SFHA, primary residence, mandatory purchase) are weighted by the number of policies. Construction vintage is classified as pre- or post-1994 relative to the HUD wind standard reform effective date. Sample restricted to homes with construction years 1986--1999 and loss years from 1994 onward. Source: FEMA OpenFEMA claims and policy data.
    \end{tablenotes}
  \end{threeparttable}
\end{table}


\begin{figure}[htbp]
  \centering
  \caption{Effect of 1994 HUD Wind Standard on Manufactured Home Prices}\label{fig:es-price}
  \includegraphics[width=\textwidth]{output/event-study/es-mhs-avg_sales_price.pdf}
  \begin{flushleft}
  \begin{footnotesize}
  Notes: Figure plots event-study coefficients from Equation \eqref{eq:event-study-cost}. Source: Census Bureau Manufactured Housing Survey.
  \end{footnotesize}
  \end{flushleft}
\end{figure}

\begin{figure}[htbp]
  \centering
  \caption{Effect of 1994 HUD Wind Standard on Manufactured Home Placements}\label{fig:es-placements}
  \includegraphics[width=\textwidth]{output/event-study/es-mhs-placements_ln.pdf}
  \begin{flushleft}
  \begin{footnotesize}
  Notes: Figure plots event-study coefficients from Equation \eqref{eq:event-study-cost}. Outcome is log placements (number of manufactured homes shipped to state).
  \end{footnotesize}
  \end{flushleft}
\end{figure}

\begin{figure}[htbp]
  \centering
  \caption{Effect of 1994 HUD Standards on Net Building Payment per Claim}\label{fig:es-building-damage}
  \includegraphics[width=\textwidth]{output/event-study/countyfp/es-building-damage.pdf}
  \begin{flushleft}
  \begin{footnotesize}
  Notes: Figure plots event-study coefficients from Equation \eqref{eq:event-study-benefit}.
  \end{footnotesize}
  \end{flushleft}
\end{figure}

\begin{figure}[htbp]
  \centering
  \caption{Effect of 1994 HUD Standards on Policies}\label{fig:es-policies}
  \includegraphics[width=\textwidth]{output/event-study/countyfp/es-policies.pdf}
  \begin{flushleft}
  \begin{footnotesize}
  Notes: Figure plots event-study coefficients from Equation \eqref{eq:event-study-benefit}.
  \end{footnotesize}
  \end{flushleft}
\end{figure}

\begin{landscape}
\begin{table}[htbp]
  \centering
  \caption{Policy Composition Event Studies}\label{tab:composition}
  \begin{threeparttable}
    \input{output/event-study/countyfp/policy-composition.tex}
    \begin{tablenotes}
      \item Notes: Coefficients from Equation \eqref{eq:event-study-benefit} estimated on the cell-level panel, with observations weighted by number of policies. \emph{Repl. cost}, \emph{Bldg covg.}, and \emph{Contents covg.} refer to the estimated replacement cost, building coverage amount, and contents coverage amount, respectively, and are reported in thousands of 2000 dollars. All other outcomes are fractions. \emph{Elevated} indicates that the building satisfies the NFIP definition of an elevated building; \emph{SFHA} indicates that the property is located in a Special Flood Hazard Area; \emph{Primary res.} indicates that the home is a primary residence; and \emph{Mandatory} indicates that flood insurance was required by the mortgage lender.  Source: FEMA OpenFEMA policy data.
    \end{tablenotes}
  \end{threeparttable}
\end{table}
\end{landscape}

\clearpage

# References
