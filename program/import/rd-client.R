# Loads the research-database R client from the checkout named by RD_HOME.
# RD_HOME also points the client's own catalog lookups at that checkout
# (rd_repo_root()), which is why no override is needed here.
library(here)
readRenviron(here(".Renviron"))

rd_home <- Sys.getenv("RD_HOME")
if (!nzchar(rd_home)) stop("RD_HOME is not set; see program/import/UPDATE.md §4")

source(file.path(rd_home, "client", "r", "load_all.R"))
rd_load_client(file.path(rd_home, "client", "r"))
