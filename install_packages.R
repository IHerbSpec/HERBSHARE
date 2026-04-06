################################################################################
# R Package Dependencies for HERBSPHERE
# Run this script to install all required R packages
################################################################################

# List of required packages
required_packages <- c(
  # Core Shiny and UI
  "shiny",
  "shinythemes",
  "shinycssloaders",
  "bslib",
  "bsicons",
  "shinyjs",

  # Data manipulation
  "data.table",
  "dplyr",
  "tidyr",

  # Visualization
  "plotly",
  "DT",
  "leaflet",
  "leaflet.extras",

  # Spatial data
  "sf",

  # GBIF and biodiversity data
  "rgbif",
  "tidygeocoder",

  # Web and API
  "httr2",
  "jsonlite",

  # Async execution
  "future",
  "promises"
)

# Function to check and install packages
install_if_missing <- function(packages) {
  new_packages <- packages[!(packages %in% installed.packages()[,"Package"])]

  if(length(new_packages) > 0) {
    cat("Installing missing packages:\n")
    print(new_packages)
    install.packages(new_packages, dependencies = TRUE)
  } else {
    cat("All required packages are already installed.\n")
  }
}

# Install missing packages
cat("Checking R package dependencies for HERBSPHERE...\n\n")
install_if_missing(required_packages)

# Verify installation
cat("\n\nVerifying installation...\n")
missing <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]

if(length(missing) > 0) {
  cat("\nWARNING: The following packages failed to install:\n")
  print(missing)
  cat("\nTry installing them manually with: install.packages(c(",
      paste0("'", missing, "'", collapse = ", "), "))\n")
} else {
  cat("\nSuccess! All required R packages are installed.\n")
}
