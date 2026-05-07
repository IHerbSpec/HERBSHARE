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
                           uiOutput(ns("specimen_table"))
                           ),
    
    bslib::accordion_panel(title = "Spectra profile",
                           id = "spectra_profile",
                           tags$div(
                             style = "display: flex; flex-wrap: wrap; gap: 14px; font-size: 0.78em; color: #444; margin-bottom: 6px; align-items: center;",
                             tags$span(style = "font-weight: 600;", "Surface:"),
                             tags$span(
                               style = "display: inline-flex; align-items: center; gap: 5px;",
                               tags$span(style = "display: inline-block; width: 26px; border-top: 2px solid #666;"),
                               "Adaxial"
                             ),
                             tags$span(
                               style = "display: inline-flex; align-items: center; gap: 5px;",
                               tags$span(style = "display: inline-block; width: 26px; border-top: 2px dotted #666;"),
                               "Abaxial"
                             ),
                             tags$span(style = "color: #ccc; padding: 0 2px;", "|"),
                             tags$span(style = "font-weight: 600;", "Background:"),
                             tags$span(
                               style = "display: inline-flex; align-items: center; gap: 5px;",
                               tags$span(style = "display: inline-block; width: 26px; border-top: 2px solid #000;"),
                               "Black"
                             ),
                             tags$span(
                               style = "display: inline-flex; align-items: center; gap: 5px;",
                               tags$span(style = "display: inline-block; width: 26px; border-top: 2px solid #7f7f7f;"),
                               "Paper"
                             )
                           ),
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
    output$specimen_table <- renderUI({
      rows <- clicked_points()
      req(nrow(rows) > 0)
      row <- dplyr::slice(rows, 1)

      get_val <- function(x) {
        if (is.null(x) || length(x) == 0) NA_character_ else as.character(x[[1]])
      }

      gbif_id <- get_val(row$gbifID)
      gbif_cell <- if (!is.na(gbif_id)) {
        tags$a(href = paste0("https://www.gbif.org/occurrence/", gbif_id),
               target = "_blank", style = "color: #0d6efd;", gbif_id)
      } else {
        NA_character_
      }

      fields <- list(
        gbifID          = gbif_cell,
        institutionName = get_val(row$institutionName),
        institutionCode = get_val(row$institutionCode),
        class           = get_val(row$class),
        order           = get_val(row$order),
        family          = get_val(row$family),
        genus           = get_val(row$genus),
        species         = get_val(row$species),
        year            = get_val(row$year),
        recordedBy      = get_val(row$recordedBy)
      )

      table_rows <- lapply(names(fields), function(nm) {
        tags$tr(tags$td(tags$strong(nm)), tags$td(fields[[nm]]))
      })

      tags$table(
        class = "table table-striped table-bordered table-sm",
        style = "width: 100%; font-size: 0.85em;",
        tags$tbody(table_rows)
      )
    })
    
    # Spectra
    output$spectra_plot <- plotly::renderPlotly({
      rows <- clicked_points()
      shiny::validate(shiny::need(nrow(rows) > 0, "Select a specimen to view spectra."))
      filename_selection <- rows$filename
      
      meta_small <- rows %>%
        dplyr::select(filename, targetClass, backgroundClass) %>%
        dplyr::mutate(
          ttc = factor(targetClass, levels = c("AD", "AB")),
          bg  = factor(backgroundClass, levels = c("B", "P"))
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
        list(title = "Reflectance",
             range = c(0, 1),
             showgrid = TRUE,
             zeroline = FALSE,
             linecolor = "grey30",
             linewidth = 0.5,
             ticks = "outside",
             mirror = T)
      } else {
        list(title = "Reflectance",
             autorange = TRUE,
             showgrid = TRUE,
             zeroline = FALSE,
             linecolor = "grey30",
             linewidth = 0.5,
             ticks = "outside",
             mirror = T)
      }

      plotly::plot_ly(data = spectra_long,
                      x = ~wavelength,
                      y = ~reflectance,
                      split = ~filename,
                      color = ~bg, colors = c("black", "grey50"),
                      linetype = ~ttc,
                      linetypes = c("solid", "dot"),
                      type = "scatter",
                      mode = "lines",
                      text = ~paste0("File: ", filename,
                                     "<br>Tissue: ", targetClass,
                                     "<br>Background: ", backgroundClass
                                     ),
                      hoverinfo = "text+x+y") %>%
        plotly::layout(showlegend = FALSE,
                       xaxis = list(title = 'Wavelength (nm)',
                                    showgrid = TRUE,
                                    linecolor = "grey30",
                                    linewidth = 0.5,
                                    mirror = T,
                                    ticks = "outside"),
                       yaxis = yaxis_opts,
                       hovermode = "closest",
                       autosize = TRUE,
                       margin = list(l = 60, r = 10, b = 50, t = 40, pad = 4)
                       ) %>%
        plotly::config(displayModeBar = TRUE, displaylogo = FALSE)
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
              "max-width: 200%; max-height: 480px; object-fit: contain;",
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