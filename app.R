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
library(tidyverse)
library(sf)
library(shinyjqui)
library(shinyWidgets)
library(shinyjs)
library(s2)
library(magrittr)
library(shinycssloaders)
library(jsonlite)
library(geojsonio)
library(plotly)
library(ggplot2)
library(kableExtra)
library(shinyBS)
library(nominatim)
library(leafgl)
library(shinybusy)

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

# Functions for Engine
# source("trait_selector_input.R")

# Potential color palette
 # "#344e41", "#3a5a40", "#588157", "#a3b18a", "#dad7cd"

################################################################################
# App---------------------------------------------------------------------------
################################################################################

# ------------------------------------------------------------------------------
# Define UI for application
ui <- page_navbar(
  title = "HERBSPHERE",
  id = "main_tabs",
  #nav_spacer(),
  theme = bs_theme(bootswatch = "lux",
                   bg = "#dad7cd",
                   fg = "#344e41", #"#7D8764",
                   primary = "#588157", #"#708A57"
                   secondary = "#a3b18a",
                   success = "#38b000",
                   info = "#14746f",
                   warning = "#d16014",
                   danger = "#931f1d",
                   # base_font = c("Grandstander", "sans-serif"),
                   # code_font = c("Courier", "monospace"),
                   # heading_font = "'Helvetica Neue', Helvetica, sans-serif"
                   ),
  
  header = tags$style(HTML("
    .navbar {
      background-color: #344e41 !important;
    }
    
    .navbar .navbar-brand,
    .navbar-nav .nav-link {
    color: #dad7cd !important;
    }
    
    .navbar-nav .nav-link.active {
    color: #a3b18a !important;
    }
  ")),
  
  explorer_panel_ui("explorer"),
  
  
  nav_panel(
    "Engine",
    # predict_panel_ui("predict")
  ),
  
  tags$footer(title="",  align = "center", style = "
                      position:fixed;
                      bottom:0;
                      width:100%;
                      height:70px; /* Height of the footer */
                      color: black;
                      padding: 0px;
                      background-color: rgba(255, 255, 255, 1);
                      z-index: 1000;
                      display: inline-block;
                      font-size: 12px !important;
                    ",
              tags$a(div(
                # a(href = "https://www.woodwellclimate.org/", target="_blank", img(src = "woodwell_climate_logo.png", style = "align: left; height:70px;")), 
                # a(href = "https://www.ufl.edu/", target="_blank", img(src = "uflorida_logo.png", style = "align: left; height:70px;")), 
                # a(href = "https://opengeohub.org/", target="_blank", img(src = "opengeohub_logo.png", style = "align: left; height:70px;")),
                style="height:70px;  text-align: left;  float:left;  align: left; padding: 0px; padding-left: 20px; bottom:0; display: inline-block;"),
                div(
                  a("Funding provided by the Harvard Data Science Iniciative" , style = "text-align: right; align: right; height:70px; text-decoration: none; color: black; font-size: 13px !important;"), 
                  style="height:70px;  text-align: right; float:right; align: right; padding: 0px; padding-right: 20px; bottom:0; display: inline-block; line-height: 70px")
                )
              )
  
  
)
  
    # busy_start_up(
    #   loader = spin_kit(spin = "circle", color = "white", style = "width:70px; height:70px;"),
    #   text = div(
    #     strong(h2("Loading data...")),
    #     #img(src = "logos/OSSL_White_1.png", style = "align: center; height:50px;"),
    #     p("Follow us on ", a(href = "https://github.com/IHerbSpec", target="_blank",
    #                          img(src = "github.png", style = "align: center; height:40px;")))
    #   ),
    #   mode = "auto",
    #   color = "white",
    #   background = "#7D8764"
    # ),



# ------------------------------------------------------------------------------
# Define server logic required to draw a histogram
server <- function(input, output, session) {
  
  # bs_themer()
  
  # Explorer
  explorer_panel_server("explorer")


}

# ------------------------------------------------------------------------------
# Run the application
shinyApp(ui = ui, server = server)
