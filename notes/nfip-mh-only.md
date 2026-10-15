# NFIP county and construction-vintage comparisons

Run `Rscript program/estimate-nfip/estimate-nfip-mh-only.R`. Outputs are in
`output/nfip/mh-only/`: `static.csv`, `event-study.csv`,
per-outcome static LaTeX tables, baseline and state-by-vintage event-study PDFs,
model summaries, and sample/exposure diagnostics.

These extend the CoreLogic design in `paper.Rmd` to NFIP outcomes. Construction
years are 1989–1999, the reference vintage is 1993, and post includes 1994.
Zone II and III interactions enter jointly, each relative to Zone I. Static
columns 1–2 and both event studies use MH only. Columns 3–4 retain the existing
housing-type triple-difference checks. County clustering supplies the plotted
95% intervals; the CSVs also report state-clustered standard errors.

The four damage/payment amounts use PPML and the shared NFIP claim cleaning.
The four corresponding shares use OLS, in percentage points, with building or
contents value as the denominator. Nonpositive or nonfinite denominators and
nonfinite or negative shares are excluded. Raw shares are retained alongside
sensitivity outcomes capped at 100% (`_bounded`). `shares-above-100.csv` reports
how many MH claims exceed that bound. These outcomes condition on a claim.
Missing zone-vintage contrasts remain missing (`identified = FALSE`), rather
than being assigned zero; the 1993 reference alone is normalized to zero.

Claim frequency uses the balanced NFIP claims/policy panel for 2009–2023,
aggregated from tracts to county × five-year calendar period × construction
year × housing type before selecting positive policy-year exposure. PPML
models claim counts with log policy-years as an offset, retaining zero-claim
cells. Calendar period replaces loss year in the fixed effects. This sample
does not require an imputed housing-stock denominator. `claim_rate` labels the
rate estimand in exports; its fitted dependent variable is the claim count.
Rate estimates are log points, and `pct` reports `100 * (exp(beta) - 1)`.
OLS share coefficients are percentage points, so their `pct` fields are missing.
Claim-frequency observation counts refer to cells; severity counts refer to
individual claims. `claim-rate-exposure-support.csv` records positive- and
zero-exposure support before estimation drops zero-exposure and all-zero FE
cells. Frequency is conditional on insurance participation.

CoreLogic figures can separately be redrawn without licensed microdata using
`Rscript program/estimate-corelogic/replot-corelogic.R`. This uses the same plotting
helpers as the estimation scripts and regenerates the paper and
vintage-vs-state-by-vintage comparison figures from exported coefficients, with
confidence ribbons and connected points.
