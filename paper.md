---
title: The Returns to Climate Adaptation in Manufactured Housing
bibliography: manufactured-code.bib
author:
- name: Colin Williams
  affiliation: University of Virginia
  email: chv7bg@virginia.edu
date: \today
abstract: "Does mandated climate adaptation pay for itself? I study the 1994 HUD wind standard reform, which required structural upgrades to manufactured homes in hurricane-prone areas. Using claim and policy data from the National Flood Insurance Program (NFIP), I compare flood damage to manufactured and site-built homes of different construction vintages exposed to floods in the same county and over the same period. Manufactured homes built after 1994 experience almost \\$6,000 lower building damage payments per claim relative to site-built homes of the same vintage. On the cost side, the reform raised manufactured home prices by about \\$5,000 in treated states. A back-of-envelope calculation suggests the flood channel alone recovers a substantial share of the upfront cost, and the total return---including wind damage and displacement costs---is likely higher. For the 22 million Americans living in manufactured homes, many of whom are low-income and lack disaster insurance, the HUD standard functions as built-in catastrophe insurance: it reduces risk automatically, without requiring annual premium payments, claims filing, or compliance with eligibility rules that many manufactured homeowners cannot meet."
header-includes:
- \usepackage{lscape}
...

# Introduction

The U.S. experienced over 100 billion-dollar climate disasters over the five years before 2026, incurring damages of over \$600 billion dollars.[^billion-dollar] These costs are projected to grow substantially as climate change intensifies extreme weather events. Building codes and other forms of mandated adaptation investment are a potential policy tool for reducing disaster losses and risk, but the returns to these investments are not well understood, and they may have indirect effects on household's exposure to climate risk by interacting with insurance markets. This paper provides new evidence on the costs and benefits of mandated adaptation in the context of manufactured housing (MH), a sector that is both highly vulnerable to climate risk and largely -- though not entirely -- uninsured.[^mh]

[^billion-dollar]: Climate Central. “U.S. Billion-Dollar Weather and Climate Disasters.” ClimateCentral.Org, 2026. \href{https://www.climatecentral.org/climate-services/billion-dollar-disasters/summary-stats}{https://www.climatecentral.org/climate-services/billion-dollar-disasters/summary-stats}.

[^mh]: "Manufactured homes" are the preferred industry term and refer specifically to mobile homes that satisfy the 1976 HUD Code. As the vast majority of mobile homes produced since 1976 satisfy the code, I use the terms "manufactured" and "mobile" interchangeably.

Government mandates for costly adaptation may be justified if private take-up is hindered by frictions. For instance, households may misperceive climate risk [@bakkensen_going_2022; @gallagher_learning_2014]. They may fail to internalize benefits to their neighbors [@baylis_mandated_2021]. They may enjoy limited upside from adaptation if mitigation behaviors are not reflected in insurance premiums [@wagner_adaptation_2022]. Finally, they may rely on public insurance programs and disaster relief instead [@deryugina_fiscal_2017; @baylis_moral_2019].

I estimate both the direct cost of compliance, in the form of additional construction costs; and the direct benefits, in reduced disaster damage. I then calibrate the self-insurance value of adaptation under a range of assumptions about risk preferences. My results suggest that the returns to mandated adaptation are likely positive, even through the single channel of flood damage reduction, and that the self-insurance value of the regulation is substantial for low-income households who do not purchase insurance against catastrophic loss.

On the cost side, I use the Census Bureau's Manufactured Housing Survey to estimate a difference-in-differences comparing manufactured home prices in states with HUD wind zones II and III (treated) to zone I states (control), before and after 1994. Prices in treated states rose by \$5000, an increase of roughly 13% on an average of $38,500 in treated states. There is no detectable effect on placements, though point estimates are imprecise. Taking the point estimates at face value, a price increase with no change in quantity is consistent with a world where households value the HUD-mandated improvements roughly at cost.

On the benefit side, I use flood insurance claim and policy data from the National Flood Insurance Program (NFIP) to estimate the effect of the HUD standard on flood damage. My identification strategy exploits two sources of variation: MH versus site-built housing, and post-1994 versus pre-1994 construction vintage. Tract by flood-loss-period fixed effects ensure comparisons are made only between homes exposed to the same floods in the same location. This is a double-difference in vintage and housing type: the site-built comparison group absorbs secular changes in construction quality and storm severity, isolating the manufactured-home-specific break at 1994.

Post-1994 manufactured homes experience \$5,700 lower building damage per claim relative to pre-1994 manufactured homes, compared to the same vintage difference for site-built homes. The event study shows flat pre-trends and a sharp break at 1994 that grows slightly with later construction cohorts, consistent with delays between the manufacture and installation of MH. I also find that damage as a share of the building's assessed value declines by approximately 6\% and that contents payments decline by \$1--2,000 per claim. At the same time, MH policies for post-1994 vintages have higher replacement costs and coverage amounts, and are more likely to be located in high-risk areas, all of which would tend to increase expected NFIP payments. These compositional shifts suggest that the estimated damage reductions comprise a lower bound on the true treatment effect of the HUD standard on flood damage.

Setting aside other benefits, the reduction in flood damage alone recovers a substantial share of the upfront compliance cost. I estimate that MH with flood insurance policies experience a claim rate of 

This paper contributes to several literatures. First, it provides direct evidence on the returns to building code regulation for disaster resilience. @simmons_economic_2018 and @dehring_coastal_2013 study whether building code reforms in Florida for site-built homes improved resilience to hurricanes and find conflicting results... For manufactured housing, my result support a body of descriptive work examining the 1994 HUD code reform [@simmons_manufactured_2008; @kevin_r_grosskopf_manufactured_2005].

Methodologically, @baylis_mandated_2021 implement a similar study of wildfire building codes in California and find large benefits to mandatory adaptation, with fiscal spillovers and insurance value potentially justifying tighter building codes even in areas with moderate wildfire risk. This paper improves on their empirical strategy by exploiting the fact that manufactured homes are regulated federally, allowing me to disentangle building code reforms from general vintage effects. Specifically, I compare site-built and manufactured homes in the same area, exposed to the same floods, and built in the same year. My design builds on the across-vintage methodology used in the economics literature to study building codes more broadly [@jacobsen_are_2013; @levinson_how_2016] and can be applied to any context where different housing types are subject to different regulatory bodies.

I also contribute to a rich literature evaluating the fiscal position of the National Flood Insurance Program. My results suggest that HUD code reforms had moderate fiscal spillovers on the NFIP, reducing total payments by roughly \$24 million over the six years after the reform; total fiscal spillovers on \emph{ex post} disaster relief programs are likely even greater [@solomon_optimal_2026].[^fiscal-spillover] 

[^fiscal-spillover]: This calculation assumes reductions of \$5,500 and \$1,000 in building and contents payments per claim, respectively, and applies those to the 3,707 claims for MH made over the period 1994-1999, assuming no change in claim frequency or policy take-up.

The scope of this paper is limited to only one channel of benefits -- flood damage reduction -- and does not attempt to estimate other benefits (e.g., wind damage reduction, spillovers to adjacent homes, reduced displacement, fiscal spillovers to \emph{ex post} disaster assistances). I leave the estimation of these channels to future work.

The remainder of the paper is organized as follows. Section \ref{institutional-background} describes the institutional background and the 1994 HUD Code reform. Section \ref{data} describes the data. Section \ref{empirical-strategy} presents the empirical strategy. Section \ref{results} reports the results, and Section \ref{conclusion} concludes.

# Institutional Background

## Manufactured Housing and the HUD Code

Approximately 6\% of the housing stock are manufactured homes. This share is substantially higher in rural areas and in the Southeast, where the share of MH can exceed 15\%.[^mh-stats] These homes are disproportionately occupied by low-income households, and they are disproportionately exposed to natural disaster risk. In 1992, Hurricane Andrew destroyed 97% of manufactured homes in its path in Dade County, Florida, compared to 11% of site-built homes.[^florida-case]

[^florida-case]: *Florida Manufactured Housing Ass'n v. Cisneros*, 53 F.3d 1565 (11th Cir. 1995).

[^mh-stats]: Manufactured-Housing Consumer Finance in the U.S. Consumer Financial Protection Bureau, 2014. https://www.consumerfinance.gov/data-research/research-reports/manufactured-housing-consumer-finance-in-the-u-s/. Manufactured homes are built in a factory and transported to a site, as distinct from site-built (stick-built) homes constructed on location.

The vulnerability of manufactured homes to extreme weather prompted a major regulatory response. In 1994, HUD revised the Manufactured Home Construction and Safety Standards---the federal building code governing all factory-built housing---to impose wind resistance requirements. The reform created a three-zone wind classification system and required structural upgrades including steel strapping, upgraded sheathing fastening, and impact-rated windows for homes sited in high-wind zones. Unlike local building codes for site-built homes, the HUD Code is a federal minimum standard that preempts state and local regulation.

The preemption of local codes is a distinctive feature of the manufactured housing market. Site-built homes are subject to state and local building codes, which vary substantially across jurisdictions and are enforced through local permitting and inspection processes. Manufactured homes, by contrast, must meet a single federal standard. This institutional feature is central to the identification strategy: the 1994 reform applied uniformly to all manufactured homes nationwide, while leaving site-built homes unaffected.

## NFIP and Flood Insurance for Manufactured Homes

The National Flood Insurance Program provides federally backed flood insurance to property owners in participating communities. Flood insurance is mandatory for properties with federally backed mortgages in FEMA-designated Special Flood Hazard Areas (SFHAs). However, manufactured homes are frequently financed with chattel loans (personal property loans secured by the home but not the land), which are exempt from the mandatory purchase requirement. As a result, NFIP take-up among manufactured homeowners is substantially lower than among site-built homeowners in comparable flood zones.

The NFIP data used in this paper record claims and policy information at the individual level. This allows direct comparison of flood damage outcomes between manufactured and site-built homes conditional on holding NFIP coverage. The selection into flood insurance coverage is a potential concern that I address through composition checks on the insured population in Section \ref{selection-and-composition}.

# Data

## Manufactured Housing Prices and Shipments

I estimate the price and quantity effects using a state-by-year panel from the Census Bureau's Manufactured Housing Survey (MHS), which reports average sales prices and placement counts by state. I focus on the period immediately around the HUD code change, 1988 - 1999. The treatment group consists of states containing HUD wind zones II or III; the control group is zone I states (see Figure \ref{map:treated-states}).

## Flood Damage and Insurance Coverage

I use two data from FEMA on individual flood insurance claims and policy records. Claims data record the date of loss, construction year, building and contents damage amounts, NFIP payments, property characteristics, and the census tract. Policy data record coverage amounts, premium, property characteristics, and flood zone designation. Both datasets include a field identifying manufactured homes.

### Final Sample

I restrict the sample to homes with construction years between 1986 and 1999 and loss dates from 1994 onward. Because claims for manufactured homes are relatively rare, I bin both the construction year and loss year in two and five year periods, respectively, to improve power. For the policy analysis, I construct a balanced panel at the county $\times$ loss-period $\times$ housing-type $\times$ construction-period level, including cells with zero claims. Each cell reports the total number of unique policies which were active at any time during the loss-period along with the average policy characteristics.

All nominal values are deflated to constant (2000) dollars using the CPI-U. I restrict both samples to the continental US. Table \ref{tab:sumstats-nfip} reports summary statistics for the NFIP data by construction vintage and housing type. Manufactured homes generally experience lower building and contents damage than site-built homes, with correspondingly lower coverage amounts. I observe less than 10,000 claims for manufactured homes in the sample, or roughly 2.4\% of all claims, substantially lower than the share of manufactured homes in the overall housing stock \citep{genz_why_2001}.

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

where $Y_{it}$ is the outcome for claim $i$ (e.g., building damage), $\alpha_{c(i),t}$ is a county $\times$ loss-period fixed effect absorbing location-specific storm severity, $\delta_m$ is a manufactured housing indicator absorbing time-invariant differences between housing types, $\text{MH}_i$ is an indicator for manufactured homes, and $\nu_i$ is the construction vintage bin of home $i$. The coefficients $\beta_k$ capture the manufactured-home-specific vintage profile relative to the 1992 reference bin. Post-1994 coefficients are the treatment effects.

Identification relies on a parallel trends assumption in the vintage profile of outcomes between manufactured and site-built homes in the absence of the HUD code reform. In other words, homes built at different times may experience different levels of flood damage due to changes in construction quality, storm severity, or intra-county location, but these vintage effects should be the same for manufactured and site-built homes. I support this assumption by showing flat pre-trends in the event study specification across a broad range of claim-level and cell-level outcomes.

I expect the treatment effect to grow with later construction cohorts as compliance rates increase. Because of lags between production and installation, some units with post-1994 construction dates may have been manufactured before the regulation went into effect in July of 1994.

For cell-level outcomes (policy characteristics), regressions are weighted by the number of policies in the cell.

# Results

## Cost Side: Manufactured Home Prices

Figure \ref{fig:es-price} presents the event study for manufactured home prices. Prior to 1994, treated and control states follow parallel trends: the pre-treatment coefficients are small, precisely estimated, and statistically indistinguishable from zero. Prices diverge sharply in 1994, with treated states experiencing a \$5000 increase that stabilizes by 1995 and persists through the end of the sample. The price effect is economically large, corresponding to an X\% increase in the price.

The immediacy of the effect is consistent with the regulation raising production costs: manufacturers anticipated the July 1994 effective date and adjusted pricing accordingly. The persistence of the premium through 2000 suggests that the regulation caused persistently higher variable costs rather than a one-time fixed cost to redesign models and re-arrange production lines.

Figure \ref{fig:es-placements} shows the corresponding event study for log placements. There is no detectable effect on the quantity of manufactured homes shipped to treated states. The point estimates are small and imprecise, centered around zero, and statistically insignificant throughout the post-period. This null result on quantities, combined with the positive price effect, is consistent with two possibilities: either demand for MH is relatively inelastic, so that the price change had little effect on equilibrium quantities; or the demand curve simultaneously shifted outwards due to the increased value of the improved construction, offsetting the higher price.

## Benefit Side: Flood Damage

### Post 1994 MH experience lower flood damages

Figure \ref{fig:es-building-damage} presents the main result: the event study for average building damage per claim. Pre-1994 construction-period coefficients are flat and close to zero, confirming parallel vintage trends between manufactured and site-built homes before the HUD standard took effect. Beginning with the 1994 construction cohort, manufactured homes experience sharply lower building damage relative to site-built homes. The effect stabilizes at over \$5,000 per claim, or almost 15\% of the average building damage across all claims.

Table \ref{tab:claims-outcomes} presents supplementary outcomes on insurance payments and damage to the building's contents. Column (3) shows effects on building damage as a share of its assessed value. Conditional on filing a claim, post-1994 manufactured homes tend to experience damage that is between 6\% and 9\% less as a proportion of their value than site-built homes of the same vintage. While the HUD wind standard raised prices, it decreased both absolute and relative flood damages. Contents damage and payments decline by roughly \$2,000 and \$1,000, respectively, consistent with improved the structural integrity.

## Selection and Composition {#selection-and-composition}

A concern with the vintage-based design is that post-1994 manufactured home policyholders may differ systematically from pre-1994 policyholders, and that these compositional differences rather than construction quality drive the damage results. Table \ref{tab:composition} reports the full set of policy composition event studies.

The composition shifts work against the main result. Relative to pre-1994 manufactured homes, post-1994 manufactured home policies have higher replacement cost (\$66--102,000), higher building coverage (\$4--14,000 per policy), and higher contents coverage (\$1.5--2.8,000 per policy). Post-1994 manufactured homes are also more concentrated in SFHAs (2--5 percentage points higher) and more likely to face mandatory purchase requirements (1 percentage point higher). These shifts would all tend to increase expected NFIP payments, not lower them, making the damage reduction estimates conservative.

The one composition shift that works in the direction of the main result is the elevated-building share, which rises by 5 percentage points for post-1998 construction vintages. Elevation is plausibly part of the treatment channel---the HUD Code encouraged improved siting and installation practices---rather than a confound. Primary-residence share is essentially unchanged across vintages.


## Robustness

The main building damage results rely on county $\times$ loss-period fixed effects to absorb location-specific variation in storm severity. A concern is that within-county variation in flood exposure---for instance, proximity to a floodplain or drainage infrastructure---could differ systematically across construction vintages and housing types. I address this by re-estimating the primary building damage specification with census tract $\times$ loss-period fixed effects, which absorb finer-grained geographic heterogeneity.

Table \ref{tab:geo-robustness} compares the two specifications. The tract-level estimates are very similar in magnitude to the county-level baseline, with modestly wider confidence intervals reflecting the smaller sample sizes within tracts. The agreement across geographic controls supports the identifying assumption that vintage effects are not confounded by within-county variation in flood exposure.

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
  \caption{States Treated by the 1994 HUD Wind Standard}\label{map:treated-states}
  \includegraphics[width=\textwidth]{output/descriptives/map-mhs-treated-states.pdf}
  \begin{flushleft}
  \begin{footnotesize}
  Notes: Treated states are those with any overlap with HUD wind zones II or III. Control states are wind zone I states. Alaska and Hawaii are excluded. Source: Census Bureau Manufactured Housing Survey and Census TIGER/Line state shapefiles.
  \end{footnotesize}
  \end{flushleft}
\end{figure}

\begin{table}[htbp]
  \centering
  \caption{NFIP Data by Construction Vintage and Housing Type}\label{tab:sumstats-nfip}
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
  Notes: Figure plots event-study coefficients from Equation \eqref{eq:event-study-cost}. Nominal values are deflated to 2000 dollars. Source: Census Bureau Manufactured Housing Survey.
  \end{footnotesize}
  \end{flushleft}
\end{figure}

\begin{figure}[htbp]
  \centering
  \caption{Effect of 1994 HUD Wind Standard on Manufactured Home Placements}\label{fig:es-placements}
  \includegraphics[width=\textwidth]{output/event-study/es-mhs-placements_ln.pdf}
  \begin{flushleft}
  \begin{footnotesize}
  Notes: Figure plots event-study coefficients from Equation \eqref{eq:event-study-cost}. Outcome is log manufactured home placements.
  \end{footnotesize}
  \end{flushleft}
\end{figure}

\begin{figure}[htbp]
  \centering
  \caption{Effect of 1994 HUD Standards on Net Building Payment per Claim}\label{fig:es-building-damage}
  \includegraphics[width=\textwidth]{output/event-study/countyfp/es-building-damage.pdf}
  \begin{flushleft}
  \begin{footnotesize}
  Notes: Figure plots event-study coefficients from Equation \eqref{eq:event-study-benefit}. Nominal values are deflated to 2000 dollars. Source: OpenFEMA claims data.
  \end{footnotesize}
  \end{flushleft}
\end{figure}

\begin{landscape}
\begin{table}[htbp]
  \centering
  \caption{Supplementary Claims Outcomes}\label{tab:claims-outcomes}
  \begin{threeparttable}
    \input{output/event-study/countyfp/claims-outcomes.tex}
    \begin{tablenotes}
      \item Notes: Coefficients from Equation \eqref{eq:event-study-benefit} estimated on claim-level data. All damage and payment values are reported in thousands of 2000 dollars. \emph{Bldg.\ dmg.\ share} reports damage as a percentage of the assessed building value. Source: OpenFEMA claims data.
    \end{tablenotes}
  \end{threeparttable}
\end{table}
\end{landscape}

\begin{landscape}
\begin{table}[htbp]
  \centering
  \caption{Policy Composition}\label{tab:composition}
  \begin{threeparttable}
    \input{output/event-study/countyfp/policy-composition.tex}
    \begin{tablenotes}
      \item Notes: Coefficients from Equation \eqref{eq:event-study-benefit} estimated on the cell-level panel, with observations weighted by number of policies. \emph{Repl. cost}, \emph{Bldg covg.}, and \emph{Contents covg.} refer to the estimated replacement cost, building coverage amount, and contents coverage amount, respectively, and are reported in thousands of 2000 dollars. All other outcomes are fractions. \emph{Elevated} indicates that the building satisfies the NFIP definition of an elevated building; \emph{SFHA} indicates that the property is located in a Special Flood Hazard Area; \emph{Primary res.} indicates that the home is a primary residence; and \emph{Mandatory} indicates that flood insurance was required by the mortgage lender.  Source: OpenFEMA policy data.
    \end{tablenotes}
  \end{threeparttable}
\end{table}
\end{landscape}

\begin{landscape}
\begin{table}[htbp]
  \centering
  \caption{Building Damage - Robustness to Census Tract FEs}\label{tab:geo-robustness}
  \begin{threeparttable}
    \input{output/event-study/countyfp/geo-robustness.tex}
    \begin{tablenotes}
      \item Notes: Coefficients from Equation \eqref{eq:event-study-benefit} estimated on claim-level data. Column (1) uses county $\times$ loss-period fixed effects (baseline). Column (2) replaces county with census tract $\times$ loss-period fixed effects. Building damage values are in thousands of 2000 dollars. Source: OpenFEMA claims data.
    \end{tablenotes}
  \end{threeparttable}
\end{table}
\end{landscape}

\clearpage

\appendix

# NFIP Take-Up {#appendix-take-up}

The damage estimates in the main text condition on filing a claim and do not speak to whether the HUD code reform affected NFIP take-up. Standard theory predicts that self-protection and insurance are substitutes: households facing lower expected losses should demand less coverage \citep{ehrlich_market_1972}. This appendix examines whether the reform affected the number of NFIP policies held by manufactured homeowners.

Table \ref{tab:take-up} reports estimates from a PPML model of total policy counts by housing type and construction vintage. Raw policy counts increase for post-1994 manufactured homes relative to site-built homes. However, this result is difficult to interpret as a change in take-up rates because the ratio of manufactured home shipments to single-family building permits rose sharply after 1994 nationwide. The NFIP data do not include a denominator for the total housing stock, so the raw count increase may simply reflect more manufactured homes in later vintage bins rather than a higher propensity to insure. I therefore focus the main text on damage outcomes where identification does not require observing the universe of homes.

\begin{table}[htbp]
  \centering
  \caption{NFIP Take-Up}\label{tab:take-up}
  \begin{threeparttable}
    \input{output/event-study/countyfp/take-up.tex}
    \begin{tablenotes}
      \item Notes: Coefficients from Equation \eqref{eq:event-study-benefit} estimated on the cell-level panel. Column (1) estimates a PPML model with total policies as the outcome. Source: OpenFEMA policy data.
    \end{tablenotes}
  \end{threeparttable}
\end{table}

