absolutePanel(id = "controls", 
              class = "panel panel-default", 
              fixed = TRUE,
              draggable = TRUE, 
              top = "80%", right = 20, left = "auto", bottom = "auto",
              width = 330, 
              p(""),
              p(""),
              actionButton(inputId = "clearS", label= "Clear selection", class = "btn-danger btn-block", icon = shiny::icon("redo")),
              p(""),
              downloadButton(outputId = "downloadData", label = "Download now", class = "btn-info btn-block", icon = shiny::icon("download")),
              #p(""),
              #actionButton(inputId = "buttonSH", label = "Show / hide feature info", class = "btn-info btn-block", icon = shiny::icon("eye-slash"))
              
),  #absolutePanel Download and clear