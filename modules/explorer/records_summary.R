################################################################################
### Summary record module

# UI
summary_records_ui <- function(id) {
  
  ns <- NS(id)
  
  uiOutput(ns("boxes"))

}

# Server
summary_records_server <- function(id, metadata) {
  moduleServer(id, function(input, output, session) {
    
    output$boxes <- renderUI({
      
      req(metadata)

      #vals <- metadata()
      
      #sites <- nrow(unique(metadata[c("latitude", "longitude")]))
      
      #sites <- uniqueN(metadata, by = c("latitude", "longitude"))
      countries <- length(unique(metadata$countryCode))
      continent <- length(unique(metadata$continent))
      
      sites <- 999
      countries <- 999
      continent <- 999
      
      locations_summary <- bslib::value_box(
        "FROM",
        paste(sites, "sites"),
        paste("Across", countries, "countries"),
        tags$p(paste("and", continent, "continent")),
        showcase = bsicons::bs_icon("globe2")
      )
      
      institutions <- length(unique(metadata$institutionName))
      collections <- length(unique(metadata$institutionCode))
      
      institutions_summary <- bslib::value_box(
        "RECORS FROM",  # (typo kept as in your code)
        paste(institutions, "owner institutions"),
        paste("and", collections, "collections"),
        showcase = bsicons::bs_icon("buildings")
      )
      
      measurements <- nrow(metadata)
      specimens <- length(unique(metadata$gbifID))
      species <- length(unique(metadata$species))
      
      specimens_summary <- bslib::value_box(
        "A TOTAL OF",
        paste(measurements, "measurements"),
        paste("From", specimens, "specimens"),
        tags$p(paste("Across", species, "species")),
        showcase = bsicons::bs_icon("flower1") #leaf 
      )
      
      # In a narrow sidebar we usually want them stacked 1 per row
      bslib::layout_columns(
        class = "mb-0",
        col_widths = c(12, 12, 12),
        locations_summary,
        institutions_summary,
        specimens_summary
      )
    })
  })
}
