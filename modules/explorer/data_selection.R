################################################################################
### Data selection panel

# uI
dataSelection_ui <- function(id) {
  
  ns <- NS(id)

  absolutePanel(
    id = "controls", 
    class = "panel panel-default", 
    fixed = TRUE,
    draggable = TRUE, 
    top = 300, left = 60, right = "auto", bottom = "auto",
    width = 330, height = "auto",
    h4("Data selection"),
    #actionButton("openTweet",label = "", icon = shiny::icon("twitter"),
    #              style = "background-color: rgba(255, 255, 255, 0.5); color:black; border:rgba(255, 255, 255, 0.5); float:right;"),
    # actionButton("openLand",label = "", icon = shiny::icon("info-circle"),
    #              style = "background-color: rgba(255, 255, 255, 0.5); color:black; border:rgba(255, 255, 255, 0.5); float:right;")),
    p(""),
    bsCollapse(id = "collapseExample",
               bsCollapsePanel("Geospatial",
                               p(""),
                               actionButton(inputId = "draw_poly", label= "Draw", class = "btn-info shiny-bound-input", icon = shiny::icon("draw-polygon")),
                               actionButton(inputId = "draw_rectangle", label= "Draw", class = "btn-info shiny-bound-input", icon = shiny::icon("square")),
                               actionButton(inputId = "del_poly", label= "Clear", class = "btn-info shiny-bound-input", icon = shiny::icon("eraser")),
                               hr(),
                               selectizeInput(
                                 inputId = 'nation',
                                 label = "Nation: ",
                                 choices = factor(sp_bounds_0$NAME_0), 
                                 multiple = F,
                                 options = list(
                                   placeholder = 'Please select a Nation',
                                   onInitialize = I('function() { this.setValue(""); }')
                                 )),
                               uiOutput("state.dynamicui"),
                               style = "success"),
               bsCollapsePanel("Attributes",
                               selectizeInput(
                                 inputId = 'soil_order',
                                 label = "Soil texture: ",
                                 choices = unique(soilsite.data$layer.texture_usda_c),
                                 multiple = T,
                                 options = list(
                                   placeholder = 'Please select a Soil texture',
                                   onInitialize = I('function() { this.setValue(""); }')
                                 )),
                               numericRangeInput(
                                 inputId = "depth_range",
                                 label = "Depth range [cm]: ",
                                 value = c(min(soilsite.data$layer.lower.depth_usda_cm, na.rm = T), max(soilsite.data$layer.lower.depth_usda_cm, na.rm = T)), # c(0, 1783), #soilsite.data$layer.lower.depth_usda_cm,
                                 separator = " to "
                               ),
                               style = "success"),
               bsCollapsePanel("Dataset",
                               
                               selectizeInput(
                                 inputId = 'library_site',
                                 label = "Source dataset: ",
                                 choices = unique(soilsite.data$dataset.title_utf8_txt), #dataset.code_ascii_c
                                 multiple = T,
                                 options = list(
                                   placeholder = 'Please select a Source dataset',
                                   onInitialize = I('function() { this.setValue(""); }')
                                 )),
                               style = "success")
    ), # bsCollapse
    #p(""),
    #actionButton(inputId = "jumpToSoil", label= "Soil properties", class = "btn-info btn-block", icon = shiny::icon("arrow-circle-right")),
    #verbatimTextOutput("id1"),verbatimTextOutput("id2"),verbatimTextOutput("id3"),verbatimTextOutput("id4")
  )
  
}

# Server
dataSelection_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    
    observe({
      updateSelectizeInput(
        session = session,
        inputId = 'soil_order',
        label = "Soil texture: ",
        choices = unique(data_sp_sel()$points$layer.texture_usda_c),
        options = list(
          placeholder = 'Please select a Soil texture',
          onInitialize = I('function() { this.setValue(""); }')
        ))
    })
    
    
    observe({
      updateSelectizeInput(
        session = session,
        inputId = 'library_site',
        label = "Source dataset: ",
        choices = unique(data_sp_sel()$points$dataset.title_utf8_txt),
        options = list(
          placeholder = 'Please select a Source dataset',
          onInitialize = I('function() { this.setValue(""); }')
        ))
    })
    
    # soil depth
    if(!is.null(input$depth_range[1])){ # range_values$range_min
      sf.points.int %<>%
        dplyr::filter(layer.upper.depth_usda_cm >=  input$depth_range[1]) # range_values$range_min
    }
    
    if(!is.null(input$depth_range[2])){ # range_values$range_max
      sf.points.int %<>%
        dplyr::filter(layer.lower.depth_usda_cm <= input$depth_range[2]) # range_values$range_max)
    }
    
    
  })
}

