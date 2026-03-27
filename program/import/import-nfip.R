library(here)

# FEMA NFIP Claims V2
url  <- "https://www.fema.gov/about/reports-and-data/openfema/v2/FimaNfipClaimsV2.parquet"
dest <- here("data", "FimaNfipClaimsV2.parquet")

if (file.exists(dest)) {
  message("NFIP claims already present, skipping download.")
} else {
  message("Downloading NFIP claims...")
  download.file(url, dest, mode = "wb")
  message("Done.")
}
