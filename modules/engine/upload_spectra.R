################################################################################
### Upload spectra module

# UI
upload_spectra_ui <- function(id) {
  ns <- NS(id)

  tagList(
    fileInput(ns("file_upload"),
              "Upload CSV file",
              accept = c(".csv", "text/csv", "text/comma-separated-values"),
              buttonLabel = "Browse...",
              placeholder = "No file selected"
              ),

    tags$div(style = "font-size: 0.9em; color: #666; margin-bottom: 1rem;",
             tags$p("Expected format:"),
             tags$ul(
               tags$li("First column: Sample ID (e.g., 'rowID')"),
               tags$li("Remaining columns: Wavelengths (450-2399 nm)"),
               tags$li("Header row required")
               )
             ),

    uiOutput(ns("file_status")),

    actionButton(ns("predict_btn"),
                 "Predict traits",
                 icon = icon("brain"),
                 class = "btn-primary btn-block",
                 style = "margin-top: 1rem;"
                 )
    )
}

# Server
upload_spectra_server <- function(id) {
  moduleServer(id, function(input, output, session) {

    # Store uploaded data
    uploaded_data <- reactiveVal(NULL)

    # Trigger for prediction
    predict_trigger <- reactiveVal(0)

    # Process uploaded file
    observeEvent(input$file_upload, {
      req(input$file_upload)

      tryCatch({
        
        # Read CSV
        df <- data.table::fread(input$file_upload$datapath)

        # Validate structure
        if (ncol(df) < 2) {
          stop("File must have at least 2 columns (ID + wavelengths)")
        }

        # Check for numeric wavelength columns
        wave_cols <- names(df)[-1]
        numeric_cols <- sapply(wave_cols, function(col) {
          is.numeric(df[[col]]) ||
            (is.character(col) && grepl("^[0-9.]+$", col))
        })

        if (!any(numeric_cols)) {
          stop("No wavelength columns detected. Column names should be numeric (e.g., 450, 451, ...)")
        }

        # Store data
        uploaded_data(df)

        showNotification(paste0("Loaded ", nrow(df), " samples with ", ncol(df) - 1, " wavelength bands"),
                         type = "message",
                         duration = 3)

      }, error = function(e) {
        
        uploaded_data(NULL)
        showNotification(paste("Error loading file:", e$message),
                         type = "error",
                         duration = 5)
        
      })
    })

    # Display file status
    output$file_status <- renderUI({
      if (is.null(uploaded_data())) {
        
        tags$div(class = "alert alert-info",
                 style = "font-size: 0.9em;",
                 icon("info-circle"),
                 "No file uploaded")
        
      } else {
        
        df <- uploaded_data()
        tags$div(class = "alert alert-success",
                 style = "font-size: 0.9em;",
                 icon("check-circle"),
                 sprintf(" %d samples loaded", nrow(df)))
      }
    })

    # Predict button
    observeEvent(input$predict_btn, {
      req(uploaded_data())
      predict_trigger(predict_trigger() + 1)
    })

    # Return data and trigger
    return(list(data = uploaded_data,
                predict_trigger = predict_trigger
                )
           )
  })
}
