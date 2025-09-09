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
      print(metadata)
      
      #vals <- metadata()
      
      locations_summary <- bslib::value_box(
        "A TOTAL OF",
        paste(vals$n, "sites"),
        paste("Across", vals$n_dest, "countries"),
        tags$p(paste("In", vals$n_carriers, "continent")),
        showcase = bsicons::bs_icon("globe2")
      )
      
      late <- if (vals$dep_delay > 0) "late" else "early"
      
      institutions_summary <- bslib::value_box(
        "RECORS FROM",  # (typo kept as in your code)
        paste(vals$dep_delay, "owner institutions"),
        paste("and", vals$dep_delay_perc, "collections"),
        showcase = bsicons::bs_icon("buildings")
      )
      
      late <- if (vals$arr_delay > 0) "late" else "early"
      
      specimens_summary <- bslib::value_box(
        "A TOTAL OF",
        paste(vals$arr_delay, "signatures"),
        paste("For", vals$arr_delay_perc, "species"),
        tags$p(paste("In", vals$n_carriers, "families")),
        showcase = bsicons::bs_icon("leaf")
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
