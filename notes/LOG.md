# Chunk log

Newest entry first. See `TODO.md` PROCESS for what belongs in each memo.

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
