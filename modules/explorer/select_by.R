################################################################################
### Select by (HERBSHARE)

# UI
select_by_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    
    # Geospatial
    bslib::accordion_panel(
      title = "Geospatial",
      div(style = "height: 6px;"),
      
      # Countries
      selectizeInput(
        ns("countryCode"), "Country code",
        choices = NULL, multiple = TRUE,
        options = list(placeholder = "Any country", closeAfterSelect = TRUE)
      ),
      
      # State/Province
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
            # Matching records (top)
            div(class = "mb-2 d-flex align-items-baseline gap-2",
                span(class = "text-muted", "Spectral measurements:"),
                textOutput(ns("n_matches"), inline = TRUE)
            ),
            # Buttons (below, full width, stacked with a little gap)
            div(class = "d-grid gap-2",
                actionButton(ns("apply_selection"),
                             "Select",
                             icon = shiny::icon("check-circle"),
                             class = "btn btn-primary btn-lg"),
                actionButton(ns("show_all"),
                             "Clean selection",
                             icon = shiny::icon("broom"),
                             class = "btn btn-outline-secondary")
            )
          )
        )
    )
  )
}

# Server 
select_by_server <- function(id, metadata, geom_filter = NULL) {
  moduleServer(id, function(input, output, session) {
    
    # Normalize dataset to reactive data.table
    dt <- reactive({
      base <- if (shiny::is.reactive(metadata)) metadata() else metadata
      data.table::as.data.table(base)
    })
    
    # Helpers
    u_ <- function(x) sort(unique(x[!is.na(x) & x != ""]))
    has <- function(nm) isTRUE(nm %in% names(dt()))
    
    # Initialize choices once
    observeEvent(dt(), {
      x <- dt()
      if(has("countryCode")) updateSelectizeInput(session, "countryCode", choices = u_(x$countryCode), server = TRUE)
      if(has("stateProvince")) updateSelectizeInput(session, "stateProvince", choices = u_(x$stateProvince), server = TRUE)
      if(has("family")) updateSelectizeInput(session, "family", choices = u_(x$family), server = TRUE)
      if(has("genus")) updateSelectizeInput(session, "genus", choices = u_(x$genus), server = TRUE)
      if(has("species")) updateSelectizeInput(session, "species", choices = u_(x$species), server = TRUE)
      if(has("institutionName")) updateSelectizeInput(session, "institutionName", choices = u_(x$institutionName), server = TRUE)
    }, ignoreInit = FALSE)
    
    # Dependent choice updates
    observeEvent(list(dt(), input$countryCode), {
      if (!has("stateProvince")) return()
      x <- dt()
      sub <- if (has("countryCode") && length(input$countryCode)) x[countryCode %in% input$countryCode] else x
      updateSelectizeInput(session, "stateProvince", choices = u_(sub$stateProvince), server = TRUE)
    }, ignoreInit = TRUE)
    
    observeEvent(list(dt(), input$family), {
      if (!has("genus")) return()
      x <- dt()
      sub <- if(has("family") && length(input$family)) x[family %in% input$family] else x
      updateSelectizeInput(session, "genus", choices = u_(sub$genus), server = TRUE)
    }, ignoreInit = TRUE)
    
    observeEvent(list(dt(), input$family, input$genus), {
      if(!has("species")) return()
      x <- dt()
      sub <- x
      if(has("family") && length(input$family)) sub <- sub[family %in% input$family]
      if(has("genus") && length(input$genus)) sub <- sub[genus %in% input$genus]
      updateSelectizeInput(session, "species", choices = u_(sub$species), server = TRUE)
    }, ignoreInit = TRUE)
    
    # Filtering logic: INCLUDES geometry filter for "Matching records"
    data <- reactive({
      x <- data.table::copy(dt())
      
      # Apply attribute filters first
      if(has("countryCode") && length(input$countryCode)) x <- x[countryCode %in% input$countryCode]
      if(has("stateProvince") && length(input$stateProvince)) x <- x[stateProvince %in% input$stateProvince]
      if(has("family") && length(input$family)) x <- x[family %in% input$family]
      if(has("genus") && length(input$genus)) x <- x[genus %in% input$genus]
      if(has("species") && length(input$species)) x <- x[species %in% input$species]
      if(has("institutionName") && length(input$institutionName)) x <- x[institutionName %in% input$institutionName]
      
      # Apply spatial filter if geometry exists
      if (!is.null(geom_filter)) {
        geom <- if (shiny::is.reactive(geom_filter)) geom_filter() else geom_filter
        
        if (!is.null(geom) && length(geom) > 0 &&
            has("decimalLongitude") && has("decimalLatitude") &&
            nrow(x) > 0) {
          
          pts <- sf::st_as_sf(x, coords = c("decimalLongitude", "decimalLatitude"),
                              crs = 4326, remove = FALSE)
          sf::st_agr(pts) <- "constant"
          
          idx <- sf::st_intersects(pts, geom, sparse = TRUE)
          keep <- lengths(idx) > 0L
          x <- x[keep]
        }
      }
      x
    })
    
    # Counter for "Matching records"
    output$n_matches <- renderText({
      x <- data()
      if (is.null(x)) return("0")
      format(nrow(x), big.mark = ",")
    })
    
    # Clear all filters when "Show all" is pressed
    observeEvent(input$show_all, {
      for (id in c("countryCode","stateProvince","family","genus","species","institutionName")) {
        if (!is.null(input[[id]])) updateSelectizeInput(session, id, selected = character())
      }
      x <- dt()
      if (has("stateProvince")) updateSelectizeInput(session, "stateProvince", choices = u_(x$stateProvince), server = TRUE)
      if (has("genus")) updateSelectizeInput(session, "genus", choices = u_(x$genus), server = TRUE)
      if (has("species")) updateSelectizeInput(session, "species", choices = u_(x$species), server = TRUE)
    }, ignoreInit = TRUE)
    
    # Expose button events (no longer exposing draw buttons)
    list(data = data,
         apply = reactive(input$apply_selection),
         show_all = reactive(input$show_all))
  })
}