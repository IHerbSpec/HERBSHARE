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
#     explorer
#         map.R
#         data_selection.R
#         records_summary.R
#         specimen_selection.R
#         select_by.R
#         download.R
#     engine
#     auxiliarity 
#         read_spectra.R
#         herbaria_locations.R
#         gbif.R

################################################################################
# Libraries --------------------------------------------------------------------


library(shiny)
library(shinythemes)
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

# library(tidyverse)
# library(shinyjqui)
# library(s2)
# library(magrittr)
# library(shinycssloaders)
# library(jsonlite)
# library(geojsonio)
# library(kableExtra)
# library(nominatim)
# library(leafgl)
# library(shinybusy)

################################################################################
# Options 

# # File size upload
# options(shiny.maxRequestSize= 1000*1024^2)
# options(shiny.deprecation.messages=FALSE)

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
source("modules/engine/predictions_output.R")
source("modules/engine/trait_visualization.R")
source("modules/auxiliary/predict_traits.R")

################################################################################
# Load initial data

metadata_and_gbif <- data.table::fread("data/02-organized/metadata_and_gbif.csv")
spectra_compiled <- data.table::fread("data/02-organized/spectra_compiled.csv", header = TRUE)

################################################################################
# App

# ------------------------------------------------------------------------------
# # Define UI for application
ui <- page_navbar(
  
  #theme = bs_theme(version = 5),
  theme = bs_theme(bootswatch = "yeti",
                   #base_font = font_google("Inter"),
                   navbar_bg = "black"),
  
  # title = tags$span(
  #   # tags$img(
  #   #   src = "logo.png",
  #   #   width = "46px",
  #   #   height = "auto",
  #   #   class = "me-3",
  #   #   alt = "Shiny hex logo"
  #   # ),
  #   "HERBSPHERE"
  # ),
  
  title = tags$span("HERBSPHERE"),
  lang = "en",
  
  nav_panel("Explorer",
            explorer_panel_ui("explorer")
            ),

  nav_panel("Engine",
            engine_panel_ui("engine")
            ),

  nav_spacer(),

  nav_panel("About",
            div("Coming soon")
            ),

  nav_item(tags$a(tags$span(bsicons::bs_icon("github"), "Source code"),
                  href = "https://github.com/IHerbSpec/HERBSPHERE",
                  target = "_blank"
                  )
           ),

  nav_item(tags$a(tags$span(bsicons::bs_icon("book"), "IHerbSpec"),
                  href = "https://iherbspec.github.io",
                  target = "_blank"
                  )
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
                        spectra_compiled = spectra_compiled)

  # Engine
  engine_panel_server("engine")

}

# ------------------------------------------------------------------------------
# Run the application
shinyApp(ui = ui, server = server)
