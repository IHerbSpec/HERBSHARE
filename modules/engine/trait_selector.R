################################################################################
### Trait selector module

# Available traits (display name = value returned)
AVAILABLE_TRAITS <- c(
  "Leaf Mass per Area (LMA)" = "LMA",
  "Equivalent Water Thickness (EWT)" = "EWT",
  "Leaf Dry Matter Content (LDMC)" = "LDMC",
  "Carotenoids (Car)" = "Car",
  "Chlorophyll a (Chla)" = "Chla",
  "Chlorophyll b (Chlb)" = "Chlb",
  "Chlorophyll a+b (Chla+b)" = "Chla+b",
  "Hemicellulose" = "Hemicellulose",
  "Cellulose" = "Cellulose",
  "Lignin" = "Lignin",
  "Nitrogen (N)" = "N",
  "Carbon (C)" = "C"
)

# UI
trait_selector_ui <- function(id) {
  ns <- NS(id)

  tagList(
    tags$div(
      style = "margin-bottom: 0.5rem;",
      actionButton(
        ns("select_all"),
        "Select all",
        class = "btn-sm btn-outline-secondary",
        style = "margin-right: 0.5rem;"
      ),
      
      actionButton(
        ns("clear_all"),
        "Clear all",
        class = "btn-sm btn-outline-secondary"
      )
      
    ),

    checkboxGroupInput(
      ns("traits"),
      label = NULL,
      choices = AVAILABLE_TRAITS,
      selected = unname(AVAILABLE_TRAITS)
    ),

    actionButton(ns("predict_btn"),
                 "Predict traits",
                 icon = icon("brain"),
                 class = "btn-primary btn-block",
                 style = "margin-top: 1rem;"
                 )
  )
}

# Server
trait_selector_server <- function(id) {
  moduleServer(id, function(input, output, session) {

    # Trigger for prediction
    predict_trigger <- reactiveVal(0)

    # Select all traits
    observeEvent(input$select_all, {
      updateCheckboxGroupInput(session,
                               "traits",
                               selected = unname(AVAILABLE_TRAITS)
                               )
      })

    # Clear all traits
    observeEvent(input$clear_all, {
      updateCheckboxGroupInput(session,
                               "traits",
                               selected = character(0)
                               )
      })

    # Predict button
    observeEvent(input$predict_btn, {
      predict_trigger(predict_trigger() + 1)
    })

    # Return selected traits and trigger
    return(list(traits = reactive(input$traits),
                predict_trigger = predict_trigger
                )
           )

  })
}
