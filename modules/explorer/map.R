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
    
    output$map <- renderLeaflet({
      leaflet(options = leafletOptions(minZoom = 2)) %>%
        addTiles() %>%
        setMaxBounds(lng1 = -180, lat1 = -90, lng2 = 180, lat2 = 90) %>%
        addMarkers(
          data = metadata_sf,
          clusterOptions = markerClusterOptions(),
          group = "one",
          layerId = ~gbifID
        ) %>%
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
        addDrawToolbar(
          targetGroup = "x",
          polygonOptions   = drawPolygonOptions(showArea = TRUE, 
                                                shapeOptions = drawShapeOptions(fillColor = "#ffba08", 
                                                                                color = "#370617", 
                                                                                clickable = FALSE)),
          rectangleOptions = drawRectangleOptions(showArea = TRUE, 
                                                  shapeOptions = drawShapeOptions(fillColor = "#ffba08", 
                                                                                  color = "#370617", 
                                                                                  clickable = FALSE)),
          position = "topright",
          polylineOptions = FALSE, circleOptions = FALSE,
          circleMarkerOptions = FALSE, markerOptions = FALSE
        ) %>%
        addResetMapButton()
    })
    
    click_id <- reactive({
      req(input$map_marker_click)
      input$map_marker_click$id
    })
    
    list(click_id = click_id)
  })
}