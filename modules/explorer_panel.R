################################################################################
### Explorer panel

# UI
explorer_panel_ui <- function(id) {
  ns <- NS(id)
  
  layout_sidebar(
    
    # Records
    sidebar = sidebar(
      id = ns("left_sb"),
      title = NULL,
      open = TRUE,
      width  = "25%",
      bslib::accordion(id = ns("collapse"),
                       open = c("by_select", "records_summary"),
                       multiple = TRUE,
                       bslib::accordion_panel(title = "Summary of records",
                                              id = "records_summary",
                                              summary_records_ui(ns("summary_records"))),
                       bslib::accordion_panel(title = "Select by",
                                              id = "by_select",
                                              select_by_ui(ns("select_by"))
                                              )
                       )
    ),
    
    
    layout_sidebar(
      class = "no-pad-main",
      fillable = TRUE,
      gap = "0%",
      border = FALSE,
      border_radius = FALSE,
      
      # Specimen information
      sidebar = sidebar(
        id = ns("right_sb"),
        title = NULL,
        position = "right",
        width  = "30%",
        open   = FALSE,
        specimen_selection_ui(ns("spec_sel"))
      ),
      
      # Map
      div(class = "p-0 m-0", style = "height: 100%;", map_ui(ns("map")))
    )
  )
}


# Server
explorer_panel_server <- function(id, metadata, spectra_compiled) {
  moduleServer(id, function(input, output, session) {
    
    # As vector
    metadata_sf <- st_as_sf(metadata, 
                            coords = c("decimalLongitude", "decimalLatitude"), 
                            crs = 4326, 
                            remove = FALSE)
    
    # Select by
    sel <- select_by_server(id = "select_by", metadata = metadata)
    
    filtered_sf <- reactive({
      
      sel_dt <- sel$data()
      
      if (is.null(sel_dt) || nrow(sel_dt) == 0) {
        return(metadata_sf[0, ])
      }
      
      if ("gbifID" %in% names(metadata_sf) && "gbifID" %in% names(sel_dt)) {
        return(metadata_sf[metadata_sf$gbifID %in% sel_dt$gbifID, ])
      }
      
      by_cols <- intersect(names(metadata_sf), names(sel_dt))
      
      if (length(by_cols) == 0) {
        return(metadata_sf[0, ])
      }
      
      dplyr::semi_join(metadata_sf, sel_dt, by = by_cols)
    })

    # Summary records
    summary_records_server("summary_records", metadata = reactive(sel$data()))
    
    # Map
    map_out <- map_server(id = "map", metadata_sf = filtered_sf())
    
    # Sidebar logic
    observeEvent(map_out$click_id(), ignoreInit = TRUE, {
      toggle_sidebar(id = "right_sb", open = TRUE,  session = session)
      toggle_sidebar(id = "left_sb",  open = FALSE, session = session)
    })
    
    # Specimen selection
    specimen_selection_server(
      id = "spec_sel",
      click_id = map_out$click_id,
      metadata = reactive(sel$data()),
      spectra_compiled = spectra_compiled
    )
  })
}