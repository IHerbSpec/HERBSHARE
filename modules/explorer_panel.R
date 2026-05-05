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
        width  = "35%",
        open   = FALSE,
        specimen_selection_ui(ns("spec_sel"))
      ),
      
      # Map and download
      div(class = "p-0 m-0",
          style = "height: 100%; position: relative;",
          map_ui(ns("map")),
          download_ui(ns("download"))
      )
    )
  )
}

# Server
explorer_panel_server <- function(id, metadata, spectra_compiled, citation) {
  moduleServer(id, function(input, output, session) {
    
    # Static sf baseline
    metadata_sf <- st_as_sf(metadata,
                            coords = c("decimalLongitude", "decimalLatitude"),
                            crs = 4326,
                            remove = FALSE)
    
    # What the map is currently showing
    current_sf <- reactiveVal(metadata_sf)
    
    # Map module: get geometry + clicks
    map_out <- map_server(id = "map",
                          metadata_sf = reactive(current_sf()))
    
    # Select-by module 
    sel <- select_by_server(id = "select_by",
                            metadata = metadata,
                            geom_filter = map_out$geom_filter)
    
    # A single "clear" signal that fires on Show all
    clear_signal <- reactive({
      sel$show_all()
    })

    # When geometry is manually deleted, trigger "Show all"
    observeEvent(map_out$geom_deleted(), {
      # Trigger show all programmatically
      current_sf(metadata_sf)
    }, ignoreInit = TRUE)

    # Clear drawn shapes when "Show all" is pressed
    observeEvent(clear_signal(), {
      # Send message to map to clear drawn shapes
      session$sendCustomMessage("herb-clear-draw", list(
        id = session$ns("map")
      ))
    }, ignoreInit = TRUE)
    
    # Helper: apply attribute filters + geometry
    make_filtered_sf <- function(sel_dt, geom) {
      # Start from empty
      if (is.null(sel_dt) || nrow(sel_dt) == 0) return(metadata_sf[0, ])
      
      # 1) Attribute subset: join metadata_sf to sel_dt
      if ("gbifID" %in% names(metadata_sf) && "gbifID" %in% names(sel_dt)) {
        sf_sub <- metadata_sf[metadata_sf$gbifID %in% sel_dt$gbifID, ]
      } else {
        by_cols <- intersect(names(metadata_sf), names(sel_dt))
        if (length(by_cols) == 0) return(metadata_sf[0, ])
        sf_sub <- dplyr::semi_join(metadata_sf, sel_dt, by = by_cols)
      }
      
      # 2) Spatial subset ONLY if a geometry exists
      if (!is.null(geom) && length(geom) > 0 && nrow(sf_sub) > 0) {
        pts <- sf_sub
        sf::st_agr(pts) <- "constant"
        idx  <- sf::st_intersects(pts, geom, sparse = TRUE)
        keep <- lengths(idx) > 0L
        sf_sub <- pts[keep, ]
      }
      
      sf_sub
    }
    
    # When user presses "Select": apply attribute + geometry filter
    observeEvent(sel$apply(), {
      sf_sub <- make_filtered_sf(sel$data(), geom = map_out$geom_filter())
      current_sf(sf_sub)
    })
    
    # "Show all": reset to full dataset
    observeEvent(sel$show_all(), {
      current_sf(metadata_sf)
    })
    
    # Summary records: use the APPLIED subset
    summary_records_server(
      "summary_records",
      metadata = reactive(sf::st_drop_geometry(current_sf()))
    )
    
    # Sidebars: open specimen panel on map click
    observeEvent(map_out$click_id(), ignoreInit = TRUE, {
      toggle_sidebar(id = "right_sb", open = TRUE,  session = session)
      toggle_sidebar(id = "left_sb",  open = FALSE, session = session)
    })
    
    # Specimen panel
    specimen_selection_server(id = "spec_sel",
                              click_id = map_out$click_id,
                              metadata = reactive(sf::st_drop_geometry(current_sf())),
                              spectra_compiled = spectra_compiled)
    
    # Download: what is currently applied on the map
    download_server(id = "download",
                    applied_data = reactive(sf::st_drop_geometry(current_sf())),
                    spectra_compiled = spectra_compiled,
                    citation = citation,
                    on_show = sel$apply,
                    on_hide = sel$show_all)
  })
}