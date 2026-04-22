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
                        nav_panel(title = "Spectra",
                                  icon = icon("chart-line"),
                                  spectra_viewer_ui(ns("spectra_viewer"))
                                  ),

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
engine_panel_server <- function(id, primary_color = "#26413C") {
  moduleServer(id, function(input, output, session) {

    # Shared predicting state
    is_predicting <- reactiveVal(FALSE)

    # Upload spectra module
    uploaded_data <- upload_spectra_server("upload_spectra")

    # Trait selector module
    trait_selector <- trait_selector_server("trait_selector", is_predicting = is_predicting)

    # Spectra viewer module
    spectra_viewer_server("spectra_viewer",
                          spectra_data = uploaded_data)

    # Predictions output module
    predictions_result <- predictions_output_server("predictions",
                                                    spectra_data = uploaded_data,
                                                    selected_traits = trait_selector$traits,
                                                    trigger_predict = trait_selector$predict_trigger,
                                                    is_predicting = is_predicting)

    # Visualization module
    trait_visualization_server("visualization",
                               predictions_data = predictions_result,
                               primary_color = primary_color)

  })
}
