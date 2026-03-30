# This script imports CPI data from the Bureau of Labor Statistics

rm(list = ls())
library(here)
library(data.table)
library(readxl)
library(lubridate)

data_path <- Sys.getenv("DATA_PATH")

# import ----
dt <- as.data.table(read_xlsx(
    file.path(data_path, "crosswalk", "bls-cpi",
    "SeriesReport-20250912131731_9e879e.xlsx"),
    skip = 10
))

# clean ----
dt <- melt(
    dt,
    id.vars = c("Year"), variable.name = "month", value.name = "cpi"
)

dt <- dt[!month %in% c("Annual", "HALF1", "HALF2")]

dt[, date := ymd(paste0(Year, "-", month, "-01"))]
dt[, month := NULL]

setnames(dt, "Year", "year")
setorder(dt, year, date)

# export ----
fwrite(dt, here("derived", "cpi-bls.csv"))