# Chunk log

Newest entry first. See `TODO.md` PROCESS for what belongs in each memo.

---

## Chunk O — Claim-level headline moved to PPML, and the cost-benefit conversion (2026-08-27)

Uncommitted in the working tree at time of writing. Colin's decision, after
Chunk N: "the levels spec gives statistical precision and a clean event study
but exaggerates the magnitude due to the vastly different home values... I don't
think I can show or report the level effects in good conscience given that model
is mis-specified. So I am inclined to do logs for everything, and also show/use
the static estimates for benefit-cost." Technical detail in `notes/specs.md`
§19.

By this point two of the paper's specifications had independently been shown
non-identified in levels — Chunk M on claim-level damages, Chunk N on take-up —
so the question was no longer whether the diagnosis was right but whether to act
on it in the headline.

### What changed

All four claim-level loss outcomes are PPML, static and event study. Building
damage **−13.4%** (SE 5.6), contents damage −13.3% (5.7), net building payment
−11.3% (6.3), net contents payment −18.5% (7.6). All four significant. The
levels fits are still run and their scalars still exported, so the paper reports
the divergence between the two scales rather than asserting it: −$5,754 in
dollars against −$1,583 from the proportional estimate applied to the pre-1994
MH mean.

**PPML rather than log OLS, and the reason is specifically the cost-benefit
conversion.** Poisson models E[Y|X] directly, so exp(b) is a ratio of
*conditional means* and multiplying an observed mean by it recovers a dollar
figure. Under log OLS exp(b) is a ratio of geometric means and that conversion
is biased — it would have reintroduced exactly the distributional assumption the
levels specification was originally chosen to avoid. Chunk M had built a log-OLS
spec; this is why it is not the one that became the headline.

### The conversion, and why it needs two baselines

Colin's question was whether to "convert from the PPML to a level effect at the
average MH price for the BCR." Yes — but the two calculations in
`estimate-welfare.R` have different counterfactuals and therefore different
baselines:

- **Private per-unit NPV** applies the *pre-1994* claim rate as the
  counterfactual hazard, so it pairs with the pre-1994 MH mean:
  Δ = ȳ_pre(1 − e^b) = $11,855 × 0.134 = **$1,583**.
- **Fiscal savings** multiplies the claims post-1994 homes *actually filed*, so
  it grosses the observed post-1994 mean up to its counterfactual:
  Δ = ȳ_post(e^−b − 1) = $10,244 × 0.128 = **$1,307**.

These differ by about 30%. The script previously used one delta for both, which
paired a pre-1994 hazard with a post-1994 damage level in one calculation or the
reverse in the other. Colin confirmed the split.

### The answer moved a lot

**BCR 0.435 → 0.163.** That changes the paper's register, so the cost-benefit
section, the intro, and the conclusion now lead with what the ratio does and
does not cover. The standard is a *wind* standard; the flood channel is the one
these data identify. Break-even for the omitted channel is now a stated,
falsifiable quantity rather than a gesture: the wind channel would need to
deliver **$2,711** per unit in present value, or **5.1×** the measured flood
benefit.

### Scrutiny of the proportional estimate — Chunk M's other open item

Adding a county-specific housing-type effect (`geo^mh`, which in PPML is a
multiplicative baseline per county × housing type, absorbing the `mh` main
effect) moves building damage −13.4% → −5.3% (n.s.) and net building payment
−11.3% → +0.5%. That looked alarming until the sample was examined: **515 of the
887 counties with any MH claim have MH claims on only one side of 1994**, so
they cannot contribute a within-county vintage contrast at all. Restricting to
counties where the contrast exists, the two specifications converge and *both*
grow:

```
all counties            base -13.4%   geo^mh  -5.3% (n.s.)
>=1  MH claim each side       -12.7%           -5.4%     372 counties, 85% of MH claims
>=5  each side                -16.4%          -10.4%      87 counties
>=20 each side                -25.7%          -18.0%      16 counties
```

So the full-sample `geo^mh` figure is attenuation, not a bias correction. It
still shows the estimate is sensitive to which counties carry it (−12.7% to
−25.7% in the base spec), which belongs in the paper. Scalars exported; whether
it becomes a robustness column is Colin's call and is one `etable` away.

### Slides

`slides.tex` and `program/write-slide-macros.R` (Colin's, added during this
session) needed the same pass. The take-up block of the generator was already on
PPML; the claim-level block was not, and the water-depth macros were a live bug:
they formatted PPML log coefficients with `fmt_d`, which multiplies by 1,000, so
`\vWdDepth` rendered a coefficient of -0.116 as "$116" on the slide. The damage
macros now emit three forms per outcome -- `*Pct` (the proportional effect),
`*LP` (coefficient and SE in log points), `*Dol` (the dollar conversion) -- and
`fmt_d` is never applied to a coefficient.

The "Why levels and not logs" backup slide argued the case the paper has now
abandoned, so it is replaced by "Why proportional and not dollars", built around
the placebo. The fiscal-spillover slide gained a line saying its per-claim
figures use the observed post-1994 means while the private calculation uses the
pre-1994 ones. `make slides.pdf` is clean and every macro a slide uses is
generated.

### Also in this chunk

- **The zero-effect placebo is now in the harness** (Chunk M's open item). It had
  to be: the paper's new "Why the estimates are proportional" section cites it in
  the main text, and a load-bearing claim should not rest on a one-off
  diagnostic. On claims built with a multiplicative housing-type gap, a
  proportional vintage gradient, and a treatment effect of exactly zero, the
  dollar spec returns −21% of the MH mean at t ≈ −10 while Poisson returns
  −0.012 (n.s.). A second test confirms the paper's conversion recovers a known
  dollar effect to within 10%.
- **Caught and corrected in my own draft:** I had written that the zero-effect
  simulation "returns −$5,754," which is the estimate on the *real* data, not the
  simulation result. Rewritten to describe the placebo qualitatively and cite
  only scalar-backed figures, per the hard-coded-figure rule in `specs.md` §9.
- **Two console formatting bugs in `estimate-welfare.R`:** compliance cost and
  per-claim deltas printed as `$%.0fk` on values already scaled by 1e3, so a
  $3,241 cost printed as "$3241k". Console-only but actively misleading.
- The unwinsorized comparison is re-run on the PPML scale, since the old
  paragraph quoted levels R² and levels coefficients that are no longer the
  headline. The cap moves building damage 12.7% → 13.4% and contents 14.6% →
  13.3%.
- The levels event-study figure is still written, to
  `es-building-damage-levels.pdf`, so the two scales can be compared without
  either overwriting the other.

---

## Chunk N — Take-up moved to PPML with an exposure offset (2026-08-27)

Uncommitted in the working tree on `chunk-m-log-damage-es` at time of writing. Colin flagged that the dynamic take-up
coefficients swing between large positive and large negative in adjacent
vintage bins, several of them significant, and that the significance looked
overstated relative to how much the point estimates moved. Full technical
detail in `notes/specs.md` §18; this is the narrative.

### Three problems, any one of which sinks the old table

**The dynamic profile was the denominator, not the data.** Running the
event study separately on `log(policies_n)` and `log(homes_n)` with the
identical interaction and fixed effects shows the imputed stock carrying a
vintage × MH profile of its own with county-clustered t-statistics of 5 to 11.
It has two parts: a sawtooth inside the 1980-89 Census bin, where every
year-to-year movement is MHS placements against BPS permits with no attrition
adjustment, and a flat +0.28 step at 1994 that is identical across the
1994/1996/1998 bins because it is the Census bin boundary, not an event. The
policy count jumps +0.27 at the same boundary, so the two nearly cancel and the
rate is flat across 1994 in logs.

**The level spec was Chunk M's problem again.** The MH/site-built take-up gap
is proportional, not additive — 3.97 annual policies per 1,000 homes in the
bottom county tercile against 107.91 in the top — so one additive `mh` fixed
effect cannot fit both ends and `post_mh` absorbs the misfit. The pooled level
estimate is +4.65, but it is negative in every tercile estimated separately
(−0.17, −1.67, −11.18), flips to −5.52 when the `mh` and `post1994` effects are
allowed to vary by tercile, to −1.46 with a county-specific `mh` effect, and to
+0.42 at five-year bins. PPML gives 0.007 / 0.164 / 0.052 across the same
perturbations. Trimming thin-stock cells changes nothing, so the thin-cell
justification for the `homes_n` weights recorded in Chunk E was not what the
weights were doing.

**County clustering overstated precision.** MHS placements are a state-year
series broadcast to every county in a state, so the denominator's error is
close to one draw per state × vintage × type. The static level estimate is
+4.65 (SE 2.24) by county and (SE 3.83) by state — significant at 5% becomes
t = 1.21.

### What replaced it

All three margins are now Poisson counts with a log exposure offset: home-years
for policies-per-home and claims-per-home, observed policy-years for claims-per-
policy. Clustered by state, with county-clustered SEs exported alongside so the
paper reports both. A new appendix table (`tab:take-up-robust`) re-runs the two
per-home columns against an equal-split denominator — same Census bin totals,
annual sources switched off — as a bound on what the imputation supplies.

### The answer changed

Static, state-clustered: policies/home **+0.007 (0.086)**, claims/home +0.176
(0.115), claims/policy +0.059 (0.050). All null. The largest coefficient in the
take-up profile is at 1990-91, four years before the reform. The appendix now
reports a noisy null — enough to rule out crowding out, which requires a fall,
and not enough to claim a rise. Colin's instruction was to keep take-up in the
paper rather than drop it: it is a key outcome in this literature and a noisy
null is still the answer to the question the appendix asks.

The **mandatory-purchase split reversed**, which is the one substantive finding
in the chunk. Old (levels): mandated +0.79, non-mandated +7.33, read as
"nine-tenths of the movement is in policies the homeowner was not required to
buy." New (PPML): mandated **+0.275 (0.057)**, non-mandated −0.011 (0.090). The
mandated component rose about 32% — which is exactly what NFIRA 1994 predicts —
but mandated policies are only 7.7% of pre-1994 MH policy-years, so its
contribution to the total is ≈ +0.021 log points. NFIRA is visible where it
should be and too small to move the aggregate. The paper says so.

### Costs, recorded rather than papered over

The exact identity `claims/home = policies/home × claims/policy` no longer
holds among the fitted coefficients (on a common sample, (1)+(3) = 0.048
against (2) = 0.176), because each column solves its own score equation against
its own offset. The paper's "Three margins" section now says three margins, not
a decomposition. The columns also no longer share a sample — Poisson drops FE
groups whose outcome is zero throughout, so the claims columns run on 44,551
cells against 68,497 — and column (1) re-estimated on the claims sample is
−0.011 (0.098), which is exported so the paper can say the sample difference is
not what separates the columns.

### Also in this chunk

- Every take-up scalar renamed with a `_ppml` marker. A coefficient on a new
  scale under an old name is the failure mode a rename prevents; the
  descriptive *level* rates the paper quotes for magnitude keep their old
  unsuffixed names, since they are statistics rather than estimates.
- Two main-text passages depended on the retired finding and were rewritten:
  the selection-channel paragraph that asserted a larger post-1994 insured pool
  (now states the estimate and its interval and calls it unsigned), and the
  claim-rate sentence feeding the cost-benefit section (now proportional).
  A third sentence claimed zero-policy cells "enter only the Poisson count
  model of Section A.1", which was never true after Chunk E — corrected.
- `impute-stock.R` emits `homes_flat_n`, the equal-split companion. Verified
  the script reproduces the existing `stock-county-vintage.Rds` byte-identically
  before the column was added.
- `test-take-up-imputation.R` rewritten: its first two tests were exercising
  the specification the paper no longer runs. The replacement includes a
  zero-effect placebo on which the level spec returns −25% of the mean and PPML
  returns ≈0, with the composition tilt that generates the bias made explicit.
- Found and fixed while getting the paper to knit, unrelated to take-up:
  `derived/mhs-dropped-states.Rds` was absent from this working copy, so
  `estimate-mhs.R` could not run and `mhs-scalars.csv` was stale enough to be
  missing `n_dropped_states`. Rebuilt via `databuild-mhs.R`. `make paper.pdf`
  and `make test` both pass.

---

## Chunk M — Log building damage event study, and the scale problem in the levels spec (2026-08-27)

Branch `chunk-m-log-damage-es`. Started from Colin's question about whether a
quantile regression on claim-level building damage would show the decline
concentrated in the upper tail — economically interesting, since the insurance
value of avoiding a total loss exceeds that of avoiding a small one. Answering
it surfaced a problem with the levels specification, and the chunk ended as a
diagnostic pass plus one new figure.

### The quantile question, and why it is not the right tool

Quantile effects do not aggregate to the mean effect, so they cannot decompose
the headline. The estimator that can is an exactly additive band decomposition:
write `Y = sum_k max(0, min(Y, c_k) - c_{k-1})` and run the same static spec on
each piece, so the coefficients sum to `building_damage_static` by construction,
on the same sample, FE, and clustering. That gives:

| Band ($000) | Coef | SE | % of effect | MH pre-1994 mean in band |
|---|---|---|---|---|
| [0,10) | −0.294 | 0.135 | 5.1 | 6.38 |
| [10,25) | −0.344 | 0.302 | 6.0 | 3.31 |
| [25,50) | −1.039 | 0.463 | 18.1 | 1.70 |
| [50,100) | −1.958 | 0.447 | 34.0 | 0.41 |
| [100,200) | −1.727 | 0.493 | 30.0 | 0.04 |
| [200,1000) | −0.392 | 0.230 | 6.8 | 0.02 |

Sums to −5.754, matching the headline exactly. 89% of the effect comes from
bands above $25k. A RIF unconditional-quantile version tells the same story
more dramatically (−$17.0k at p90, t = −4.76, flat below the median).

That is the figure Colin had in mind, and it is an artifact. The $100–200k band
supplies 30% of the effect from an MH pre-1994 base of $40, because the sample
contains **3 pre-1994 and 4 post-1994 MH claims above $100k in total**.

### Root cause: the levels spec is not identified in its own units

§1's parallel-vintage-trends assumption is that the common vintage effect is the
same for both housing types. In levels that requires it to hold **in dollars**.
The data reject that and support the proportional version:

| | Pre-1994 | Post-1994 | Change |
|---|---|---|---|
| Site-built median repl. cost | 143.6 | 165.8 | +15.4% |
| MH median repl. cost | 39.9 | 46.6 | +16.7% |
| Site-built mean bldg. damage | 28.95 | 33.46 | +15.6% |
| MH mean bldg. damage | 11.86 | 13.36 | +12.7% |

Same DiD, two units: on log replacement cost `post_mh` = −0.031 (SE 0.027);
on the level of replacement cost, −20.58 (SE 2.89). Newer homes of both types
are bigger and worth more, and dollar damage scales with what is at risk. A
common proportional gradient on bases differing by 2.4× mechanically yields
`11.86 × 0.156 − 28.95 × 0.156 = −2.67` with **no resilience effect at all**,
against a raw level DiD of −3.00 and the FE headline of −5.75.

Two confirmations. (a) Trimming site-built claims to below the MH 90th
percentile of replacement cost, **retaining every MH claim**, moves the levels
estimate from −5.754 (1.451) to +0.099 (0.783) and Poisson from −13.4% to
+2.3%; the trim gradient is monotone (−5.51 → −1.85 → −0.46 → +0.02). (b) A
placebo on simulated claims with a TRUE effect of zero and a common
proportional vintage gradient returns −5.31 (t = −5.44) in levels while Poisson
recovers zero, and reproduces the FE amplification (analytic bias −2.67, FE
estimate −5.31, ratio 1.99; real data −3.00 and −5.75, ratio 1.92).

This extends Chunk L's own diagnosis to the outcome it exempted. Chunk L found
the contaminated value fields "sit in the comparison group and destabilize the
MH × vintage interaction," then reasoned the payment fields are safe because
statutory limits censor them. `building_damage` is a loss estimate, not a
payment — no statutory bound applies, and its site-built tail runs to $1M.

### What was built

One new figure, `output/event-study/countyfp/es-log-building-damage.pdf`, per
Colin's request, dropping zeros. In `estimate-nfip.R`: `log_building_damage` at
data construction; `est_claim_es_log` and `est_static_log`, estimated separately
from `s_claim` so the four columns of `claims-outcomes.tex` and
`claims-outcomes-static.tex` are untouched; the `plot_es` call; nine scalars.
`plot_es` gained an optional `ylab` argument, defaulted so every existing call
behaves identically. Full spec in `notes/specs.md` §17.

**Result:** static `post_mh` = **−0.145 (SE 0.0635), t = −2.28** (−13.5%),
against Poisson's −13.4% on the same spec — the two proportional estimators
agree closely. Event-study post-1994 coefficients −0.056, −0.075, −0.158:
monotone in vintage, consistent with the compliance ramp, individually noisy.
Pre-period flat but not perfectly (1988 bin +0.13, wide CI). Zeros cost 1.5% of
the sample (201,054 → 197,967).

### Why log damage rather than damage / replacement value

Colin's instinct was that the ratio removes the value-at-risk problem. It does,
for the estimand — but the ratio inherits the denominator's contamination, which
is where its noise comes from. Same static spec:

| Outcome | post_mh | SE | t | R2 |
|---|---|---|---|---|
| `100 × damage / repl_cost` | +4.745 | 54.248 | 0.09 | 0.009 |
| `log(damage / repl_cost)` | −0.1255 | 0.0582 | −2.16 | 0.409 |
| `log(damage)` | −0.1452 | 0.0635 | −2.28 | 0.398 |

The levels ratio has sd 19,828 and exceeds 100% — impossible by construction —
for 1.1% of claims. In logs the identity `log(ratio) = log(damage) −
log(repl_cost)` holds exactly in the estimates (−0.1579 − (−0.0324) = −0.1255),
and since the denominator term is small and insignificant, subtracting it mostly
adds noise. Log damage is the more precisely measured version of the same
object and does not condition on a contaminated field.

### Verified

- `make test` passes (4 suites).
- `building_damage_static` unchanged, byte-identical: −5.75370154734659. No
  existing table, figure, or scalar moved.
- Band decomposition asserted to sum to the raw outcome row-wise, and its
  coefficients verified to sum to the headline.
- Log/level identity check above reproduces to 4 decimal places.

### Open questions

1. **Does the paper's headline move to a proportional estimator?** Poisson
   targets `E[Y|X]` directly, so it escapes all three of Chunk L's objections to
   logs — no retransformation, zeros handled natively, and the vintage effect
   enters proportionally, as the data say it operates. The framing in §15 was
   levels-vs-logs; Poisson is the third option. −13.5% on the MH pre-1994 mean
   of 11.86 implies ≈ **−1.6 per claim vs the current −5.75**, a factor of 3.6,
   which would take the BCR from ~0.52 to roughly 0.15. Sits with Chunk C's
   compliance-cost decision and Chunk I's static-vs-event-study delta question.
2. **The proportional estimate is not nailed down either.** Poisson's −13.4%
   is much larger than the raw proportional DiD of −2.5%, so the county ×
   loss-year FE do heavy lifting. Not necessarily wrong — composition across
   counties and storms is real — but it deserves the same scrutiny.
3. **The common-support estimate is not the truth.** Conditioning on a value
   window while the whole value distribution shifts up induces its own
   selection: a $68k post-1994 site-built home is a more unusual home than a
   $68k pre-1994 one. Use as a diagnostic, not a headline.
4. **The placebo is not in `program/tests/`.** Verified in simulation and
   described in a code comment, but not added to the fake-data harness. Should
   be, before the levels headline is defended in print.
5. **The figure is not wired into `paper.Rmd`**, and `estimate-welfare.R` still
   uses the levels deltas.

---

## Chunk L — Levels vs. logs on the NFIP outcomes, and table presentation (2026-08-26)

Branch `chunk-k-water-depth-robustness` (continued from Chunk K rather than
re-branched, since the diff builds directly on it). Colin's request came in
three parts across a working session, all prompted by reading the revised
`tab:composition` and `tab:claims-outcomes`: replacement cost varies wildly
across vintages with an R2 near zero — why, and should it stay; the building
damage share is noisy and imprecise with a tiny R2 and may add nothing; and
contents coverage does not warrant two columns for its two margins. He then
raised the levels-vs-logs tension explicitly (logs need no deflation given
year fixed effects, avoid the insane values, and give more natural parallel
trends for prices — but break comparability with the cost side and discard
zeros), and asked for a recommendation. A follow-up turn asked for
percentage-point units on the two binary composition columns and proposed
dropping the water-depth robustness table.

### What was done

One diagnosis explains both badly-fitting columns. The FEMA
*value/appraisal* fields are contaminated in the tail; the *payment* fields
cannot be, because the NFIP statutory coverage limits censor them
(`net_building_pmt` max 441, `net_contents_pmt` max 113, against `repl_cost`
max 1,371,528). The contamination is asymmetric — `building_value` has a
99.9th percentile of 1,074,609 for site-built against 3,750 for MH — so it
sits in the comparison group and destabilizes the MH × vintage interaction
rather than merely adding noise.

Resolution: the estimand differs by table, so the units should too.

1. **Claim-level damage and payment outcomes stay in levels**, because the
   cost-benefit analysis needs the change in the expected dollar loss, not
   the change in a geometric mean, and the retransformation does its heaviest
   work in exactly the fat right tail that dominates expected loss.
   Independently, the two payment outcomes are 29.6% and 66.9% zeros, so they
   admit no log at all. All four are winsorized at `MAX_CLAIM_LOSS = 1000`
   ($000 of 2000 dollars), which binds for 8 building-damage and 29
   contents-damage records, no payment records, and no manufactured homes.
   Uncapped copies are retained and the static spec re-estimated on them, so
   the paper quotes the movement instead of asserting the cap is harmless.
2. **Replacement cost moves to logs** in `tab:composition`, where the column
   signs a bias and never enters an arithmetic ratio, so the comparability
   objection does not apply. Winsorizing the level was checked and rejected:
   it fits better than the raw level but leaves a steep declining pre-trend,
   because the tail is where that pre-trend lives.
3. **Contents coverage collapses to one unconditional column.** Both margins
   are individually null after 1994, and the conditional-amount column was
   estimated on a sample selected by the outcome of the column beside it.
4. **The building damage share is dropped from both claims tables.** Bounding
   it at 100 does fix the fit, but the cleaned event study then shows a trend
   across the whole vintage window rather than a break at 1994, so parallel
   vintage trends fails for this outcome and the static estimate averages
   over a pre-trend. That is the decisive reason, not the R2. It is still
   estimated and its scalars still exported, since
   `notes/apps/abstract-appam.Rmd` reads `building_damage_share_avg`.
5. **The two binary composition outcomes are scaled to percentage points**
   (`elevated_policy_pct`, `sfha_policy_pct`, labelled *Elevated (%)* and
   *SFHA (%)*) so they stop printing as leading zeros beside the log and
   dollar columns. Pure rescaling: R2, t-statistics, and stars unchanged.

On deflation, since it came up: the claims data are deflated by loss-year CPI
against a `geo^year_loss` fixed effect, so under a log outcome the deflator
would be exactly absorbed and deflating would be a no-op — but it is not a
no-op under a level outcome, since deflation is multiplicative and does not
commute with additive fixed effects. The policy micro is deflated by policy
year against a fixed effect spanning five calendar years, across which CPI
moves about 10%, so deflation is only partly absorbed there and remains
necessary even in logs. Deflation is therefore not a reason to prefer logs.

### What changed in outputs

- `output/event-study/countyfp/policy-composition.tex`: six columns to five.
  Log repl. cost R2 0.001 → 0.20, with flat insignificant pre-1994
  coefficients and a stable +0.07\*\*\*/+0.06\*\*/+0.08\*\*\* after.
  Contents covg. now unconditional (R2 0.19). Elevated and SFHA now in
  points: elevated +0.96, -1.6, -1.3, -1.7 pre and -0.02, +1.2, +5.3\*\*\*
  post; SFHA -2.9, -4.8\*\*, -3.6\*, -3.9\*\* pre and +2.7\*\*,
  +4.3\*\*\*, +8.0\*\*\* post.
- `output/event-study/countyfp/claims-outcomes.tex` and
  `claims-outcomes-static.tex`: five columns to four. `building_damage_static`
  -5.557 → -5.754 (SE 1.451), R2 0.33 → 0.43; `contents_damage_static`
  -3.752 → -3.198 (SE 0.672), R2 0.07 → 0.25.
- `output/results/welfare-scalars.csv`: `delta_contents` moves with the
  contents-damage coefficient, so `delta_total` is now $6,342,
  `npv_3pct_20yr` $1,411, and `bcr_3pct_20yr` 44%. **This is the one headline
  number the winsorization rule materially affects**, and it is documented as
  such rather than buried.
- Sixteen new scalars in `nfip-scalars.csv` (winsor counts and cap, zero
  shares, uncapped static coefficients, R2 pairs) plus three water-depth
  variation scalars, so no figure in the new paper text is hardcoded.

### Verified

- `Rscript program/estimate/estimate-nfip.R` and `estimate-welfare.R`: exit 0.
- `Rscript -e 'rmarkdown::render("paper.Rmd")'`: exit 0, no undefined
  references, and the new appendix figures confirmed present in `paper.pdf`.
- `make test`: all fake-data tests pass (mhs-price-did, nfip-claims-es,
  take-up-imputation, welfare-arithmetic).
- `notes/specs.md` §15 and §16 added; §14's superseded outcome list marked as
  such in four places so it cannot be read as current.

### One correction worth recording

Colin proposed dropping `tab:water-depth-robustness` because it "adds almost
nothing to R2," inferring that water depth must be nearly constant within a
county and loss year. **The premise is false**, and it was checked before
acting rather than after. On the estimation sample, of the 7 depth bins the
average claim sits in a cell containing 6.0 of them, and only 4.1% of claims
are in a cell where every claim falls in one bin; a continuous version,
`water_depth ~ 1 | countyfp^year_loss`, has an R2 of 0.11, so about 89% of
the depth variance is within-cell. The control therefore has ample variation,
which is what makes the table informative — `post_mh` moves only
-5.75 → -5.15 → -5.26 across the three columns despite a control that
genuinely varies. Incremental R2 is the wrong diagnostic: the relevant
questions are whether the covariate varies within cell and whether the
coefficient is stable, and both are satisfied. The small R2 gain says depth
explains little of the *claim-to-claim* variance in damage once the cell is
absorbed, because single-claim damage is governed mainly by home size and
value; depth predicts the mean damage level, which is what
`fig:damage-function` already shows. Table kept, per Colin's call after seeing
the diagnostic, and the appendix now states the point explicitly so a reader
does not repeat the inference.

### Open questions for check-in

1. `contents_damage_static` moving $554 per claim on the winsorization cap is
   the largest single sensitivity introduced here, and it flows into the BCR.
   `MAX_CLAIM_LOSS = 1000` is deliberately generous (the NFIP contents limit
   is 100); a tighter cap would move it further. Confirm 1000 is the rule you
   want, or name a different one.
2. Replacement cost in logs drops the 5.6% of policy terms recording an exact
   zero. I read a $0 replacement cost on an insured single-family home as a
   recording convention rather than a fact, but that is a judgment call.
3. `building_damage_share` is still estimated and exported purely for
   `notes/apps/abstract-appam.Rmd`. If the APPAM abstract no longer needs it,
   the whole outcome can come out of the script.

---

## Chunk K — Water-depth robustness for building damage (2026-08-26)

Branch `chunk-k-water-depth-robustness`, off `main` (post Chunk J). Colin's
request: pick up the first bullet of `TODO.md`'s Chunk K — "non-parametric
water-depth controls and depth-bin × MH interactions, plus a damage-function
figure. Handle the post-1994 rise in MH water-depth missingness" — as a new
appendix table, columns (1) baseline, (2) + water depth, (3) another spec.
The single-family-restriction bullet under the same TODO heading was already
done in the Chunk J session; the trim/winsorize bullet is untouched.

### What changed

`estimate-nfip.R` (`program/estimate/estimate-nfip.R`):

1. **`water_depth_bin`:** six non-parametric bins on `water_depth` — below
   the lowest floor; 0-1, 1-2, 2-4, 4-8 ft above it; 8+ ft — plus an
   explicit `"Missing"` bin, built on `dt_claims` so it is available
   everywhere `dt_claims_est` is used. The top bin also catches a data
   quality issue found while designing the bins: a sharp spike of 1,576
   claims at exactly `water_depth == 99`, ~50x the count at neighboring
   values and physically implausible as a real flood depth — almost
   certainly a top-coded sentinel in the source field. Binning rather than
   using water depth linearly means this doesn't need a separate decision;
   it just lands in the top bin with the other severe/extreme readings.
2. **Missingness diagnostic (`dt_wd_miss`):** the rate is highest, and
   rises the most across the reform, for MH: 12.9% (pre-1994 MH) → 14.0%
   (post-1994 MH) vs. 9.8% → 10.0% for site-built. This is the cell the
   composition concern in "Selection and Composition" is about, which is
   why a linear control (which would listwise-delete these rows) was
   rejected in favor of the bin approach.
3. **Rewrote `fmla_rob_a`-`d` as `fmla_rob_a`-`c`, and switched from event
   study to static.** The old three-column-plus-baseline event-study table
   (`i(period_constr, mh, ref = ...) | geo^period_loss + mh`, optionally `+
   water_depth + elevated + sfha`, optionally tract FE) had three
   independent problems, none caught before because the table was never
   wired into `paper.Rmd`: it used `period_loss` where the main spec uses
   `year_loss`, it was missing the `period_constr`/`post1994` FE entirely
   (the bug Chunk B flagged and assigned to whoever next touched this
   table), and `fmla_rob_b`'s formula had a literal duplicated
   `water_depth` term (`water_depth + elevated + sfha + water_depth`).
   Replaced with a static `post_mh` spec matching `fmla_static` exactly —
   `building_damage ~ post_mh | geo^year_loss + mh + post1994` — so column
   (1) is not just similar to but bit-identical to the headline
   `building_damage_static` (both estimate to -5.5567272527661, SE
   1.46084170890248; verified by comparing the two scalars after a run,
   not just eyeballing rounded table output). Column (2) adds
   `water_depth_bin` as a fixed effect (non-parametric, absorbs the
   average damage level in each bin). Column (3) additionally adds
   `i(water_depth_bin, mh, ref = "[0,1) ft")`, letting the damage-depth
   relationship itself differ by housing type, identifying `post_mh` off
   within-depth-bin, within-housing-type variation alone. A `stopifnot` on
   `nobs()` asserts N is identical across all three columns — true by
   construction once "Missing" is its own bin rather than a dropped value,
   and a cheap check that the bin approach is doing what it claims.
   Retired the tract-FE columns (already covered by `fmla_geo_rob`/
   `tab:geo-robustness`, separately still commented out pending Colin's
   review — untouched here). `est_geo_rob` still has the
   `period_constr`/`year_loss` issue Chunk B flagged; out of scope since
   this chunk only touched `fmla_rob_a`-`c`.
4. **Table output.** `etable(..., keep_raw = "post_mh", headers =
   names(est_rob_list))` — `keep_raw` (not `keep`) because `post_mh` has a
   dictionary entry, and fixest's `keep` matches pre-dictionary names by
   default; `headers = names(est_rob_list)` because a named list's names
   are NOT used as column headers in `etable`'s `tex = TRUE` mode by
   default (they are in the console-print default), which needed a quick
   throwaway check against a toy `fixest` example to confirm before relying
   on it. Output path unchanged (`output/event-study/countyfp/robustness.tex`)
   since nothing else referenced it.
5. **Damage-function figure.** Replaced the old `plot_es_multi(est_rob_list,
   ...)` call (which required the event-study coefficient shape the
   rewritten `est_rob_list` no longer has) with a new plot: raw mean
   `building_damage` by `water_depth_bin` × `mh` (excluding `"Missing"`,
   which has no position on a depth axis), with 95% CIs from the
   within-cell standard deviation. Depth-ordered on the x-axis (`<0 ft` →
   `>=8 ft`) — note this is a *different* factor level order than the
   regression's reference-level ordering (`"[0,1) ft"` first, for the
   `i()` reference), so the plotting code re-levels a copy rather than
   reusing the regression's factor. Output:
   `output/event-study/countyfp/damage-function.pdf`.
6. **New scalars in `nfip-scalars.csv`:** the four missingness rates and
   the three columns' `post_mh` estimate/SE
   (`building_damage_static_rob_{base,depth,depthx}[_se]`).
7. **Dictionary additions:** `post1994` → "Post-1994", `water_depth_bin` →
   "Water depth bin". These are used by every table with a `post1994` FE,
   not just this one, so `claims-outcomes-static.tex` and
   `take-up-static.tex`'s FE-row label changed from the raw `post1994` to
   "Post-1994" as a side effect — cosmetic only, no point estimates
   touched (diffed both files to confirm).

`paper.Rmd`: new appendix section `# Water Depth and the Damage Function
{#appendix-water-depth}`, placed after the take-up appendix's caveat
subsection and before "Price Effects by Home Size" (benefit-side material
grouped with benefit-side material, ahead of the cost-side appendices). New
Table `tab:water-depth-robustness` and Figure `fig:damage-function`. A new
paragraph in "Selection and Composition" (main text) flags the depth-based
version of the composition concern and points to the appendix rather than
arguing it in place, matching how the take-up appendix is referenced
elsewhere in that section.

### Result

The static building-damage effect is stable across all three columns:
**baseline -$5,557 (SE $1,461) → +water-depth-bins -$4,951 (SE $1,321) →
+depth-bins×MH -$5,071 (SE $1,314)**. All three significant at 1%. The
damage-function figure shows why the interaction column barely moves the
estimate: damage rises with water depth for both housing types (as
expected), but visibly more steeply for site-built than for manufactured
homes — a level and slope difference the depth-bin×MH interaction absorbs,
without disturbing the treatment estimate. Read together with "Selection
and Composition"'s existing findings (composition, where it moves at all,
moves in a direction that works against the result), this closes the most
obvious remaining channel by which the building-damage estimate could be a
composition artifact rather than a construction-quality effect: it is not
explained by manufactured and site-built homes being flooded to
systematically different depths.

### Verified

`make estimates` (just `estimate-nfip.R`, standalone) runs clean, no
errors, no new `fixest` warnings beyond the pre-existing ones (singleton FE
removal, LHS-NA removal on `building_damage_share`, both present before
this chunk). `make test` passes (fake-data harness is independent of this
change — it does not touch `impute-stock.R`, take-up, or the claims
event-study spec this chunk didn't modify). `make paper.pdf` builds clean
from a fresh render; spot-checked the rendered PDF text for the new
section, table, and figure and confirmed the two prose numbers that quote
the baseline column ($5,557/$1,461) match the existing headline exactly.

### Open questions

- The TODO bullet's stated missingness figure was "rises to 16%"; the
  actual computed rate on the current (post-Chunk-J single-family-restricted)
  sample is 14.0% for post-1994 MH. Reported the measured number in the
  paper rather than chasing the discrepancy — plausibly the TODO figure
  predates Chunk J's occupancy restriction, which changed the claims sample
  composition, but this isn't confirmed.
- Whether the ≥99 ft spike is truly a sentinel (vs. a small number of real
  extreme floods) is not confirmed against FEMA's data dictionary; the bin
  design sidesteps needing to decide, but a reviewer asking directly "what
  is water_depth == 99?" would not be answered by anything in this chunk.
- `est_geo_rob`/`tab:geo-robustness` still carries the FE bug Chunk B
  flagged in 2026-08-12 and assigned to "whichever chunk writes up that
  section." This chunk fixed the water-depth table's copy of the same bug
  but left the geography table's copy alone, since it's a separate,
  still-commented-out table outside this chunk's scope.
- The remaining Chunk K/F bullet (winsorize/trim `building_value` for the
  `building_damage_share` outcome) is untouched.

## Chunk J — Single-family occupancy restriction and policy-level composition table (2026-08-26)

Branch `chunk-j-policy-composition`, off `chunk-i-window-claim-rate`. Colin's
request: align the claims and policy samples on a shared single-family
occupancy restriction (Chunk I-b had diagnosed but not fixed this — see its
entry below and `notes/specs.md` §12.2's "for the record" note), then
implement Chunk J's policy-level composition table.

### Occupancy restriction, both samples

`OCCUPANCY_TYPE_SF <- c(1L, 11L, 14L)` added to `project-params.R` (legacy
single-family code 1, RR2.0 single-family code 11, RR2.0 residential-MH code
14 — see the file for the full code-list rationale) and applied as
`occupancy_type IN (...)` in both SQL queries in `databuild-nfip.R`, plus
the new policy-micro query below. A `stopifnot` after the claims query
checks the restriction actually landed, since the SQL `WHERE` clause is the
only thing enforcing it.

Rebuilt `derived/nfip-claims.Rds` and `derived/nfip-balanced.Rds` against
research-database (`NFIP_VERSION` unchanged). Site-built claims fall
1,816,724 → 1,492,255 (-17.9%); MH claims fall 25,798 → 25,294 (-2.0%) —
the floors-only filter had let 2-4 unit, 5+ unit, condo-association, and
non-residential rows into the site-built group, and non-residential MH rows
into the MH group. Sanity checks: uniqueness of the balanced panel on
`(tractfp, period_loss, mh, year_constr)`, zero missingness on the ID/date
columns, `occupancy_type` restricted to `{1, 11, 14}` on both sides, no
negative counts, existing `assert_geo_coverage`/`assert_geo_coverage_any`
checks unchanged. `make test` passes (fake-data harness, independent of
this restriction).

**Effect on headline numbers.** `building_damage_static` (Table
`tab:claims-outcomes-static`) moves from $4,110 to **-5,557 (SE 1,461)** —
larger in magnitude, as expected from removing a noisier tail from the
comparison group. The take-up artifact from Chunk I-b's fix
(`policies_per_1k_homes_yr_static`, +8.12 (2.71)) moves to **+4.65 (2.24,
t=2.08)** — still positive and significant at 5%, so the reversed-sign
take-up finding survives, at roughly half the earlier magnitude. Full
detail and the complete new scalar set: `notes/specs.md` §13.

**Not rebuilt:** `estimate-mhs.R` (blocked by a pre-existing missing
`derived/mhs-dropped-states.Rds`, needs `databuild-mhs.R`, unrelated to this
change) and `program/descriptives/map.R` (blocked by a pre-existing missing
`tigris` package). Neither depends on the NFIP occupancy restriction — both
are environment gaps in this sandbox, not introduced here. Everything else
in `make estimates` (`estimate-nfip.R`, `estimate-welfare.R`,
`estimate-sumstats-nfip.R`, `plot-nfip.R`) was re-run and completed without
error.

### Chunk J: policy-level composition table

New `program/import/databuild-nfip-policy.R` → `derived/nfip-policy-micro.parquet`,
one row per policy term (12,787,544 terms, 266,312 MH), same filters as
`databuild-nfip.R`'s policy query (now including the occupancy restriction
above), same construction-year window, restricted to calendar years
2009-2023 and deflated to 2000 dollars. Added to the `data` Makefile target.

`estimate-nfip.R`'s cell-level composition fit (`est_comp_post`, weighted
OLS on cell averages) is removed and replaced with a fit run directly on
the policy microdata: `c(repl_cost, building_policy_covg,
contents_covg_positive, contents_policy_covg_pos, elevated_policy,
sfha_policy) ~ i(period_constr, mh, ref = 1992) | countyfp^period_loss + mh
+ period_constr`, clustered by county, unweighted (no cell aggregation to
re-weight against). Added the contents-coverage choice margin the TODO
asked for: an indicator for carrying any contents coverage, and the amount
conditional on carrying it. 31.9% of MH policy terms carry no contents
coverage vs. 13.5% of site-built, in the 30-35% range the TODO anticipated.
Output file name and table label (`policy-composition.tex`, `tab:composition`)
kept the same, so `paper.Rmd`'s `\input`/`\ref` needed no path changes.

**Result.** Pre-1994: replacement cost and contents coverage (conditional
amount) show a large MH-site-built gap in the earliest bin that shrinks to
insignificant by 1990-1991, same shape as the old table's coverage columns.
SFHA share is a new finding at this level of detail: significantly *lower*
for MH in three of four pre-1994 bins, and it does not shrink toward the
reference bin the way the other two do — a genuine pre-trend concern for
that one outcome. Post-1994: building coverage, replacement cost (first two
of three bins), and SFHA share are all significantly *higher* for MH, all
three pointing toward higher, not lower, expected damage for the treated
group. This is one more outcome pointing that direction than the old
two-outcome table, so the paper's conservative-bias reading in "Selection
and Composition" is if anything strengthened, not weakened, by the more
careful design. Elevated share rises only in the last post-1994 bin,
unchanged from before, so Chunk D's mechanism-split comment referencing that
timing did not need to change. Rewrote the "Selection and Composition"
section's four paragraphs to match the new table; renumbered nothing else.

`paper.Rmd` also gets a sentence in "Final Sample" describing the
single-family restriction and noting the composition table's separate
policy-term-level extract, and updated table notes for the new six-column
structure. Full `make estimates` + `rmarkdown::render('paper.Rmd')` run
clean to a rebuilt `paper.pdf` with no errors or missing-scalar failures.

### Verified

- `make test` — all fake-data tests pass, unaffected by any of the above.
- `databuild-nfip.R` and `databuild-nfip-policy.R` — both run clean against
  research-database; sanity checks above.
- `estimate-nfip.R`, `estimate-welfare.R`, `estimate-sumstats-nfip.R`,
  `plot-nfip.R` — re-run clean against the new derived data.
- `rmarkdown::render('paper.Rmd')` — clean, `paper.pdf` rebuilt, table
  renders with the expected six columns.

### Open questions for check-in

1. The SFHA pre-trend noted above (significantly negative in 3 of 4
   pre-1994 bins, not shrinking toward the reference bin) is a genuinely
   new finding versus the pre-restriction table, which showed no comparable
   pre-1994 SFHA pattern. Worth a sentence flagging it as a caveat on the
   parallel-trends assumption specifically for that outcome (currently
   included in "Selection and Composition"), or should it be investigated
   further (e.g., whether it is itself a multi-family/occupancy artifact in
   the *pre*-restriction years, given the restriction was diagnosed on
   post-1994 vintages)?
2. `estimate-mhs.R` and `program/descriptives/map.R` remain blocked by
   pre-existing environment gaps (`derived/mhs-dropped-states.Rds`,
   `tigris`) unrelated to this chunk. Flagging in case a machine with a
   complete environment is wanted before the next merge, so the cost-side
   (Chunk C) numbers and the map figure can be confirmed unaffected by the
   NFIP occupancy restriction (they should be — neither reads NFIP data —
   but this was not empirically checked this session).
3. Every prior chunk's damage/take-up point estimates (Chunks A, C1, D, E,
   I, I-b) now describe a sample that no longer exists at those exact
   numbers, since the occupancy restriction changed the underlying claims
   and policy data. This session updated `notes/specs.md` and the headline
   claims/take-up numbers it feeds into `paper.Rmd`, but did not re-audit
   every number in every other section of the paper (e.g., Chunk D's
   mechanism-split table, Chunk E's summary statistics) against the new
   sample — `make estimates` regenerated their `.tex`/`.csv` outputs, so
   `paper.Rmd` is internally consistent, but the *prose* describing those
   other tables was not re-read against the refreshed numbers the way
   "Selection and Composition" was here. Worth a pass before APPAM if this
   merges.

---

## Chunk I-b — Two take-up denominator defects, and the mandatory-purchase question (2026-08-26)

Branch `mhs-fixed-weight-index`. Two questions from Colin: (1) does the
site-built take-up jump at the 1994/1995 vintage boundary come from
mandatory-purchase policies, and if so should there be a non-mandatory-only
version; (2) does the multi-family contamination noted for the policy sample
also affect the claims data, and what exactly are the current filters. The
first question turned out to have a different answer than expected, because
checking it surfaced two defects in the take-up denominator that between them
were producing the jump.

### Answer to (1): no, and the specification is not needed

Split column (1)'s numerator into `mandatory_purchase_policy_n` and its
complement, same denominator, weights, fixed effects and clustering, so the two
coefficients sum to the total. Mandated **+0.79 (0.20)**, non-mandated **+7.33
(2.56)**: about nine-tenths of the movement is in policies the homeowner was not
required to buy. A non-mandatory-only version would therefore give essentially
the same answer, so it is not worth a separate column. One caveat: the flag
marks only 4–9% of policy-years, well below the SFHA share in the same cells, so
it under-records mandate exposure and the split is a lower bound on the mandated
part. This closes the open NFIRA item under Chunk I — the National Flood
Insurance Reform Act of 1994 explanation is now tested directly and rejected,
and the text asserting it is out of the paper.

### Answer to (2): yes, and on both sides, because the filter is on floors

The structure restriction is a *floors* filter, not an occupancy filter:
`number_of_floors_in_the_insured_building IN (1, 2, 3, 5)` on claims and
`number_of_floors_in_insured_building IN (1, 2, 3, 5)` on policies. Code 5 is the
manufactured-home category and is what defines `mh`; code 4 (split-level) is
excluded. Nothing in either query filters occupancy — `occupancy_type` is
selected but unused on the claims side and is not selected at all on the policies
side, which has to change before Chunk J's single-family restriction can be
applied there. So small multi-family and low-rise non-residential structures
enter the site-built comparison group in the claims data too. Tabulating the
1984–1999 claim sample: site-built claim rows are 83.6% single-family (codes 1
and 11), with the remaining 16.4% split across 2–4 unit, other residential and
non-residential categories; MH rows are 98.1% single-family or
residential-manufactured (codes 1 and 14), 1.3% non-residential (4) and 0.3%
non-residential manufactured (17). The full filter list, both sides, is written
into `notes/specs.md` §12.2 so it does not have to be re-derived.

### Defect A — within-bin shares normalized over retained years only

`impute-stock.R` allocates each Census 2000 county × vintage-bin total across
construction years using MHS placements (MH) and BPS single-family permits
(site-built). The Census bins are wider than the retained 1984–1999 window: the
`1980_1989` bin keeps only 1984–1989, `1990_1994` keeps 1990–1993, `1999_2000`
keeps 1999. The shares were computed *after* subsetting the annual sources to
the retained years, so they summed to one over the retained years and the full
bin total was spread across them. The dropped years' stock was silently
redistributed onto the years that remained, inflating 1984–1989 denominators by
about 1.5×, 1990–1993 by about 1.3× and 1999 by about 1.2×, while the fully
retained 1995–1998 bin was correct.

That is bias along the treatment split, not noise. It depressed measured
pre-reform take-up on both sides, and since the site-built rate is roughly four
times the MH rate it moved the comparison group's pre-reform level by about four
times as much in levels — which is exactly the "site-built jump at 1994/1995"
that prompted Colin's question.

The old adding-up test enshrined the defect: it asserted that the retained years
sum to the full Census bin total, which is precisely what should not hold.

Fixed with a new `bin_span` table listing every construction year each bin
spans, with a partial-year weight (the last Census bin is "1999 to March 2000",
so 2000 enters at 3/12). Shares normalize over the span and are then subset, so
a partly retained bin contributes only its retained fraction. Validation was
restructured rather than relaxed: the exact invariant (shares sum to one over
the full span, per state × bin for MH and per county × bin for site-built) now
lives in the share-construction blocks where it belongs, and the allocation-step
test became a bound — retained years never exceed the bin total, fully retained
bins match exactly — plus a printed realized-versus-year-count retained
fraction. My first attempt asserted the *mechanical* year-count fraction as an
exact target and failed: the shares are source-proportional, so the realized
retained fraction is placements- and permits-weighted (0.61–0.67 for
`1980_1989`, 0.74–0.77 for `1990_1994`, 0.81–0.83 for `1999_2000`), not the
0.6/0.8/0.8 the year counts imply. The report now shows both side by side. The
national benchmark moves from ratio 0.95 to 0.75 against cumulative MHS
shipments, which is the expected direction: the imputed stock is now a
Census-2000 surviving stock net of the dropped 1994 year rather than an inflated
one.

### Defect B — the 1994 bin mixed a two-year numerator with a one-year denominator

`dt_home_cell` was `dt_cell[!is.na(homes_n) & homes_n > 0]`. `dt_cell` sums
`policies_n` and `claims_n` over every construction year in a `period_constr`
bin, while `homes_n` is undefined for construction year 1994. The 1994 bin
therefore had a numerator covering 1994 and 1995 over a denominator covering
1995 alone. Construction year 1994 supplies 48.5% of that bin's site-built
policy-years and 45.3% of its MH policy-years, so the bin's measured rate was
inflated about 1.9× — again mostly on the comparison group in levels, and again
at exactly the treatment boundary. Chunk I's own specs note asserted this was
already handled; it was true of the denominator only.

`dt_home_cell` is now rebuilt from the row level: the set of `(county,
construction year, type)` cells with a positive `homes_n` is computed first, the
numerator is the row-level panel inner-joined to it, and the denominator comes
from the same rows, deduped on the county key before summing since `homes_n` is
tract-duplicated by the section-5.5 merge. `stopifnot` asserts that no
construction year 1994 survives on either side. The per-home rate columns were
deleted from `dt_cell`, where they were unsafe by construction.

### What this does to the results

The static take-up estimate moves −4.88 (3.06) → +3.62 (2.93) after fix A →
**+8.12 (2.71)** after fix B. Claims per 1,000 homes per year: 0.018 (0.040) →
**+0.110 (0.055)**. Claims per policy is essentially unmoved — 0.00064 → 0.00055,
SE 0.00065, still insignificant — because it never used `homes_n`. The 1994-bin
event-study coefficient in column (1) moves −35.5 → −28.0 → −4.34. N falls
73,487 → 71,492. The claim-level damage results and the whole of
`estimate-welfare.R` are untouched: neither uses the housing-stock denominator,
so the cost-benefit numbers in the abstract are unaffected.

The sign is now reversed. Post-1994 MH take-up is *higher*, not lower, and since
claims per policy is flat the decomposition identity assigns nearly all of the
claims-per-home rise to the take-up margin — the opposite of the crowding-out
story the earlier text told.

### How the paper reports it

Descriptively, not causally, with three limitations stated in the text rather
than in a footnote:

1. The vintage profile trends rather than steps. The earliest pre-reform bin is
   −14.2 (3.05) and significant, so a level shift at 1994 is not what column (1)
   shows.
2. The sign depends on the geographic fixed effects. The same contrast without
   them is −2.05 (1.49), because MH stock concentrates in counties whose overall
   take-up rose least. This also means the four pooled levels (MH 10.2 → 9.6,
   site-built 40.3 → 41.8) do **not** decompose the fitted coefficient the way
   Chunk I's text claimed; that claim is gone.
3. The denominator is imputed from a single 2000 Census cross-section while the
   numerator is administrative.

Also added a paragraph to Selection and Composition on the insured-pool-size
channel, whose sign is not determined: more MH policies could mean either
better-informed owners of better-built homes or a wider pool including
marginal risks.

### Open item this leaves

The trending pre-period in column (1) is unexplained. A monotone pre-1994
profile in a take-up *rate* is what differential survivorship in a
Census-2000-anchored denominator would produce — older vintages have lost more
stock, and differentially by housing type — rather than anything about the 1994
standard. Bounding it needs a vintage-specific attrition estimate, which is the
same ACS continuous-vintage series already open under Chunk E's caveat. Until
that exists, column (1) stays descriptive. Filed under Chunk I-b in `TODO.md`.

### Verification

`estimate-nfip.R` runs clean end-to-end against the patched panel (the standing
`$DATA_PATH` limitation means `databuild-nfip.R` itself is not re-run here, same
as every prior chunk); `impute-stock.R` runs clean with the new invariants;
`make test` passes; `paper.pdf` re-renders with no unresolved references. Six
throwaway diagnostics under `/tmp` (mandatory-purchase split, denominator
levels, occupancy tabulation, the 1994-bin decomposition) are not committed.

One process note worth recording: my first pass at the hand-computed take-up
levels disagreed with the script's scalars by a factor of two, because the
diagnostic summed `homes_n` across tract rows. The estimation code dedupes to
county level first and was right; the diagnostic was wrong. The section-5.5
comment in `databuild-nfip.R` says this explicitly, and it is worth reading
before writing any new diagnostic that touches `homes_n`.

---

## Chunk I — Vintage window 1984–1999, annualized take-up, and p(claim | policy) (2026-08-26)

Branch `chunk-i-window-claim-rate`. Four requests: move the effect window to
1984–1999, add p(claim | policy) to the take-up table, revisit the policy
composition results, and begin on how much of the damage decline is
composition versus technology. The last of these is Chunks J and K; this memo
covers the first three plus several defects found on the way.

### What changed

**1. Window is 1984–1999.** `MIN_YEAR_CONSTR` moved 1983 → 1984 in
`project-params.R`. Two reasons, both in the file's comment: with two-year bins
anchored so 1992–1993 is the last pre-treatment bin, a 1983 start left one bin
holding a single construction year, and 1984–1999 coincides exactly with the
range over which the take-up denominator `homes_n` is defined (no source
separates 1980–1983 inside the Census `1980_1989` bin; 1999 is the last vintage
with a value). Colin's instruction was to stop at 1999, which removes the
2000-bin question entirely and means no new stock imputation was needed.

`databuild-nfip.R` had its own `year_min`/`year_max` literals; it now reads the
parameters, so the panel grid and the estimation-time restriction cannot drift
apart. Both `derived/nfip-claims.Rds` and `derived/nfip-balanced.Rds` were
rebuilt against research-database (`NFIP_VERSION` v2026-08-15, unchanged):
1,842,522 claims (25,798 MH), balanced panel 5,591,840 rows over 67,357 tracts
and 16 construction years. Event-study coefficients per outcome are now 7, not
8. `paper.Rmd` claimed "eleven" in two places; corrected to seven.

**2. The per-home take-up outcomes were not rates.** `policies_n` counts policy
*years* summed over the five calendar years of a `period_loss` bin, so
`policies_per_1k_homes` and `claims_per_1k_homes` were five-year cumulative
counts carrying a per-period label, and the appendix read them as rates. Both
are now divided by `homes_n * N_YEARS_PERIOD` and renamed with a `_yr` suffix.
Point estimates are the old ones ÷ 5. `N_YEARS_PERIOD = 5L` is asserted against
the data rather than assumed: every retained `period_loss` bin must be exactly
five years wide and the last must end at `MAX_YEAR_LOSS`.

Relatedly, `paper.Rmd`'s panel description said each cell "reports the number of
unique policies active at any time during the period." There is no policy
identifier in the file and nothing counts distinct policies; the cell counts
policy terms assigned to a calendar year by their coverage midpoint. Corrected,
with the midpoint rule stated.

**3. p(claim | policy) is now column (3).** `claim_rate` was already estimated
and plotted (`est_pclaim_es`, `es-claim-rate.pdf`) but never tabled. Colin chose
Table 6 column 3 with all columns annualized, which makes the three columns an
exact decomposition:

    claims/home = policies/home × claims/policy

To keep that identity from being broken by a sample difference, the claim-rate
fits run on `dt_home_cell` (the `homes_n > 0` subsample) rather than the wider
`dt_cell`, so all three columns use the same 73,487 cells. This matters at the
1994 bin, which spans construction years 1994–1995: `homes_n` is undefined for
1994, so on the common sample that bin is construction year 1995 alone in every
column. Weights still differ by column (`homes_n` for (1)–(2), `policies_n` for
(3)) and cannot be pooled into one fit, so the table is two `feols` calls
combined in one `etable`; `depvar = FALSE` suppresses the list names, so column
headers come from `headers`.

A static counterpart, `tab:take-up-static`, was added, matching §2's convention
of quoting the single `post_mh` coefficient as the headline.

**Result on the margin that matters: claim frequency is flat.** Static +0.64
claims per 1,000 policy-years (SE 0.65) against a pre-1994 MH rate of 14.7, and
no vintage bin is individually significant. Claims per 1,000 homes per year is
also indistinguishable from zero (+0.018, SE 0.040, baseline 0.095). Since
`estimate-welfare.R` uses exactly this hazard rate, the cost-benefit's
assumption of a constant claim rate now has direct support, and the whole of the
estimated benefit comes from severity rather than frequency. This is stated in
§6.1 as well as the appendix.

**4. Four cell-level fits reported IID standard errors.** `est_pclaim_es`,
`est_comp_post`, `est_share_es` and `est_pois_es` passed no `cluster` argument,
so `fixest` defaulted to IID — while both `paper.Rmd`'s notes for Tables 3 and 4
and `notes/specs.md` §3 stated the SEs were clustered. This is the same defect
Chunk C1 fixed on the claim-level side; the cell side was missed then. Now
`cluster = ~geo`. SEs widen materially and several previously-significant
post-1994 composition coefficients no longer clear conventional levels, which
forced the next item.

**5. "Selection and Composition" was rewritten.** The old text asserted that
post-1994 MH policies have higher replacement cost ($20–30k), higher building
coverage ($8–15k) *and* higher contents coverage ($1–2k), and read the damage
estimates as a lower bound on that basis. The table does not show that. What it
shows, and what the section now says:

- The large coefficients are *pre-1994*: MH building coverage is much lower and
  contents coverage modestly higher for mid-1980s vintages relative to the
  1992–1993 reference, shrinking to roughly a quarter of that size by 1990–1991.
  These movements are complete before treatment, so they cannot be an effect of
  the reform, but they do mean the coverage columns have non-flat pre-trends,
  and the section says so rather than claiming flatness the table contradicts.
- The *post-1994* coverage shifts are small and mostly insignificant, and
  opposite in sign to the mid-1980s gaps.
- The one clean post-1994 shift is location: SFHA share rises monotonically and
  significantly across all three post bins.

The direction-of-bias argument survives but now rests on SFHA concentration and
the modest coverage increases rather than on the coverage claims that did not
hold. The intro's "comprise a lower bound on the true treatment effect"
sentence is replaced with the weaker and accurate "run against the estimated
damage reductions rather than producing them," and the section says explicitly
that it is not offering a quantitative bound. The table notes also described
`Primary res.` and `Mandatory` columns that are commented out of the outcome
list and have not appeared in the table for some time.

**6. Take-up column (1) is an artifact and is now labelled as one.** Its static
coefficient is −4.9 annual policies per 1,000 homes against a pre-1994 MH level
of 6.4, and the 1994–1995 bin is −35.5 — a decline larger than the level, which
is impossible as stated. It is not a decline. MH take-up *rises* across the
vintage boundary, 6.4 → 10.2 annual policies per 1,000 homes; site-built rises
28.3 → 47.0; the coefficient is the difference net of the county × period fixed
effects. Four new level scalars
(`policies_per_1k_homes_yr_{mh,sb}_{pre,post}`) let the appendix quote all four
levels so the coefficient cannot be misread.

The site-built jump lands exactly at the 1994/1995 vintage boundary and is
common to both housing types, which does not look like construction quality.
The candidate explanation offered in the paper is the National Flood Insurance
Reform Act of 1994: homes built from 1995 on were first financed under
strengthened mandatory-purchase enforcement, and chattel-financed MH are
largely outside federally related lending — which the paper already argues in
§3.2 as the reason MH take-up is low overall. Under that reading column (1)
measures differential exposure to a contemporaneous mandate, not a demand
response to the HUD standard, and it is not evidence on self-protection
crowding out insurance. **This is asserted as a candidate explanation, not
tested** — see open questions.

### Verified

- `make test` passes (`mhs-price-did`, `nfip-claims-es`, `take-up-imputation`,
  `welfare-arithmetic`).
- Full chain rerun in dependency order against the rebuilt panel:
  `databuild-nfip.R` → `databuild-welfare.R` → `estimate-nfip.R` →
  `estimate-welfare.R` → `estimate-sumstats-nfip.R` → `plot-nfip.R`, then
  `paper.Rmd`. No errors; `paper.pdf` renders with no unresolved references.
- The import layer ran for real this time. Earlier chunks could not run
  `databuild-nfip.R` (no `$DATA_PATH`); the research-database parquet cache is
  available in this sandbox, so §12's standing "not covered by this chunk" note
  about the real `databuild-nfip.R` run is now closed for the NFIP path.
- Decomposition identity checked in units: with all three outcomes annual and
  estimated on the same 73,487 cells, columns (1)–(3) are consistent.
- Take-up levels cross-checked outside the regression: the `homes_n`-weighted
  mean of cell ratios equals the pooled ratio of summed policies to summed
  home-years, so the four quoted levels are exactly the quantities the fit
  differences.

### Open questions for Colin

1. **NFIRA 1994 is asserted, not tested.** Separating it from other differences
   specific to 1995+ vintages needs mortgage-origination timing or variation in
   the mandatory-purchase flag — which is in the policy file but commented out
   of the composition spec. If column (1) stays in the paper it deserves a
   paragraph of evidence rather than a plausible story. Alternatively, drop
   column (1) and present only the two margins that are interpretable.
2. **`estimate-welfare.R` takes its deltas from the event-study average while
   the paper's headline is the static estimate.** Pre-existing and unchanged
   here, but now conspicuous: the abstract quotes $4.11k for building damage
   (static) while the cost-benefit applies $4.88k (event-study average).
   Contents runs the other way ($2.77k event-study, $4.07k static), so
   switching to static deltas throughout would raise the BCR from ~0.52 to
   ~0.56, not lower it. Same class of decision as Chunk C's open
   compliance-cost question; they should be settled together.
3. **The pre-1994 coverage trends are a real weakness, not just a text fix.**
   The rewritten section is honest about them, but "the pre-trends are not flat
   for coverage" invites the question of whether they are flat for damage
   because of power rather than because of parallel vintages. Chunk J's
   single-family restriction is the first thing to try, since the diagnostic
   behind the rewrite traced most of the 1980s coverage gap to a tail of
   multi-family and commercial policies in the site-built comparison group.
4. **`databuild-welfare.R`'s `1980_1989` Census bin now pairs with 1984–1989
   policies** rather than 1983–1989. Pre-existing mismatch between the Census
   vintage bin and the policy window, slightly changed by the new start year;
   not addressed here.

## Geographic coverage safeguards, and closing a second silent leak (2026-08-24)

Follow-up to the CT incident below, per Colin's request: turn the specific
CT fix into a general safeguard against the same failure mode (a default
inner-join merge against a geographic crosswalk silently drops rows instead
of producing a catchable NA), and confirmed Colin wants the sample's
existing scope (continental US, i.e. AK and HI both excluded, matching
`paper.Rmd`'s "I restrict both samples to the continental US") kept as-is
rather than expanded to include Hawaii.

**New `program/import/geo-coverage-checks.R`**, sourced by `databuild-nfip.R`,
`databuild-mhs.R`, `estimate-nfip.R`. `EXCLUDED_STATEFP <- c("02", "15")`
(AK, HI) documents the sample's own intentional exclusions. Two checks:
- `assert_geo_coverage()`: zero tolerance -- fails loudly if any row outside
  `EXCLUDED_STATEFP` has an NA in the crosswalk column after a merge. For
  merges that should have complete coverage (wind zone).
- `assert_geo_coverage_any()`: per-FIPS-code tolerance -- fails only if a
  whole county has *no* non-NA rows at all, tolerating documented
  within-county sparsity (e.g. impute-stock.R's dropped 1994 construction
  year) while still catching a wholesale per-county drop. Takes an
  `allow_fips` list for individually-justified, commented exceptions --
  never a blanket suppression.

**Applied:**
- `databuild-nfip.R`'s wind-zone merge (the actual CT bug site): changed
  from a default inner join to `all.x = TRUE` + `assert_geo_coverage()`,
  replacing a `stopifnot(!anyNA(wind_zone))` that could never fire after an
  inner join (nothing to catch) with one that actually can.
- `databuild-nfip.R`'s housing-stock merge: added `assert_geo_coverage_any()`,
  allow-listing Broomfield County, CO (08014, created 2001, predates the
  Census 2000 stock by construction, not by gap).
- `databuild-mhs.R`'s wind-zone merge: swapped its already-correct
  `all.x = TRUE` + bare `stopifnot(!anyNA(...))` for the shared, more
  informative check (same behavior, consistent messaging).
- `estimate-nfip.R`'s Chunk D mechanism-decomposition wind-zone merge:
  same swap.

**Running the new stock-coverage check immediately caught a second, real,
pre-existing leak** (distinct from the CT bug -- not a crosswalk-coverage
gap, a sample-scope leak): 5 territory counties (Northern Mariana Islands
69110; Puerto Rico 72057/72113/72127/72145) were present in
`nfip-balanced.Rds` despite the SQL's `property_state NOT IN (...)` filter.
This is exactly the asymmetry already flagged and deferred in this log's
2026-08-21 entry: the policies SQL, unlike the claims SQL, had no
`tractfp`-derived guard, so a policy whose self-reported `property_state`
disagreed with its actual tract geography slipped through. Fixed by adding
the same `TRY_CAST(LEFT(tractfp, 2) AS INT) <= 56` guard the claims query
already had, and adding 'MP' (Northern Mariana Islands) to the
`property_state` exclusion list for defense in depth. `nfip-balanced.Rds`
shrank by 306 rows (7 tracts) as a result -- immaterial to any headline
number (territories were never in scope), but it closes a real gap, not
just an observed-and-parked one.

**Verified.** `make test` (4/4). Full pipeline re-run end to end;
`databuild-mhs.R`, `databuild-nfip.R`, `databuild-welfare.R`,
`estimate-mhs.R`, `estimate-nfip.R` all clean. `building_damage_static`
unchanged at -3.6397 (territory leakage was immaterial to any in-scope
estimate).

**Open question.** The two coverage checks are applied at the specific
merge sites known to have failed. Other crosswalk merges in the pipeline
(Census 2000 stock levels, BPS/MHS shares in `impute-stock.R`) already use
`all.x = TRUE` with their own explicit `stopifnot()`s and were not
retrofitted onto the shared helper, since they were not implicated in
either incident -- worth a pass if a third instance of this pattern
surfaces.

---

## Merge verification: chunk-b-review-fixes onto research-database, and a live CT bug (2026-08-24)

**What was done.** After merging `chunk-b-review-fixes` (Chunk D/E) onto
`main`'s research-database migration (merge commit, see git log), actually
ran the full pipeline in this sandbox (`RD_HOME`/`RD_CACHE` were present and
already populated -- earlier claiming otherwise in this session was wrong,
corrected after the user asked) rather than resting on `make test` alone.

**Found a live data-loss bug, not introduced by this merge.** `databuild-nfip.R`'s
inner join of the balanced panel onto `ecfr_wind_zone` (research-database,
pinned `ECFR_WIND_ZONE_VERSION`) silently dropped every Connecticut row
(17,717 claims, ~1% of the full sample) with no error: `ecfr_wind_zone`'s
import script filtered `geo_county` to `is_current == TRUE`, and Connecticut
retired its 8 counties for 9 planning regions in 2022, so none of the
pre-2022 county FIPS that NFIP claims/policies actually carry had a match.
An inner join on a coverage gap produces no NA, so `databuild-nfip.R`'s own
`stopifnot(!anyNA(wind_zone))` didn't catch it. The merged-in Chunk D
mechanism-decomposition block in `estimate-nfip.R` *did* crash on this (it
does a left join + assert against a since-orphaned local
`derived/ecfr-windzone.csv`, left over from the deleted
`import-ecfr-windzone.R`), which is what surfaced the issue.

**Fixed upstream, in `research-database` (commit `15f43b2`, fast-forwarded
to `main`, then re-run to overwrite the pinned `v2026-08-24` curated
version in place -- a same-snapshot logic fix, not a new eCFR amendment,
per Colin's call).** `program/ecfr/wind-zones/import.R` now builds its
county universe from all of `geo_county`, not just `is_current == TRUE`.
None of the newly-included historical FIPS codes (CT, plus scattered ones
in AK/MI/NM/SD/VA) are ever named in the eCFR Wind Zone II/III listings, so
they all fall through to the existing WZ1 residual rule -- verified WZ2/WZ3
counts are unchanged (144/30) before and after, only WZ1 grew (3,032→3,046;
3,206→3,220 counties total). Also fixed `estimate-nfip.R`'s Chunk D block
to read `rd_read("ecfr_wind_zone", version = ECFR_WIND_ZONE_VERSION)`
directly instead of the stale local CSV, and dropped its NYC-borough
fallback after confirming every countyfp in `nfip-claims.Rds` now matches
directly (0 unmatched, checked explicitly).

**What changed in outputs.** `nfip-balanced.Rds` grew from 5,957,310 to
6,023,134 rows (+727 tracts, all Connecticut) once CT could match. Headline
numbers moved negligibly: `building_damage_static` -3.640 (SE 1.658,
unchanged to 3 decimals from pre-fix), `price_effect_level` $4,194
(unchanged -- MHS treatment is state-level and CT already resolved to
untreated/Zone I either way), mechanism-split Zone III -6.434 vs. the
previously-recorded -6.57 (small movement, CT is Zone I so this is exactly
the kind of shift a coverage fix should produce and no more). Connecticut
remains a Zone I control state throughout, so this is a sample-completeness
fix, not a treatment-definition change.

**Verified.** `make test` (4/4, unchanged). Full pipeline re-run end to end
in this sandbox: `databuild-mhs.R`, `databuild-nfip.R`, `databuild-welfare.R`,
`impute-stock.R`, `estimate-mhs.R`, `estimate-nfip.R`, `estimate-welfare.R`,
all descriptive/plot scripts except `map.R` (fails on a missing `tigris`
package in this sandbox, pre-existing and unrelated -- `map.R` untouched by
either branch). `paper.pdf` could not be rendered in this sandbox (pandoc
1.12.3.1, predates the `--extract-media` flag `rmarkdown` now emits) -- an
environment gap, not a content issue; every number `paper.Rmd` would pull
in was independently verified against the regenerated scalar CSVs above.

**Open questions.** Whether other research-database-curated crosswalks this
project depends on (`geo_county` itself, `census_bps`, etc.) have similar
current-vintage-only gaps against this project's historical data is not
checked beyond `ecfr_wind_zone` -- worth a pass if another silent-drop
surfaces. The `research-database` fix widened coverage nationally (not just
CT), so other research-database consumers with historical data may have had
the same silent gap; worth flagging to whoever else uses that repo.

---

## Chunk D — Migrate program/import/ onto research-database (2026-08-21)

**Base commit:** 8219921. Full plan: `program/import/UPDATE.md`. Three
commits, per the plan's bisectable sequencing: BPS/MHS plumbing, NFIP onto
curated parquet, wind-zone crosswalk onto `geo_county`. CPI (§6.1) is
deliberately deferred — `$DATA_PATH` survives for that one file only.

**Environment note — no baseline to diff against.** This session's checkout
has no `derived/` directory and no `$DATA_PATH` access at all (unlike the
prior verification chunk's sandbox, which at least had an empty mount).
`UPDATE.md` §7's gate ("snapshot the baseline first, diff old vs new
`derived/*`") could not be executed as written — there is no old `derived/`
to diff against in this environment. What was verified instead: every
migrated script runs end-to-end against the real `research-database` cache
(pulled from S3 the first time); output row counts for the NFIP claims/
policy panel match `UPDATE.md`'s own stated verified benchmarks exactly
(1,842,522 claims, 25,798 MH, 68,107 tracts); `rd_check_id()` passes on
every `countyfp`/`tractfp`/`statefp` column produced; key uniqueness holds
on every panel artifact's declared key; cross-field consistency holds
(`countyfp`/`statefp` recomputed from `tractfp` match the merged columns
exactly); and the full downstream chain (`make test`, `estimate-mhs.R`,
`estimate-nfip.R`, `estimate-welfare.R`, `plot-mhs.R`, `plot-nfip.R`) runs
against the migrated `derived/*` without error. A real baseline diff still
needs to happen on a machine that has both this migration and the old
`$DATA_PATH` tree, before the headline numbers in `paper.Rmd` are updated.

**Update (same day):** `CENSUS_API_KEY` was added to `.Renviron` after the
above was written; `import-census.R` was re-run for real (3,141 counties,
8,779,228 total MH units from H030; 12,564 county x vintage cells, 4,395,673
MH units from HCT006), and `databuild-mhs.R`/`databuild-welfare.R` were
re-run against the real `census2000-mh-county-vintage.Rds` (welfare build:
24 of 11,696 county x vintage cells missing a Census MH count, a real and
expected small gap, not an error). Re-checked: key uniqueness and
`rd_check_id()` conformance still hold on both rebuilt artifacts.

**Update (same day): CPI resolved, §6.1 closed via option 1.** `research-database`
gained a real `bls_cpi` dataset (commit `71d9cdf`: `program/bls/download.R` +
`import.R`, pulling CUUR0000SA0/CUSR0000SA0 from the BLS Public Data API,
1913-01 through 2026-07). `import-cpi.R` now reads `bls_cpi` via `rd_read()`
instead of the `$DATA_PATH` workbook, taking `cpi_u_nsa_1982_84` (BLS's native
1982-84=100 index, one NA row dropped: 2025-10, a real appropriations-lapse
gap outside every window this project uses) rather than the catalog's own
2000-rebased column — the project's downstream `cpi / cpi[year ==
DISCOUNT_YEAR]` step in `databuild-mhs.R`/`databuild-nfip.R` still does its
own rebase, per §6.1's "indices are data, deflation is a function" principle;
the two are mathematically equivalent after that rebase, so the column choice
is about keeping the raw/rebase split honest, not about the numbers.
`$DATA_PATH` is no longer referenced anywhere in `program/import/`; `Makefile`'s
comment updated accordingly.

Re-ran `databuild-mhs.R`, `databuild-nfip.R`, and `databuild-welfare.R`
against the real deflator. Row counts are unchanged from the CPI-stub run
(expected — CPI only rescales dollar columns), `cpi[year == 2000] == 1`
exactly in `sample-mhs.Rds`, and all uniqueness/`rd_check_id()` checks still
pass. `make test` and `estimate-mhs.R`/`estimate-nfip.R`/`estimate-welfare.R`
all re-ran clean against real dollar figures (e.g. MHS `Dep. Var. mean`
recomputed from $35,279.7 under the flat-CPI stub to $41,515.7 under the real
deflator — expect this kind of change, this is the CPI stub finally coming
out). **`derived/` is now built entirely from real sources** (BPS, MHS,
Census, NFIP, wind-zone crosswalk, CPI) for the first time in this session —
no synthetic stand-ins remain. A real baseline diff against a pre-migration
`derived/` still has not been done (no such baseline exists in any
environment this session had access to); that is still the outstanding gate
before `paper.Rmd`'s headline numbers get updated.

**Noticed in passing, not touched (out of scope):** `program/estimate/estimate-mhs.R:12`
reads `Sys.getenv("DATA_PATH")` into `data_path` but never uses it — dead code,
same pattern as the `dt_state` dead read this chunk removed from
`databuild-mhs.R`. Outside `program/import/`, so left alone.

**Chunk 1 — BPS/MHS plumbing.** `import-bps.R` and `import-mhs.R` deleted;
`databuild-mhs.R` reads `census_bps`/`census_mhs_state_year` via `rd_read()`
and joins `geo_state` for `state_name` (no longer carried by
`census_mhs_state_year`); asserts `survey_era == "pre_2014"` for the
1985-2003 window, then drops the column so `sample-mhs.Rds`'s column set is
unchanged. `permits-co.Rds`/`mhs-state-year.Rds` are retired.

**Chunk 2 — NFIP onto curated parquet.** `databuild-nfip.R` queries
`fema_nfip_claims`/`fema_nfip_policies` (pinned `NFIP_VERSION =
"v2026-08-15"` in `project-params.R`) via `rd_con()`/`rd_path()` instead of
`$DATA_PATH/derived/fema.duckdb`. This is a v2 -> v3 OpenFEMA vintage change,
not just a rename — expect headline NFIP estimates to move once a real
baseline diff is run. `nfip-claims.Rds` row order is now pinned with
`setorder()` since a filtered parquet scan does not preserve file order.

**Chunk 3 — wind-zone crosswalk onto `geo_county`.** `import-ecfr-windzone.R`
now matches eCFR county names against `rd_read("geo_county")` (filtered to
`is_current == TRUE`) + `geo_state`, instead of
`Govt_Units_2021_Final.xlsx`. `norm()` gained suffix-stripping for
`geo_county`'s naming convention (" County", " Parish", " City", " Borough",
" Census Area", " Municipality", " City and Borough"); the `"ORLEANS" =
"NEW ORLEANS"` correction was dropped (Orleans Parish now matches directly);
the other three spelling corrections (Vermillion, La Fourche, Terrabonne)
and the Dade->Miami-Dade rename survive. Result: 3,206 counties (144 WZ2, 30
WZ3) — every US county except AK resolves, so the per-jurisdiction
`max(wind_zone)` collapse is now a no-op safety net rather than a real
collapse. Confirmed the `statefp == "36"` NYC-borough fallback in
`databuild-nfip.R` is dead (all five boroughs resolve to wind_zone 1 through
the normal path) and removed it in this chunk, as the plan specified.

**Update (2026-08-24): wind-zone crosswalk promoted upstream, §5.4/§6.3
closed.** `research-database` gained a real `ecfr_wind_zone` dataset
(commit `d954f1e`: `program/ecfr/wind-zones/download.R` + `import.R`,
`catalog/datasets/ecfr_wind_zone.yml`) — `import-ecfr-windzone.R`'s eCFR
scrape and `geo_county` matching logic from this chunk, ported essentially
verbatim onto the download/import split `principles.md` requires there.
`import-ecfr-windzone.R` is deleted here; `databuild-mhs.R` and
`databuild-nfip.R` now read `rd_read("ecfr_wind_zone", version =
ECFR_WIND_ZONE_VERSION)` (pinned `"v2026-08-24"` in `project-params.R`,
same rationale as `NFIP_VERSION`) instead of `fread("derived/ecfr-windzone.csv")`;
the `Makefile`'s `data:` target no longer runs the old script.

Verified as a true no-op: `rd_read("ecfr_wind_zone")` against the same eCFR
snapshot matches the old `derived/ecfr-windzone.csv` exactly — 3,206
counties, zero countyfp added or dropped, zero `wind_zone` values changed.
Re-ran `databuild-mhs.R` and `databuild-nfip.R`; `mhs-windzone-intensity.Rds`,
`sample-mhs.Rds`, `nfip-claims.Rds`, and `nfip-balanced.Rds` are all
`identical()` to their pre-swap versions (byte-for-byte, not just
`all.equal`). `make test` passes. §6.3's "keep the scrape local" call is
superseded by this — the wind-zone map is shared infrastructure now that a
second consumer (this project asked for it) exists.

**Observed, not fixed — out of scope for this chunk.** 238 of 5,957,310
`nfip-balanced.Rds` rows (0.004%) carry `statefp == "72"` (Puerto Rico).
These come entirely from the policies leg: unlike the claims query, the
original (pre-migration) policies SQL never had the
`TRY_CAST(LEFT(tractfp,2) AS INT) <= 56` guard, only a `propertyState NOT
IN (...)` filter — so a policy whose self-reported `propertyState` disagrees
with its tract's actual state slips through. This asymmetry predates the
migration and was preserved as-is (not part of `UPDATE.md`'s scope); flagging
for a future chunk.

---

**Merge note (2026-08-24):** this session's "Chunk D" label collides with
TODO.md's actual Chunk D (mechanism decomposition, still `[ ]` unstarted as
of this merge) — this entry is an infra migration done directly on `main`,
not lettered in TODO.md's plan. Left as originally written rather than
renamed, to avoid rewriting another session's log; flagging so the collision
doesn't read as the mechanism-decomposition chunk being done. The entry
below (Chunk E, 2026-08-13) predates this one and was merged in from
`chunk-b-review-fixes`; its base commit (73ebd07) predates this session's
research-database migration, so `impute-stock.R` and `databuild-nfip.R`'s
stock merge were written against the old `$DATA_PATH`-based import layer —
see the merge commit for how that was reconciled onto `rd_read()`.

---

## Chunk E — Housing-stock denominator and the take-up margin (2026-08-13)

**Base commit:** 73ebd07 (Chunk C committed). Note: a peer session was
working Chunk D (mechanism decomposition) in the same working tree
concurrently — its uncommitted `estimate-nfip.R` additions (insurance-
accounting outcomes, sample splits) were already on disk when this chunk
started and are left untouched; this chunk's edits are additive to a
different part of the same file. Diff review should distinguish the two by
section header (`# mechanism decomposition (Chunk D)` vs. the take-up
blocks below).

### What was done

Replaced `policies_ppermit` (policies ÷ single-family building permits —
wrong housing type, and BPS coverage of the site-built stock falls from a
median 0.70 in low-MH counties to 0.20 in high-MH counties, exactly where
MH concentrate) with `policies_per_home` / a `homes_n`-offset PPML, per
TODO.md Chunk E.

- **New `program/import/impute-stock.R`.** Builds
  `derived/stock-county-vintage.Rds` (`countyfp x year_constr x mh`,
  `homes_n`), covering construction years 1984-1999. Levels from Census
  2000 (`mh_units`, `total_units - mh_units`); within a Census vintage bin,
  annual allocation uses MHS state-year placements (MH, broadcast to every
  county in the state) and BPS county-year single-family permits
  (site-built), falling back to the state permit share where a county
  reports zero/missing permits in the bin. 1980-1983 dropped (no source
  distinguishes them within the `1980_1989` bin); 1994 dropped by default
  (ambiguous pre/post given the July effective date and
  production/installation lags), per TODO's explicit instruction.
  Standalone validation (script prints/asserts all of these; no
  `$DATA_PATH` needed since every input is already in `derived/`):
  - Adding-up: allocated years sum exactly to the Census bin total
    (`stopifnot`, tolerance 1e-6).
  - Uniqueness on `(countyfp, year_constr, mh)`; no negative/missing
    `homes_n`.
  - Stability: county share of state MH stock correlates 0.86-0.95 across
    all pairs of the four Census vintage bins.
  - Benchmark: national MH stock 1986-1999 (imputed, summed) = 3,608,146
    vs. cumulative MHS national shipments over the same years = 3,799,500;
    ratio 0.95 — sensible (2000-Census stock is somewhat below cumulative
    shipments, consistent with attrition/relocation-out-of-state between
    construction and the 2000 snapshot).
- **`databuild-nfip.R`.** Retired the section-5.5 per-tract permit-split
  block (`permits_sf_n`, normalized by `n_tracts`). Replaced with a merge
  of `stock-county-vintage.Rds` onto the balanced panel by
  `(countyfp, year_constr, mh)` — `homes_n` is therefore a COUNTY-level
  value duplicated across every tract row for a given county/year/type, by
  design (per TODO: do not re-divide by tract count; the ratio is formed
  after policies are re-aggregated to county in estimation). Verified
  standalone by merging the new stock onto the existing (pre-Chunk-E)
  `nfip-balanced.Rds`: 6.3% of rows get `homes_n = NA`, essentially all of
  it the dropped 1994 construction year; exactly one county (`08014`,
  Broomfield CO, created in 2001) is absent from the Census-2000-anchored
  stock entirely and gets NA for all years. `databuild-nfip.R` itself could
  not be run end-to-end — no `$DATA_PATH` access in this sandbox, same
  standing limitation as Chunks A/C/C1.
- **`estimate-nfip.R`.** Added a `dt_homes_cell` aggregation
  (`countyfp x period_constr x mh`) that takes a DISTINCT county-level
  `homes_n` before summing across `year_constr` into `period_constr` bins —
  summing the raw tract-duplicated column would have inflated it by the
  tract count. A `period_constr` bin whose only `year_constr` member is the
  dropped 1994 (or otherwise fully missing) stays `NA` rather than
  silently becoming a 0-home bin. Merge or NA-fill is conditional on
  `agg_geo == "countyfp"` — the stock has no finer geography, so a
  `tractfp`/`statefp` run leaves `homes_n` undefined and skips the
  per-home specs.
  - `policies_per_home`, `claims_per_home` added to `dt_cell` (OLS-ready
    ratios).
  - Take-up `Table \ref{tab:take-up}` now reports a PPML with
    `offset = ~log(homes_n)` rather than modelling raw counts — coefficients
    are log rate ratios in the per-home rate. Two outcomes (policies,
    claims) decompose the benefit into claim frequency (extensive/
    insurability margin) vs. payment conditional on a claim (the existing
    damage-outcome tables, intensive margin, no stock denominator needed).
  - Added a 2009-2013-only restricted column pair (least exposed to
    Census-2000-to-policy-snapshot attrition; see caveats below) alongside
    the pooled 2009-2023 columns — 4 columns total in `take-up.tex`.
  - New scalar exports to `nfip-scalars.csv`:
    `policies_per_home_logrr_{avg,min,max}`,
    `claims_per_home_logrr_{avg,min,max}` (log rate ratios, exponentiated
    in `paper.Rmd` to a percent change).
  - Raw-count `est_pois_es` (no offset) kept for the `tractfp`/`statefp`
    case and as the direct predecessor comparison.
- **`paper.Rmd` take-up appendix rewritten** (review target 2) — replaced
  the "uninterpretable, no denominator" passage with the `homes_n`
  construction, the rate-ratio results (`r ppl_home_pct` ≈ 7% higher
  policies-per-home, `r clm_home_pct` ≈ 22% higher claims-per-home,
  post-1994 MH vs. site-built), and a new caveat paragraph on the
  Census-2000-vs.-2009-2023-policy-data time gap (why the 2009-2013 column
  is reported separately; ACS noted as a conceptual bound but NOT
  implemented — no ACS import script or data exists in this repo, and
  building one was out of this chunk's scope; left as a TODO). Table
  retitled "NFIP Take-Up per Housing-Unit Stock."
- **`Makefile`**: `impute-stock.R` added to the `data` target, before
  `databuild-nfip.R` (which now depends on its output).
- **New test** `program/tests/test-take-up-imputation.R`: simulates a
  panel where `homes_n` grows differentially by MH status across vintage
  bins (mimicking the real MH stock) and a known post-1994 MH log rate
  ratio in the per-home policy rate. Confirms the `offset = ~log(homes_n)`
  PPML recovers the true rate ratio with a flat pre-trend, and confirms
  that dropping the offset produces a spurious pre-trend (the differential
  stock-growth trend has nowhere else to go) — the same failure mode that
  made `policies_ppermit` uninterpretable.

### What changed in outputs

- `output/event-study/countyfp/take-up.tex`: 2 columns → 4 columns;
  coefficients are now log rate ratios (offset PPML), not raw-count PPML
  coefficients — not comparable to the pre-Chunk-E table by column
  position.
- `output/results/nfip-scalars.csv`: 6 new rows (`policies_per_home_logrr_*`,
  `claims_per_home_logrr_*`).
- `paper.Rmd` take-up appendix: substantially rewritten (see above); this
  is the change review target 2 asked for.
- `derived/stock-county-vintage.Rds`: new file (94,230 rows, 3,141
  counties, years 1984-1999). Not committed (`derived/` is gitignored
  project-wide, consistent with every other `derived/*.Rds`).

### Verified

- `impute-stock.R` run standalone end-to-end (no `$DATA_PATH` needed) —
  adding-up, uniqueness, non-negativity, stability, and benchmark checks
  all pass (see above).
- `databuild-nfip.R`'s new merge logic verified standalone by patching a
  copy of the existing `nfip-balanced.Rds` with the merge from
  `stock-county-vintage.Rds` (same technique Chunk C used for
  `databuild-mhs.R`) — confirmed exactly one distinct `homes_n` value per
  `(countyfp, year_constr, mh)`, and that the NA pattern is limited to the
  dropped 1994 year plus the one post-2000 county.
- `estimate-nfip.R` run end-to-end against the patched `nfip-balanced.Rds`
  — no errors, `take-up.tex` and the new scalar rows produced.
- `Rscript program/tests/run-tests.R` (`make test`) — all four test files
  pass, including the new `test-take-up-imputation.R`.
- `rmarkdown::render('paper.Rmd')` from a deleted `paper.pdf` — clean
  render, no missing-scalar errors; take-up appendix renders with the
  expected ≈7%/≈22% figures.
- `make data` (raw import layer, i.e. `databuild-nfip.R` against a real
  `fema.duckdb`) still not verified in this sandbox — same standing
  limitation noted in every prior chunk's log (§7 in `notes/specs.md`).

### Open questions for check-in

1. **1994 handling.** Dropped from the stock imputation entirely (per
   TODO's explicit default), which leaves the `period_constr` bin covering
   1994-1995 (`BIN_CONSTR_YEAR = 2`) representing only 1995's stock. This
   is documented but is a real approximation — flag if you'd rather
   interpolate 1994 (e.g., half-weight) instead of dropping it outright.
2. **ACS bounding not built.** TODO asked for the caveat to bound
   differential attrition using the ACS decade series; I wrote the caveat
   into the paper but did not build an ACS import (no `import-acs.R`
   exists, and the chunk header's "all inputs already on disk" did not
   hold for this specific ask). The 2009-2013-only column is a cheaper
   partial substitute (uses only data already in the repo) but is not a
   real bound. Worth a follow-up chunk if the referee pushes on this.
3. **Broomfield County, CO (08014)** has no Census-2000-era stock (county
   didn't exist yet) and so gets `homes_n = NA` for all years in the
   balanced panel — a single-county omission from the take-up specs, not
   flagged anywhere else. Immaterial to any headline number but noting for
   completeness.
4. Confirm the concurrent-Chunk-D coexistence in `estimate-nfip.R` is
   fine to leave interleaved rather than sequenced — I did not touch or
   reorder Chunk D's additions.

### Follow-up, same day: PPML → OLS take-up spec (Colin's request)

Swapped the take-up spec from PPML with a `log(homes_n)` offset to OLS
directly on `policies_per_home`/`claims_per_home`, clustered by county, per
Colin's request. Unweighted OLS was tried first and rejected on inspection
— a handful of near-zero-`homes_n` cells (mostly the volatile 1994 bin)
produced `policies_per_home` ratios as high as 48 and dominated the fit;
added `weights = ~homes_n` (same rationale as the existing `policies_n`
weights on the composition/claim-rate cell regressions), which fixed it.
`test-take-up-imputation.R` rewritten to match: now simulates a DGP with a
small share of near-zero-stock cells and confirms the homes_n-weighted OLS
recovers the true level effect while the unweighted version is distorted
by the outlier cells.

**Substantive change worth flagging:** the OLS result is materially
different from the PPML-offset version, not just rescaled — pooled
post-1994 coefficients are small and slightly negative (-12.7 policies,
-0.11 claims, per 100/1,000 homes respectively) versus the PPML version's
positive ≈+7%/+22% log rate ratios, and the OLS result is substantially
driven by the volatile 1994 bin. Paper text (take-up appendix, `paper.Rmd`)
and `notes/specs.md` §12 updated to describe this as "no clear extensive-
margin take-up shift" rather than the previous "genuine take-up increase"
framing. `nfip-scalars.csv` rows renamed `policies_per_home_{avg,min,max}`
/ `claims_per_home_{avg,min,max}` (level differences, not log rate ratios
— the `_logrr_` suffix no longer applies). Also fixed a Unicode minus sign
(`−`) in the new `paper.Rmd` formatting helper that broke `pdflatex`.
Re-verified: `make test` (4/4 pass) and a clean `paper.pdf` render from
scratch.

### Follow-up 2, same day: rescale to per 1,000 homes; drop the 2009-2013 columns (Colin's request)

Two more changes to the same take-up table, both requested directly:

- **Outcome rescaled** from raw `policies_per_home`/`claims_per_home`
  ratios to `policies_per_1k_homes`/`claims_per_1k_homes`
  (`1000 * policies_n / homes_n`, `1000 * claims_n / homes_n`) — same
  regression, coefficients just ×1000 for readability. `nfip-scalars.csv`
  rows renamed again to `policies_per_1k_homes_{avg,min,max}` /
  `claims_per_1k_homes_{avg,min,max}`.
- **Dropped the 2009-2013-only columns (3)-(4)** from `take-up.tex` — I had
  checked and confirmed before dropping that their point estimates were
  extremely similar to the pooled 2009-2023 column, so this matches
  Colin's read; the `est_home_ols_early` model and its fitting code were
  removed from `estimate-nfip.R` entirely rather than just left out of the
  `etable()` call, since nothing else used it. Table is now 2 columns
  (policies and claims per 1,000 homes, pooled sample).
- `paper.Rmd`: updated the in-text pooled-average figures
  (-126.6 policies, -0.11 claims, per 1,000 homes), the table notes (were
  still describing the old PPML-offset spec — a leftover from the
  Follow-up-1 edit that I'd missed), and the time-gap caveat paragraph
  (now describes the 2009-2013 restriction in the past tense, as something
  checked and found not to matter, rather than as an ongoing robustness
  column).
- Hit one new LaTeX break: a literal `` `homes_n` `` (backtick-quoted,
  Pandoc markdown) inside the `\tablenotes` block doesn't get converted
  there since that whole block is raw LaTeX passed through unprocessed —
  the underscore in the raw text then reads as a LaTeX math-mode escape
  and fails to compile. Fixed by switching to `$\mathrm{homes\_n}$`,
  matching how the rest of the document already escapes this identifier in
  LaTeX contexts (e.g. the wind-zone appendix).
- Re-verified: `make test` (4/4 pass, `test-take-up-imputation.R`
  unaffected since it tests the weighting logic, not the ×1000 scale or
  column count) and a clean `paper.pdf` render from scratch.

---

## Chunk B — Review quick fixes (2026-08-12)

**Base commit:** 9e13e4b (uncommitted at time of writing). Note: a peer
session was working Chunk C in the same working tree; that chunk's changes
to `databuild-mhs.R`/`estimate-mhs.R` and its `specs.md` §11 / LOG entry are
**not** part of this chunk's diff. Chunk B touched `paper.Rmd`,
`program/estimate/estimate-nfip.R` (one dict label),
`program/descriptives/estimate-sumstats-nfip.R`, the review file, `TODO.md`,
and `notes/specs.md` §3.

### What was done

Text, notation, and units batch from the review — comments 1, 3-5, 7-15,
20-23 — plus the panel-structure clarifications, 16-18. 21 of 23 detailed
comments are now `[Addressed]`; comment 2 (conservative-bias language) is
assigned to Chunk F and comment 6 was already closed.

**Notation (1, 20).** Eq. (2) gains the common construction-vintage term
`\lambda_{\nu_i}` and an explicit `k \neq 1992`, with prose describing
`\beta_k` as MH-specific deviations from the common vintage profile. This
is a notation fix only: `period_constr` has been in the estimating formula
since Chunk A. Eq. (1) gains `k \neq 1993` plus a sentence on why the
reference interaction must be dropped.

**Damage shares in percentage points (21).** The outcome is
`100 x damage / assessed value`, so coefficients are percentage-point
changes in that ratio. The old text reported "between 1% and 22% less,"
built from `abs()` of the event-study min and max — but the max is now
**+0.8** (one post-1994 share coefficient is positive), so that range was
both mislabeled and directionally misleading. Replaced with the static
estimate, `-12.8 pp (SE 4.4)`, consistent with Chunk C1's decision to make
the static ATT the headline. New scalars `bldg_shr_static`,
`bldg_shr_static_se` in the setup chunk; `bldg_shr_lo`/`_hi`/`_avg` retired.

**Panel structure (16-18).** The Data section now states that the balanced
panel is built over tract-periods with positive policy exposure; that
policy records begin in 2009 so the policy panel is three five-year
calendar periods (2009-2013, 2014-2018, 2019-2023); that zero-claim cells
with at least one active policy are kept and contribute a zero to the claim
rate; and that zero-policy cells are dropped from the weighted cell-level
regressions and appear only in the take-up PPML. The `v_dict` entry for
`period_loss` changed from "Loss period" to **"Calendar period"**, so the
policy tables no longer label a policy-year bin as a loss period; the
composition and take-up table notes now spell out the panel dimensions and
the FE substitution relative to Eq. (2).

**Units (22).** Table 1's damage rows relabeled `(\$000s)` and given one
decimal (integers in $000s were rounding away real precision), with the
scale stated in the table note.

**Softened claims (11-15).** Anticipation, cost-structure, and demand-
elasticity readings all reworded to what the estimates can support; the
elevation paragraph now says explicitly that the elevated-building share
rises only in the latest vintages and so cannot explain the 1994-96 bins;
the (still commented-out) tract-FE robustness paragraph no longer claims to
rule out within-tract exposure differences, and its table note now states
the clustering level (19).

**Institutional wording (7-9).** "Applied uniformly to all manufactured
homes nationwide" replaced with national administration + zone-varying
intensity, which is also what the cost design actually exploits;
"impact-rated windows" replaced with the wind-pressure/components-and-
cladding language; the chattel-loan exemption recast as a lending-channel
statement rather than a categorical class exemption.

**Conclusion and abstract (3-5).** The conclusion now states the pieces
separately (building damage, contents damage, total per event, PV benefit)
and draws the insured-claimant boundary explicitly. "Cost-effective tool"
became "can generate meaningful disaster-loss reductions." The abstract's
"recovers a substantial share of the upfront cost" is now the actual
number: the insured flood channel recovers ~21% (`bcr_pct`), with the
omitted channels named as unmeasured.

### What changed in outputs

- `paper.pdf` rebuilt. No estimates moved except through the relabeling:
  `policy-composition.tex`, `take-up.tex`, `robustness.tex` FE rows now read
  "County-Calendar period"; `sumstats-nfip.tex` damage rows relabeled and
  carry a decimal.
- No scalar values changed. The paper now cites
  `building_damage_share_static`/`_se` instead of the share event study's
  min/max/avg.

### Verified

- `make test` — all fake-data tests pass.
- `Rscript program/estimate/estimate-nfip.R`, then
  `estimate-sumstats-nfip.R`, then `rmarkdown::render('paper.Rmd')` — clean,
  no missing-scalar failures. One pre-existing LaTeX "float too large"
  warning, unchanged.

### Open questions for check-in

1. **Damage-share magnitude.** The static share effect is -12.8 pp against
   a dependent-variable mean of 24.8% — a ~52% proportional decline, much
   larger than the ~10% implied by the dollar outcomes (-3.7 on a mean of
   35.3). The share denominator (`building_value`) is itself a composition
   variable that moves after 1994, so the two are not measuring the same
   thing. I wrote the text to avoid asserting the proportional figure.
   Worth a look in Chunk D, which owns the damage-share-vs-dollars split.
2. **Welfare inputs still use event-study averages.** `delta_building`
   (4.80) and `delta_contents` (3.05) in `welfare-scalars.csv` come from
   `*_avg`, not the static ATT (3.68 / 4.06) that Chunk C1 made the
   headline. The conclusion I rewrote reports the welfare numbers, so the
   paper currently quotes two different building-damage effects in two
   places. Chunk G should reconcile; flagging now because it is visible in
   the conclusion.
3. **`databuild-nfip.R` vintage window.** An uncommitted edit was in the
   working tree at the start of this session (`year_min` 1984→1986,
   `year_max` 1999→2001), neither mine nor Chunk C's; Colin confirmed it
   should be discarded, and it is reverted. Separately, the file's
   `year_min` fought `project-params.R`'s `MIN_YEAR_CONSTR = 1983L` — the
   databuild filter binds, so the 1983 pre-period Chunk C1 bought was never
   actually in `nfip-claims.Rds`. Set `year_min <- 1983L` to match. **This
   only takes effect when `make data` is rerun with `$DATA_PATH` set**,
   which has not happened since Chunk A; until then the estimates still
   run on a 1984-start sample. Better still would be sourcing the constants
   from `project-params.R` so the two cannot drift again — not done here to
   keep the diff inside Chunk B's scope.
4. **`est_rob_list` / `est_geo_rob` lack the `period_constr` FE** (they run
   `| geo^period_loss + mh`), the same omission Chunk A fixed in Tables 3-4,
   and they use `period_loss` where the main claim spec uses `year_loss`.
   Out of scope here; Chunk F owns those columns.

---

## Chunk C — Cost side: wind-zone dose-response (2026-08-12)

**Base commit:** 9e13e4b (uncommitted at time of writing; see diff)

### What was done

Confined to `program/import/databuild-mhs.R` and
`program/estimate/estimate-mhs.R`, per assignment. Full detail in
`notes/specs.md` §11.

1. Built `treated_intensity`: state-level MH-stock-weighted share of a
   state's 1980-2000 MH stock sitting in a Zone II/III county
   (`ecfr-windzone.csv` × `census2000-mh-county-vintage.Rds`), replacing
   the diluted binary `treated`. Written to
   `derived/mhs-windzone-intensity.Rds`; state table exported as
   `output/descriptives/windzone-intensity.tex` (not yet wired into
   `paper.Rmd`).
2. Re-estimated the price event study with `treated_intensity` in place
   of `treated`, and separately with the binary spec restricted to the
   three high-intensity treated states (FL, LA, MA) vs. zone I controls.
3. **Result: the gradient is steep.** Implied fully-treated price effect
   from the continuous spec is ~$8,116 (`price_effect_dose_level`) vs.
   ~$4,194 from the binary spec (`price_effect_level`) — a ratio of
   ~1.94 (`dose_binary_ratio`). The high-intensity-restricted binary
   estimate is ~$6,520, in between. Per the interpretation TODO
   specified in advance: this means the true per-unit compliance cost is
   larger than the $5,000 headline implies, which worsens the
   benefit-cost ratio — reported as-is, not reframed.

### What changed in outputs

New rows in `output/results/mhs-scalars.csv`
(`price_effect_dose_level`, `price_effect_hi_level`,
`dose_binary_ratio`); new plots
`output/event-study/es-mhs-avg_sales_price-{dose,hi}.pdf`; new table
`output/descriptives/windzone-intensity.tex`; new derived file
`derived/mhs-windzone-intensity.Rds`. No existing MHS scalar changed
value — `treated`/binary spec untouched.

### What was verified

- `make test` passes unmodified (`test-mhs-price-did.R` only exercises
  the binary spec).
- `databuild-mhs.R` could not be executed end-to-end this session
  (`$DATA_PATH` unavailable — a pre-existing, unrelated `dt_state`
  crosswalk read blocks any run regardless of this chunk's changes). The
  intensity construction was verified by replicating it standalone
  against the checked-in `derived/*.Rds` files: reproduces the dilution
  memo's state-level numbers exactly (FL 96.6%, LA 63.6%, MA 46.3%, ...,
  pooled 29.7%, vs. the memo's FL 97%/LA 64%/MA 46%/pooled 30%).
  `estimate-mhs.R` was then run end-to-end against a patched copy of
  `sample-mhs.Rds` carrying the new columns (output above); the
  patched file was discarded afterward, `derived/sample-mhs.Rds` is
  unmodified.
- Both scripts parse cleanly (`parse()`); ran the full patched pipeline
  without errors or warnings other than an expected single-point
  `geom_line()` note for a state with one intensity value.

### Not done in this chunk (left for review / next chunk)

- Benefit-side companion (dose-response on NFIP damages using
  `treated_wz3`) — out of scope per the task assignment (`estimate-nfip.R`
  untouched).
- §3280.305 institutional-text correction — checked against the current
  `paper.Rmd`: the Institutional Background section already describes
  the 1994 rule correctly as amending the "Construction and Safety
  Standards" (a design/manufacturing requirement), not an installation
  standard, so no paper-text change was needed. Did not independently
  verify the eCFR effective date for Part 3285 installation standards
  against source, since no paper claim currently depends on it.
- New scalars/table are not yet cited in `paper.Rmd` or `notes/specs.md`'s
  interpretation folded into the Results/Discussion prose — that write-up
  (and the welfare-table consequence, since the $5,000 compliance cost
  feeds Chunk G) is left for Colin's review or a follow-on chunk.
- No fake-data test added for the dose-response spec.

### Open questions

- Should `price_effect_dose_level` (or the high-intensity-restricted
  estimate) replace `price_effect_level` as the paper's headline
  compliance cost, given the steep gradient? This changes the $5,000
  figure cited throughout the abstract/intro/discussion and the Chunk G
  welfare table's BCR. Flagging for Colin rather than deciding
  unilaterally, per TODO's "report whichever obtains; do not condition
  the framing on the sign."
- `dt_state` (unused, dead crosswalk read in `databuild-mhs.R`, present
  before this chunk) blocks any real end-to-end run without
  `$DATA_PATH`. Worth deleting independent of this chunk if confirmed
  unused.

---

## Chunk C1 — Fix specifications (2026-08-12)

**Base commit:** 7209775

### What was done

Four baseline-spec fixes to the NFIP claim-level design (`estimate-nfip.R`,
`project-params.R`), all identified in Chunk A/the review and scoped in
`TODO.md` Chunk C1. Run before D–G since every downstream number moves.

1. **Cluster by county.** `est_claim_es`, `est_claim_pois`, the four
   `est_rob_list` covariate-robustness specs, and `est_geo_rob` now pass
   `cluster = ~countyfp` (2,245 clusters). Previously no `cluster` argument
   was set, so `fixest` silently defaulted to the first FE (`geo^year_loss`),
   which is not defensible given repeat flooding and persistent local
   siting practices within a county. This is a defensibility fix — SEs
   move only modestly, per the diagnostics logged in `TODO.md`.
2. **Two-year construction bins as the default.** `BIN_CONSTR_YEAR`
   default changed `1L` → `2L` (`estimate-nfip.R:29`). The Makefile calls
   the script with no arguments, so the paper was being built on annual
   bins while `paper.Rmd` already claimed two-year binning — now true.
   Reference bin moves from 1993 to 1992-1993, matching the paper text's
   "1992 reference bin" (already correct, was a latent bug).
3. **Extended construction window to 1983.** `MIN_YEAR_CONSTR` changed
   `1988L` → `1983L` in `project-params.R`. Buys a longer pre-period for
   the parallel-trends test. This constant is shared with
   `estimate-sumstats-nfip.R`, so the summary-stats table's
   construction-year range moved too — updated the note in `paper.Rmd`
   (`tab:sumstats-nfip`, was "1986–1999," now correctly "1983–1999").
   `MAX_YEAR_CONSTR` extension past 1999 is an **open question**, not
   decided this chunk (see the 2005 construction-year-bin sentinel-value
   flag in `TODO.md`).
4. **Added the static TWFE.** Filled in the previously-empty `# static
   ----` section: `post_mh` (single post-1994 × MH coefficient) on the
   same sample/FE/clustering as the event study, for `building_damage`,
   `net_building_pmt`, `building_damage_share`, `contents_damage`, and
   `net_contents_pmt`. New table
   `output/event-study/countyfp/claims-outcomes-static.tex`
   (`tab:claims-outcomes-static` in `paper.Rmd`, wrapped in `landscape` —
   without it the 5-column table overflowed the page width, caught by
   rendering and checking the PDF). New `*_static`/`*_static_se`/
   `*_static_t` scalar rows in `nfip-scalars.csv`. Wired into the
   abstract, introduction, and results as the **headline number**
   (`paper.Rmd`'s `bldg_dmg_eff` now reads `building_damage_static`
   instead of the event-study average `building_damage_avg`, which is
   kept as a separate `bldg_dmg_evt_avg` for describing the post-1994
   ramp in the results text, not as the headline).

**Also fixed (from the same TODO item's bookkeeping):** the
`fig:es-building-damage` caption said "Net Building Payment per Claim" but
the figure and surrounding prose are both about `building_damage` —
corrected the caption to match, rather than changing the figure or text.

### What changed in outputs

- `paper.pdf`: headline building-damage effect changed from the
  event-study average (~$4,800/claim) to the static ATT (~$3,700/claim,
  SE ~$1,650) — a real point-estimate change, not just a relabeling, since
  clustering, binning, and the sample window all changed simultaneously
  with the switch to the static estimator. Abstract, intro, and Results
  §Benefit Side all updated; `tab:sumstats-nfip` construction-year range
  note corrected.
- `output/results/nfip-scalars.csv`, `output/results/welfare-scalars.csv`:
  regenerated; new `*_static` rows added to the former.
- `output/event-study/countyfp/*.tex`, `output/event-study/countyfp/*.pdf`:
  regenerated under the new spec; new `claims-outcomes-static.tex`.
- `notes/specs.md` §2 rewritten to describe the new spec; new §10
  documents the chunk's changes and rationale in one place.

### Verified

- `make estimates && make test && make paper.pdf` — clean run from a
  deleted `paper.pdf`, on the `derived/*.Rds` files already on disk
  (no `$DATA_PATH` access in this session, consistent with Chunk A's
  environment note — `make data` not reverified).
- `make test` — all fake-data tests pass unchanged (they exercise the
  estimator logic, not these specific parameter values).
- Spot-checked the rendered PDF text (`pdftotext`) for: the new headline
  number in the abstract and intro, the static table rendering all 5
  columns after the `landscape` fix, and the corrected 1983–1999
  construction-year range in both the Final Sample paragraph and the
  summary-statistics table note.

**Resolved same session:** Colin confirmed `building_damage` as the
headline outcome (2026-08-12) — matches what was implemented, no code
change needed. `TODO.md`'s bookkeeping item and `notes/specs.md` §10
updated to record the decision explicitly rather than leaving it open.

### Open questions for check-in

1. Whether to extend `MAX_YEAR_CONSTR` past 1999 (TODO.md flags a likely
   sentinel-value issue in the 2005 construction-year bin to check first —
   not investigated this chunk).
2. Table `tab:claims-outcomes-static` sits directly after Table
   `tab:claims-outcomes`, both in `landscape`, which means two full
   landscape pages back-to-back — fine as a draft, may want to reflow for
   the APPAM version.
3. Did not touch the `+ Controls` robustness columns' labeling (mediators
   vs. cleaner estimate) — per TODO.md's "considered and deliberately not
   adopted" note, that's a text-only change left for whichever chunk
   writes up that section (constrains Chunk F).

---

## Chunk A — Verification harness and reconciliation (2026-08-11)

**Base commit:** f899e87

### Addendum: missing vintage FE in Tables 3 and 4 (same session, post-review)

Colin caught that Table 3 (policy composition) and Table 4 (take-up) both
cite Equation (2) but were missing its `period_constr` (ν) fixed effect —
`fmla_comp_post` and `fmla_out_es` only had `geo^period_loss + mh`. This is
the identical bug class to the §5 geography fix: `i(period_constr, mh)`
only produces MH-group deviation dummies, so without a separate
`period_constr` main effect, the site-built (mh=0) reference group's own
vintage trend has nowhere to go except into the MH-interacted coefficients.
Added `+ period_constr` to both formulas (and to `est_ppermit_es`, the
currently-unused OLS take-up alternative, for consistency). All three
tables descending from Equation (2) — claims-outcomes, policy-composition,
take-up — now share the same FE structure. Take-up numbers moved
noticeably (post-1994 MH×ν coefficients now show a much larger,
monotonically increasing 0.03 → 0.47 profile, vs. a smaller/inconsistent
pattern before). Re-ran `estimate-nfip.R` → `estimate-welfare.R` →
`rmarkdown::render` → `make test`, all clean. Detail in `notes/specs.md` §3.

### What was done

1. **Fake-data verification harness** (`program/tests/`, wired to `make test`):
   - `test-nfip-claims-es.R`: simulates claim-level data with a known MH ×
     post-1994 effect, a common (shared MH/site-built) construction-vintage
     trend, and geography × loss-year shocks. Confirms the production spec
     recovers the true effect with flat pre-trends, and separately
     demonstrates that dropping the common-vintage FE (`period_constr`)
     contaminates the MH-vintage coefficients with the vintage trend — the
     mechanism the spec sheet's identifying assumption relies on.
   - `test-mhs-price-did.R`: simulates a state-year panel with a known
     post-1994 treated-state price effect; confirms the MHS DiD spec
     recovers it.
   - `test-welfare-arithmetic.R`: unit-tests the NPV annuity formula
     (factored out into new `program/estimate/welfare-lib.R` so it's
     testable without running the full welfare script) against closed-form
     values, and recomputes claim rate / annual benefit / NPV / BCR from a
     small synthetic panel with known inputs.
   - All three pass. `make test` runs them via `program/tests/run-tests.R`
     (testthat, `stop()`s with nonzero exit on any failure).

2. **Rebuild verification — found and fixed two real bugs in the process:**
   - `derived/welfare-county-vintage.Rds` was **stale**: it had a column
     named `policy_years`, but the current `databuild-welfare.R` writes
     `policies_n`. This made `estimate-welfare.R` fail outright
     (`Object 'policies_n' not found`). Rebuilt via
     `Rscript program/import/databuild-welfare.R` — its inputs
     (`nfip-balanced.Rds`, Census vintage data) were already current, no
     raw data access needed.
   - **Bigger issue:** `estimate-nfip.R`'s main claim-level spec was
     hardcoded to `statefp^year_loss` FE regardless of the `agg_geo` CLI
     argument, and its output was hardcoded to write into
     `output/event-study/statefp/`. That directory turned out to hold
     **stale output from an old script version** (different vintage-bin
     width, clustered SEs, extra covariates the current script doesn't
     even compute) — not a fresh run at state geography. The paper's main
     damage-effects table (`tab:claims-outcomes`) and main figure
     (`fig:es-building-damage`) were rendering from this stale table.
     Full writeup, decision, and fix in `notes/specs.md` §5. Short version:
     decided county × loss-period is the intended baseline (matches the
     paper's own robustness framing, `agg_geo`'s default, and — per the
     `coarse-output` review file's quoted excerpts of the equation text —
     matches how the reviewer themselves read the spec), fixed the FE and
     output path to follow `agg_geo`, extended the (currently-commented-out)
     geo-robustness table to a 3-way state/county/tract comparison so state
     is reported as an explicit robustness column instead of silently
     standing in as an unlabeled main spec, and repointed `paper.Rmd`'s
     `\input`/`\includegraphics` paths from `statefp/` to `countyfp/`.
   - **This changed the paper's headline numbers**, not just labels or
     text — the abstract's building-damage and price effects, and every
     number derived from `nfip-scalars.csv`, are different from what
     `paper.pdf` showed before this chunk, because the "main" table had
     been silently rendering the wrong (stale, wrong-geography) results.
     **This is the one thing to check carefully in the diff.**
   - Verified `make estimates && make test && make paper.pdf` runs clean
     end-to-end from the `derived/*.Rds` files already on disk. Could not
     verify `make data` (the raw-data import layer) in this session — see
     "environment note" below. Runtimes and exact scope documented in
     `notes/specs.md` §7.
   - Added `data`/`estimates`/`test`/`all` phony stage targets to the
     `Makefile` (previously it only had a rule to render `paper.pdf` from
     `paper.Rmd`, with no rule at all connecting `derived/`/`program/`/
     `output/`). These are stage-level, not per-file rules, since each
     script writes multiple outputs.

3. **`notes/specs.md`** written: FE/sample/weights/clustering for every
   table and figure, the geography decision and fix (§5), the rebuild
   verification scope and runtimes (§7), the test harness description (§8),
   and the hard-coded-figure audit findings (§9).

4. **Hard-coded-figure audit:** most estimation-derived figures in
   `paper.Rmd` already flow through `output/results/*-scalars.csv` via
   `get_nfip()`/`get_mhs()`/`get_welf()`/`get_ss()`. Found and left for a
   follow-up chunk: two prose passages (paper.Rmd ~L200/202, policy
   composition ranges) that eyeball the current composition-robustness
   table rather than reading it as a scalar — accurate as of this run, will
   go stale silently on the next re-estimation. Also flagged (not fixed,
   needs a citation check not a scalar fix): the "100 billion-dollar
   disasters" / "$600 billion" figures on ~L80 read as potentially dated.
   Full detail in `notes/specs.md` §9.

### Environment note

This session ran in a sandbox without `$DATA_PATH` raw-data access —
`.Renviron` points it at `/mnt/storage/research-data`, which exists but is
empty. Several R packages (`fixest`, `duckdb`, `kableExtra`, `lubridate`,
`testthat`) were also missing and were installed from CRAN for this
session. This means the `program/import/*.R` scripts (raw data →
`derived/`) were not run or checked for freshness in this chunk beyond the
one bug found by inspection (the welfare file above) — only the
`derived/*.Rds` → `output/` → `paper.pdf` chain was verified. **Recommend
running `make data && make all` on a machine with `$DATA_PATH` set before
the next check-in**, to rule out similar staleness in the import layer.

### What changed in outputs

- `paper.pdf`: headline building-damage and price effects changed (main
  spec now runs at county geography instead of the stale state-geography
  table it was silently reading before). Take-up table numbers changed
  similarly (N went from ~3,528 clustered-state observations to 200,784
  IID county observations — the take-up spec was already using the
  `agg_geo`-driven `out_dir`, so its stale-vs-current split was smaller,
  but the `\input` path itself was still pointed at the stale `statefp/`
  copy and has been corrected).
- `derived/welfare-county-vintage.Rds`, `output/results/welfare-scalars.csv`:
  regenerated (were broken/stale before this chunk).
- `output/event-study/countyfp/claims-outcomes.tex`,
  `output/event-study/countyfp/es-building-damage.pdf`,
  `output/event-study/geo-robustness.tex`: new/refreshed under the fixed
  spec.
- `output/event-study/statefp/*`: untouched (still stale) — nothing reads
  from this directory anymore; left in place rather than deleted in case
  the old numbers are wanted for comparison. Flag if you'd rather I remove
  it.

### Verified

- `make test` — all fake-data tests pass.
- `make estimates && make test && make paper.pdf` — clean run from a
  deleted `paper.pdf`, no errors, no missing-scalar failures.
- Confirmed by `grep` that no remaining `\input`/`\includegraphics` in
  `paper.Rmd`/`slides.tex` points at `output/event-study/statefp/`.

### Open questions for check-in

1. **Geography decision (specs.md §5)** — I decided county is the intended
   baseline and fixed the code/paper to match. This is a judgment call
   with a direct effect on the paper's headline numbers; please confirm
   before this merges, or redirect me to state/tract if you intended
   otherwise.
2. Delete or keep `output/event-study/statefp/*` (stale, now unreferenced)?
3. OK to leave the two remaining hard-coded composition-robustness ranges
   (paper.Rmd ~L200/202) for a follow-up chunk, or worth the small scalar-export
   addition now?
4. The "100 billion-dollar disasters" / "$600 billion" figures (paper.Rmd
   ~L80) look like they may need a fresher citation for the APPAM version —
   flagging, did not touch.
5. `make data` (raw import layer) needs to be verified on a machine with
   `$DATA_PATH` set — I could not do this in this sandbox.
