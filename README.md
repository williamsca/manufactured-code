# manufactured-code

The CoreLogic workstream builds and analyzes licensed data on Rivanna. See
[the implementation and build results](notes/corelogic-databuild.md) and
[the research plan](PLAN_CORELOGIC.md). `make test-corelogic` checks synthetic
SQL fixtures; `make data-corelogic` requires a Rivanna Slurm allocation.

Vintage prices run through `program/estimate/corelogic-prices.slurm` with
`CORELOGIC_BUILD` pointing to a verified build and `CORELOGIC_RESULTS` to a new
private results directory. `make estimates-corelogic` also requires Slurm.
See [the amenity and location robustness plan](PLAN_CORELOGIC_ROBUSTNESS.md).
The [initial vintage price results](notes/corelogic-prices.md) include the figures,
specification comparisons, and snapshot size balance.
The [wind-zone triple differences](notes/corelogic-windzone.md) use an audited
county reference and retain zone-specific construction-vintage effects.
The current profiles retain 1994 as its own partially treated cohort; static
summaries also retain 1994 with separate transition-cohort terms.
