################################################################################
### Specimen selection features

# UI
specimen_selection_ui <- function(id) {
  
  ns <- NS(id)
  
  bslib::accordion(id = ns("collapse"),
                   open = NULL,
                   multiple = FALSE,
                   bslib::accordion_panel(title = "Specimen metadata",
                                          id = "specimen_info",
                                          tableOutput(ns("specimen_table"))
                   ),
                   bslib::accordion_panel(title = "Spectra profile",
                                          id = "spectra_profile",
                                          plotlyOutput(ns("spectra_plot"))
                   )
  )

}

# Server
specimen_selection_server <- function(id, 
                                      click_id, 
                                      metadata, 
                                      spectra_compiled) {
  moduleServer(id, function(input, output, session) {
    
    shinyjs::hide(id = session$ns("controls_specimen_selection"))
    
    observeEvent(click_id(), {
      shinyjs::show(id = session$ns("controls_specimen_selection"))
    }, ignoreInit = TRUE)
    
    clicked_points <- reactive({
      req(click_id())
      dplyr::filter(metadata, gbifID %in% click_id())
    })
    
    output$specimen_table <- renderTable({
      
      rows <- clicked_points()
      req(nrow(rows) > 0)
      
      row <- rows %>% dplyr::slice(1)

      data.frame(
        Name  = c("gbifID",
                  "institutionName",
                  "collectionCode",
                  "class",
                  "order",
                  "family",
                  "genus",
                  "species"),
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
    
    
    output$spectra_plot <- plotly::renderPlotly({
      
      rows <- clicked_points()
      shiny::validate(shiny::need(nrow(rows) > 0, "Error"))
      filename_selection <- rows$filename
      
      # Keep per-file metadata we need
      meta_small <- rows %>%
        dplyr::select(filename, targetTissueClass, backgroundClass) %>%
        dplyr::mutate(
          # fixed mappings via factor levels
          ttc = factor(targetTissueClass, levels = c("AD", "AB")),
          bg  = factor(backgroundClass,     levels = c("BGB", "BGP"))
        )
      
      # Subset spectra and pivot
      spectra <- dplyr::filter(spectra_compiled, .data$filename %in% filename_selection)
      
      spectra_long <- tidyr::pivot_longer(
        data = spectra,
        cols = -filename,
        names_to = "wavelength",
        values_to = "reflectance",
        names_transform = list(wavelength = as.numeric)) %>%
        dplyr::left_join(meta_small, by = "filename")
      
      # y-axis rule: fixed [0,1] if all <=1, else flexible
      ymax <- suppressWarnings(max(spectra_long$reflectance, na.rm = TRUE))
      yaxis_opts <- if (is.finite(ymax) && ymax <= 1) {
        list(title = "Reflectance", range = c(0, 1))
      } else {
        list(title = "Reflectance", autorange = TRUE)
      }
      
      plotly::plot_ly(
        data = spectra_long,
        x = ~wavelength,
        y = ~reflectance,
        split = ~filename,
        color = ~bg,  colors = c("black", "grey30"),
        linetype = ~ttc, linetypes = c("solid", "dotted"),
        type = "scatter",
        mode = "lines",
        text = ~paste0(
          "File: ", filename,
          "<br>Tissue: ", targetTissueClass,
          "<br>Background: ", backgroundClass
        ),
        hoverinfo = "text+x+y"
      ) %>%
        plotly::layout(
          showlegend = FALSE,
          xaxis = list(title = 'Wavelength (nm)'),
          yaxis = yaxis_opts,
          autosize = TRUE,
          margin = list(l = 0, r = 0, b = 0, t = 0, pad = 0)
        )
    })
    
    
  })
}