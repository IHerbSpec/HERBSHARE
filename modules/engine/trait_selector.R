################################################################################
### Trait selector module

# Available traits
AVAILABLE_TRAITS <- c(
  "LMA" = "Leaf Mass per Area (LMA)",
  "EWT" = "Equivalent Water Thickness (EWT)",
  "LDMC" = "Leaf Dry Matter Content (LDMC)",
  "Car" = "Carotenoids (Car)",
  "Chla" = "Chlorophyll a (Chla)",
  "Chlb" = "Chlorophyll b (Chlb)",
  "Chla+b" = "Chlorophyll a+b (Chla+b)",
  "Hemicellulose" = "Hemicellulose",
  "Cellulose" = "Cellulose",
  "Lignin" = "Lignin",
  "N" = "Nitrogen (N)",
  "C" = "Carbon (C)"
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
      selected = names(AVAILABLE_TRAITS)
    )
  )
}

# Server
trait_selector_server <- function(id) {
  moduleServer(id, function(input, output, session) {

    # Select all traits
    observeEvent(input$select_all, {
      updateCheckboxGroupInput(session,
                               "traits",
                               selected = names(AVAILABLE_TRAITS)
                               )
      })

    # Clear all traits
    observeEvent(input$clear_all, {
      updateCheckboxGroupInput(session,
                               "traits",
                               selected = character(0)
                               )
      })

    # Return selected traits
    return(reactive(input$traits))
    
  })
}
