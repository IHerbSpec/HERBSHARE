################################################################################
### Trait visualization module

# UI
trait_visualization_ui <- function(id) {
  ns <- NS(id)

  tagList(div(style = "margin-bottom: 1rem;",
              h4("Trait Distribution")),

          uiOutput(ns("histogram_grid"))
  )
}

# Server
trait_visualization_server <- function(id, predictions_data, primary_color = "#26413C") {
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
          create_trait_histogram(pred_df, trait, primary_color)
        })
      })
    })

  })
}

# Helper function to create interactive histogram
create_trait_histogram <- function(data, trait_name, primary_color = "#26413C") {

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
      color = primary_color,
      line = list(color = "white", width = 1)
    ),
    hovertemplate = paste0(
      "Range: %{x}<br>",
      "Count: %{y}<br>",
      "<extra></extra>"
    )
  ) %>%
    plotly::layout(
      # title = list(
      #   text = paste0("<b>", trait_info$label, "</b>"),
      #   font = list(size = 14)
      # ),
      xaxis = list(
        title = trait_info$unit,
        showgrid = FALSE,
        linecolor = "black",
        linewidth = 0.5,
        mirror = T,
        ticks = "outside"
      ),
      yaxis = list(
        title = "Count",
        showgrid = FALSE,
        zeroline = TRUE,
        linecolor = "black",
        linewidth = 0.5,
        mirror = T,
        ticks = "outside"
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
            dash = "dot"
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
          bordercolor = NULL,
          borderwidth = 1
        )
      ),
      hovermode = "closest",
      margin = list(l = 60, r = 10, b = 50, t = 40, pad = 4)
    ) %>%
    plotly::config(displayModeBar = TRUE, displaylogo = FALSE)

  return(p)
}

# Helper function to get trait information
get_trait_info <- function(trait_name) {

  trait_labels <- list(
    "LMA" = list(
      label = "Leaf Mass per Area (LMA)",
      unit = "LMA (g/m²)"
    ),
    "EWT" = list(
      label = "Equivalent Water Thickness (EWT)",
      unit = "EWT (g/m²)"
    ),
    "LDMC" = list(
      label = "Leaf Dry Matter Content (LDMC)",
      unit = "LDMC (g/g)"
    ),
    "Car" = list(
      label = "Carotenoids (Car)",
      unit = "Car (μg/g)"
    ),
    "Chla" = list(
      label = "Chlorophyll a (Chla)",
      unit = "Chla (μg/g)"
    ),
    "Chlb" = list(
      label = "Chlorophyll b (Chlb)",
      unit = "Chlb (μg/g)"
    ),
    "Chla+b" = list(
      label = "Total Chlorophyll (Chla+b)",
      unit = "Chla+b (μg/g)"
    ),
    "Hemicellulose" = list(
      label = "Hemicellulose",
      unit = "Hemicellulose (g/g)"
    ),
    "Cellulose" = list(
      label = "Cellulose",
      unit = "Cellulose (g/g)"
    ),
    "Lignin" = list(
      label = "Lignin",
      unit = "Lignin (g/g)"
    ),
    "N" = list(
      label = "Nitrogen (N)",
      unit = "Nitrogen (g/g)"
    ),
    "C" = list(
      label = "Carbon (C)",
      unit = "Carbon (g/g)"
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
