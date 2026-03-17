################################################################################
### Engine panel

# UI
engine_panel_ui <- function(id) {
  ns <- NS(id)

  layout_sidebar(

    # Controls
    sidebar = sidebar(id = ns("left_sb"),
                      title = NULL,
                      open = TRUE,
                      width  = "30%",
                      
                      bslib::accordion(id = ns("collapse"),
                                       open = c("upload_data", "trait_selection"),
                                       multiple = TRUE,
                                       
                                       bslib::accordion_panel(title = "Upload spectra",
                                                              id = "upload_data",
                                                              upload_spectra_ui(ns("upload_spectra"))
                                                              ),
                                       
                                       bslib::accordion_panel(title = "Trait selection",
                                                              id = "trait_selection",
                                                              trait_selector_ui(ns("trait_selector"))
                                                              )
                                       )
                      ),

    # Predictions output and visualization
    div(class = "p-3",
        style = "height: 100%; overflow-y: auto;",
        
        navset_card_tab(id = ns("output_tabs"),
                        nav_panel(title = "Predictions Table",
                                  icon = icon("table"),
                                  predictions_output_ui(ns("predictions"))
                                  ),
                        
                        nav_panel(title = "Visualization",
                                  icon = icon("chart-bar"),
                                  trait_visualization_ui(ns("visualization"))
                                  )
                        )
        )
  )
}

# Server
engine_panel_server <- function(id) {
  moduleServer(id, function(input, output, session) {

    # Upload spectra module
    uploaded_data <- upload_spectra_server("upload_spectra")

    # Trait selector module
    selected_traits <- trait_selector_server("trait_selector")

    # Predictions output module
    predictions_result <- predictions_output_server("predictions",
                                                    spectra_data = uploaded_data$data,
                                                    selected_traits = selected_traits,
                                                    trigger_predict = uploaded_data$predict_trigger)

    # Visualization module
    trait_visualization_server("visualization",
                               predictions_data = predictions_result)

  })
}
