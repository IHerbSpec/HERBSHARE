################################################################################
### Define create database

################################################################################
# Source of helpers ------------------------------------------------------------
################################################################################

source("modules/auxiliary/")

################################################################################
# Metadata ---------------------------------------------------------------------
################################################################################

# Read metadata
metadata <- fread("data/metadata.csv")

# Download datasets

# Compile datasets for evaluation
compile_datasets <- function(metadata) {
  
  unique_sensors <- unique(metadata$instrumentModel)
  
  for(i in 1:length(unique_sensors)) {
    
    # SVC files (.sig)
    if(unique_sensors[i] == "SVC HR-1024i") {
      
      # Paths
      paths <- list.files(path = paste0(getwd(), "/data/spectra"), 
                          pattern = ".sig", 
                          all.files = TRUE,
                          full.names = TRUE, 
                          recursive = TRUE)
      # Frame
      spectra <- read_svc(paths = paths, 
                          new_bands = 340:2500)
      
      fwrite(spectra, paste0(getwd(), "/data/compiled/sig_spectra.csv"))
      
    }
  }
}

# Create database
compile_datasets(metadata)

