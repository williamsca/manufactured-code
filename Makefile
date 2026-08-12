# Citations seem good enough for now, but can change formatting with CSL
# CSL = chicago-author-date

paper.pdf: paper.Rmd manufactured-code.bib
	Rscript -e "rmarkdown::render('$<')"

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
# `data` requires the raw FEMA/Census/MHS source files and $DATA_PATH
# (see .Renviron); it is not runnable without access to that raw data.
# `estimates` and `test` only need the derived/*.Rds files already checked
# into this working copy and have no external data dependency.
# ---------------------------------------------------------------------------

.PHONY: data estimates test all

data:
	Rscript program/import/import-cpi.R
	Rscript program/import/import-ecfr-windzone.R
	Rscript program/import/import-census.R
	Rscript program/import/import-bps.R
	Rscript program/import/import-mhs.R
	Rscript program/import/databuild-mhs.R
	Rscript program/import/databuild-nfip.R
	Rscript program/import/databuild-welfare.R

estimates:
	Rscript program/estimate/estimate-mhs.R
	Rscript program/estimate/estimate-nfip.R
	Rscript program/estimate/estimate-welfare.R
	Rscript program/descriptives/estimate-sumstats-mhs.R
	Rscript program/descriptives/estimate-sumstats-nfip.R
	Rscript program/descriptives/plot-mhs.R
	Rscript program/descriptives/plot-nfip.R
	Rscript program/descriptives/map.R

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
