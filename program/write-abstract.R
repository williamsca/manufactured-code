# Writes the abstract of paper.Rmd, with inline R expressions evaluated, to abstract.md.
library(here)
library(stringr)

source(here("program", "load-results.R"))
tex <- function(x) x  # output is markdown, so leave percent signs unescaped

lines <- readLines(here("paper.Rmd"), warn = FALSE)
start <- which(str_detect(lines, fixed("\\begin{abstract}")))[1]
end   <- which(str_detect(lines, fixed("\\end{abstract}")))[1]
abstract <- paste(lines[(start + 1):(end - 1)], collapse = "\n")

pattern <- "`r ([^`]+)`"
exprs   <- str_match_all(abstract, pattern)[[1]][, 2]
for (e in unique(exprs)) {
  val <- paste(eval(parse(text = e)), collapse = "")
  abstract <- str_replace_all(abstract, fixed(paste0("`r ", e, "`")), val)
}

writeLines(c(str_trim(abstract), ""), here("abstract.md"))
