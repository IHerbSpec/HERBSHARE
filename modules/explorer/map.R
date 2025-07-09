################################################################################
### Leaflet map

map_ui <- function(id) {
  
  ns <- NS(id)
  
  leafletOutput(ns("map"), width = "100%", height = "100%")
  
}

map_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    
    output$map <- renderLeaflet({
      
      leaflet(options = leafletOptions(minZoom = 2)) %>%
        addTiles() %>%
        setMaxBounds(lng1 = -180, lat1 = -90, lng2 = 180, lat2 = 90)  %>%
        # addMarkers(data = sf_dat_unique, clusterOptions = markerClusterOptions(), group = "one", layerId = sf_dat_unique$id.layer_local_c) %>%
        addProviderTiles("Esri.WorldImagery", group = "Esri.WorldImagery") %>%
        addProviderTiles("OpenStreetMap.Mapnik", group = "OpenStreetMap.Mapnik") %>%
        addProviderTiles("Esri.WorldTopoMap", group = "Esri.WorldTopoMap") %>%
        addProviderTiles("Esri.WorldTerrain", group = "Esri.WorldTerrain") %>%
        addLayersControl(baseGroups = c("Esri.WorldImagery", "OpenStreetMap.Mapnik", "Esri.WorldTopoMap", "Esri.WorldTerrain")) %>%
        # addDrawToolbar(targetGroup = "x",
        #                polygonOptions = drawPolygonOptions(showArea = TRUE, shapeOptions=drawShapeOptions(fillColor = "yellow", color = "green", clickable = F)),
        #                rectangleOptions = drawRectangleOptions(showArea = TRUE, shapeOptions=drawShapeOptions(fillColor = "yellow", color = "green", clickable = F)),
        #                position = "topright", 
        #                polylineOptions = FALSE, 
        #                circleOptions = FALSE, 
        #                circleMarkerOptions = FALSE, 
        #                markerOptions = FALSE) %>% 
        addResetMapButton()
    })
    
  })
}