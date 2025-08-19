################################################################################
##### Script to process and retrieve GBIF and create database
################################################################################

#-------------------------------------------------------------------------------
# Libraries

library(data.table)
library(rgbif)
library(tidygeocoder)

#-------------------------------------------------------------------------------
# Source code

source("modules/auxiliary/read_spectra.R")

#-------------------------------------------------------------------------------
# Read GBIF file and metadata file

gbif_file <- fread("data/gbif.csv")
metadata_spectra_file <- fread("data/spectra/HUH_metadata.csv")

#-------------------------------------------------------------------------------
# Preprare GBIF file

# Get location function if that does not exist
get_locations <- function(gbif_file) {
  
  # Get missing locations
  na_coordinates <- is.na(gbif_file$decimalLatitude)
  na_gbif_file <- gbif_file[na_coordinates == TRUE, ]
  
  # Locations
  get_locations <- geo(county = gbif_file$county,
                       state = gbif_file$stateProvince,
                       country = gbif_file$countryCode,
                       method = 'osm')
  
  gbif_file$decimalLatitude[na_coordinates = TRUE] <- get_locations$lat
  gbif_file$decimalLongitude[na_coordinates = TRUE] <- get_locations$long
  
  return(gbif_file)
  
}

# Get locations
gbif_file <- get_locations(gbif_file)

# Get key columns
gbif_file <- gbif_file[, .SD, .SDcols = c("gbifID", "institutionCode", "catalogNumber",
                                          "decimalLatitude", "decimalLongitude",
                                          "species", "genus", "family", "order", "class")]

#-------------------------------------------------------------------------------
# Merge GBIF and metadata

# Landmark columns
metadata_spectra_file$catalogNumber <- paste0("barcode-", 
                                              sprintf("%08d", metadata_spectra_file$specimenIdentifier))
# Merge metadata of spectra and GBIF
metadata_and_gbif <- merge(gbif_file,
                           metadata_spectra_file,
                           by = "catalogNumber")

# Export file
fwrite(metadata_and_gbif, "data/metadata_and_gbif.csv")

#-------------------------------------------------------------------------------
# Compile spectra data

# Search of paths
file_paths <- list.files("data/spectra",
                         full.names = TRUE, 
                         recursive = TRUE)

# Files to use
order_files <- match(metadata_spectra_file$filename, basename(file_paths))
file_paths <- file_paths[order_files]
spectra <- read_spectra(file_paths)

# Export file
fwrite(spectra, "data/spectra_compiled.csv")
