################################################################################
### R wrapper for Python trait prediction

#' Predict traits from spectral data using PyTorch model
#'
#' @param reflectance_path Path to CSV file with reflectance data
#' @param target_traits Character vector of trait names to predict
#' @param python_path Path to Python executable (optional)
#' @param use_uncertainty Logical, whether to compute MC-Dropout uncertainty
#'
#' @return data.frame with predictions
predict_traits_python <- function(reflectance_path,
                                  target_traits = NULL,
                                  python_path = NULL,
                                  use_uncertainty = FALSE) {

  # Default traits if not specified
  if (is.null(target_traits)) {
    target_traits <- c("LMA", "EWT", "LDMC", "Car", "Chla", "Chlb", "Chla+b",
                       "Hemicellulose", "Cellulose", "Lignin", "N", "C")
  }

  # Validate input file
  if (!file.exists(reflectance_path)) {
    stop("Reflectance file not found: ", reflectance_path)
  }

  # Get project root (use working directory for Shiny apps)
  project_root <- getwd()

  # Python script path
  python_script <- file.path(
    project_root,
    "modules/auxiliary/engine_predict.py"
  )

  if (!file.exists(python_script)) {
    stop("Python prediction script not found: ", python_script)
  }

  # Create temporary output file
  temp_output <- tempfile(fileext = ".csv")

  # Build command
  if (is.null(python_path)) {
    # Default to Windows Python installation
    python_cmd <- "C:/Users/jog4076/AppData/Local/Python/pythoncore-3.14-64/python.exe"
  } else {
    python_cmd <- python_path
  }

  # Prepare arguments
  args <- c(
    shQuote(python_script),
    "--input", shQuote(reflectance_path),
    "--output", shQuote(temp_output),
    "--traits", shQuote(paste(target_traits, collapse = ","))
  )

  if (use_uncertainty) {
    args <- c(args, "--uncertainty")
  }

  # Run Python script
  cmd <- paste(c(python_cmd, args), collapse = " ")

  #message("Running prediction model...")
  #message("Command: ", cmd)

  # Capture both stdout and stderr
  result <- system(cmd, intern = TRUE, ignore.stderr = FALSE)
  exit_code <- attr(result, "status")

  if (is.null(exit_code)) {
    exit_code <- 0  # Success if no status attribute
  }

  if (exit_code != 0) {
    error_msg <- paste(result, collapse = "\n")
    stop("Python prediction script failed with exit code: ", exit_code,
         "\nError output: ", error_msg)
  }

  # Check if output file was created
  if (!file.exists(temp_output)) {
    stop("Prediction output file was not created")
  }

  # Read predictions
  predictions <- data.table::fread(temp_output)

  # Clean up
  unlink(temp_output)

  return(predictions)
}


#' Check if Python environment is properly configured
#'
#' @return Logical indicating if Python is available
check_python_environment <- function() {

  tryCatch({
    python_version <- system("python3 --version", intern = TRUE)
    message("Python found: ", python_version)

    # Check for required packages
    required_pkgs <- c("torch", "numpy", "polars", "pywt")

    for (pkg in required_pkgs) {
      check_cmd <- sprintf("python3 -c 'import %s'", pkg)
      result <- system(check_cmd, intern = FALSE, ignore.stderr = TRUE)

      if (result != 0) {
        warning("Python package not found: ", pkg)
        return(FALSE)
      }
    }

    message("All required Python packages found")
    return(TRUE)

  }, error = function(e) {
    warning("Python environment check failed: ", e$message)
    return(FALSE)
  })
}
