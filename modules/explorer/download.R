################################################################################
### Download bundle

# UI
download_ui <- function(id) {
  ns <- NS(id)
  uiOutput(ns("btn"))
}

# Server
download_server <- function(id, applied_data, spectra_compiled, on_show, on_hide) {
  moduleServer(id, function(input, output, session) {
    
    ns <- session$ns
    
    # Visibility toggled
    visible <- reactiveVal(FALSE)
    observeEvent(on_show(), { visible(TRUE)  }, ignoreInit = TRUE)
    observeEvent(on_hide(), { visible(FALSE) }, ignoreInit = TRUE)
    
    # Applied metadata as data.frame (drop geometry if sf)
    sel_md <- reactive({
      req(visible())
      x <- if (shiny::is.reactive(applied_data)) applied_data() else applied_data
      if (inherits(x, "sf")) x <- sf::st_drop_geometry(x)
      x
    })
    
    # Spectra subset by filename
    sel_spectra <- reactive({
      md <- sel_md()
      if (!isTRUE(nrow(md) > 0)) return(spectra_compiled[0, ])
      if (!"filename" %in% names(md)) return(spectra_compiled[0, ])
      dplyr::filter(spectra_compiled, filename %in% md$filename)
    })
    
    # Overlay panel inside map container
    output$btn <- renderUI({
      if (!isTRUE(visible())) return(NULL)
      md <- sel_md()
      if (!isTRUE(nrow(md) > 0)) return(NULL)
      
      tags$div(
        style = "position:absolute; right: 1rem; bottom: 1rem; z-index: 500;",
        downloadButton(ns("download_zip"), "Download selected (.zip)", class = "btn btn-success")
      )
    })
    
    observeEvent(input$hide_panel, { visible(FALSE) }, ignoreInit = TRUE)
    
    # Create ZIP
    output$download_zip <- downloadHandler(
      filename = function() paste0("herbsphere_selection_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".zip"),
      content  = function(file) {
        md <- sel_md()
        validate(need(nrow(md) > 0, "No rows selected to download."))
        sp <- sel_spectra()
        
        tmpdir <- tempfile("herbsel_"); dir.create(tmpdir)
        md_path <- file.path(tmpdir, "metadata_selected.csv")
        sp_path <- file.path(tmpdir, "spectra_selected.csv")
        
        data.table::fwrite(md, md_path)
        data.table::fwrite(sp, sp_path)
        
        if (requireNamespace("zip", quietly = TRUE)) {
          zip::zipr(zipfile = file, files = c(md_path, sp_path), include_directories = FALSE)
        } else {
          oldwd <- setwd(tmpdir); on.exit(setwd(oldwd), add = TRUE)
          utils::zip(zipfile = file, files = c("metadata_selected.csv", "spectra_selected.csv"))
        }
      }
    )
  })
}
