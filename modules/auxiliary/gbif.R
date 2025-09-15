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

# gbif_file <- fread("data/01-gbif/gbif2.csv")
metadata_spectra_file <- fread("data/01-spectra/HUH_metadata.csv")
herbaria_location <- fread("data/01-herbaria_locations/hebaria_locations.csv")

#-------------------------------------------------------------------------------
# Merge GBIF and metadata

# Landmark columns
metadata_spectra_file <- metadata_spectra_file[!is.na(specimenIdentifier),]
metadata_spectra_file$catalogNumber <- paste0("barcode-", 
                                              sprintf("%08d", metadata_spectra_file$specimenIdentifier))

api_search <- function(catalogNumber = unique(metadata_spectra_file$catalogNumber)) {
  
  p <- pred_in("catalogNumber", metadata_spectra_file$catalogNumber)
  
  # Set GBIF_USER / GBIF_PWD / GBIF_EMAIL as env vars, or pass user/pwd/email explicitly.
  key <- occ_download(p,
                      user  = "antguz",
                      pwd   = "Tonito_20191107!",
                      email = "antguz06@gmail.com")
  
  # Wait for completion
  occ_download_wait(key)
  
  # Fetch the zip and import to R as a data.table
  zip_path <- occ_download_get(key, path = "data/01-gbif", overwrite = TRUE)
  gbif_downloaded <- as.data.table(occ_download_import(zip_path))
  
  # Keep only columns you want
  keep <- c("gbifID","institutionCode","catalogNumber",
            "continent","countryCode", "higherGeography", "stateProvince", "locality", "decimalLatitude","decimalLongitude",
            "species","genus","family","order","class",
            "references")
  
  gbif_keep <- gbif_downloaded[, ..keep]
  
  return(gbif_keep)
  
}


# Search catalogNumber
gbif_file <- api_search(catalogNumber = unique(metadata_spectra_file$catalogNumber))

# Merge metadata of spectra and GBIF
metadata_and_gbif <- merge(gbif_file,
                           metadata_spectra_file,
                           by = "catalogNumber")

# Export file
fwrite(metadata_and_gbif, "data/02-organized/metadata_and_gbif.csv")

#-------------------------------------------------------------------------------
# Preprare GBIF file

metadata_and_gbif <- fread("data/02-organized/metadata_and_gbif.csv")
gbif_file <- metadata_and_gbif

# Get location function if that does not exist
get_coords <- function(gbif_file, herbaria_location) {
  
  pad_to <- function(x, n) {
    # ensures length(x) == n by padding with NA
    if (length(x) >= n) return(x[seq_len(n)])
    c(x, rep(NA_real_, n - length(x)))
  }
  
  # pass 1 — city + state + country
  na_coordinates <- is.na(gbif_file$decimalLatitude)
  na_gbif_file <- gbif_file[na_coordinates, ]
  
  if(nrow(na_gbif_file) > 0) {
    
    loc_city <- geo(city = na_gbif_file$locality,
                    state = na_gbif_file$stateProvince,
                    country = na_gbif_file$countryCode,
                    method = "osm")
    
    # pad to exactly the number of NAs
    lat1  <- pad_to(loc_city$lat,  sum(na_coordinates))
    long1 <- pad_to(loc_city$long, sum(na_coordinates))
    
    gbif_file$decimalLatitude[na_coordinates]  <- lat1
    gbif_file$decimalLongitude[na_coordinates] <- long1
    
  }
  
  # pass 2 — state + country for any still-missing rows
  na_coordinates <- is.na(gbif_file$decimalLatitude)
  na_gbif_file <- gbif_file[na_coordinates, ]
  
  if(nrow(na_gbif_file) > 0) {
    
    loc_state <- geo(state = na_gbif_file$stateProvince,
                     country = na_gbif_file$countryCode,
                     method  = "osm")
    
    lat2  <- pad_to(loc_state$lat,  sum(na_coordinates))
    long2 <- pad_to(loc_state$long, sum(na_coordinates))
    
    # Only fill where still NA
    idx <- which(na_coordinates)
    fill_lat  <- is.na(gbif_file$decimalLatitude[idx])
    fill_long <- is.na(gbif_file$decimalLongitude[idx])
    
    gbif_file$decimalLatitude[idx[fill_lat]]  <- lat2[fill_lat]
    gbif_file$decimalLongitude[idx[fill_long]] <- long2[fill_long]
    
  }
  
  # Merge herbaria locations
  gbif_file <- merge(gbif_file,
                     herbaria_location,
                     by = "institutionCode",
                     all.x = TRUE,
                     all.y = FALSE)
  
  gbif_file

}

# Get locations
gbif_file <- get_locations(metadata_and_gbif, herbaria_location)

# Export file
fwrite(gbif_file, "data/02-organized/metadata_and_gbif.csv")

#-------------------------------------------------------------------------------
# Compile spectra data

# Search of paths
file_paths <- list.files("data/01-spectra",
                         full.names = TRUE, 
                         recursive = TRUE)

# Files to use
order_files <- match(metadata_spectra_file$filename, basename(file_paths))
file_paths <- file_paths[order_files]
spectra <- read_spectra(paths = file_paths)

# Order columns
bands <- as.numeric(colnames(spectra)[-1])
bands <- bands[order(bands)]
spectra <- spectra[, .SD, .SDcols = c(colnames(spectra)[1], as.character(bands))]

# Export file
fwrite(spectra, "data/02-organized/spectra_compiled.csv")




























