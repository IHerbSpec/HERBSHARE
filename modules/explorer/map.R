################################################################################
### Leaflet map

# uI
map_ui <- function(id) {
  
  ns <- NS(id)
  
  leafletOutput(ns("map"), width = "100%", height = "100%")
  
}

# Server
map_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    
    output$map <- renderLeaflet({
      
      leaflet(options = leafletOptions(minZoom = 2)) %>%
        addTiles() %>%
        setMaxBounds(lng1 = -180, lat1 = -90, lng2 = 180, lat2 = 90)  %>%
        addProviderTiles("Esri.WorldImagery", group = "Esri.WorldImagery") %>%
        addProviderTiles("OpenStreetMap.Mapnik", group = "OpenStreetMap.Mapnik") %>%
        addProviderTiles("Esri.WorldTopoMap", group = "Esri.WorldTopoMap") %>%
        addProviderTiles("Esri.WorldTerrain", group = "Esri.WorldTerrain") %>%
        addLayersControl(baseGroups = c("Esri.WorldImagery", "OpenStreetMap.Mapnik", "Esri.WorldTopoMap", "Esri.WorldTerrain")) %>%
        addResetMapButton()
    })
  })
}