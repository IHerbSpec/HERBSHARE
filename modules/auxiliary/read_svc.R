################################################################################
##### Function to read SVC files and get metadata
################################################################################

# Look and extract information of .sig files based on a root path

#-------------------------------------------------------------------------------
# Libraries

library(data.table)
library(parallel)

#-------------------------------------------------------------------------------
#Function
read_svc <- function(paths, new_bands = 340:2500) {
  
  # To compile function
  apply_compile <- function(X, 
                            paths,
                            new_bands = 340:2500) {
    
    # Read spectra
    spectra <- fread(paths[X], skip= 30)
    spectra <- spectra[, .SD , .SDcols= c(1, ncol(spectra))]
    colnames(spectra) <- c("wv", "reflectance")
    
    if(mean(spectra$reflectance) >= 10) {
      spectra$reflectance <- spectra$reflectance/100
    }
    
    #Create and predict a spline function
    resample_function <- smooth.spline(x = spectra$wv,
                                       y = spectra$reflectance,
                                       spar= 0.05)
    
    spectra_smoothed <- predict(resample_function, new_bands)
    
    # Out
    return(spectra_smoothed$y)
    
  }
  
  # Apply compilation
  reflectance <- lapply(X = 1:length(paths),
                          FUN = apply_compile,
                          paths = paths,
                          new_bands = 340:2500)
  
  reflectance <- do.call(rbind, reflectance)
  reflectance <- as.data.table(reflectance)
  colnames(reflectance) <- as.character(340:2500)
  reflectance <- cbind(data.table(filename = basename(paths)),
                       reflectance)
  
  return(reflectance)
  
}
