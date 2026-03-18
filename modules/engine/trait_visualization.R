################################################################################
### Trait visualization module

# UI
trait_visualization_ui <- function(id) {
  ns <- NS(id)

  tagList(div(style = "margin-bottom: 1rem;",
              h4("Trait Distribution")),

          uiOutput(ns("histogram_grid")),

          div(style = "margin-top: 1rem;",
              uiOutput(ns("download_section"))
              )
  )
}

# Server
trait_visualization_server <- function(id, predictions_data) {
  moduleServer(id, function(input, output, session) {

    ns <- session$ns

    # Check if we have prediction data
    has_predictions <- reactive({
      !is.null(predictions_data()) && nrow(predictions_data()) > 0
    })

    # Get trait columns (exclude rowID)
    trait_columns <- reactive({
      
      req(has_predictions())
      pred_df <- predictions_data()
      cols <- names(pred_df)

      # Exclude ID column and uncertainty columns
      trait_cols <- cols[cols != "rowID" &
                         !grepl("_q0025$|_q0975$|_uncertainty$", cols)]
      trait_cols
      
      })

    # Download section
    output$download_section <- renderUI({
      req(has_predictions())

      downloadButton(
        ns("download_plots_png"),
        "Download plots (PNG)",
        class = "btn-success"
      )
    })

    # Generate histogram grid
    output$histogram_grid <- renderUI({
      req(has_predictions())

      traits <- trait_columns()

      if (length(traits) == 0) {
        return(div(
          class = "alert alert-info",
          "No trait data available for visualization"
        ))
      }

      # Create grid of histograms
      plot_outputs <- lapply(traits, function(trait) {
        div(
          style = "margin-bottom: 1rem;",
          plotlyOutput(ns(paste0("hist_", trait)), height = "300px")
        )
      })

      div(
        style = "display: grid; grid-template-columns: repeat(auto-fit, minmax(400px, 1fr)); gap: 1rem;",
        plot_outputs
      )
    })

    # Create individual histograms
    observe({
      req(has_predictions())

      pred_df <- predictions_data()
      traits <- trait_columns()

      lapply(traits, function(trait) {
        output[[paste0("hist_", trait)]] <- plotly::renderPlotly({
          create_trait_histogram(pred_df, trait)
        })
      })
    })

    # Download PNG
    output$download_plots_png <- downloadHandler(
      filename = function() {
        paste0("herbsphere_trait_histograms_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".png")
      },
      content = function(file) {
        req(has_predictions())

        pred_df <- predictions_data()
        traits <- trait_columns()

        # Create static plots for export
        plots <- lapply(traits, function(trait) {
          create_static_histogram(pred_df, trait)
        })

        # Arrange in grid
        n_plots <- length(plots)
        n_cols <- min(3, n_plots)
        n_rows <- ceiling(n_plots / n_cols)

        # Save as PNG
        png(file, width = 1200, height = 400 * n_rows, res = 100)
        par(mfrow = c(n_rows, n_cols), mar = c(4, 4, 2, 1))

        for (i in seq_along(plots)) {
          plots[[i]]()
        }

        dev.off()
      }
    )
  })
}

# Helper function to create interactive histogram
create_trait_histogram <- function(data, trait_name) {

  # Get values
  values <- data[[trait_name]]
  values <- values[is.finite(values)]

  if (length(values) == 0) {
    return(plotly::plotly_empty())
  }

  # Get trait info
  trait_info <- get_trait_info(trait_name)

  # Calculate statistics
  mean_val <- mean(values, na.rm = TRUE)
  median_val <- median(values, na.rm = TRUE)
  sd_val <- sd(values, na.rm = TRUE)

  # Create histogram
  p <- plotly::plot_ly(
    x = values,
    type = "histogram",
    marker = list(
      color = "#3498db",
      line = list(color = "#2c3e50", width = 1)
    ),
    hovertemplate = paste0(
      "Range: %{x}<br>",
      "Count: %{y}<br>",
      "<extra></extra>"
    )
  ) %>%
    plotly::layout(
      title = list(
        text = paste0("<b>", trait_info$label, "</b>"),
        font = list(size = 14)
      ),
      xaxis = list(
        title = trait_info$unit,
        showgrid = TRUE
      ),
      yaxis = list(
        title = "Count",
        showgrid = TRUE
      ),
      shapes = list(
        # Mean line
        list(
          type = "line",
          x0 = mean_val, x1 = mean_val,
          y0 = 0, y1 = 1,
          yref = "paper",
          line = list(
            color = "#e74c3c",
            width = 2,
            dash = "dash"
          )
        )
      ),
      annotations = list(
        list(
          x = 0.98,
          y = 0.98,
          xref = "paper",
          yref = "paper",
          text = sprintf(
            "Mean: %.2f<br>Median: %.2f<br>SD: %.2f<br>n: %d",
            mean_val, median_val, sd_val, length(values)
          ),
          showarrow = FALSE,
          xanchor = "right",
          yanchor = "top",
          font = list(size = 10),
          bgcolor = "rgba(255, 255, 255, 0.8)",
          bordercolor = "#cccccc",
          borderwidth = 1
        )
      ),
      hovermode = "closest",
      margin = list(t = 40, b = 40, l = 50, r = 10)
    ) %>%
    plotly::config(displayModeBar = TRUE, displaylogo = FALSE)

  return(p)
}

# Helper function to create static histogram for export
create_static_histogram <- function(data, trait_name) {

  function() {
    values <- data[[trait_name]]
    values <- values[is.finite(values)]

    if (length(values) == 0) {
      plot.new()
      text(0.5, 0.5, "No data", cex = 1.5)
      return(invisible())
    }

    # Get trait info
    trait_info <- get_trait_info(trait_name)

    # Calculate statistics
    mean_val <- mean(values, na.rm = TRUE)
    median_val <- median(values, na.rm = TRUE)
    sd_val <- sd(values, na.rm = TRUE)

    # Create histogram
    hist(
      values,
      main = trait_info$label,
      xlab = trait_info$unit,
      ylab = "Count",
      col = "#3498db",
      border = "#2c3e50",
      las = 1
    )

    # Add mean line
    abline(v = mean_val, col = "#e74c3c", lwd = 2, lty = 2)

    # Add statistics
    legend(
      "topright",
      legend = sprintf(
        "Mean: %.2f\nMedian: %.2f\nSD: %.2f\nn: %d",
        mean_val, median_val, sd_val, length(values)
      ),
      bty = "n",
      cex = 0.8
    )
  }
}

# Helper function to get trait information
get_trait_info <- function(trait_name) {

  trait_labels <- list(
    "LMA" = list(
      label = "Leaf Mass per Area (LMA)",
      unit = "g/m²"
    ),
    "EWT" = list(
      label = "Equivalent Water Thickness (EWT)",
      unit = "g/m²"
    ),
    "LDMC" = list(
      label = "Leaf Dry Matter Content (LDMC)",
      unit = "fraction"
    ),
    "Car" = list(
      label = "Carotenoids (Car)",
      unit = "μg/cm²"
    ),
    "Chla" = list(
      label = "Chlorophyll a (Chla)",
      unit = "μg/cm²"
    ),
    "Chlb" = list(
      label = "Chlorophyll b (Chlb)",
      unit = "μg/cm²"
    ),
    "Chla+b" = list(
      label = "Total Chlorophyll (Chla+b)",
      unit = "μg/cm²"
    ),
    "Hemicellulose" = list(
      label = "Hemicellulose",
      unit = "fraction"
    ),
    "Cellulose" = list(
      label = "Cellulose",
      unit = "fraction"
    ),
    "Lignin" = list(
      label = "Lignin",
      unit = "fraction"
    ),
    "N" = list(
      label = "Nitrogen (N)",
      unit = "fraction"
    ),
    "C" = list(
      label = "Carbon (C)",
      unit = "fraction"
    )
  )

  if (trait_name %in% names(trait_labels)) {
    return(trait_labels[[trait_name]])
  } else {
    return(list(
      label = trait_name,
      unit = "value"
    ))
  }
}
