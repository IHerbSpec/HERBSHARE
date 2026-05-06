################################################################################
#'@title Script to process and retrieve GBIF and create database
################################################################################

#-------------------------------------------------------------------------------
#'@Libraries

library(data.table)
library(rgbif)
library(tidygeocoder)

#-------------------------------------------------------------------------------
#'@Source-code

source("modules/auxiliary/read_spectra.R")

#-------------------------------------------------------------------------------
#'@Compile-file-metadata

read_metadata <- function(folder, pattern = "\\.csv$") {
  
  files <- list.files(folder, pattern = pattern, full.names = TRUE)
  
  # Read all files into a list of data.tables
  dt_list <- lapply(files, fread)
  
  # Get all unique column names across files
  all_cols <- unique(unlist(lapply(dt_list, names)))
  
  # Add missing columns to each data.table
  dt_list <- lapply(dt_list, function(dt) {
    missing_cols <- setdiff(all_cols, names(dt))
    if (length(missing_cols) > 0) {
      dt[, (missing_cols) := NA]
    }
    # Reorder columns so all tables match
    setcolorder(dt, all_cols)
    dt
  })
  
  # Combine all aligned tables
  combined_dt <- rbindlist(dt_list, use.names = TRUE, fill = TRUE)
  
  return(combined_dt)
}

IHerbSpec_metadata <- read_metadata("data/01-spectra/01-metadata")
IHerbSpec_metadata <- cbind(rowID = 1:nrow(IHerbSpec_metadata), IHerbSpec_metadata)
IHerbSpec_metadata[IHerbSpec_metadata == ""] <- NA
fwrite(IHerbSpec_metadata, "data/01-spectra/IHerbSpec_metadata.csv")

# Total
# - 7560

#-------------------------------------------------------------------------------
#'@GBIF-records-search

# Read IHerbSpec metadata
IHerbSpec_metadata <- fread("data/01-spectra/IHerbSpec_metadata.csv")
IHerbSpec_metadata[IHerbSpec_metadata == ""] <- NA

# Read herbaria locations
herbaria_location <- fread("data/01-herbaria_locations/hebaria_locations.csv")

# API search function
api_search <- function(catalogNumber,
                       institutionCode) {

  p <- pred_and(pred_in("catalogNumber", catalogNumber),
                pred_in("institutionCode", institutionCode))

  # Read credentials from key.txt
  # creds <- read.table("key.txt", sep = "=", col.names = c("k", "v"), strip.white = TRUE)
  # creds <- setNames(trimws(creds$v), trimws(creds$k))

  # key <- occ_download(p,
  #                     user = creds["user"],
  #                     pwd = creds["pwd"],
  #                     email = creds["email"])
  
  key <- occ_download(p,
                      user = "antguz",
                      pwd = "Tonito_20191107!",
                      email = "antguz06@gmail.com")
  
  # Wait for completion
  occ_download_wait(key)
  
  # Fetch the zip and import to R as a data.table
  zip_path <- occ_download_get(key, path = "data/01-gbif", overwrite = TRUE)
  gbif_downloaded <- as.data.table(occ_download_import(zip_path))
  
  # Keep only columns you want
  keep <- c("gbifID","institutionCode","catalogNumber",
            "continent", "countryCode", "higherGeography", "stateProvince", 
            "locality", "decimalLatitude","decimalLongitude",
            "species","genus","family","order","class",
            "eventDate", "year", "month", "day", "recordedBy",
            "references",
            "accessRights", "license", "rightsHolder")
  
  gbif_keep <- gbif_downloaded[, ..keep]
  
  return(gbif_keep)
  
}

# Clean records for API search
api_file <- unique(IHerbSpec_metadata[, .(catalogNumber, institutionCode)])
api_file <- api_file[!is.na(catalogNumber)]
api_file <- api_file[!is.na(institutionCode)]

# Do search
gbif_file <- api_search(catalogNumber = api_file$catalogNumber,
                        institutionCode = api_file$institutionCode)

# Merge metadata of spectra and GBIF
HERBSPHERE_metadata <- merge(gbif_file,
                             IHerbSpec_metadata,
                             by = c("catalogNumber", "institutionCode"),
                             all.x = TRUE,
                             all.y = TRUE)

# Clean and order metadata
HERBSPHERE_metadata[HERBSPHERE_metadata == ""] <- NA
setcolorder(HERBSPHERE_metadata, c("rowID", setdiff(names(HERBSPHERE_metadata), "rowID")))
HERBSPHERE_metadata <- HERBSPHERE_metadata[order(rowID)]

# Export file
fwrite(HERBSPHERE_metadata, "data/02-organized/HERBSPHERE_metadata.csv")

#-------------------------------------------------------------------------------
#'@Cleaning-HERBSPHERE_metadata

# Select no matching
HERBSPHERE_missing <- HERBSPHERE_metadata[is.na(rowID)]
HERBSPHERE_missing <- HERBSPHERE_missing[, -1]
HERBSPHERE_missing <- HERBSPHERE_missing[, 1:21]
HERBSPHERE_missing[HERBSPHERE_missing == ""] <- NA

# Select matching
HERBSPHERE_metadata <- HERBSPHERE_metadata[!is.na(rowID)]
HERBSPHERE_metadata[HERBSPHERE_metadata == ""] <- NA

# Columns to fill
fill_cols <- setdiff(intersect(names(HERBSPHERE_metadata), names(HERBSPHERE_missing)),
                     c(HERBSPHERE_missing[,-2]))

# Fill missing values
HERBSPHERE_metadata[HERBSPHERE_missing,
                    (fill_cols) := Map(fcoalesce,
                                       mget(fill_cols),
                                       mget(paste0("i.", fill_cols))
                                       ),
                    on = "catalogNumber"]

# Export file
fwrite(HERBSPHERE_metadata, "data/02-organized/HERBSPHERE_metadata.csv")

#-------------------------------------------------------------------------------
#'@Search-locations

# Read HERBSPHERE_metadata
HERBSPHERE_metadata <- fread("data/02-organized/HERBSPHERE_metadata.csv")
HERBSPHERE_metadata[HERBSPHERE_metadata == ""] <- NA
gbif_file <- HERBSPHERE_metadata

# Get location function
get_coords <- function(gbif_file, herbaria_location) {
  
  pad_to <- function(x, n) {
    if(length(x) >= n) return(x[seq_len(n)])
    c(x, rep(NA_real_, n - length(x)))
  }
  
  # pass 1 — higherGeography
  na_coordinates <- is.na(gbif_file$decimalLatitude)
  na_gbif_file <- gbif_file[na_coordinates, ]
  
  if(nrow(na_gbif_file) > 0) {
    
    parts <- strsplit(as.character(na_gbif_file$higherGeography), ";")
    max_len <- max(lengths(parts))
    
    mat <- t(sapply(parts, function(x) {
      x <- x[x != ""]
      length(x) <- max_len
      x
    }))
    
    continent <- mat[, 1]
    country <- mat[, 2]
    state <- mat[, 3]
    county <- mat[, 4]
    
    loc_city <- geo(street = na_gbif_file$locality,
                    county = county,
                    state = state,
                    country = country,
                    method = "osm")
    
    # pad to exactly the number of NAs
    lat1  <- pad_to(loc_city$lat,  sum(na_coordinates))
    long1 <- pad_to(loc_city$long, sum(na_coordinates))
    
    gbif_file$decimalLatitude[na_coordinates]  <- lat1
    gbif_file$decimalLongitude[na_coordinates] <- long1
    
  }
  
  # pass 2 — higherGeography
  na_coordinates <- is.na(gbif_file$decimalLatitude)
  na_gbif_file <- gbif_file[na_coordinates, ]
  
  if(nrow(na_gbif_file) > 0) {
    
    parts <- strsplit(as.character(na_gbif_file$higherGeography), ";")
    max_len <- max(lengths(parts))
    
    mat <- t(sapply(parts, function(x) {
      x <- x[x != ""]
      length(x) <- max_len
      x
    }))
    
    continent <- mat[, 1]
    country <- mat[, 2]
    state <- mat[, 3]
    county <- mat[, 4]
    
    loc_city <- geo(county = county,
                    state = state,
                    country = country,
                    method = "osm")
    
    # pad to exactly the number of NAs
    lat1  <- pad_to(loc_city$lat,  sum(na_coordinates))
    long1 <- pad_to(loc_city$long, sum(na_coordinates))
    
    gbif_file$decimalLatitude[na_coordinates]  <- lat1
    gbif_file$decimalLongitude[na_coordinates] <- long1
    
  }
  
  # pass 3 — city + state + country
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
  
  # pass 4 — state + country for any still-missing rows
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
  
  # pass 5 — Country for any still-missing rows
  na_coordinates <- is.na(gbif_file$decimalLatitude)
  na_gbif_file <- gbif_file[na_coordinates, ]
  
  if(nrow(na_gbif_file) > 0) {
    
    loc_state <- geo(country = na_gbif_file$countryCode,
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
  
  # pass 6 - 0 to 0 coordinates
  gbif_file[is.na(decimalLatitude), decimalLatitude := 0.0]
  gbif_file[is.na(decimalLongitude), decimalLongitude := 0.0]
  
  # Merge herbaria locations
  gbif_file <- merge(gbif_file,
                     herbaria_location,
                     by = "institutionCode",
                     all.x = TRUE,
                     all.y = FALSE)
  
  gbif_file

}

# Get locations
gbif_file <- get_coords(gbif_file, herbaria_location)

# Order
setcolorder(gbif_file, c("rowID", setdiff(names(gbif_file), "rowID")))
gbif_file <- gbif_file[order(rowID)]

# Export file
fwrite(gbif_file, "data/02-organized/HERBSPHERE_metadata_locations.csv")

#-------------------------------------------------------------------------------
#'@Compile-spectra

# Search of paths
file_paths <- list.files("data/01-spectra",
                         full.names = TRUE, 
                         recursive = TRUE,
                         pattern = "\\.(sed|sig|asd)$",)

# Read spectra
spectra <- read_spectra(paths = file_paths)

# Order columns
bands <- as.numeric(colnames(spectra)[-1])
bands <- bands[order(bands)]
spectra <- spectra[, .SD, .SDcols = c(colnames(spectra)[1], as.character(bands))]

# Export file
fwrite(spectra, "data/02-organized/spectra_compiled.csv")

# Files to use
database_names <- c(gbif_file$filename,
                    gbif_file$backgroundFilename[!is.na(gbif_file$backgroundFilename)],
                    gbif_file$whiteRefFilename[!is.na(gbif_file$whiteRefFilename)])

spectra_names <- spectra$filename

# Files that are not in spectra_names
setdiff(database_names, spectra_names)

# Files that are not in database_names
setdiff(spectra_names, database_names)




