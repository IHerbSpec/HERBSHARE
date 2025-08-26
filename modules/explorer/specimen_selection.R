################################################################################
### Specimen selection features

# UI
specimen_selection_ui <- function(id) {
  
  ns <- NS(id)

  absolutePanel(
    id = ns("controls_specimen_selection"),
    class = "panel panel-default",
    fixed = TRUE, 
    draggable = TRUE, 
    width = 400,
    top = "20%", left = "auto", right = "5%", bottom = "auto",
    #style = "z-index: 1000; background: #fff; padding: 10px;",
    p(""),
    bsCollapse(
      id = ns("collapse"),
      #open = "Specimen properties",
      bsCollapsePanel(
        title = "Specimen information",
        #value = "Specimen properties",
        style = "success",
        tableOutput(ns("specimen_table"))
      ),
      bsCollapsePanel(
        title = "Spectra profile",
        #value = "Specimen properties",
        style = "success"
        #tableOutput(ns("specimen_table"))
      )
    )
    
  )
}

# Server
specimen_selection_server <- function(id, click_id, metadata_sf, points_sf) {
  moduleServer(id, function(input, output, session) {
    
    shinyjs::hide(id = session$ns("controls_specimen_selection"))
    
    observeEvent(click_id(), {
      shinyjs::show(id = session$ns("controls_specimen_selection"))
    }, ignoreInit = TRUE)
    
    clicked_points <- reactive({
      req(click_id())
      dplyr::filter(metadata_sf, gbifID %in% click_id())
    })

    output$specimen_table <- renderTable({
      
      rows <- clicked_points()
      req(nrow(rows) > 0)
      
      row <- rows %>% dplyr::slice(1)
      row %>% 
        sf::st_drop_geometry() %>%
        dplyr::select(gbifID, institutionName, collectionCode,
          class, order, family, genus, species)
      
      data.frame(
        Name  = c("gbifID", 
                  "institutionName", 
                  "collectionCode", 
                  "class", 
                  "order", 
                  "family", 
                  "genus", 
                  "species"),
        Value = c(as.character(row$gbifID[[1]]),
                  row$institutionName[[1]],
                  row$collectionCode[[1]],
                  row$class[[1]],
                  row$order[[1]],
                  row$family[[1]],
                  row$genus[[1]],
                  row$species[[1]]),
        stringsAsFactors = FALSE
      )
      
    }, striped = TRUE, bordered = TRUE, rownames = FALSE)
  })
    
    # # Show shinyjs and namespaced ids
    # observeEvent(click_id(), {
    #   shinyjs::show(id = session$ns("controls_specimen_selection"))
    # }, ignoreInit = TRUE)
    # 
    # # Compute the clicked set when click_id changes
    # clicked_points <- reactive({
    #   req(click_id())
    #   point_click <- dplyr::filter(metadata_sf, gbifID %in% click_id())
    #   req(nrow(point_click) > 0)
    # 
    #   pts <- points_sf()                 # sf POINT collection
    #   req(NROW(pts) > 0)
    # 
    #   ids <- sf::st_intersects(point_click, pts, sparse = TRUE)[[1]]
    #   req(length(ids) > 0)
    #   pts[ids, ]
    # })
    # 
    # # Update the picker
    # observeEvent(clicked_points(), {
    #   choices <- unique(clicked_points()$gbifID)
    #   updateSelectInput(
    #     session, "specimen_selection",
    #     label   = NULL,
    #     choices = choices,
    #     selected = if (length(choices)) choices[1] else character(0)
    #   )
    # }, ignoreInit = TRUE)
    # 
    # # Render the table
    # output$specimen_table <- renderTable({
    #   req(input$specimen_selection)
    #   row <- dplyr::filter(clicked_points(), gbifID == input$specimen_selection)
    #   validate(need(nrow(row) > 0, "No data for selection"))
    #   data.frame(
    #     Name  = c("gbifID", "lon", "lat"),
    #     Value = c(row$gbifID[1], sf::st_coordinates(row)[1,1], sf::st_coordinates(row)[1,2])
    #   )
    # })
    
    # clicked_points <- reactive({
    #   click <- input$map_marker_click$id
    #   if(is.null(click)){return()}
    #   point_click <- metadata_sf %>% filter(gbifID %in% click)
    #   if(nrow(point_click) == 0){return()}
    #   all_selected_points <- data_all()$points
    #   ids = st_intersects(point_click, all_selected_points, sparse = T)[[1]]
    #   points_clicked = all_selected_points[ids, ]
    #   points_clicked
    # })
     
    # output$point_table <- reactive({
    #   
    #   point_id <- input$pointselection
    #   point_click <- clicked_points()[clicked_points()$id.layer_local_c == point_id, ]
    #   df_f <- data.frame(Name = c("ID: ", "Soil texture: ", "Upper depth [cm]: ", "Lower depth [cm]: ",  "Address: "),
    #                      Values = c(point_click$id.layer_local_c[1],
    #                                 point_click$layer.texture_usda_c[1],
    #                                 point_click$layer.upper.depth_usda_cm[1],
    #                                 point_click$layer.lower.depth_usda_cm[1],
    #                                 point_click$location.address_utf8_txt[1]))
    #   
    #   df_f %>%
    #     kable(caption = "Attributes: ", digits = 4, align = "c", col.names = NULL) %>%
    #     kable_styling(bootstrap_options = c("striped", "hover", "condensed", "responsive"), full_width = TRUE)
    #   
    # })
    # 
    # spectra <- reactive({
    #   point_id <- input$selectPointInfo
    #   
    #   visnir.data %>%
    #     select(c(-1:-3, -5:-16)) %>%
    #     filter(visnir.data$id.layer_local_c %in% point_id) %>%
    #     select(c(-1)) %>%
    #     arrange()
    # })
    # 
    # output$pl.vis <- renderPlotly({
    #   aaa <- visnir()
    #   y <- unlist(aaa[, -1])
    #   x <- readr::parse_number(gsub(".*scan_visnir.(.*)\\_pcnt.*", "\\1", names(y)))#/1000
    #   #color <- rep(as.character(aaa[, 1]), ncol(aaa[, -1]))
    #   df <- data.frame(
    #     x = x,
    #     y = y#,
    #     #cut = color
    #   )
    #   
    #   # ggplot(data = df, aes(x = x, y = y)) +
    #   #   geom_line(colour = "blue") +
    #   #   labs(x = 'Wavelength [nm]', y = "Absorbance") +
    #   #   theme_minimal()+
    #   #   theme(legend.position = 'none')
    #   shiny::validate(
    #     shiny::need(nrow(df) > 0, "Non-existent VISNIR data for the selected location!")
    #   )
    #   plot_ly(df, x = ~x, y = ~y, line = list(color = 'rgb(22, 96, 167)')) %>%
    #     add_lines() %>%
    #     layout(xaxis = list(title = 'Wavelength [nm]'),
    #            yaxis = list(title = 'Reflectance [%]'))  %>%
    #     layout(autosize = TRUE, margin = list(
    #       l = 0, r = 0, b = 0, t = 0, pad = 0
    #     ))
    #   
    #   
    # })

}