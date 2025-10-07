################################################################################
### Leaflet map

# uI
map_ui <- function(id) {
  ns <- NS(id)
  leafletOutput(ns("map"), width = "100%", height = "100%")
}

# Server
map_server <- function(id, metadata_sf) {
  moduleServer(id, function(input, output, session) {

    group_name <- "specimens"

    # Base map once (no data here)
    output$map <- renderLeaflet({
      leaflet(options = leafletOptions(minZoom = 2)) %>%
        addTiles() %>%
        setMaxBounds(lng1 = -180, lat1 = -90, lng2 = 180, lat2 = 90) %>%
        addProviderTiles("Esri.WorldImagery", group = "Esri.WorldImagery") %>%
        addProviderTiles("OpenStreetMap.Mapnik", group = "OpenStreetMap.Mapnik") %>%
        addProviderTiles("Esri.WorldTopoMap", group = "Esri.WorldTopoMap") %>%
        addProviderTiles("Esri.WorldTerrain", group = "Esri.WorldTerrain") %>%
        addLayersControl(
          baseGroups = c(
            "Esri.WorldImagery", "OpenStreetMap.Mapnik",
            "Esri.WorldTopoMap", "Esri.WorldTerrain"
          )
        ) %>%
        # addDrawToolbar(
        #   targetGroup = "x",
        #   polygonOptions   = drawPolygonOptions(
        #     showArea = TRUE,
        #     shapeOptions = drawShapeOptions(fillColor = "#ffba08", color = "#370617", clickable = FALSE)
        #   ),
        #   rectangleOptions = drawRectangleOptions(
        #     showArea = TRUE,
        #     shapeOptions = drawShapeOptions(fillColor = "#ffba08", color = "#370617", clickable = FALSE)
        #   ),
        #   position = "topright",
        #   polylineOptions = FALSE, circleOptions = FALSE,
        #   circleMarkerOptions = FALSE, markerOptions = FALSE
        # ) %>%
        addResetMapButton()
    })

    # Normalize input to a reactive sf
    sf_data <- reactive({
      if (shiny::is.reactive(metadata_sf)) metadata_sf() else metadata_sf
    })

    # Whenever data changes, (re)draw markers only
    observe({
      x <- sf_data()
      proxy <- leafletProxy("map", session = session) %>%
        clearGroup(group_name) %>%
        clearMarkers()

      if (is.null(x) || nrow(x) == 0) return(invisible())

      proxy <- proxy %>%
        addMarkers(
          data = x,
          clusterOptions = markerClusterOptions(),
          group = group_name,
          layerId = ~gbifID
        )

      # Fit bounds to current data
      bx <- sf::st_bbox(x)
      if (all(is.finite(bx))) {
        proxy %>% fitBounds(
          lng1 = unname(bx["xmin"]),
          lat1 = unname(bx["ymin"]),
          lng2 = unname(bx["xmax"]),
          lat2 = unname(bx["ymax"])
        )
      }
    })

    # Click handler
    click_id <- reactiveVal(NULL)
    observeEvent(input$map_marker_click, {
      click_id(input$map_marker_click$id)
    })

    list(click_id = click_id)
  })
}