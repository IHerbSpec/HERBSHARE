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
      summary_records_ui(ns("summary_records"))
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
    
    # metadata_sf <- reactive({
    #   st_as_sf(metadata,
    #            coords = c("decimalLongitude", "decimalLatitude"),
    #            crs = 4326)
    # })
    
    # Summary records
    summary_records_server("summary_records", metadata = metadata)
    
    # Map
    map_out <- map_server(id = "map", metadata_sf = metadata_sf)
    
    # Sidebar logic
    observeEvent(map_out$click_id(), ignoreInit = TRUE, {
      toggle_sidebar(id = "right_sb", open = TRUE,  session = session)
      toggle_sidebar(id = "left_sb",  open = FALSE, session = session)
    })
    
    # Specimen selection
    specimen_selection_server(
      id = "spec_sel",
      click_id = map_out$click_id,
      metadata = metadata,
      spectra_compiled = spectra_compiled
    )
  })
}