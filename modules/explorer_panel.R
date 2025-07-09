################################################################################
### Explorer panel


explorer_panel_ui <- function(id) {
  ns <- NS(id)

  tabPanel(
    title = span("Explorer", title = "Browse by location"),
    value = "Explorer",
    div(class = "outer",
        tags$head(
          includeCSS("styles.css"),  # make sure this file exists
          tags$style(HTML('
            html, body, .outer {
              height: 100%;
              margin: 0;
              padding: 0;
            }
            #map {
              height: 100%;
            }
            div.leaflet-control-search {
              left: 50% !important;
              top: 2px !important;
              margin-top: -20px !important;
              position: absolute;
            }
          '))
        ),
        
        map_ui(ns("map"))
        
    )
  )
}

explorer_panel_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    
    map_server("map")
    
  })
}


