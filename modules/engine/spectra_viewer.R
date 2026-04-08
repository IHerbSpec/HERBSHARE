################################################################################
### Spectra viewer module for Engine

# UI
spectra_viewer_ui <- function(id) {
  ns <- NS(id)

  tagList(
    div(style = "margin-bottom: 1rem;",
        h4("Uploaded Spectra"),
        uiOutput(ns("status"))
    ),

    plotlyOutput(ns("spectra_plot"), height = "600px")
  )
}

# Server
spectra_viewer_server <- function(id, spectra_data) {
  moduleServer(id, function(input, output, session) {

    # Status message
    output$status <- renderUI({
      if (is.null(spectra_data())) {
        tags$div(class = "alert alert-info",
                 icon("info-circle"),
                 " Upload spectra to view spectral profiles")
      } else {
        df <- spectra_data()
        tags$div(class = "alert alert-success",
                 icon("check-circle"),
                 sprintf(" Showing %d spectral profiles", nrow(df)))
      }
    })

    # Spectra plot
    output$spectra_plot <- plotly::renderPlotly({
      req(spectra_data())

      df <- spectra_data()

      # Get ID column (first column) and wavelength columns
      id_col <- names(df)[1]
      wave_cols <- names(df)[-1]

      # Convert wavelength column names to numeric
      wave_numeric <- as.numeric(wave_cols)

      # Check if wavelengths are valid
      valid_waves <- wave_numeric >= 450 & wave_numeric <= 2399 & !is.na(wave_numeric)

      if (!any(valid_waves)) {
        return(plotly::plotly_empty() %>%
                 plotly::layout(
                   title = "No valid wavelength columns found (expected 450-2399 nm)",
                   xaxis = list(title = ""),
                   yaxis = list(title = "")
                 ))
      }

      # Subset to valid wavelengths
      wave_cols_valid <- wave_cols[valid_waves]
      wave_numeric_valid <- wave_numeric[valid_waves]

      # Pivot to long format
      spectra_long <- tidyr::pivot_longer(
        data = df,
        cols = all_of(wave_cols_valid),
        names_to = "wavelength",
        values_to = "reflectance",
        names_transform = list(wavelength = as.numeric)
      )

      # Determine y-axis range
      ymax <- suppressWarnings(max(spectra_long$reflectance, na.rm = TRUE))
      yaxis_opts <- if (is.finite(ymax) && ymax <= 1) {
        list(title = "Reflectance",
             range = c(0, 1),
             showgrid = FALSE,
             zeroline = FALSE,
             linecolor = "black",
             linewidth = 0.5,
             ticks="outside",
             mirror = T)
      } else {
        list(title = "Reflectance",
             autorange = TRUE,
             showgrid = FALSE,
             zeroline = FALSE,
             linecolor = "black",
             linewidth = 0.5,
             ticks="outside",
             mirror = T)
      }

      # Create plot
      plotly::plot_ly(
        data = spectra_long,
        x = ~wavelength,
        y = ~reflectance,
        split = as.formula(paste0("~", id_col)),
        type = "scatter",
        mode = "lines",
        line = list(width = 1.5),
        alpha = 0.7,
        text = as.formula(paste0("~paste0('Sample: ', ", id_col, ")")),
        hovertemplate = paste0(
          "%{text}<br>",
          "Wavelength: %{x} nm<br>",
          "Reflectance: %{y:.4f}<br>",
          "<extra></extra>"
        )
      ) %>%
        plotly::layout(
          showlegend = FALSE,
          legend = list(
            orientation = "v",
            yanchor = "top",
            y = 1,
            xanchor = "right",
            x = 1
          ),
          xaxis = list(
            title = "Wavelength (nm)",
            showgrid = FALSE,
            linecolor = "black",
            linewidth = 0.5,
            mirror = T,
            ticks="outside"
          ),
          yaxis = yaxis_opts,
          hovermode = "closest",
          margin = list(l = 60, r = 10, b = 50, t = 40, pad = 4)
        ) %>%
        plotly::config(displayModeBar = TRUE, 
                       displaylogo = FALSE)
    })

  })
}
