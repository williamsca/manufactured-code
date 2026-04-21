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
