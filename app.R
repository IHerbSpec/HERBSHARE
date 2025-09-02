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
  title = "HERBSPHERE",
  id = "main_tabs",
  theme = bs_theme(
    bootswatch = "lux",
    bg = "#000000",
    fg = "#ffffff",
    primary = "#588157",
    secondary = "#a3b18a",
    success = "#38b000",
    info = "#14746f",
    warning = "#d16014",
    danger = "#931f1d"
  ),
  
  tags$head(
    # Font Awesome
    tags$link(rel = "stylesheet", href = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css"),
    # Global spacing rules
    tags$style(HTML("
      :root { --footer-h: 100px; --navbar-h: 56px; }   /* defaults (will be updated by JS) */

      /* Remove default padding so content can sit flush to edges */
      .bslib-page-navbar .nav-panel-content { padding: 0 !important; }

      html, body { height: 100%; margin: 0; padding: 0; }
    ")),
    
    tags$script(HTML("
      function setNavbarHeightVar(){
        var nb = document.querySelector('.navbar');
        var h = nb ? nb.getBoundingClientRect().height : 56;
        document.documentElement.style.setProperty('--navbar-h', h + 'px');
      }
      window.addEventListener('load', setNavbarHeightVar);
      window.addEventListener('resize', setNavbarHeightVar);
      // Also observe DOM mutations in case navbar changes height dynamically
      new MutationObserver(setNavbarHeightVar).observe(document.documentElement,{subtree:true,childList:true,attributes:true});
    "))
  ),
  
  header = tagList(
    tags$style(HTML("
      .navbar { background-color: #000000 !important; }
      .navbar .navbar-brand, .navbar-nav .nav-link { color: #ffffff !important; }
      .navbar-nav .nav-link.active { color: #cccccc !important; }
      .custom-navbar-icons { display: flex; align-items: center; gap: 15px; margin-right: 20px; }
      .custom-navbar-icons a { color: #ffffff !important; font-size: 1.5rem; }
      .custom-navbar-icons a:hover { color: #cccccc !important; }
    ")),
    tags$script(HTML("
      $(function() {
        const icons = `
          <div class='custom-navbar-icons ms-auto'>
            <a href='https://https://github.com/IHerbSpec/HERBSPHERE' target='_blank' title='GitHub'><i class='fab fa-github'></i></a>
            <a href='https://iherbspec.github.io' target='_blank' title='Documentation'><i class='fas fa-book'></i></a>
          </div>`;
        $('.navbar-nav').after(icons);
      });
    "))
  ),
  
  explorer_panel_ui("explorer"),
  
  nav_panel("Engine"),
  
  # your fixed footer (keep height in sync with --footer-h above!)
  tags$footer(
    align = "center",
    style = "
      position: fixed; bottom: 0; width: 100%; height: 100px;
      color: black; padding: 0; background-color: rgba(255,255,255,1);
      z-index: 1000; display: flex; justify-content: space-between; align-items: center;
      font-size: 12px !important;",
    div(
      a(href = 'https://www.huh.harvard.edu/', target = '_blank',
        img(src = 'HUH_black.png', style = 'height: 75px;')
      ),
      style = 'padding-left: 20px;'
    ),
    div(
      'Funding provided by:   ',
      a(href = 'https://datascience.harvard.edu/', target = '_blank',
        img(src = 'HDSI_black.png', style = 'height: 30px;')
      ),
      style = 'padding-right: 20px; font-size: 13px !important;'
    )
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
