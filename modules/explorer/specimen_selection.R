################################################################################
### Specimen selection features

# UI
specimen_selection_ui <- function(id) {
  ns <- NS(id)
  
  absolutePanel(
    id = ns("controls_specimen_selection"),
    class = "panel panel-default",
    fixed = TRUE,
    draggable = TRUE,
    width = 400,
    top = "20%", left = "auto", right = "5%", bottom = "auto",
    #style = "z-index: 1001; background: rgba(255,255,255,0.95); padding: 10px;",
    p(""),
    bslib::accordion(id = ns("collapse"),
                     open = "specimen_info",
                     bslib::accordion_panel(title = "Specimen information",
                                            id = "specimen_info",
                                            tableOutput(ns("specimen_table"))
                                            ),
                     bslib::accordion_panel(title = "Spectra profile",
                                            id = "spectra_profile",
                                            plotlyOutput(ns("spectra_plot"))
                                            )
    )
  )
}

# Server
specimen_selection_server <- function(id, 
                                      click_id, 
                                      metadata_sf, 
                                      points_sf,
                                      spectra_compiled) {
  moduleServer(id, function(input, output, session) {
    
    shinyjs::hide(id = session$ns("controls_specimen_selection"))
    
    observeEvent(click_id(), {
      shinyjs::show(id = session$ns("controls_specimen_selection"))
    }, ignoreInit = TRUE)
    
    clicked_points <- reactive({
      req(click_id())
      dplyr::filter(metadata_sf, gbifID %in% click_id())
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
    
    
    output$spectra_plot <- renderPlotly({

      rows <- clicked_points()
      
      shiny::validate(
        shiny::need(nrow(rows) > 0, "Error")
      )
      
      metatada <- st_drop_geometry(rows)
      filename_selection <- metatada$filename
      spectra <- dplyr::filter(spectra_compiled, filename %in% filename_selection)
      
      spectra_long <- tidyr::pivot_longer(data = spectra,
                                          cols = -filename,
                                          names_to = "wavelength",
                                          values_to = "reflectance",
                                          names_transform = list(wavelength = as.numeric)
                                          )
      
      plot_ly(
        data = spectra_long, 
        x = ~wavelength,
        y = ~reflectance,
        split = ~filename,
        color = ~filename,
        type = "scatter",
        mode = "lines"
      ) %>%
        layout(
          showlegend = FALSE,                      # ← hide legend
          xaxis = list(title = 'Wavelength (nm)'),
          yaxis = list(title = 'Reflectance'),
          autosize = TRUE,
          margin = list(l = 0, r = 0, b = 0, t = 0, pad = 0)
        )
    })
    
  })
}