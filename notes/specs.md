# Spec sheet

Source of truth for every table/figure in `paper.Rmd`/`slides.tex`. Paper text
is checked against this file, not against memory. Update in the same commit
as any spec change (see `TODO.md` PROCESS).

Last verified: 2026-08-13, against commit at the top of `notes/LOG.md` (Chunk E).

## 1. MHS price/quantity event study (Eq. 1)

- **Script:** `program/estimate/estimate-mhs.R`
- **Data:** `derived/sample-mhs.Rds`, restricted to `year` between 1988-1999
- **Spec:** `c(price outcomes) ~ i(year, treated, ref = 1993) | statefp + year`
- **Sample:** state-year panel, 1988-1999
- **Weights:** none
- **Clustering:** by `statefp`
- **Treated:** states containing HUD wind zone II or III counties (binary; see
  §11 for the Chunk C continuous-intensity replacement)
- **Outputs:** `output/event-study/es-mhs-*.pdf`, `output/results/mhs-scalars.csv`

## 2. NFIP claim-level event study (Eq. 2) — main result

- **Script:** `program/estimate/estimate-nfip.R`, run with default args
  (`agg_geo = "countyfp"`, `BIN_CONSTR_YEAR = 2`, fixed 2026-08-12 in
  Chunk C1 — was `1L`, i.e. annual bins, contradicting `paper.Rmd`'s
  claim of two-year binning)
- **Data:** `derived/nfip-claims.Rds`, restricted to
  `year_constr` in [1984, 1999] and `year_loss` in [1994, 2023]
  (`MIN_YEAR_CONSTR`/`MAX_YEAR_CONSTR`/`MIN_YEAR_LOSS`/`MAX_YEAR_LOSS` in
  `program/import/project-params.R`; `MIN_YEAR_CONSTR` extended from 1988
  to 1983 in Chunk C1 to buy a longer pre-period for the parallel-trends
  check, then moved 1983 → 1984 in Chunk I, which closes the
  `MAX_YEAR_CONSTR` open question at 1999). Two reasons for 1984–1999:
  with two-year bins anchored so 1992–1993 is the last pre-treatment bin,
  1984 makes every bin hold two full construction years (the 1983 start
  left a bin holding one year), and the window then coincides exactly
  with the range over which the take-up denominator `homes_n` is defined
  (§12) — no vintage in the panel lacks a stock denominator for a reason
  other than the deliberately dropped 1994. Vintage filtering now lives
  only in `project-params.R`: `databuild-nfip.R` reads
  `MIN_YEAR_CONSTR`/`MAX_YEAR_CONSTR` rather than restating literals, so
  the panel grid and the estimation-time restriction cannot drift apart.
  Rows with negative net payments after recoveries are dropped so the OLS
  and Poisson estimators share a sample (`dt_claims_est`).
- **Event-study coefficients:** 7 per outcome (bins 1984, 1986, 1988,
  1990, 1994, 1996, 1998; 1992 is the reference). Was 8 under the 1983
  start. `paper.Rmd` states this count in two places.
- **Spec:** `c(building_damage, net_building_pmt, ...) ~ i(period_constr, mh, ref = 1992) | geo^year_loss + mh + period_constr`,
  where `geo = countyfp`, `period_constr` is the construction-vintage bin
  (two-year, `BIN_CONSTR_YEAR = 2`, ref bin 1992-1993 — see script header
  for the general binning convention), and `mh` indicates manufactured
  housing.
- **Baseline geography: county × loss-year.** See §5 below — this was a
  code/text mismatch as of the start of Chunk A and has been fixed.
- **Weights:** none (claim-level OLS/Poisson)
- **Clustering: by county (`countyfp`, 2,245 clusters)**, fixed 2026-08-12
  in Chunk C1 — previously no `cluster` argument was passed, so `fixest`
  silently defaulted to `geo^year_loss` (arbitrary correlation within a
  county-loss-year, but independence across loss years within a county,
  which is not defensible given repeat flooding and persistent local
  siting practices). SEs move only modestly (see Chunk C1 diagnostics in
  `TODO.md` DONE). Applies to all claim-level specs: `est_claim_es`,
  `est_claim_pois`, `est_static`, `est_rob_list` (a-d), `est_geo_rob`.
  State clustering (49 clusters) considered and rejected as the default —
  visibly noisier variance estimate; pair with a wild cluster bootstrap if
  a referee asks for it. Two-way county + loss-year rejected: returned a
  non-positive-definite VCOV and is redundant given `geo^year_loss`.
- **Static ATT (Chunk C1, new):** `c(building_damage, net_building_pmt, building_damage_share, contents_damage, net_contents_pmt) ~ post_mh | geo^year_loss + mh + post1994`,
  same sample/geography/clustering as above, collapsing the vintage
  profile to a single post-1994 × MH coefficient (`post_mh`). This is now
  the **headline number** reported in the abstract/intro/results — the
  event study is retained for pre-trends and the compliance ramp, not as
  the headline figure. Outputs to
  `output/event-study/countyfp/claims-outcomes-static.tex` (Table
  `tab:claims-outcomes-static`) and `*_static`/`*_static_se`/`*_static_t`
  rows in `nfip-scalars.csv`.
- **Outputs:** `output/event-study/countyfp/claims-outcomes.tex` (Table
  `tab:claims-outcomes`), `output/event-study/countyfp/es-building-damage.pdf`
  (Figure `fig:es-building-damage`, shows `building_damage` — the caption
  previously said "Net Building Payment per Claim," a mismatch fixed in
  Chunk C1), `output/results/nfip-scalars.csv`

## 3. NFIP cell-level event studies (take-up, MH share, policy composition)

- **Script:** same as §2, same run
- **Data:** `derived/nfip-balanced.Rds` aggregated to
  `geo × period_loss × mh × period_constr` cells (`dt_cell`), or to
  `geo × period_loss × mh × period_constr` including zero-policy cells for
  the Poisson take-up spec (`dt_pois`)
- **Panel definition (documented in the paper, Chunk B, review comments
  16-18):** the balanced panel is built at
  `tractfp × period_loss × mh × year_constr` in `databuild-nfip.R`, over the
  grid of tract-periods with positive policy exposure (`period_loss >= 2009`,
  since OpenFEMA policy records begin in 2009), then aggregated to `geo` in
  estimation. `period_loss` is a **five-year calendar-period bin** (2009-2013,
  2014-2018, 2019-2023 for the policy panel); both policy records and claims
  are assigned to it by calendar year, so a single index serves both. It is
  therefore labeled **"Calendar period"** in the `v_dict` (changed from
  "Loss period" in Chunk B — the old label described the claim side only and
  mislabeled the policy-composition and take-up tables).
  - Cells with **zero claims but ≥1 active policy** are retained and
    contribute a zero to `claim_rate`.
  - Cells with **zero active policies** have undefined per-policy averages and
    claim rate; `dt_cell` filters them out (`policies_n > 0`), so they leave
    the weighted composition/claim-rate regressions. `dt_pois` keeps them,
    since the take-up PPML models the policy count itself.
- **Spec (take-up, PPML):** `c(policies_n, claims_n) ~ i(period_constr, mh, ref = 1993) | geo^period_loss + mh + period_constr`
- **Spec (policy composition, OLS):** `c(repl_cost_ppol, ...) ~ i(period_constr, mh, ref = 1993) | geo^period_loss + mh + period_constr`
  Five outcomes are reported (replacement cost, building coverage, contents
  coverage, elevated share, SFHA share); `primary_res_share` and
  `mandatory_purchase_share` are commented out of the outcome list, and
  Chunk I removed them from the Table 3 notes, which still described them.
- **Weights:** cell-level OLS specs (composition, MH-share, claim-rate) are
  weighted by `policies_n`; the take-up PPML is unweighted (counts model)
- **Clustering: by county (`geo`)**, fixed in Chunk I (2026-08-26).
  Previously no `cluster` argument was passed to the four cell-level fits
  (`est_pclaim_es`, `est_comp_post`, `est_share_es`, `est_pois_es`), so
  `fixest` reported IID SEs — while `paper.Rmd`'s notes for Tables 3 and 4
  and this spec sheet's own §3 both claimed clustering. The claim-level
  specs in §2 had already been fixed in Chunk C1; this closes the same bug
  on the cell side. SEs widen materially: the pre-1994 building-coverage
  coefficients keep their signs and significance, but several
  previously-significant post-1994 composition coefficients are no longer
  distinguishable from zero, which is what forced the rewrite of the
  paper's Selection and Composition section in Chunk I.
- **Outputs:** `output/event-study/countyfp/take-up.tex` (Table
  `tab:take-up`, appendix), `output/event-study/countyfp/take-up-static.tex`
  (Table `tab:take-up-static`, appendix, new in Chunk I),
  `output/event-study/countyfp/policy-composition.tex`
  (Table `tab:composition`)
- **Fixed (Chunk E, 2026-08-13):** `policies_ppermit` (policies ÷
  single-family building permits) was the wrong take-up denominator —
  replaced by a `homes_n`-offset PPML. See §12.
- **Fixed 2026-08-11:** both specs were missing the `period_constr` FE even
  though both tables' notes claim estimation from Equation (2) (which
  includes it). Without it, `i(period_constr, mh)` — which only creates
  MH-group *deviation* dummies — had nothing else absorbing the site-built
  (mh=0) reference group's own vintage variation, so it leaked into the
  MH-interacted coefficients. Same bug class, independently, as the §5
  geography fix. Added `+ period_constr` to both `fmla_comp_post` (Table 3)
  and `fmla_out_es` (Table 4, and the currently-unused `est_ppermit_es`
  OLS alternative), matching `fmla_claim_es` (Table 2) and `fmla_pclaim_es`
  (already correct). All tables descending from "Equation (2)" now share
  the same FE structure — `geo^{year_loss|period_loss} + mh + period_constr`
  — differing only in whether the location×period FE runs at the claim
  data's native `year_loss` or the pre-aggregated cell panel's `period_loss`.
  This changed Table 4's point estimates materially (e.g. the 1999 MH ×
  ν coefficient moved from a small/inconsistent value to a much larger,
  monotonically increasing 0.03 → 0.47 post-1994 profile) — check this in
  the diff along with the §5 change.

## 4. Covariate-controlled and geographic robustness

- **Script:** same as §2, same run
- **Covariate robustness (`fmla_rob_a`-`d`):** baseline vs. `+ water_depth +
  elevated + sfha` controls, vs. tract × loss-period FE, vs. both. Outcome:
  `building_damage`. Output: `output/event-study/countyfp/robustness.tex`.
- **Geographic robustness (`fmla_geo_rob`):** `building_damage ~ i(period_constr, mh, ref = 1993) | sw(statefp^period_loss, countyfp^period_loss, tractfp^period_loss) + mh`.
  Three columns: state (coarsest), county (baseline), tract (finest).
  Output: `output/event-study/geo-robustness.tex` (Table `tab:geo-robustness`,
  currently commented out in `paper.Rmd` pending Colin's review — see
  `notes/LOG.md`).

## 5. Geography discrepancy — resolved 2026-08-11

**Finding:** `estimate-nfip.R`'s main claim-level spec (§2) was hardcoded to
`statefp^year_loss` FE (ignoring the `agg_geo` CLI argument and the `geo`
column already built for that purpose), and its output — including the
paper's central damage-effects table and figure — was hardcoded to write
into `output/event-study/statefp/`. That `statefp/` directory turned out to
hold **stale output from an old script version** (different vintage-bin
width, clustered SEs, extra covariates no longer in the script) — not a
refresh of the current spec at state geography. Meanwhile the paper text
said the baseline was "tract" (intro) or "county" (robustness section,
Table `tab:geo-robustness` notes), and the code's own `sw()` robustness
block already treated county as the reference level being swapped out.

**Decision:** county × loss-period is the baseline geography. Rationale:
(1) the paper's own robustness section frames tract as the alternative to a
county baseline, not vice versa; (2) `agg_geo` defaults to `"countyfp"`
everywhere else in the script; (3) state is coarse enough to plausibly
absorb the wind-zone treatment itself into the FE structure, given Chunk
C's finding that treatment is highly diluted within state (~30% of stock
pooled, ranging 3%-97%) — differencing within state risks absorbing
mechanical variation as well as noise.

**Fix (this chunk):**
- `estimate-nfip.R`: `fmla_claim_es` FE changed from `statefp^year_loss` to
  `geo^year_loss` (so it follows `agg_geo`, default county); the
  `claims-outcomes.tex` output path changed from hardcoded `statefp/` to
  the dynamic `out_dir`.
- `fmla_geo_rob` extended from `sw(countyfp^period_loss, tractfp^period_loss)`
  to a 3-way `sw(statefp^period_loss, countyfp^period_loss, tractfp^period_loss)`,
  so state is now reported as an explicit robustness column rather than
  silently doubling as an unlabeled "main spec."
- `paper.Rmd`: intro's "tract by flood-loss-period" corrected to "county by
  flood-loss-period"; `\input` paths for `claims-outcomes.tex`,
  `es-building-damage.pdf`, and `take-up.tex` repointed from `statefp/` to
  `countyfp/`; `geo-robustness.tex` table notes updated to describe 3
  columns (state/county/tract) instead of 2.

**Consequence — headline numbers changed.** Because the "main" table was
previously rendering stale/wrong-geography output, re-running the corrected
county spec changed the paper's reported effects (e.g., abstract building
damage effect: was computed from the stale state-FE table before this
chunk). **This is the single most important thing to check in the diff at
the next check-in** — the point estimates, not just the labels, moved.

**Not yet done:** `output/event-study/statefp/` and `output/event-study/tractfp/`
are left as-is (the `statefp/` copy is stale, there is no `tractfp/` folder).
Nothing in `paper.Rmd`/`slides.tex` reads from them any longer (verified by
grep). If a future chunk wants a state-only or tract-only run's full table
set (not just the 3-way `building_damage` robustness column already
produced), rerun `Rscript program/estimate/estimate-nfip.R statefp` /
`tractfp` explicitly.

## 6. Welfare / cost-benefit calculation

- **Script:** `program/estimate/estimate-welfare.R`, arithmetic factored
  into `program/estimate/welfare-lib.R` (tested, see §8)
- **Data:** `derived/welfare-county-vintage.Rds` (county × Census-2000
  vintage bin), `output/results/nfip-scalars.csv`, `output/results/mhs-scalars.csv`
- **Found and fixed this chunk:** `derived/welfare-county-vintage.Rds` was
  stale — it had a column named `policy_years` while the current
  `databuild-welfare.R` writes `policies_n`, causing `estimate-welfare.R` to
  fail outright (`Object 'policies_n' not found`). Rebuilt via
  `Rscript program/import/databuild-welfare.R` (inputs — `nfip-balanced.Rds`,
  `census2000-mh-county-vintage.Rds` — were already current on disk, no
  `DATA_PATH` needed for this step).
- **Counterfactual claim rate:** pre-1994 pooled (1980-1989 + 1990-1994),
  with 1990-1994-only reported as an alternative
- **Discount rates:** 0%, 3%, 7%; **lifespans:** 20/30/40 years; baseline
  cell used in the paper text is r=3%, T=20yr
- **Outputs:** `output/results/welfare-scalars.csv`

## 7. Rebuild verification (this chunk)

Environment: this session runs in a sandbox without `$DATA_PATH` raw-data
access — `.Renviron` points `DATA_PATH` at `/mnt/storage/research-data`,
which exists but is empty (no `fema.duckdb`, no raw MHS/Census/BPS source
files). Required R packages (`fixest`, `duckdb`, `kableExtra`, `lubridate`,
`testthat`) were missing and were installed from CRAN for this session.

**Verified end-to-end, from a clean `derived/` (already on disk) through
`paper.pdf`:**

| Stage | Command | Runtime (this run) |
|---|---|---|
| Estimation + descriptives | `make estimates` | ~35s total (nfip ~22s, sumstats-nfip ~10s, mhs/welfare/plots each <3s) |
| Fake-data test harness | `make test` | <1s |
| Paper render | `make paper.pdf` (after `rm paper.pdf`) | ~1-2 min incl. pdflatex/bibtex passes |

`make estimates`, `make test`, and `make paper.pdf` are wired into the
`Makefile` as phony stage targets (not fine-grained per-file rules — each
script writes multiple outputs, so "stage order" is the unit of dependency,
not individual files). `make all` runs the full chain including `data`.

**Not verified in this session — requires `$DATA_PATH` raw data:**
`make data` (the `program/import/*.R` scripts that build `derived/*` from
raw FEMA/Census/MHS/BPS sources). These were not run or checked for
freshness beyond the one bug found by inspection (§6). Recommend running
`make data && make all` on a machine with `$DATA_PATH` set to confirm the
import layer is not similarly stale before the next check-in.

## 8. Fake-data verification harness (`program/tests/`, `make test`)

- `test-nfip-claims-es.R`: simulates claim-level data with a known MH ×
  post-1994 effect, a common (MH-and-site-built) construction-vintage trend,
  and geography × loss-year shocks. Confirms the production spec (§2)
  recovers the true effect and flat pre-trends; confirms that dropping the
  `period_constr` FE (the common vintage control) contaminates the
  MH-vintage coefficients with the common vintage trend.
- `test-mhs-price-did.R`: simulates a state-year panel with a known
  post-1994 treatment effect for treated states; confirms the production
  spec (§1) recovers it with flat pre-trends.
- `test-take-up-imputation.R`: two groups. (i) The take-up SPEC (§12):
  simulates a `geo x period_constr x mh` panel with a known per-home rate
  shift and a small share of near-zero-stock cells; confirms the
  `homes_n`-weighted OLS recovers the effect and that dropping the weights
  lets those cells dominate. (ii) The take-up DENOMINATOR (§12.2, added
  2026-08-26 after both defects there slipped past the harness): confirms
  that within-bin shares normalized over the Census bin's full span recover
  the true retained stock while normalizing over retained years only inflates
  it by 1/(retained source share) — and that the inflation factor is
  source-implied, not the year-count fraction — and confirms that a per-home
  rate built from matched construction years is not inflated by a numerator
  covering a year the denominator omits, the way a row filter on an
  already-aggregated bin is.
- `test-welfare-arithmetic.R`: unit-tests `npv_annuity()` against
  closed-form annuity values; recomputes claim rate / annual benefit / NPV /
  BCR from a small synthetic county × vintage panel with known parameters
  and checks the pipeline's arithmetic against hand calculation.

## 9. Hard-coded-figure audit (this chunk)

Grepped `paper.Rmd`/`slides.tex` for literal dollar amounts and percentages
not sourced via `` `r ...` `` scalar references.

- **Clean:** the overwhelming majority of estimation-derived figures already
  flow through `output/results/*-scalars.csv` via the `get_nfip()`/
  `get_mhs()`/`get_welf()`/`get_ss()` helpers defined in `paper.Rmd`'s setup
  chunk. `slides.tex` has no literal dollar/percent figures at all (it
  presumably `\input`s tables/figures rather than citing numbers in prose —
  not checked line-by-line this chunk).
- **Not violations (external citations, not this paper's estimates):**
  paper.Rmd lines ~80 ("100 billion-dollar disasters", "$600 billion"),
  ~116 ("6%"/"15%"/"97%"/"11%" — housing-stock share and the Hurricane
  Andrew statistic), ~226 (Solomon et al. footnote figure). These cite
  external sources via footnotes and are out of scope for "figures from
  this paper's own scalars."
  - **Follow-up needed, not this chunk's decision to make alone:** the
    "over 100" / "\$600 billion" disaster-cost figures on line ~80 read as
    dated — climate-disaster-cost figures from 5-years-before-2026 should
    be checked against the cited source before the APPAM draft goes out;
    flagging for Colin rather than silently editing since it needs a
    citation-level check, not a scalar-migration fix.
- **Remaining hard-codes, not migrated this chunk:** paper.Rmd lines
  ~200/~202 describe the policy-composition robustness check
  (`est_comp_post`, Table `tab:composition`) in prose with manually-typed
  ranges — e.g. "higher replacement cost (\$20--30,000)", "3--7 percentage
  points higher" for SFHA share, "rises by 6 percentage points" for
  elevated share post-1999. These are eyeballed off the current table and
  were spot-checked against `output/event-study/countyfp/policy-composition.tex`
  this chunk (they're accurate as of this run), but they will silently go
  stale the next time `estimate-nfip.R` is rerun with different data/specs.
  Migrating them requires adding post-1994 min/max scalar exports for
  `repl_cost_ppol`, `building_policy_covg_ppol`, `contents_policy_covg_ppol`,
  `sfha_share`, and `elevated_share` to `nfip-scalars.csv`, parallel to
  `extract_post_stats()`'s existing pattern — left for a follow-up chunk
  given Chunk A's low-effort budget for August.

## 10. Chunk C1 baseline-spec fixes (2026-08-12)

Four changes to the NFIP claim-level design, all contained to
`estimate-nfip.R`, `project-params.R`, and the run-order documented above.
Rationale and diagnostics are in `TODO.md` Chunk C1; this section records
the resulting spec, which is what §2 above now reflects.

1. **Clustering** — added `cluster = ~countyfp` to every claim-level spec
   (previously IID/`geo^year_loss`-default SEs). Defensibility fix, not a
   power fix; see §2.
2. **Bin width** — `BIN_CONSTR_YEAR` default changed `1L` → `2L`. The
   Makefile calls `estimate-nfip.R` with no arguments, so this was
   previously building the paper on annual bins while `paper.Rmd` claimed
   two-year bins; now they agree. Reference bin is 1992-1993 (`ref_period
   = 1994 - BIN_CONSTR_YEAR = 1992`).
3. **Sample window** — `MIN_YEAR_CONSTR` changed `1988L` → `1983L` in
   `project-params.R`. Buys a longer pre-period for the parallel-trends
   test; claim counts are healthy back through the late 1970s. This
   parameter is shared by `estimate-nfip.R` and
   `estimate-sumstats-nfip.R`, so the summary-statistics table's
   construction-year range moved too (`paper.Rmd` Table `tab:sumstats-nfip`
   note updated 1986–1999 → 1983–1999). `MAX_YEAR_CONSTR` extension is an
   **open question**, not decided this chunk — see `TODO.md`.
4. **Static ATT** — added the previously-empty `# static ----` section:
   `post_mh` (single post-1994 × MH coefficient) in place of the
   event-study's per-vintage-bin interactions, same sample/FE/clustering.
   Reported as the headline number in the abstract, introduction, and
   results (`paper.Rmd` `bldg_dmg_eff`, now sourced from
   `building_damage_static` rather than the event-study average
   `building_damage_avg`, which is retained as `bldg_dmg_evt_avg` for
   describing the post-1994 ramp). New Table `tab:claims-outcomes-static`
   (`output/event-study/countyfp/claims-outcomes-static.tex`), wrapped in
   `landscape` like Table `tab:claims-outcomes` — 5 columns overflow the
   page width without it (caught by rendering the PDF and checking, not by
   inspection). New `*_static`/`*_static_se`/`*_static_t` scalar rows in
   `nfip-scalars.csv` for `building_damage`, `net_building_pmt`,
   `contents_damage`, `net_contents_pmt`, `building_damage_share`.

**Also fixed:** the `fig:es-building-damage` caption said "Net Building
Payment per Claim" but the figure is generated from `building_damage`
(`plot_es(est_claim_es, "building_damage", ...)`) and the body text already
described it as building damage — caption corrected to match figure and
text, not the other way around, since building damage (not net payment) is
the outcome discussed in the surrounding prose and is what the static
headline table reports.

**Downstream:** all of `nfip-scalars.csv` moved (new sample/bins/clustering
+ new static rows), so `welfare-scalars.csv` and every abstract/intro/
results/discussion number derived from it shifted. Full chain verified this
chunk: `make estimates && make test && make paper.pdf` from a fresh
`paper.pdf`, no errors. `make data` (raw import layer) not reverified — see
§7's standing caveat about `$DATA_PATH` access.

**Not done, per TODO's "considered and deliberately not adopted":** the
`+ Controls` robustness columns (`fmla_rob_b`, `fmla_rob_d`) were not
relabeled as a decomposition in this chunk — text-only change, deferred to
whichever chunk writes up that section (constrains Chunk F).

## 11. Chunk C — wind-zone dose-response, cost side (2026-08-12)

Addresses the dilution problem in §1's binary `treated`: pooled across
treated states, only ~30% of the 1980-2000 MH stock actually sits in a
Zone II/III county (range: FL 97% down to VA 3%). Confined to
`program/import/databuild-mhs.R` and `program/estimate/estimate-mhs.R`;
the benefit-side companion (`treated_wz3` dose-response on NFIP damages)
and the §3280.305 institutional-text correction are **not** part of this
chunk and remain open in `TODO.md`.

- **Intensity construction** (`databuild-mhs.R`): `treated_intensity` is
  the MH-stock-weighted share of a state's 1980-2000 MH stock (summed
  across all four vintage bins of `census2000-mh-county-vintage.Rds`)
  sitting in a county classified Zone II or III by
  `derived/ecfr-windzone.csv`. 35 counties have no eCFR match (AK, HI,
  NYC boroughs, and a handful of renamed/consolidated FIPS codes, e.g.
  46113, 51515, 51560) — following the `statefp == 36` NA fallback
  already used in `databuild-nfip.R`, these default to Zone I. Written to
  `derived/mhs-windzone-intensity.Rds` (state-level: `mh_stock`,
  `mh_stock_wz23`, `treated_intensity`) and merged onto the state-year
  panel by `statefp`; states with no eCFR-matched WZ2/3 county at all get
  `treated_intensity = 0` by construction. `high_intensity` flags the
  three states used for the restricted-binary comparison: FL, LA, MA
  (statefp 12, 22, 25) — the same three the TODO's dilution memo (see
  `TODO.md` DONE, 2026-08-11) identified as having intensity well above
  the rest of the treated group (97%/64%/46% vs. ≤25% for every other
  treated state).
- **Continuous-intensity spec** (`estimate-mhs.R`):
  `c(price outcomes) ~ i(year, treated_intensity, ref = 1993) | statefp + year`,
  same sample/clustering as §1. `treated_intensity` is scaled 0-1, so
  `beta_k` is directly comparable to the binary spec's coefficient: the
  implied price effect of moving a state from 0% to 100% Zone II/III MH
  stock.
- **High-intensity-restricted binary spec**: original binary spec (§1),
  sample restricted to `high_intensity == TRUE | treated == FALSE` (FL/LA/MA
  vs. the zone I controls; all other treated states dropped).
- **Result:** `price_effect_dose_level` (implied fully-treated effect,
  continuous spec) ≈ **$8,116**, vs. `price_effect_level` (binary, §1) ≈
  **$4,194** — `dose_binary_ratio` ≈ **1.94**. The high-intensity-restricted
  binary estimate (`price_effect_hi_level`) ≈ **$6,520**, between the two.
  **The gradient is steep, not flat**: per the interpretation TODO laid
  out in advance, this means the true per-unit compliance cost is
  substantially larger than the binary $5,000 headline implies, which
  *worsens* the benefit-cost ratio in Chunk G's welfare table. This
  finding is reported as-is, per TODO's "do not condition the framing on
  the sign." All three scalars land in `output/results/mhs-scalars.csv`;
  event-study plots at `output/event-study/es-mhs-avg_sales_price-dose.pdf`
  and `-hi.pdf`.
- **Appendix table**: state-level intensity table
  (`output/descriptives/windzone-intensity.tex`, state / MH stock / MH
  stock in WZ II-III / intensity, sorted descending, states with zero
  WZ2/3 stock omitted) — not yet wired into `paper.Rmd`.
- **Not yet done:** these new scalars/table are not cited anywhere in
  `paper.Rmd` yet (no hard-coded numbers were added — this is scaffolding
  for whoever writes up the Results/Discussion consequences of the steep
  gradient, likely Chunk C's own write-up pass or Chunk G's welfare
  table). `make test` was not extended with a dose-response fake-data
  test — the existing `test-mhs-price-did.R` only checks the binary spec
  and still passes unmodified since `treated` is untouched.
- **Verification:** `databuild-mhs.R` could not be executed end-to-end in
  this session (`$DATA_PATH` unavailable, per §7's standing caveat — the
  unrelated `dt_state <- fread(file.path(data_path, "crosswalk",
  "states.txt"))` read, dead code even before this chunk, blocks a full
  run). The intensity construction and merge logic were verified instead
  by replicating them standalone against the checked-in `derived/*.Rds`
  files and confirming the state-level intensities reproduce the
  dilution memo's numbers exactly (FL 96.6%, LA 63.6%, MA 46.3%, SC
  24.8%, MS 17.0%, NC 13.9%, ME 11.5%, AL 8.8%, TX 8.6%, GA 5.8%, VA
  2.6%, pooled 29.7%), then patching a copy of `derived/sample-mhs.Rds`
  with the new columns to run `estimate-mhs.R` end-to-end (output above).
  `program/import/databuild-mhs.R` itself was read-verified line-by-line
  against this replication but not executed with real `$DATA_PATH`.

## 12. Take-up housing-stock denominator, `homes_n` (Chunk E, 2026-08-13)

Replaces `policies_ppermit` (§3's old "known issue") throughout.

- **Script:** `program/import/impute-stock.R` (new) builds
  `derived/stock-county-vintage.Rds`, keyed `countyfp x year_constr x mh`,
  `homes_n`. Reads `census_mhs_state_year`, `census_mhs_national_year`, and
  `census_bps` via `rd_read()` (research-database; see
  `program/import/UPDATE.md`) rather than the project's own local
  `derived/*.Rds` artifacts — ported onto the curated source at merge time
  (2026-08-24), after this chunk was originally written against
  `$DATA_PATH`-derived `derived/mhs-state-year.Rds` / `derived/permits-co.Rds`.
- **Levels:** Census 2000 (`census2000-mh-county-vintage.Rds`), `mh_units`
  for MH, `total_units - mh_units` for site-built, by county x vintage bin
  (`1980_1989`, `1990_1994`, `1995_1998`, `1999_2000`).
- **Within-bin year allocation:** MHS state-year `placements`
  (`census_mhs_state_year`) for MH, broadcast to every county in the state
  (MHS has no county detail); BPS county-year `permits_sf`
  (`census_bps`) for site-built, falling back to the state's permit
  shares where a county has zero/missing permits in the bin. Both sources
  are used only to split a Census-anchored bin TOTAL across years, so their
  own level bias (BPS undercounts non-permitting rural counties; MHS is a
  state series) does not enter the resulting ratio. **Shares are normalized
  over every construction year the Census bin spans** (`bin_span`), not over
  the subset retained below, so a partly retained bin contributes only its
  retained fraction; normalizing over retained years only was a defect,
  fixed 2026-08-26 — see §12.2.
- **Years covered: 1984-1999.** 1980-1983 dropped from the `1980_1989` bin
  (no source distinguishes them from 1984+ within that bin). **1994 dropped
  by default** from the `1990_1994` bin (ambiguous pre/post reform given the
  July effective date and production/installation lags) — a `period_constr`
  bin whose only `year_constr` member is 1994 is `NA`, not silently 0. The
  dropped years' stock is dropped, not reallocated onto the retained years
  (see the allocation bullet above and §12.2). Because the retained window
  is narrower than the Census bins, the per-home outcomes must also exclude
  construction year 1994 from their NUMERATOR, or the 1994 `period_constr`
  bin mixes a two-year numerator with a one-year denominator — enforced in
  `estimate-nfip.R` as of 2026-08-26, §12.2.
- **Validation (run inside the script, `stopifnot`):** uniqueness on
  `(countyfp, year_constr, mh)`; no negative/missing `homes_n`; adding-up,
  in two parts — exact (within-bin shares sum to 1 over the bin's full span,
  per state x bin for MH and per county x bin for site-built, asserted where
  the shares are built) and a bound (retained years never sum to more than
  the Census bin total, and match it exactly for fully retained bins),
  alongside a printed realized-vs-year-count retained fraction; stability
  (county share of state MH stock correlates 0.86-0.95 across all pairs of
  the 4 Census bins); benchmark (national MH stock 1986-1999, imputed, =
  2,865,353 vs. cumulative MHS shipments 1986-1999 = 3,799,500, ratio 0.75).
  The pre-2026-08-26 version of this bullet reported an exact adding-up test
  on the retained years and a ratio of 0.95; both were symptoms of the
  normalization defect in §12.2.
- **Merge into the balanced panel** (`databuild-nfip.R`, replacing the old
  section-5.5 per-tract permit-split block): `stock-county-vintage.Rds`
  merged onto `nfip-balanced.Rds` by `(countyfp, year_constr, mh)`.
  `homes_n` is therefore a COUNTY-level value duplicated across every tract
  row for a given county/year/type — this is intentional (see script
  comment); it is NOT re-divided by tract count, unlike the old
  `permits_sf_n`.
- **Aggregation in estimation** (`estimate-nfip.R`): `dt_homes_cell` takes
  a DISTINCT `(countyfp, year_constr, mh, homes_n)` value before summing
  across `year_constr` into `period_constr` bins — summing the raw
  tract-duplicated column would inflate by the tract count. Only defined
  when `agg_geo == "countyfp"` (the stock has no finer geography); `NA` at
  `tractfp`/`statefp` aggregation, and the per-home specs are skipped there
  (raw-count `est_pois_es` covers that case).
- **Take-up spec (updated 2026-08-13, twice, same day as the rest of Chunk
  E):** `c(policies_per_1k_homes, claims_per_1k_homes) ~ i(period_constr, mh, ref = ref_period) | geo^period_loss + mh + period_constr`,
  **OLS**, `weights = ~homes_n`, `cluster = ~geo` (county, since `geo ==
  countyfp` under the default `agg_geo`). Outcomes are `1000 * policies_n /
  homes_n` and `1000 * claims_n / homes_n` (rescaled from a first pass that
  used the raw `policies_n / homes_n` ratio, per Colin's request — same
  regression, coefficients just ×1000 for readability). Originally a PPML
  with `offset = ~log(homes_n)`; swapped to OLS directly on the ratio
  outcomes per Colin's request. Unweighted OLS was tried first and
  rejected: a handful of cells (mostly the flagged, partial-stock 1994
  bin) have imputed `homes_n` well under 1, producing ratios in the tens
  of thousands (per 1,000 homes) that dominate an unweighted fit;
  weighting by `homes_n` (same logic as the `policies_n` weights already
  used for the composition/claim-rate cell regressions) fixes this.
  Pooled across all three policy periods only (2009-2023) — an
  earliest-period-only (2009-2013) restriction was tried and dropped from
  the table: point estimates were extremely similar to the pooled column
  and added no information (see caveat below).
- **Decomposition:** claim frequency (claims per home, extensive/
  insurability margin, this section) vs. payment conditional on a claim
  (the existing damage-outcome tables/`est_claim_es`, intensive margin, no
  stock denominator needed) — different welfare interpretations per the
  review notes. Chunk I splits the first of these in two; see §12.1.
- **Result (as of Chunk E; superseded by §12.1):** pooled post-1994 average
  coefficient (across the 1994, 1996, 1998 `period_constr` bins) is -126.6
  policies and -0.11 claims per 1,000 homes over a five-year period,
  relative to site-built homes of the same vintage — largely driven by the
  volatile 1994 bin; the 1996/1998 coefficients are small and closer to
  zero. Read as no clear extensive-margin take-up/claim-frequency shift, in
  contrast to the earlier PPML-offset version of this table (log rate
  ratios ≈ +7%/+22%) — the sign/magnitude are NOT robust to the
  OLS-vs-PPML choice, and this OLS version is what is currently in the
  paper.
- **Outputs:** `derived/stock-county-vintage.Rds`,
  `output/event-study/countyfp/take-up.tex` (Table `tab:take-up`, retitled
  "NFIP Take-Up per Housing-Unit Stock"), and take-up rows in
  `output/results/nfip-scalars.csv` (renamed in Chunk I, see §12.1).

### 12.1 Annualization, third margin, and static column (Chunk I, 2026-08-26)

- **Annualized outcomes.** `policies_per_1k_homes` and
  `claims_per_1k_homes` divided `policies_n`/`claims_n` by `homes_n` only.
  Because `policies_n` counts policy-**years** summed over the five
  calendar years of a `period_loss` bin, those outcomes were five-year
  cumulative counts carrying a per-period label — the paper called them
  rates. Both are now divided by `homes_n * N_YEARS_PERIOD` and renamed
  with a `_yr` suffix: `policies_per_1k_homes_yr`,
  `claims_per_1k_homes_yr`. Point estimates are the old ones ÷ 5.
  `N_YEARS_PERIOD = 5L` is asserted against the data (every retained
  `period_loss` bin is exactly five years wide and the last one ends at
  `MAX_YEAR_LOSS`), since the annualization divides by it.
- **Third margin: `claim_rate`** (claims per policy-year) added as column
  (3) of Tables `tab:take-up`/`tab:take-up-static` (`est_claimrate_ols`,
  `est_claimrate_static`). It was already estimated and plotted
  (`est_pclaim_es`, `es-claim-rate.pdf`) but never tabled. With all three
  outcomes annual, the columns satisfy
  `claims/home = policies/home × claims/policy` in consistent units.
  Weights differ by column (`homes_n` for (1)-(2), `policies_n` for (3)),
  so the table is two `feols` calls combined in one `etable`; column
  headers are set via `headers`, not the list names, since `depvar = FALSE`
  suppresses those.
- **Common sample.** `est_claimrate_*` is estimated on `dt_home_cell`, not
  the wider `dt_cell`, so all three columns use the same cells and the
  identity above is not broken by a sample difference. This matters at the
  1994 vintage bin, which spans construction years 1994-1995: `homes_n` is
  undefined for 1994, so that bin must be construction year 1995 alone in
  every column, on both sides of every ratio. The Chunk I version of this
  bullet asserted that was already the case; it held for the denominator
  only, because `dt_home_cell` was a row filter on `dt_cell`, whose
  numerators had already been summed over 1994 and 1995. Fixed 2026-08-26 by
  rebuilding `dt_home_cell` from the row level (§12.2); the cell count is
  71,492, not the 73,487 originally reported here. The paper states the
  1995-only restriction; earlier text called 1995 "a single, ambiguous
  construction year," conflating it with the 1994 year that was dropped
  *because* it is ambiguous.
- **Static column.** `est_home_static` / `est_claimrate_static`:
  `~ post_mh | geo^period_loss + mh + post1994`, same samples, weights and
  clustering, written to
  `output/event-study/countyfp/take-up-static.tex` (Table
  `tab:take-up-static`). The paper now quotes the static estimate as the
  headline for each margin, matching §2's choice for the damage outcomes.
- **Scalars.** Renamed `policies_per_1k_homes_*` →
  `policies_per_1k_homes_yr_*`, `claims_per_1k_homes_*` →
  `claims_per_1k_homes_yr_*`. Added `claim_rate_{avg,min,max}`,
  `*_static`/`*_static_se`/`*_static_t` for all three margins, pre-1994 MH
  baselines `*_base_mh` for all three, and the four levels
  `policies_per_1k_homes_yr_{mh,sb}_{pre,post}`.
- **Why those four levels** (`policies_per_1k_homes_yr_{mh,sb}_{pre,post}`).
  Reported so the static coefficient can be read against the levels it sits
  between. **Superseded in substance by §12.2:** as of Chunk I the column (1)
  static coefficient was -4.9, larger in magnitude than the pre-1994 MH level
  itself, and this bullet explained the gap by a site-built jump at the
  1994/1995 vintage boundary attributed to the National Flood Insurance
  Reform Act of 1994. Both the coefficient and the explanation were
  artifacts of the two denominator defects in §12.2. The corrected estimate
  is +8.12 (2.71), the corrected levels are MH 10.2 → 9.6 and site-built
  40.3 → 41.8, and NFIRA has now been tested directly and ruled out (the
  effect is nine-tenths non-mandated policies). The levels are still
  reported, but the paper no longer uses them to decompose the fitted
  coefficient, since with geographic fixed effects they do not.
- **Caveat, in the paper (`paper.Rmd` appendix), not just here:** `homes_n`
  is fixed as of the 2000 Census; the policy periods run 2009-2023, 9-23
  years later, so differential attrition of the pre-/post-1994 MH stock
  over that gap biases the denominator asymmetrically by vintage, growing
  with the gap. An earliest-period-only (2009-2013) column was checked as
  a partial mitigation and dropped (see above) since it didn't move the
  point estimates. ACS's continuous housing-vintage series could in
  principle bound this drift directly but was **not implemented this
  chunk** (no `import-acs.R` exists in this repo; out of scope for the
  "all inputs already on disk" chunk budget) — noted as a caveat in the
  paper text and as an open item in `notes/LOG.md`, not built.
- **Not covered by this chunk:** `make data`'s `databuild-nfip.R` step
  (the real, non-patched run against `fema.duckdb`) — no `$DATA_PATH`
  access in this sandbox, same standing limitation as every prior chunk
  (§7). Verified instead by patching a copy of the existing
  `nfip-balanced.Rds` with the new merge and running `estimate-nfip.R`
  end-to-end against it (same technique Chunk C used for
  `databuild-mhs.R`/`sample-mhs.Rds`); full detail in `notes/LOG.md`.

### 12.2 Two denominator defects in the take-up design (2026-08-26)

Found while checking whether the site-built take-up jump at the 1994/1995
vintage boundary (§12.1) came from mandatory-purchase policies. It did not.
Both the jump and the negative take-up coefficient it produced were
artifacts of the denominator. Superseding the §12.1 "why those four levels"
bullet and the NFIRA candidate explanation entirely.

**Defect A — within-bin shares normalized over retained years only**
(`program/import/impute-stock.R`). The Census vintage bins are wider than
the retained construction-year window: `1980_1989` retains 1984-1989,
`1990_1994` retains 1990-1993, `1999_2000` retains 1999. The MHS/BPS
within-bin shares were computed after subsetting the annual sources to the
retained years, so they summed to 1 over the retained years and the FULL
Census bin total was allocated across them. The dropped years' stock was
redistributed onto the years that remained: 1984-1989 denominators were
inflated by ~1/0.61-1/0.67, 1990-1993 by ~1/0.74-1/0.77, 1999 by ~1/0.81,
while 1995-1998 (a fully retained bin) were correct. Because the inflation
falls on the pre-reform side of the treatment split it does not cancel; it
depressed measured pre-reform take-up, and since the site-built rate is
~4x the MH rate it depressed the comparison group's pre-reform level by ~4x
as much in levels. The old adding-up test *enshrined* the defect: it
asserted the retained years sum to the full bin total, which is exactly
what should not hold.

*Fix.* New `bin_span` table lists every construction year each Census bin
spans, with a partial-year weight (`1999_2000` is "1999 to March 2000", so
2000 enters at 3/12). Shares are normalized over the span, then subset to
the retained years, so a bin contributes only its retained fraction.
Validation restructured: the exact invariant (shares sum to 1 over the full
span, per state x bin for MH and per county x bin for site-built) is now
asserted in the share-construction blocks, where it belongs; the
section-5 test became a bound (retained years never exceed the bin total,
fully retained bins match exactly) plus a printed realized-vs-year-count
retained fraction, since the realized fraction is source-implied rather
than mechanical. Realized fractions: `1980_1989` 0.667 SB / 0.606 MH,
`1990_1994` 0.768 / 0.735, `1995_1998` 1.000 / 1.000, `1999_2000` 0.805 /
0.828. Benchmark moves from ratio 0.95 to 0.75 (national imputed MH stock
1986-1999 2,865,353 vs. 3,799,500 cumulative MHS shipments) — expected,
since the imputed stock is now a Census-2000 surviving stock net of the
dropped 1994 year rather than an inflated one.

**Defect B — numerator and denominator spanned different construction
years** (`program/estimate/estimate-nfip.R`). `dt_home_cell` was
`dt_cell[!is.na(homes_n) & homes_n > 0]`. `dt_cell` sums `policies_n` and
`claims_n` over every `year_constr` in a `period_constr` bin, while
`homes_n` is undefined for construction year 1994. The 1994 bin therefore
had a two-year numerator (1994 and 1995) over a one-year denominator (1995)
— construction year 1994 supplies 48.5% of that bin's site-built
policy-years and 45.3% of its MH policy-years, so the bin's measured rate
was inflated ~1.9x. Again this lands mostly on the comparison group in
levels, and it lands at exactly the treatment boundary. §12.1's claim that
"on `dt_home_cell` that bin is construction year 1995 alone in every
column" was true of the denominator only.

*Fix.* `dt_home_cell` is rebuilt from the row level rather than filtered
out of `dt_cell`: `dt_home_ok` is the set of `(countyfp, year_constr, mh)`
with a positive `homes_n`, the numerator is `dt` inner-joined to it, and
the denominator is built from the same rows (deduped on the county key
before summing, since `homes_n` is tract-duplicated). `stopifnot` asserts
no `year_constr == 1994` survives on either side. The per-home rate columns
were removed from `dt_cell`, where they were unsafe by construction.

**Effect on the results.** Column (1) of `tab:take-up-static` (annual
policies per 1,000 homes, static `post_mh`) moves -4.88 (3.06) →
+3.62 (2.93) after fix A → **+8.12 (2.71)** after fix B. Column (2)
(claims per 1,000 homes) +0.018 (0.040) → **+0.110 (0.055)**. Column (3)
(claims per policy) is essentially unmoved: 0.00064 (0.00065) →
0.00055 (0.00065), still insignificant — it never used `homes_n`. The
1994-bin event-study coefficient in column (1) moves -35.5 → -28.0 → -4.34.
The claim-level damage results and `estimate-welfare.R` are untouched:
neither uses `homes_n`. N falls 73,487 → 71,492 (construction year 1994
policy-years no longer enter the per-home cells).

**Interpretation now in the paper.** The sign is reversed: post-1994 MH
take-up is *higher*, not lower, and since claims per policy is flat the
identity assigns nearly all of the claims-per-home rise to the take-up
margin. The paper reports this as descriptive, not as a treatment effect,
for three stated reasons: (i) the vintage profile trends rather than steps
— the earliest pre-reform bin is -14.2 (3.05) and significant; (ii) the
sign depends on the geographic fixed effects — the same contrast without
them is -2.05 (1.49), since MH stock concentrates in counties whose overall
take-up rose least, so the pooled levels (MH 10.2 → 9.6, SB 40.3 → 41.8) do
**not** decompose the fitted coefficient the way §12.1 claimed; (iii) the
denominator is imputed while the numerator is not.

**Mandatory-purchase split (the original question).** New
`est_home_mand_static`: the column (1) numerator split into
`mandatory_purchase_policy_n` and its complement, same denominator, weights,
FE and clustering, so the two coefficients sum to the total. Mandated
**+0.79 (0.20)**, non-mandated **+7.33 (2.56)** — about nine-tenths of the
movement is in policies the homeowner was not required to buy, so NFIRA-style
mandate enforcement cannot account for it and a non-mandatory-only version of
the specification is not needed. Caveat: the flag marks only 4-9% of
policy-years, well below the SFHA share, so it under-records mandate exposure
and the split is a lower bound on the mandated part.
`est_home_static_nogeo` supplies the no-geography-FE contrast cited above.

**New scalars** in `output/results/nfip-scalars.csv`:
`policies_{mand,nonmand}_per_1k_homes_yr_static{,_se}`,
`policies_per_1k_homes_yr_static_nogeo{,_se}`,
`policies_per_1k_homes_yr_pre_first{,_se}` (the earliest pre-reform bin),
and `policies_per_1k_homes_yr_max`.

**Sample filters, for the record** (diagnostic only — see §13 for the fix).
The structure restriction is a *floors* filter, not an occupancy filter:
`number_of_floors_in_the_insured_building IN (1, 2, 3, 5)` on claims and
`number_of_floors_in_insured_building IN (1, 2, 3, 5)` on policies (code 5 is
the manufactured-home category and defines `mh`; code 4, split-level, is
excluded). It therefore admits small multi-family and low-rise
non-residential structures into the site-built comparison group on **both**
sides. In the 1984-1999 claim sample, occupancy codes put 83.6% of
site-built claim rows in single-family (codes 1 and 11) and the remaining
16.4% in 2-4 unit (2, 12), other residential (3, 13, 15, 16), and
non-residential (4, 18, 19) categories; the MH side is 98.1% single-family
or residential-manufactured (1, 14), with 1.3% non-residential (4) and 0.3%
non-residential manufactured (17). `occupancy_type` is selected but never
filtered in the claims query and is **not selected at all** in the policies
query — it must be added there before Chunk J's single-family restriction
can be applied on the policy side.

## 13. Single-family occupancy_type restriction, claims and policies (Chunk J/K, 2026-08-26)

Implements the §12.2-adjacent diagnostic above. Colin's decision 2026-08-26:
apply one `occupancy_type` restriction to both the claims and policies
queries in `databuild-nfip.R`, ahead of and shared with Chunk J's
policy-micro build (§14), rather than leaving it as an estimation-time
robustness spec (the original Chunk K plan).

- **Restriction.** `OCCUPANCY_TYPE_SF <- c(1L, 11L, 14L)` in
  `project-params.R`, applied as `occupancy_type IN (...)` in both SQL
  queries in `databuild-nfip.R` (`occ_sf`, built once and shared). Kept
  codes are detached single-family residential under both FEMA coding eras:
  legacy code 1 (also covers pre-RR2.0 MH, since the legacy scheme has no
  separate MH occupancy code), RR2.0 code 11 (single-family, excepting MH or
  a unit within a multi-unit building), and RR2.0 code 14 (residential MH).
  Dropped: 2/3/12/13/15/16 (multi-unit) and 4/6/17/18/19 (non-residential).
  A `stopifnot` after the claims query asserts every retained row's
  `occupancy_type` is in the kept set, since the SQL `WHERE` clause is the
  only thing enforcing this.
- **Effect on sample size.** Claims: 1,816,724 → 1,492,255 site-built
  (mh=0, -17.9%), 25,798 → 25,294 MH (mh=1, -2.0%). The floors-only filter
  had let occupancy 2/3/4/6/12/13/15/16/18/19 rows into the site-built
  group and occupancy 4/6/17 (non-residential) rows into the MH group.
- **Effect on the headline claim-level result.** `building_damage_static`
  (Table `tab:claims-outcomes-static`, §2) moves from the pre-restriction
  $4,110 to **-5,557 (SE 1,461, t=-3.80)** — larger in magnitude, as
  expected from removing a noisier, non-single-family tail from the
  comparison group rather than from the MH group (MH loses only 2% of
  rows). Event-study coefficients keep the same flat-pre/growing-post
  shape (Table `tab:claims-outcomes`, `est_claim_es`).
- **Effect on the take-up artifact (§12.2).** Column (1) of
  `tab:take-up-static` (`policies_per_1k_homes_yr_static`) moves from
  §12.2's post-fix +8.12 (2.71) to **+4.65 (2.24, t=2.08)** — still
  positive and still significant at 5%, so §12.2's reversed-sign finding
  (post-1994 MH take-up higher, not lower) survives the restriction, at
  roughly half the earlier magnitude. `claims_per_1k_homes_yr_static` and
  `claim_rate_static` move similarly modestly; see current
  `output/results/nfip-scalars.csv` for the full set.
- **Consistency checks run:** uniqueness of `nfip-balanced.Rds` on
  `(tractfp, period_loss, mh, year_constr)`; zero missingness on
  `countyfp`/`tractfp`/`year_loss`/`year_constr`/`mh`; `occupancy_type`
  values confirmed restricted to `{1, 11, 14}` on both sides; no negative
  `policies_n`/`claims_n`; `assert_geo_coverage`/`assert_geo_coverage_any`
  (wind-zone, `homes_n`) both pass unchanged. `make test` (fake-data
  harness) passes unchanged, since it runs on simulated data independent
  of this restriction.
- **Not rebuilt this pass:** `estimate-mhs.R` and its downstream MHS
  tables/scalars (cost side, Chunk C) — blocked in this environment by a
  pre-existing missing `derived/mhs-dropped-states.Rds` (needs
  `databuild-mhs.R`, unrelated to this restriction and out of scope here)
  — and `program/descriptives/map.R`, blocked by a pre-existing missing
  `tigris` package in this environment. Neither depends on the NFIP
  occupancy restriction; both are pre-existing environment gaps, not
  introduced by this change.

## 14. Policy-level composition table (Chunk J, 2026-08-26)

Replaces the cell-level policy-composition table of the old §3
(`est_comp_post`, weighted OLS on `geo x period_loss x mh x period_constr`
cell averages) with a design run directly on policy-term microdata, per
Colin's decision 2026-08-26. `est_comp_post`, `v_comp`, `s_comp`, and
`fmla_comp_post` are removed from `estimate-nfip.R`; nothing else in the
script read them.

- **Script:** `program/import/databuild-nfip-policy.R` (new) builds
  `derived/nfip-policy-micro.parquet`, one row per policy term, from the
  same `fema_nfip_policies` source and version (`NFIP_VERSION`) as
  `databuild-nfip.R`'s policy query, with the same floors/occupancy_type/
  state/county/tract filters and construction-year window
  (`MIN_YEAR_CONSTR`-`MAX_YEAR_CONSTR`), restricted to calendar years
  2009-`MAX_YEAR_LOSS` (policy records begin in 2009, matching the balanced
  panel) and deflated to `DISCOUNT_YEAR` dollars via the same CPI series.
  `id` (the dataset's key field) is asserted unique. Added to the `data`
  Makefile target, after `databuild-nfip.R`.
- **Estimation:** `program/estimate/estimate-nfip.R` reads the parquet,
  restricts to `MIN_YEAR_CONSTR`-`MAX_YEAR_CONSTR` (redundant with the
  build-time restriction, kept for consistency with every other data block
  in the script), and computes `period_constr` from `year_constr` with the
  same `bin_constr()` used everywhere else in the file. Always run at
  `countyfp x period_loss`, independent of the script's `agg_geo` argument,
  since the Chunk J spec fixes the geography.
- **Spec:** `c(repl_cost, building_policy_covg, contents_covg_positive, contents_policy_covg_pos, elevated_policy, sfha_policy) ~ i(period_constr, mh, ref = ref_period) | countyfp^period_loss + mh + period_constr`,
  `ref_period` = 1992 under the default `BIN_CONSTR_YEAR = 2`, matching the
  literal `ref = 1992` in the Chunk J plan.
- **New outcome: contents-coverage choice margin.** `contents_covg_positive`
  (`1[contents coverage > 0]`, built in `databuild-nfip-policy.R`) and
  `contents_policy_covg_pos` (the coverage amount, `NA` when the indicator
  is 0 — same "NA, not 0, when the margin doesn't apply" convention as the
  claim-level per-claim averages elsewhere in the script). 31.9% of MH
  policy terms carry no contents coverage vs. 13.5% of site-built, matching
  the 30-35% range in the TODO.md plan.
- **Weights:** none — unlike the cell-level version (`weights = ~policies_n`),
  this is a direct regression on policy-level rows, so no re-weighting is
  needed to recover a policy-weighted average.
- **Clustering: by county (`countyfp`)**, matching every other spec in the
  file.
- **Sample:** 12,787,544 policy terms (266,312 MH, 12,521,232 site-built)
  before per-outcome missingness; `repl_cost` N = 12,645,529 (1.1% missing);
  `contents_policy_covg_pos` N = 11,010,714 (the ~14-32% with no contents
  coverage, by construction).
- **Outputs:** `output/event-study/countyfp/policy-composition.tex` (Table
  `tab:composition`, same file name and table label as the design it
  replaces, so `paper.Rmd`'s `\input` and `\ref` did not need to change).
- **Result, briefly** (full reading in `paper.Rmd` "Selection and
  Composition"): pre-1994, replacement cost and contents coverage
  (conditional amount) show a large gap in the two earliest bins that
  shrinks to insignificant by 1990-1991; the contents-coverage indicator
  (any coverage vs. none) shows a smaller version of the same gap but stays
  significant in three of four pre-1994 bins rather than fading; SFHA share
  is significantly *lower* for MH in three of four pre-1994 bins and, like
  the contents-coverage indicator, does not shrink toward the reference bin
  the way replacement cost and conditional contents coverage do. Post-1994,
  building coverage, replacement cost (first two
  of three bins), and SFHA share are all significantly *higher* for MH,
  each pointing toward higher, not lower, expected damage for the treated
  group — strengthening the conservative-bias reading relative to the
  cell-level table's two-outcome version. Elevated share rises only in the
  last post-1994 bin, unchanged from before.
