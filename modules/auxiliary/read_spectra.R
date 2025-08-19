################################################################################
##### Read spectra
################################################################################

#-------------------------------------------------------------------------------
# Libraries

library(data.table)
library(tools)

#-------------------------------------------------------------------------------
# Spectrometers

# NaturaSpec253-94F6 = .sed

#-------------------------------------------------------------------------------
# Read spectra function

read_spectra <- function(paths) {
  
  #type <- file_ext(paths)
  type <- "sed"

  ### .sed files
  if(type == "sed") {
    
    selection <- grepl("\\.sed$", paths)
    
    reflectance <- lapply(X = 1:length(paths[selection == TRUE]),
                          FUN = apply_sed,
                          paths = paths)
    
    range_max <- sapply(reflectance, `[[`, 1)
    range_spectra <- c(min(range_max[1,]), max(range_max[2,]))
    spectral_bands <- range_spectra[1]:range_spectra[2]
    
    reflectance <- do.call(rbind, lapply(reflectance, function(x) x$spectra))
    reflectance <- as.data.table(reflectance)
    colnames(reflectance) <- as.character(spectral_bands)
    
    reflectance <- cbind(filename = basename(paths),
                         reflectance)
    
  }

  return(reflectance)
  
}

# Apply .sed
apply_sed <- function(X,
                      paths) {
  
  # Read spectra
  spectra <- fread(paths[X], skip= 27)
  spectra <- spectra[, .SD , .SDcols= c(1, ncol(spectra))]
  colnames(spectra) <- c("wv", "reflectance")
  
  if(mean(spectra$reflectance) >= 10) {
    spectra$reflectance <- spectra$reflectance/100
  }
  
  # Range
  range_spectra <- range(spectra$wv)
  diff_range <- range_spectra[2] - range_spectra[1]
  
  if(diff_range == (nrow(spectra)-1)) {
    
    return(list(range = round(range_spectra),
                spectra = spectra$reflectance))
    
  } else {
    
    #Create and predict a spline function
    resample_function <- smooth.spline(x = spectra$wv,
                                       y = spectra$reflectance,
                                       spar= 0.01)
    
    spectra_smoothed <- predict(resample_function, round(range_spectra[1]:range_spectra[2]))$y
    
    # Out
    return(list(range = round(range(spectra$wv)),
                spectra = spectra_smoothed))
    
  }
}
