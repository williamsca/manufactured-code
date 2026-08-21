# Chunk log

Newest entry first. See `TODO.md` PROCESS for what belongs in each memo.

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
