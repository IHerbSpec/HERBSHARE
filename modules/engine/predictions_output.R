################################################################################
### Predictions output module

# UI
predictions_output_ui <- function(id) {
  ns <- NS(id)

  tagList(div(style = "margin-bottom: 1rem;",
              h4("Trait Predictions"),
              uiOutput(ns("status"))),

    div(style = "margin-top: 1rem;",
        DT::dataTableOutput(ns("predictions_table"))),

    div(style = "margin-top: 1rem;",
        uiOutput(ns("download_section")))

  )
}

# Server
predictions_output_server <- function(id, spectra_data, selected_traits, trigger_predict, is_predicting = NULL) {
  moduleServer(id, function(input, output, session) {

    # Store predictions
    predictions <- reactiveVal(NULL)

    # Use shared is_predicting if provided, otherwise create local one
    if (is.null(is_predicting)) {
      is_predicting <- reactiveVal(FALSE)
    }

    # Run prediction
    observeEvent(trigger_predict(), {
      req(trigger_predict() > 0)
      req(spectra_data())
      req(length(selected_traits()) > 0)

      is_predicting(TRUE)
      predictions(NULL)

      # Capture reactive values before async hand-off
      current_spectra <- spectra_data()
      current_traits  <- selected_traits()
      temp_input <- tempfile(fileext = ".csv")
      data.table::fwrite(current_spectra, temp_input)

      future({
        predict_traits_python(reflectance_path = temp_input,
                              target_traits    = current_traits)
      }) %...>% (function(result) {
        predictions(result)
        is_predicting(FALSE)
        showNotification("Predictions completed successfully!",
                         type = "message", duration = 3)
        unlink(temp_input)
      }) %...!% (function(e) {
        is_predicting(FALSE)
        predictions(NULL)
        showNotification(paste("Prediction error:", e$message),
                         type = "error", duration = 10)
        unlink(temp_input)
      })

      NULL  # Must return NULL so Shiny does not treat the promise as a value

    }, ignoreInit = TRUE)
    
    # Status message
    output$status <- renderUI({
      
      if (is_predicting()) {
        
        tags$div(class = "alert alert-info",
                 icon("spinner", class = "fa-spin"),
                 "Computing predictions. This may take a few seconds.")
        
      } else if (!is.null(predictions())) {
        
        tags$div(class = "alert alert-success",
                 icon("check-circle"),
                 sprintf(" Predictions ready for %d samples", nrow(predictions())))
        
      } else {
        
        tags$div(class = "alert alert-secondary",
                 icon("info-circle"),
                 "Upload spectra and click 'Predict traits' to start")
        
      }
    })
    
    # Download section
    output$download_section <- renderUI({
      req(predictions())
      
      ns <- session$ns
      tags$div(style = "margin-bottom: 1rem;",
               downloadButton(
                 ns("download_csv"),
                 "Download predictions (CSV)",
                 class = "btn-primary")
               )
    })
    
    # Predictions table
    output$predictions_table <- DT::renderDataTable({
      req(predictions())
      
      DT::datatable(predictions(),
                    options = list(
                      pageLength = 25,
                      scrollX = TRUE,
                      scrollY = "500px",
                      dom = 'Bfrtip',
                      buttons = c('copy', 'csv', 'excel')
                    ),
                    rownames = FALSE,
                    class = 'cell-border stripe'
      ) %>%
        DT::formatRound(columns = names(predictions())[-1],
                        digits = 4)
      })
    
    # Download handler
    output$download_csv <- downloadHandler(
      filename = function() {
        paste0("herbsphere_predictions_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")
      },
      content = function(file) {
        data.table::fwrite(predictions(), file)
      }
    )
    
    # Return predictions for visualization module
    return(predictions)
    
  })
}
