################################################################################
### Upload spectra module

# UI
upload_spectra_ui <- function(id) {
  ns <- NS(id)

  tagList(
    fileInput(ns("file_upload"),
              "Upload CSV file",
              accept = c(".csv"),
              buttonLabel = "Browse...",
              placeholder = "No file selected",
              ),

    tags$div(style = "font-size: 0.9em; color: #666; margin-bottom: 1rem;",
             tags$p("Expected format:"),
             tags$ul(
               tags$li("First column should be a sample identifier (e.g., rowID)"),
               tags$li("Header columns for wavelengths at 1 nm of resolution are required (e.g., 450, 451, 452, ...)"),
               tags$li("The files must have a spectral range between 450 and 2399 nm"),
               tags$li("A maximum of 100 samples per run"),
               tags$li("Files exported from the Explorer module are supported")
               )
             ),

    uiOutput(ns("file_status"))
    )
}

# Server
upload_spectra_server <- function(id) {
  moduleServer(id, function(input, output, session) {

    # Store uploaded data
    uploaded_data <- reactiveVal(NULL)

    # Process uploaded file
    observeEvent(input$file_upload, {
      req(input$file_upload)

      tryCatch({

        # Read CSV — header=TRUE is required because numeric column names (wavelengths)
        # confuse fread's auto-detection, causing it to treat the header as data
        df <- data.table::fread(input$file_upload$datapath, header = TRUE)

        # Validate structure
        if (ncol(df) < 2) {
          stop("File must have at least 2 columns (ID + wavelengths)")
        }

        # Rename first column to rowID (supports any original name, integer or character)
        data.table::setnames(df, old = names(df)[1], new = "rowID")
        df[, rowID := as.character(rowID)]

        # Auto-detect wavelength columns: numeric names in 450-2399 nm range
        col_names <- names(df)[-1]
        num_vals  <- suppressWarnings(as.numeric(col_names))
        wave_cols <- col_names[!is.na(num_vals) & num_vals >= 450 & num_vals <= 2399]

        if (length(wave_cols) == 0) {
          stop("No wavelength columns (450–2399 nm) detected. Column names must be numeric wavelengths.")
        }

        # Keep only rowID + wavelength columns
        df <- df[, c("rowID", wave_cols), with = FALSE]

        # Limit to 100 samples
        truncated <- nrow(df) > 100L
        if (truncated) df <- df[1:100, ]

        # Store data
        uploaded_data(df)

        msg <- sprintf("Loaded %d samples — %d wavelength bands (%.0f–%.0f nm)",
                       nrow(df), length(wave_cols),
                       as.numeric(wave_cols[1]),
                       as.numeric(wave_cols[length(wave_cols)]))
        if (truncated) msg <- paste0(msg, " — truncated to 100 samples")
        showNotification(msg, type = "message", duration = 4)

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

    # Return uploaded data
    return(uploaded_data)
  })
}
