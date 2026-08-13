# Spec sheet

Source of truth for every table/figure in `paper.Rmd`/`slides.tex`. Paper text
is checked against this file, not against memory. Update in the same commit
as any spec change (see `TODO.md` PROCESS).

Last verified: 2026-08-12, against commit at the top of `notes/LOG.md` (Chunk C1).

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
  `year_constr` in [1983, 1999] and `year_loss` in [1994, 2023]
  (`MIN_YEAR_CONSTR`/`MAX_YEAR_CONSTR`/`MIN_YEAR_LOSS`/`MAX_YEAR_LOSS` in
  `program/import/project-params.R`; `MIN_YEAR_CONSTR` extended from 1988
  to 1983 in Chunk C1 to buy a longer pre-period for the parallel-trends
  check — `MAX_YEAR_CONSTR` extension is an open question, not decided);
  rows with negative net payments after recoveries are dropped so the OLS
  and Poisson estimators share a sample (`dt_claims_est`).
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
- **Weights:** cell-level OLS specs (composition, MH-share, claim-rate) are
  weighted by `policies_n`; the take-up PPML is unweighted (counts model)
- **Clustering:** none (IID)
- **Outputs:** `output/event-study/countyfp/take-up.tex` (Table
  `tab:take-up`, appendix), `output/event-study/countyfp/policy-composition.tex`
  (Table `tab:composition`)
- **Known issue (Chunk E):** `policies_ppermit` (policies ÷ single-family
  building permits) is the wrong take-up denominator — see TODO Chunk E.
  The take-up table currently reports raw PPML counts, not a rate.
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
