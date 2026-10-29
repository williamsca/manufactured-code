# Build the paper from local output files. Run CoreLogic estimation explicitly.
.DEFAULT_GOAL := paper.pdf
.PHONY: corelogic
corelogic:
	./run_remote.sh estimate-corelogic

# Citations seem good enough for now, but can change formatting with CSL
# CSL = chicago-author-date

CL_PAPER = output/corelogic
CL_PAPER_INPUTS = $(wildcard $(CL_PAPER)/prices/*.csv $(CL_PAPER)/quantities/*.csv) \
	$(CL_PAPER)/prices/manifest.json $(CL_PAPER)/quantities/manifest.json

paper.pdf: paper.Rmd program/load-results.R manufactured-code.bib \
	$(CL_PAPER_INPUTS) \
	output/descriptives/sumstats-corelogic.tex \
	$(wildcard output/nfip/*.csv output/nfip/*.tex output/nfip/*.pdf) \
	output/descriptives/sumstats-nfip-scalars.csv output/descriptives/sumstats-nfip.tex \
	output/census/census-scalars.csv output/census/census-static-paper.tex \
	output/cost-benefit/corelogic-comparison-scalars.csv output/cost-benefit/corelogic-comparison.tex
	Rscript -e "rmarkdown::render('$<')"

output/descriptives/sumstats-corelogic.tex: program/descriptives/sumstats-corelogic.R \
	$(CL_PAPER_INPUTS)
	Rscript program/descriptives/sumstats-corelogic.R

output/cost-benefit/corelogic-comparison-scalars.csv output/cost-benefit/corelogic-comparison.tex &: \
	program/cost-benefit/estimate-corelogic-comparison.R $(CL_PAPER_INPUTS) \
	output/cost-benefit/hud-comparison-scalars.csv output/mhs/mhs-scalars.csv notes/hud-wind-forecasts.csv
	Rscript program/cost-benefit/estimate-corelogic-comparison.R

two-pager.pdf: two-pager.Rmd program/load-results.R program/estimate-nfip/nfip-scalars.R manufactured-code.bib \
	$(wildcard output/*/*.csv output/*/*.tex output/*/*.pdf)
	Rscript -e "rmarkdown::render('$<')"

# slides.pdf refreshes the quoted numbers first: every estimate on a slide is a
# macro from output/slide-numbers.tex, never typed in by hand.
slides.pdf: slides.tex manufactured-code.bib output/slide-numbers.tex \
	output/corelogic/quantities/mh_raw_counts_by_zone.pdf \
	output/descriptives/map-mhs-windzone-counties.pdf \
	output/corelogic/prices/mh_static_ladder.tex \
	output/corelogic/prices/mh_static_ladder_slides_1.tex \
	output/corelogic/prices/mh_static_ladder_slides_2.tex \
	output/corelogic/prices/mh_static_ladder_slides_3.tex \
	output/corelogic/prices/mh_static_ladder_slides_4.tex \
	output/corelogic/prices/log_es_ddd.pdf \
	output/corelogic/prices/mh_only_vintage_prices_slides.pdf \
	output/corelogic/quantities/mh_only_vintage_quantities_slides.pdf
	pdflatex slides
	bibtex slides
	pdflatex slides
	pdflatex slides

output/descriptives/map-mhs-windzone-counties.pdf: program/descriptives/map.R \
	program/import/project-params.R program/import/rd-client.R \
	derived/mhs-state-treatment.Rds
	Rscript program/descriptives/map.R

.PHONY: output/slide-numbers.tex
output/slide-numbers.tex:
	Rscript program/write-slide-macros.R

%.pdf: %.tex manufactured-code.bib
	pdflatex $*
	bibtex $*
	pdflatex $*
	pdflatex $*

%.tex: %.md
	pandoc --natbib $< --template=latex.template.article -o $@

paper.html: paper.md
	pandoc --citeproc paper.md --template=html.template -o $@


# Latex and CSL templates available at: '~/.pandoc/templates' and '~/.pandoc/csl'

# ---------------------------------------------------------------------------
# Full pipeline: data/ -> derived/ -> program/ -> output/ -> paper.pdf
#
# Stage targets, not fine-grained per-file rules: each R script writes
# several output files, so `make` here means "run this stage's scripts in
# dependency order," not "make will skip a script because its outputs look
# current." Run order and per-stage runtimes are documented in
# notes/specs.md.
#
# `data` requires $RD_HOME (a research-database checkout), a populated
# $RD_CACHE or AWS credentials to fill it, a Census API key, and network
# access to eCFR (see .Renviron and program/import/UPDATE.md §4). $DATA_PATH
# is no longer needed anywhere in this layer.
# `estimates` and `test` only need the derived/*.Rds files already checked
# into this working copy and have no external data dependency.
# ---------------------------------------------------------------------------

.PHONY: data estimates test all

# Hosted licensed data; run only on its host/compute node, independently of
# the local public-data rebuild. Override CORELOGIC_ARGS for a state pilot.
.PHONY: data-corelogic
data-corelogic:
	Rscript program/import/databuild-corelogic.R $(CORELOGIC_ARGS)

.PHONY: test-corelogic
test-corelogic:
	Rscript program/tests/check-corelogic-databuild.R
	Rscript program/tests/check-corelogic-mh-only.R

# CoreLogic estimates run on Rivanna via Slurm, not locally:
#   ./run_remote.sh estimate-corelogic [SCRIPT]
# writes output/corelogic/{prices,quantities}/.
# See program/estimate-corelogic/estimate-corelogic.slurm.

data:
	Rscript program/import/import-cpi.R
	Rscript program/import/import-fhfa-hpi.R
	Rscript program/import/import-census.R
	Rscript program/import/import-census-takeup.R
	Rscript program/import/import-census-tenure.R
	Rscript program/import/databuild-mhs.R
	Rscript program/import/impute-stock.R
	Rscript program/import/databuild-nfip.R
	Rscript program/import/databuild-nfip-policy.R
	Rscript program/import/databuild-welfare.R
	Rscript program/import/databuild-hud-benefit.R

estimates:
	Rscript program/descriptives/map.R
	Rscript program/descriptives/sumstats-corelogic.R
	Rscript program/descriptives/sumstats-nfip.R
	Rscript program/descriptives/windzone-intensity.R
	Rscript program/estimate-mhs/estimate-mhs.R
	Rscript program/estimate-nfip/estimate-nfip-claims.R
	Rscript program/estimate-nfip/estimate-nfip-composition.R
	Rscript program/estimate-nfip/estimate-nfip-takeup.R
	Rscript program/estimate-nfip/estimate-nfip-windzone.R
	Rscript program/estimate-census/estimate-census.R
	Rscript program/cost-benefit/estimate-welfare.R
	Rscript program/cost-benefit/estimate-hud-comparison.R
	Rscript program/cost-benefit/estimate-corelogic-comparison.R

# Work in progress, not in the paper.
.PHONY: nfip-mh-only
nfip-mh-only:
	Rscript program/estimate-nfip/estimate-nfip-mh-only.R

# Fake-data verification harness (program/tests/): each estimator is applied
# to simulated data with known parameters and must recover the truth.
test:
	Rscript program/tests/run-tests.R

# Full clean-rebuild chain: data -> estimates -> test -> paper.pdf
all: data estimates test paper.pdf

# Clean target
.PHONY: clean

clean:
	rm -f paper.pdf
	rm -f proposal.pdf
	rm -f Rplots.pdf
	rm -f .RData
	rm -f *.aux
	rm -f *.log
	rm -f *.gz
	rm -f *.out
	rm -f *.bbl
	rm -f *.blg
	rm -f *.nav
	rm -f *.snm
	rm -f *.toc
