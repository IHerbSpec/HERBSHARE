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
    
    # Normalize: always work with a reactive data.table `md()`
    md <- reactive({
      if (shiny::is.reactive(metadata)) {
        data.table::as.data.table(metadata())
      } else {
        data.table::as.data.table(metadata)
      }
    })
    
    # Small safe helpers
    n_unique_safe <- function(x, col) {
      if (!col %in% names(x)) return(0L)
      length(unique(stats::na.omit(x[[col]])))
    }
    has_cols <- function(x, cols) all(cols %in% names(x))
    
    output$boxes <- renderUI({
      req(md())
      x <- md()
      
      # Locations
      sites <- if (has_cols(x, c("decimalLatitude", "decimalLongitude"))) {
        data.table::uniqueN(x, by = c("decimalLatitude", "decimalLongitude"))
      } else 0L
      countries <- n_unique_safe(x, "countryCode")
      continents <- n_unique_safe(x, "continent")
      
      locations_summary <- bslib::value_box(
        "FROM",
        paste(sites, "locations"),
        paste("Across", countries, "countries"),
        tags$p(paste("and", continents, ifelse(continents == 1, "continent", "continents"))),
        showcase = bsicons::bs_icon("globe2")
      )
      
      # Institutions
      institutions <- n_unique_safe(x, "institutionName")
      collections  <- n_unique_safe(x, "institutionCode")
      
      institutions_summary <- bslib::value_box("RECORDS FROM",
                                               paste(institutions, "owner institutions"),
                                               paste("and", collections, "collections"),
                                               showcase = bsicons::bs_icon("buildings"))
      
      # Totals
      measurements <- nrow(x)
      specimens    <- n_unique_safe(x, "gbifID")
      species      <- n_unique_safe(x, "species")
      
      specimens_summary <- bslib::value_box("A TOTAL OF",
                                            paste(measurements, "measurements"),
                                            paste("From", specimens, "specimens"),
                                            tags$p(paste("Across", species, ifelse(species == 1, "species", "species"))),
                                            showcase = bsicons::bs_icon("flower1"))
      
      bslib::layout_columns(class = "mb-0",
                            col_widths = c(12, 12, 12),
                            row_heights = c(2, 2, 2),
                            locations_summary,
                            institutions_summary,
                            specimens_summary)
    })
  })
}
