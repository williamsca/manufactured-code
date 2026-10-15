# Redraw the public CoreLogic event-study figures from exported coefficients;
# no licensed microdata or Rivanna connection required.
# Usage: Rscript program/estimate-corelogic/replot-corelogic.R
library(here)
library(data.table)
library(ggplot2)
source(here("program", "estimate-corelogic", "corelogic-mh-only.R"))
for (analysis in c("prices", "quantities")) {
    out_dir <- here("output", "corelogic", analysis)
    quantity <- analysis == "quantities"
    tab <- fread(file.path(out_dir, "mh_only_vintage_coefficients.csv"))
    cl_mh_only_paper_plot(tab, out_dir, quantity = quantity)
    tab_state <- fread(file.path(out_dir, "mh_only_vintage_coefficients_state_vintage_fe.csv"))
    cl_mh_only_compare_plot(tab, tab_state, out_dir, quantity = quantity)
}
