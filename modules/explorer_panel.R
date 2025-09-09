################################################################################
### Explorer panel

# UI
# explorer_panel_ui <- function(id) {
#   ns <- NS(id)
#   
#   
#   map_css_id <- paste0("#", ns("map-map"))
#   map_wrap_id <- paste0("#", ns("map-viewport"))
#   
#   bslib::nav_panel(
#     "Explorer",
#     tags$head(
#       tags$style(HTML(paste0(
#         "
#         /* Full-bleed, fixed map that fills between navbar & footer */
#         ", map_wrap_id, " {
#           position: fixed; left: 0; right: 0;
#           top: var(--navbar-h);      /* dynamic navbar height */
#           bottom: var(--footer-h);   /* fixed footer height */
#           z-index: 0;                /* under your floating panel */
#         }
#         ", map_css_id, " { height: 100%; width: 100%; } /* map fills wrapper */
# 
#         /* Optional: position your floating specimen panel above the map */
#         .panel.panel-default { z-index: 1001; }
#         "
#       )))
#     ),
#     
#     div(id = ns("map-viewport"),
#         map_ui(ns("map"))
#     ),
#     
#     specimen_selection_ui(ns("spec_sel"))
#   )
# }

explorer_panel_ui <- function(id) {
  
  ns <- NS(id)

  layout_sidebar(
    
    # Current records
    sidebar = sidebar(
      title = "Records",
      "Content for the left sidebar"
    ),
    
    layout_sidebar(
      class = "no-pad-main",
      fillable = TRUE,
      gap = 0,
      
      # Specimen information
      sidebar = sidebar(
        title = "Specimen information",
        position = "right",
        width = "30%",
        specimen_selection_ui(ns("spec_sel"))
      ),
      
      # Main area
      div(
        class = "p-0 m-0",
        style = "height: 100%;",   # container fills available height
        map_ui(ns("map"))          # inside, make sure map output uses height = '100%'
      )
    )
  )
}

# Server
explorer_panel_server <- function(id, 
                                  metadata_sf, 
                                  points_sf, 
                                  spectra_compiled) {
  
  moduleServer(id, function(input, output, session) {
    
    map_out <- map_server(id = "map", metadata_sf = metadata_sf)
    
    specimen_selection_server(id = "spec_sel",
                              click_id = map_out$click_id,
                              metadata_sf = metadata_sf,
                              points_sf = points_sf,
                              spectra_compiled = spectra_compiled)
  })
}