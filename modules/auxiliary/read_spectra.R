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
  
  # Frame
  files <- data.table(paths = paths)
  files[, ext := file_ext(paths)]
  files <- files[ext != "csv"]
  
  apply_spectra <- function(X,
                            files) {
    
    # File of intest
    fileExt <- files$ext[X]
    path <- files$paths[X]
    
    if(fileExt == "sed") {
      
      readResult <- apply_sed(path)
      
    } else if(fileExt == "sig") {
      
      readResult <- apply_sig(path)
      
    } else if(fileExt == ".asd") {
      
      readResult <- apply_asd(path)
      
    }
    
    return(readResult)
    
  }
  
  # Get reflectance
  reflectance <- lapply(X = 1:nrow(files),
                        FUN = apply_spectra,
                        files = files)
  
  # Compiled results
  reflCompiled <- rbindlist(
    
    lapply(seq_along(reflectance), function(i) {
      
      x <- reflectance[[i]]
      row <- as.list(setNames(x$spectra, (x$range[1]:x$range[2])))
      c(list(filename = i), row)
      
    }),
    use.names = TRUE, fill = TRUE
  )
  
  reflCompiled$filename <- basename(files$paths)
  
  return(reflCompiled)
  
}

# Apply .sed
apply_sed <- function(path) {
  
  # Read spectra
  spectra <- fread(path, skip= 27)
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
    
    spectra_smoothed <- predict(resample_function, round(range_spectra[1]):round(range_spectra[2]))$y
    
    # Out
    return(list(range = round(range_spectra),
                spectra = spectra_smoothed))
    
  }
}

# Apply .sig
apply_sig <- function(path) {
  
  # Read spectra
  spectra <- fread(path, skip= 27)
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
    
    resample_function <- smooth.spline(x = spectra$wv,
                                       y = spectra$reflectance,
                                       spar= 0.01)
    
    spectra_smoothed <- predict(resample_function, round(range_spectra[1]:range_spectra[2]))$y
    
    # Out
    return(list(range = round(range_spectra),
                spectra = spectra_smoothed))
    
  }
}
