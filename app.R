################################################################################
#               ___________________________________________________            #
#                                   HERBSPHERE                                 #
#      HERBSPHERE: Herbarium Spectral Hub for Research and Exploration         #
#                  A Shiny Application for the exploration of spectroscopy     #
#            data from herbarium specimens and prediction of leaf traits       #
#                             Author: J. Antonio Guzmán Q.                     #
#               ___________________________________________________            #
#                                                                              #
################################################################################

### Module guide
## modules
#     explorer_panel.R
#     explorer
#         map.R
#         records_summary.R
#         specimen_selection.R
#         select_by.R
#         download.R
#     engine_panel.R
#     engine
#         upload_spectra.R
#         trait_selector.R
#         spectra_viewer.R
#         predictions_output.R
#         trait_visualization.R
#         predict_traits.R
#     about_panel.R
#     auxiliary
#         read_spectra.R
#         read_svc.R
#         herbaria_locations.R
#         gbif.R

################################################################################
# Libraries --------------------------------------------------------------------

library(shiny)
library(shinythemes)
library(shinycssloaders)
library(bslib)
library(bsicons)
library(leaflet)
library(leaflet.extras)
library(data.table)
library(sf)
library(dplyr)
library(tidyr)
library(shinyjs)
library(plotly)
library(DT)
library(future)
library(promises)
library(bit64)
plan(multisession)

################################################################################
# Source of helpers 

# Functions for Explorer
source("modules/explorer_panel.R")
source("modules/explorer/map.R")
source("modules/explorer/records_summary.R")
source("modules/explorer/specimen_selection.R")
source("modules/explorer/select_by.R")
source("modules/explorer/download.R")

# Functions for Engine
source("modules/engine_panel.R")
source("modules/engine/upload_spectra.R")
source("modules/engine/trait_selector.R")
source("modules/engine/spectra_viewer.R")
source("modules/engine/predictions_output.R")
source("modules/engine/trait_visualization.R")
source("modules/engine/predict_traits.R")

# Functions for about
source("modules/about_panel.R")

################################################################################
# Load initial data

metadata_and_gbif <- data.table::fread("data/02-organized/HERBSPHERE_metadata_locations.csv")
metadata_and_gbif <- metadata_and_gbif[decimalLatitude != 0 & decimalLongitude != 0,]
spectra_compiled <- data.table::fread("data/02-organized/spectra_compiled.csv", header = TRUE)
citation <- data.table::fread("data/02-organized/citation.csv", header = TRUE, encoding = "UTF-8")

################################################################################
# App

# Define theme
app_theme <- bs_theme(bootswatch = "yeti",
                      navbar_bg = "#162623",
                      bg = "#ffffff",
                      fg = "#162623",
                      primary = "#162623",
                      secondary = "#26413C",
                      success = "#26413C",
                      info = "#26413C",
                      warning = "yellow",
                      danger = "red")

# Extract primary color from theme
theme_colors <- bs_get_variables(app_theme, c("primary"))
primary_color <- theme_colors["primary"]

# ------------------------------------------------------------------------------
# # Define UI for application
ui <- page_navbar(

  theme = app_theme,
  title = tags$span("HERBSPHERE"),

  # Custom CSS for button colors
  header = tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "styles.css"),
    useShinyjs(),
    includeHTML("google-analytics.html")
  ),
  lang = "en",
  
  nav_panel("Explorer",
            explorer_panel_ui("explorer")
            ),

  nav_panel("Engine",
            engine_panel_ui("engine")
            ),

  nav_spacer(),

  nav_panel("About",
            about_panel_ui("about")
            ),

  nav_item(tags$a(tags$span(bsicons::bs_icon("github"), "Source code"),
                  href = "https://github.com/IHerbSpec/HERBSPHERE",
                  target = "_blank")
           ),

  nav_item(tags$a(tags$span(bsicons::bs_icon("book"), "IHerbSpec"),
                  href = "https://iherbspec.github.io",
                  target = "_blank")
           ),

  nav_item(input_dark_mode(id = "dark_mode",
                           mode = "light",
                           `data-bs-theme` = "dark")
           )
)

# ------------------------------------------------------------------------------
# Define server logic required to draw a histogram
server <- function(input, output, session) {
  
  # Explorer
  explorer_panel_server("explorer",
                        metadata = metadata_and_gbif,
                        spectra_compiled = spectra_compiled,
                        citation = citation)

  # Engine
  engine_panel_server("engine", primary_color = primary_color)

}

# ------------------------------------------------------------------------------
# Run the application
shinyApp(ui = ui, server = server)
