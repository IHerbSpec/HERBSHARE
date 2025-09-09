################################################################################
#               ___________________________________________________            #
#                                   HERBSPHERE                                 #
#      HERBSPHERE: Herbarium Spectral Hub for Research and Exploration         #
#                  A Shiny Application for the exploration of spectroscopy     #
#            data from herbarium specimens prediction leaf traits              #
#                             and prediction of leaf traits                    #
#                             Author: J. Antonio Guzmán Q.                     #
#               ___________________________________________________            #
#                                                                              #
################################################################################

# Name convention for scripts
# _panel: all visual panels that display information
# _input: all user information that serve as input
# _import: functions to read files
# _frame: all data.frames created
# _plot: scripts to render figures in ui
# _figure: all figures created as outputs
# _go: names to link between panels
# _action: name for bottom activation
# _aux: Auxiliary functions

################################################################################
# Libraries --------------------------------------------------------------------
################################################################################

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

# # 
# remotes::install_github("bhaskarvk/leaflet.extras", ref = remotes::github_pull("184")) 
# remotes::install_github("bhaskarvk/leaflet.extras")
# _input: all user information that serve as inputremotes::install_github("hrbrmstr/nominatim")
# install.packages("leafgl") # https://github.com/r-spatial/leafgl

################################################################################
# Options ----------------------------------------------------------------------
################################################################################

# # File size upload
# options(shiny.maxRequestSize= 1000*1024^2)
# options(shiny.deprecation.messages=FALSE)

################################################################################
# Source of helpers ------------------------------------------------------------
################################################################################

# Functions for Explorer
source("modules/explorer_panel.R")
source("modules/explorer/map.R")
source("modules/explorer/records_summary.R")
source("modules/explorer/specimen_selection.R")

# Functions for Engine
# source("trait_selector_input.R")

################################################################################
# Load initial data------------------------------------------------------------
################################################################################

metadata_and_gbif <- data.table::fread("data/02-organized/metadata_and_gbif.csv")
spectra_compiled <- data.table::fread("data/02-organized/spectra_compiled.csv", header = TRUE)

################################################################################
# App---------------------------------------------------------------------------
################################################################################

# # ------------------------------------------------------------------------------
# # Define UI for application
ui <- page_navbar(
  
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
  theme = bs_theme(version = 5),

  nav_panel(
    "Explorer",
    explorer_panel_ui("explorer")
  ),

  nav_panel(
    "Engine",
    div("Coming soon")
  ),

  nav_spacer(),

  nav_panel(
    "About",
    div("Coming soon")
  ),

  nav_item(
    tags$a(
      tags$span(bsicons::bs_icon("github"), "Source code"),
      href = "https://github.com/IHerbSpec/HERBSPHERE",
      target = "_blank"
    )
  ),

  nav_item(
    tags$a(
      tags$span(bsicons::bs_icon("book"), "Documentation"),
      href = "https://iherbspec.github.io",
      target = "_blank"
    )
  ),

  nav_item(
    input_dark_mode(id = "dark_mode", mode = "light")
  )
)

# ------------------------------------------------------------------------------
# Define server logic required to draw a histogram
server <- function(input, output, session) {
  
  # Load information into the server
  metadata_sf <- st_as_sf(metadata_and_gbif, 
                          coords = c("decimalLongitude", "decimalLatitude"), 
                          crs = 4326, 
                          remove = FALSE)
  
  points_sf <- reactive({
    st_as_sf(metadata_sf,
             coords = c("decimalLongitude", "decimalLatitude"),
             crs = 4326)
  })

  # Explorer
  explorer_panel_server("explorer", metadata_sf, points_sf, spectra_compiled)

}

# ------------------------------------------------------------------------------
# Run the application
shinyApp(ui = ui, server = server)
