################################################################################
### Select by (HERBSPHERE)

# UI
select_by_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    
    # Geospatial
    bslib::accordion_panel(
      title = "Geospatial",
      div(style = "height: 6px;"),
      selectizeInput(
        ns("countryCode"), "Country code",
        choices = NULL, multiple = TRUE,
        options = list(placeholder = "Any country", closeAfterSelect = TRUE)
      ),
      selectizeInput(
        ns("stateProvince"), "State/Province",
        choices = NULL, multiple = TRUE,
        options = list(placeholder = "Any state/province", closeAfterSelect = TRUE)
      )
    ),
    
    # Taxonomy
    bslib::accordion_panel(
      title = "Taxonomy",
      selectizeInput(ns("family"), "Family", choices = NULL, multiple = TRUE,
                     options = list(placeholder = "Any family", closeAfterSelect = TRUE)),
      selectizeInput(ns("genus"), "Genus", choices = NULL, multiple = TRUE,
                     options = list(placeholder = "Any genus", closeAfterSelect = TRUE)),
      selectizeInput(ns("species"), "Species", choices = NULL, multiple = TRUE,
                     options = list(placeholder = "Any species", closeAfterSelect = TRUE))
    ),
    
    # Institution 
    bslib::accordion_panel(
      title = "Institution",
      selectizeInput(ns("institutionName"), "Institution", choices = NULL, multiple = TRUE,
                     options = list(placeholder = "Any institution", closeAfterSelect = TRUE))
    ),
    
    # Footer: counts
    div(class = "mt-3",
        bslib::card(
          class = "shadow-sm",
          bslib::card_body(
            div(class = "d-flex justify-content-between align-items-center",
                div(
                  strong("Matching records: "),
                  textOutput(ns("n_matches"), inline = TRUE)
                ),
                actionButton(ns("clear_filters"), "Clear filters")
            )
          )
        )
    )
  )
}

# Server 
select_by_server <- function(id, metadata) {
  moduleServer(id, function(input, output, session) {
    
    # Reactive data.table
    dt <- reactive({
      base <- if(shiny::is.reactive(metadata)) metadata() else metadata
      data.table::as.data.table(base)
    })
    
    # Helpers
    u_  <- function(x) sort(unique(x[!is.na(x) & x != ""]))
    has <- function(nm) isTRUE(nm %in% names(dt()))
    
    # Initialize choices once
    observeEvent(dt(), {
      x <- dt()
      
      if(has("countryCode")) {
        updateSelectizeInput(session, "countryCode",
                             choices = u_(x$countryCode), server = TRUE)
      }
      
      if(has("stateProvince")) {
        updateSelectizeInput(session, "stateProvince",
                             choices = u_(x$stateProvince), server = TRUE)
      }
      
      if(has("family")) {
        updateSelectizeInput(session, "family",
                             choices = u_(x$family), server = TRUE)
      }
      
      if(has("genus")) {
        updateSelectizeInput(session, "genus",
                             choices = u_(x$genus), server = TRUE)
      }
      
      if(has("species")) {
        updateSelectizeInput(session, "species",
                             choices = u_(x$species), server = TRUE)
      }
      
      if(has("institutionName")) {
        updateSelectizeInput(session, "institutionName",
                             choices = u_(x$institutionName), server = TRUE)
      }
    }, ignoreInit = FALSE)
    
    # State filtered by countryCode
    observeEvent(list(dt(), input$countryCode), {
      if (!has("stateProvince")) return()
      x <- dt()
      sub <- if (has("countryCode") && length(input$countryCode))
        x[countryCode %in% input$countryCode] else x
      updateSelectizeInput(session, "stateProvince",
                           choices = u_(sub$stateProvince), server = TRUE)
    }, ignoreInit = TRUE)
    
    # Genus filtered by Family
    observeEvent(list(dt(), input$family), {
      if(!has("genus")) return()
      x <- dt()
      sub <- if (has("family") && length(input$family))
        x[family %in% input$family] else x
      updateSelectizeInput(session, "genus",
                           choices = u_(sub$genus), server = TRUE)
    }, ignoreInit = TRUE)
    
    # Species filtered by Family + Genus
    observeEvent(list(dt(), input$family, input$genus), {
      if(!has("species")) return()
      x <- dt()
      sub <- x
      if(has("family") && length(input$family)) sub <- sub[family %in% input$family]
      if(has("genus")  && length(input$genus))  sub <- sub[genus  %in% input$genus]
      updateSelectizeInput(session, "species",
                           choices = u_(sub$species), server = TRUE)
    }, ignoreInit = TRUE)
    
    # Clear filters
    observeEvent(input$clear_filters, {
      for (id in c("countryCode","stateProvince","family","genus","species","institutionName")) {
        if(!is.null(input[[id]])) updateSelectizeInput(session, id, selected = character())
      }
    }, ignoreInit = TRUE)
    
    # ---------- Filtering logic ----------
    data <- reactive({
      x <- data.table::copy(dt())
      
      # Geospatial (by codes + state)
      if(has("countryCode")   && length(input$countryCode))
        x <- x[countryCode %in% input$countryCode]
      if(has("stateProvince") && length(input$stateProvince))
        x <- x[stateProvince %in% input$stateProvince]
      
      # Taxonomy hierarchy
      if(has("family")  && length(input$family))  x <- x[family %in% input$family]
      if(has("genus")   && length(input$genus))   x <- x[genus  %in% input$genus]
      if(has("species") && length(input$species)) x <- x[species %in% input$species]
      
      # Institution
      if(has("institutionName") && length(input$institutionName))
        x <- x[institutionName %in% input$institutionName]
      
      x
    })
    
    # Matching records counter
    output$n_matches <- renderText({
      x <- data()
      if(is.null(x)) return("0")
      format(nrow(x), big.mark = ",")
    })
    
    list(data = data)
  })
}
