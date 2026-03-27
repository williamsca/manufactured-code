# Analysis plan: HUD Code changes and manufactured home prices

## Motivation

The MH industry shows measured productivity declines over recent decades. One candidate explanation is tightening HUD construction standards, which raise production costs but also improve quality. This exercise estimates the price effects of major HUD Code changes to gauge how much of the productivity story they can explain.

## Data

- **`sample.Rds`** — national-year panel (1958–2024). Key variables: `avg_sales_price`, `avg_sales_price_single`, `avg_sales_price_double`, `shipments`, `emp_mh`, plus NBER-CES productivity measures (`tfp4_nberces`, `real_vadd_pemp_nberces`).
- **`sample-state.Rds`** — state-year panel (1980–2024, prices through 2013). Key variables: `avg_sales_price` (overall, single, double), `placements`, `emp_mh`, `statefp`, `state_name`.

Prices are nominal. Deflate to constant dollars using the BLS CPI-U (or the NBER-CES shipments deflator `piship_nberces` for the national series).

## Wind zone classification

The 1994 rule created three wind zones. For the DiD, classify each state by its *predominant* HUD wind zone exposure:

| Zone | Description | States (illustrative) |
|------|-------------|----------------------|
| I | Inland, 70 mph | Most interior states |
| II | Hurricane-susceptible coast, 100 mph | TX (Gulf), LA, MS, AL, FL panhandle, GA coast, SC, NC, VA coast, NY/NJ coast, New England coast |
| III | Highest-risk coast, 110 mph | South FL, FL Keys, southern TX coast, parts of LA coast |

For tractability, define a binary treatment indicator: **Treated = state where a substantial share of MH placements go to Zone II or III counties.** Coastal Gulf and Atlantic states from Texas to Maine are treated; interior and Pacific states are control. Refinements:
- Assign treatment based on the HUD Basic Wind Zone Map county designations (24 CFR 3280.305)
- States with only a small coastal fringe (e.g., Virginia, New York) could be coded as partially treated or excluded in robustness checks
- An intensity measure (share of state area or population in Zone II/III) can serve as a continuous treatment variable

---

## Analysis 1: National time series with regulatory event markers

### Purpose
Show the trajectory of real MH prices alongside major code changes, giving a visual sense of whether prices jump at plausible moments.

### Specification
- Plot real average sales price (overall, single-wide, double-wide) from 1980–2013
- Add vertical lines at the four costliest regulatory events identified in `code-history.md`:
  1. **1994** — Wind Zone II/III structural overhaul (effective July 1994)
  2. **2006** — First MHCC rule effective, including NEC/AFCI adoption (effective May 2006)
  3. **2002** — Smoke alarm interconnection rule (effective ~2002)
  4. **1994** — Energy conservation Uo values (effective October 1994)
- Secondary panel: plot `real_vadd_pemp_nberces` or `tfp4_nberces` on the same timeline to connect price changes to productivity measures

### Notes
- This is purely descriptive — many things move prices (lumber costs, demand cycles, mix shifts toward doubles). The value is in establishing the basic time-series facts.
- Consider also plotting shipments-weighted average to account for composition.

---

## Analysis 2: Average prices by wind zone around 1994

### Purpose
Show whether treated (Zone II/III) states experienced differential price increases relative to control (Zone I) states around the 1994 wind standard.

### Specification
- Compute average real price (weighting by placements) for treated vs. control states, 1985–2000
- Plot the two series on the same axes with a vertical line at 1994
- Repeat separately for single-wide and double-wide prices
- Optionally show the *gap* (treated minus control) over time

### What to look for
- Parallel pre-trends before 1994
- A level shift or divergence beginning in 1994–1995 in treated states
- Whether the gap stabilizes (one-time cost passthrough) or continues widening

---

## Analysis 3: Event study — 1994 wind standard DiD

### Purpose
Formally estimate the dynamic treatment effect of the 1994 wind zone requirements on MH prices.

### Specification

**Baseline two-way fixed effects event study:**

```
log(price_st) = α_s + γ_t + Σ_k β_k · (Treated_s × 1[year = k]) + X_st'δ + ε_st
```

where:
- `s` indexes states, `t` indexes years
- `α_s` = state fixed effects
- `γ_t` = year fixed effects
- `Treated_s` = 1 if state is in Wind Zone II/III
- `k` ranges over event-time indicators, e.g., 1988–2000 with 1993 as the omitted base year
- `X_st` = optional controls: log placements (demand), share double-wide (composition), state-level construction employment

**Estimation details:**
- Estimate with `fixest::feols`
- Cluster standard errors by state (the level of treatment assignment)
- Sample: 1985–2002 (symmetric window; robustness with 1980–2005)
- Dependent variable: log real average sales price (overall; then single and double separately)

**Event study plot:**
- Plot β_k coefficients with 95% CIs
- Pre-period coefficients should be near zero if parallel trends hold
- Post-1994 coefficients measure the cumulative price effect of Zone II/III compliance

### Robustness checks
1. **Continuous treatment intensity:** Replace binary `Treated_s` with share of state area/population in Zone II/III
2. **Exclude partially-treated states:** Drop states with ambiguous zone assignment
3. **Placebo test:** Run the same specification with a fake treatment date (e.g., 1990) on the pre-period only
4. **Wild cluster bootstrap:** With ~15–20 treated states, asymptotic cluster SEs may be unreliable. Use `fwildclusterboot` or similar for inference.

---