################################################################################
### Specimen selection features

# UI
specimen_selection_ui <- function(id) {
  ns <- NS(id)
  bslib::accordion(
    id = ns("collapse"),
    open = NULL,
    multiple = FALSE,
    bslib::accordion_panel(title = "Specimen metadata",
                           id = "specimen_info",
                           tableOutput(ns("specimen_table"))
                           ),
    
    bslib::accordion_panel(title = "Spectra profile",
                           id = "spectra_profile",
                           plotlyOutput(ns("spectra_plot"))
                           ),
    bslib::accordion_panel(title = "Specimen image",
                           id = "specimen_image",
                           uiOutput(ns("specimen_image"))
                           )
  )
}

# Server
specimen_selection_server <- function(id, click_id, metadata, spectra_compiled) {
  moduleServer(id, function(input, output, session) {
    
    # Normalize metadata to a reactive data.frame
    md <- reactive({
      if (shiny::is.reactive(metadata)) metadata() else metadata
    })
    
    # Rows for the clicked specimen(s)
    clicked_points <- reactive({
      req(click_id())
      dplyr::filter(md(), gbifID %in% click_id())
    })
    
    # Table
    output$specimen_table <- renderTable({
      rows <- clicked_points()
      req(nrow(rows) > 0)
      row <- dplyr::slice(rows, 1)
      
      data.frame(
        Name  = c("gbifID","institutionName","collectionCode","class",
                  "order","family","genus","species"),
        Value = c(
          as.character(row$gbifID[[1]]),
          row$institutionName[[1]],
          row$collectionCode[[1]],
          row$class[[1]],
          row$order[[1]],
          row$family[[1]],
          row$genus[[1]],
          row$species[[1]]
        ),
        stringsAsFactors = FALSE
      )
    }, striped = TRUE, bordered = TRUE, rownames = FALSE)
    
    # Spectra
    output$spectra_plot <- plotly::renderPlotly({
      rows <- clicked_points()
      shiny::validate(shiny::need(nrow(rows) > 0, "Select a specimen to view spectra."))
      filename_selection <- rows$filename
      
      meta_small <- rows %>%
        dplyr::select(filename, targetTissueClass, backgroundClass) %>%
        dplyr::mutate(
          ttc = factor(targetTissueClass, levels = c("AD", "AB")),
          bg  = factor(backgroundClass, levels = c("BGB", "BGP"))
        )
      
      # Subset spectra and pivot to long
      spectra <- dplyr::filter(spectra_compiled, filename %in% filename_selection)
      
      spectra_long <- tidyr::pivot_longer(
        data = spectra,
        cols = -filename,
        names_to = "wavelength",
        values_to = "reflectance",
        names_transform = list(wavelength = as.numeric)
      ) %>%
        dplyr::left_join(meta_small, by = "filename")
      
      ymax <- suppressWarnings(max(spectra_long$reflectance, na.rm = TRUE))
      yaxis_opts <- if (is.finite(ymax) && ymax <= 1) {
        list(title = "Reflectance", range = c(0, 1))
      } else {
        list(title = "Reflectance", autorange = TRUE)
      }
      
      plotly::plot_ly(data = spectra_long,
                      x = ~wavelength,
                      y = ~reflectance,
                      split = ~filename,
                      color = ~bg, colors = c("black", "grey30"),
                      linetype = ~ttc, 
                      linetypes = c("solid", "dot"),
                      type = "scatter",
                      mode = "lines",
                      text = ~paste0("File: ", filename,
                                     "<br>Tissue: ", targetTissueClass,
                                     "<br>Background: ", backgroundClass
                                     ),
                      hoverinfo = "text+x+y") %>%
        plotly::layout(showlegend = FALSE,
                       xaxis = list(title = 'Wavelength (nm)'),
                       yaxis = yaxis_opts,
                       autosize = TRUE,
                       margin = list(l = 0, r = 0, b = 0, t = 0, pad = 0)
                       )
    })
    
    # Image
    output$specimen_image <- shiny::renderUI({
      rows <- clicked_points()
      shiny::validate(shiny::need(nrow(rows) > 0, "Select a specimen to view the image."))
      
      ref <- rows$references[[1]]
      if (is.null(ref) || is.na(ref) || !nzchar(ref)) {
        return(shiny::div("No image available."))
      }
      
      m <- regexpr("https?://[^\\s,;|]+", ref, perl = TRUE)
      url <- if (m[1] != -1) regmatches(ref, m)[[1]] else NA_character_
      if (is.na(url)) return(shiny::div("No image URL found."))
      
      shiny::tags$div(
        style = "text-align:center;",
        shiny::tags$a(
          href = url, target = "_blank", rel = "noopener",
          shiny::tags$img(
            src = url, alt = "Specimen image (thumbnail)",
            style = paste(
              "max-width: 100%; max-height: 240px; object-fit: contain;",
              "border: 1px solid #ddd; border-radius: 4px; padding: 2px;"
            )
          )
        ),
        shiny::tags$div(
          style = "font-size: 0.85em; margin-top: 6px;",
          "Click the image to open full-size in a new tab."
        )
      )
    })
  })
}