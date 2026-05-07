################################################################################
### Leaflet map

# UI
map_ui <- function(id) {
  ns <- NS(id)
  leafletOutput(ns("map"), width = "100%", height = "100%")
}

# Server
map_server <- function(id, metadata_sf, clear_draw = NULL) {
  moduleServer(id, function(input, output, session) {

    group_name <- "specimens"
    draw_group <- "drawsel"

    # Store the drawn geometry
    geom_filter <- reactiveVal(NULL)

    # Track geometry deletion
    geom_deleted <- reactiveVal(0)

    # Track if initial load
    initial_load <- reactiveVal(TRUE)

    # Flag to suppress fitBounds after a "Show all" reset
    skip_fit <- reactiveVal(FALSE)
    
    output$map <- renderLeaflet({
      leaflet(options = leafletOptions(minZoom = 2)) %>%
        addTiles() %>%
        setMaxBounds(lng1 = -180, lat1 = -90, lng2 = 180, lat2 = 90) %>%
        setView(lng = 0, lat = 20, zoom = 2) %>%
        addProviderTiles("Esri.WorldImagery", group = "Esri.WorldImagery") %>%
        addProviderTiles("OpenStreetMap.Mapnik", group = "OpenStreetMap.Mapnik") %>%
        addProviderTiles("Esri.WorldTopoMap", group = "Esri.WorldTopoMap") %>%
        addProviderTiles("Esri.WorldTerrain", group = "Esri.WorldTerrain") %>%
        addLayersControl(baseGroups = c("Esri.WorldImagery", "OpenStreetMap.Mapnik",
                                        "Esri.WorldTopoMap", "Esri.WorldTerrain")) %>%
        leaflet.extras::addDrawToolbar(
          targetGroup = draw_group,
          polygonOptions   = drawPolygonOptions(
            showArea = TRUE,
            shapeOptions = drawShapeOptions(fillColor = "lightblue", 
                                            color = "black", 
                                            clickable = FALSE)
          ),
          rectangleOptions = drawRectangleOptions(
            showArea = TRUE,
            shapeOptions = drawShapeOptions(fillColor = "lightblue", 
                                            color = "black", 
                                            clickable = FALSE)
          ),
          polylineOptions = FALSE, 
          circleOptions = FALSE,
          circleMarkerOptions = FALSE, 
          markerOptions = FALSE,
          editOptions = editToolbarOptions(
            edit = FALSE,
            remove = TRUE,
            selectedPathOptions = selectedPathOptions()
          ),
          position = "topright"
        ) %>%
        addResetMapButton() %>%
        htmlwidgets::onRender("
          function(el, x) {
            var map = this;
            var id = el.id;

            // Listen for custom clear message
            Shiny.addCustomMessageHandler('herb-clear-draw', function(msg) {
              if(msg.id !== id) return;

              // Primary: clear via the draw control's feature group
              if (map.drawControl &&
                  map.drawControl.options &&
                  map.drawControl.options.edit &&
                  map.drawControl.options.edit.featureGroup) {
                map.drawControl.options.edit.featureGroup.clearLayers();
              } else {
                // Fallback: remove polygon/rectangle layers added by drawing
                var toRemove = [];
                map.eachLayer(function(layer) {
                  if (layer instanceof L.Polygon || layer instanceof L.Rectangle) {
                    toRemove.push(layer);
                  }
                });
                toRemove.forEach(function(l) { map.removeLayer(l); });
              }
            });
          }
        ")
    })
    
    # "Show all": reset geometry, view, and clear drawn shapes
    if (!is.null(clear_draw)) {
      observeEvent(clear_draw(), {
        geom_filter(NULL)
        skip_fit(TRUE)
        leafletProxy("map", session = session) %>%
          setView(lng = 0, lat = 20, zoom = 2)
        session$sendCustomMessage("herb-clear-draw", list(id = session$ns("map")))
      }, ignoreInit = TRUE)
    }

    # Capture drawn shapes
    observeEvent(input$map_draw_new_feature, {
      feature <- input$map_draw_new_feature
      
      # Convert GeoJSON to sf
      geojson_str <- jsonlite::toJSON(feature, auto_unbox = TRUE)
      drawn_sf <- sf::st_read(geojson_str, quiet = TRUE)
      
      # Set CRS to WGS84
      sf::st_crs(drawn_sf) <- 4326
      
      # Store as sfc geometry
      geom_filter(sf::st_geometry(drawn_sf))
      
    })
    
    # Capture when user manually deletes a shape
    observeEvent(input$map_draw_deleted_features, {
      geom_filter(NULL)
      # Increment counter to trigger reactive
      geom_deleted(geom_deleted() + 1)

    })
    
    # Normalize input to a reactive sf
    sf_data <- reactive({
      if(shiny::is.reactive(metadata_sf)) metadata_sf() else metadata_sf
    })
    
    # Update markers when data changes
    observe({
      x <- sf_data()
      
      # Skip initial load flag after first render
      is_initial <- initial_load()
      if (is_initial) {
        initial_load(FALSE)
      }
      
      proxy <- leafletProxy("map", session = session) %>%
        clearGroup(group_name) %>%
        clearMarkers()
      
      if(is.null(x) || nrow(x) == 0) return(invisible())
      
      proxy <- proxy %>% 
        addMarkers(data = x,
                   clusterOptions = markerClusterOptions(),
                   group = group_name,
                   layerId = ~gbifID)
      
      # Fit bounds to current data (skipped after a "Show all" reset)
      if (!is_initial && !isolate(skip_fit())) {
        bx <- sf::st_bbox(x)
        if (all(is.finite(bx))) {
          proxy %>% fitBounds(
            lng1 = unname(bx["xmin"]),
            lat1 = unname(bx["ymin"]),
            lng2 = unname(bx["xmax"]),
            lat2 = unname(bx["ymax"])
          )
        }
      }
      isolate(skip_fit(FALSE))
    })
    
    # Click handler
    click_id <- reactiveVal(NULL)
    observeEvent(input$map_marker_click, { 
      click_id(input$map_marker_click$id) 
    })
    
    list(click_id = click_id,
         geom_filter = geom_filter,
         geom_deleted = reactive(geom_deleted()),
         draw_group = draw_group)
  })
}