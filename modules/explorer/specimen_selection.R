################################################################################
### Specimen selection features

# UI
# specimen_selection_ui <- function(id) {
#   ns <- NS(id)
# 
#   absolutePanel(
#     id = ns("controls_specimen_selection"),
#     class = "panel panel-default",
#     fixed = TRUE,
#     draggable = TRUE,
#     width = 400,
#     top = "20%", left = "auto", right = "5%", bottom = "auto",
# 
#     tags$style(HTML(sprintf("
#       /* Header (collapsed & expanded) */
#       #%s .accordion-button {
#         background-color: #000000 !important;
#         color: #ffffff !important;
#       }
#       #%s .accordion-button:not(.collapsed) {
#         background-color: #000000 !important;
#         color: #ffffff !important;
#         box-shadow: none !important;
#       }
#       /* Remove focus ring & set border color */
#       #%s .accordion-button:focus {
#         box-shadow: none !important;
#         border-color: #333333 !important;
#       }
#       /* Body + item background & border */
#       #%s .accordion-body {
#         background-color: #ffffff !important;
#         color: #ffffff !important;
#       }
#       #%s .accordion-item {
#         background-color: #ffffff !important;
#         border-color: #333333 !important;
#       }
#       /* Chevron icon to light (so it shows on dark header) */
#       #%s .accordion-button::after {
#         filter: invert(1);
#       }
#     ",
#                             ns("collapse"), ns("collapse"), ns("collapse"),
#                             ns("collapse"), ns("collapse"), ns("collapse")
#     ))),
#     
# #     tags$style(HTML(sprintf("
# #   /* Wrapper created by tableOutput(ns('specimen_table')) */
# #   #%s table {
# #     background-color: #ffffff !important;
# #     color: #000000 !important;
# #     border-color: #ffffff !important;
# #   }
# #   #%s thead th {
# #     background-color: #ffffff !important;
# #     color: #000000 !important;
# #     border-color: #ffffff !important;
# #   }
# #   #%s tbody td {
# #     border-color: #ffffff !important;
# #   }
# #   /* Stripes & hover (works with renderTable(striped=TRUE)) */
# #   #%s tbody tr:nth-child(odd)  { background-color: #111111 !important; }
# #   #%s tbody tr:nth-child(even) { background-color: #161616 !important; }
# #   #%s tbody tr:hover           { background-color: #1f1f1f !important; }
# #   /* Optional: link color */
# #   #%s a { color: #a3b18a !important; }
# # ", ns("specimen_table"), ns("specimen_table"), ns("specimen_table"), ns("specimen_table"),
# #                             ns("specimen_table"), ns("specimen_table"), ns("specimen_table")))),
# 
#     bslib::accordion(id = ns("collapse"),
#                      open = NULL,
#                      multiple = FALSE,
#                      bslib::accordion_panel(title = "Specimen information",
#                                             id = "specimen_info",
#                                             tableOutput(ns("specimen_table"))
#                                             ),
#                      bslib::accordion_panel(title = "Spectra profile",
#                                             id = "spectra_profile",
#                                             plotlyOutput(ns("spectra_plot"))
#                                             )
#     )
#   )
# }


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
    
    
    output$spectra_plot <- plotly::renderPlotly({
      rows <- clicked_points()
      shiny::validate(shiny::need(nrow(rows) > 0, "Error"))
      
      md <- sf::st_drop_geometry(rows)
      filename_selection <- md$filename
      
      # Keep per-file metadata we need
      meta_small <- md %>%
        dplyr::select(filename, targetTissueClass, backgroundClass) %>%
        dplyr::mutate(
          # fixed mappings via factor levels
          ttc = factor(targetTissueClass, levels = c("AB", "AD")),
          bg  = factor(backgroundClass,     levels = c("Black", "Paper"))
        )
      
      # Subset spectra and pivot
      spectra <- dplyr::filter(spectra_compiled, .data$filename %in% filename_selection)
      
      spectra_long <- tidyr::pivot_longer(
        data = spectra,
        cols = -filename,
        names_to = "wavelength",
        values_to = "reflectance",
        names_transform = list(wavelength = as.numeric)
      ) %>%
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