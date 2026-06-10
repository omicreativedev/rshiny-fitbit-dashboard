# Fitbit Dashboard Template - Layout Only
# STARS program

library(shiny)
library(shinydashboard)

# Source external colour palette
source("R/colours.R")

# ------------------------------------------------------------
# UI - links to external CSS
# ------------------------------------------------------------
ui <- fluidPage(
  title = "FitBit Research Dashboard",
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "custom.css")
  ),
  
  div(class = "top-bar",
      h3("Fitbit Research Dashboard"),
      p("Physiological & Psychological Effects of Discrimination - STARS Program & BU Labs")
  ),
  
  div(class = "date-filter",
      dateRangeInput("date_range", "Date Range",
                     start = Sys.Date() - 7,
                     end = Sys.Date(),
                     width = "280px")
  ),
  
  div(class = "main-container",
      tabsetPanel(
        tabPanel("Overview",
                 br(),
                 fluidRow(
                   column(3, div(class = "metric-card",
                                 p("AVG HEART RATE", class = "metric-label"),
                                 h2("—", class = "metric-value"),
                                 p("bpm", class = "metric-unit"))),
                   column(3, div(class = "metric-card",
                                 p("AVG DAILY STEPS", class = "metric-label"),
                                 h2("—", class = "metric-value"),
                                 p("steps", class = "metric-unit"))),
                   column(3, div(class = "metric-card",
                                 p("AVG DEEP SLEEP", class = "metric-label"),
                                 h2("—", class = "metric-value"),
                                 p("minutes", class = "metric-unit"))),
                   column(3, div(class = "metric-card",
                                 p("AVG SPO2", class = "metric-label"),
                                 h2("—", class = "metric-value"),
                                 p("%", class = "metric-unit")))
                 ),
                 br(),
                 fluidRow(
                   column(6, div(class = "chart-card",
                                 p("Heart Rate Over Time", class = "chart-title"),
                                 p(class = "placeholder-text", "Chart placeholder"))),
                   column(6, div(class = "chart-card",
                                 p("Daily Steps", class = "chart-title"),
                                 p(class = "placeholder-text", "Chart placeholder")))
                 ),
                 fluidRow(
                   column(12, div(class = "chart-card",
                                  p("Sleep Stage Breakdown", class = "chart-title"),
                                  p(class = "placeholder-text", "Chart placeholder")))
                 )
        ),
        tabPanel("Heart Rate", p("Heart Rate tab - add your charts")),
        tabPanel("Sleep", p("Sleep tab - add your charts")),
        tabPanel("Activity", p("Activity tab - add your charts"))
      )
  )
)

# ------------------------------------------------------------
# Server - minimal, no data
# ------------------------------------------------------------
server <- function(input, output, session) {
  # No data processing yet - just layout
  observe({
    req(input$date_range)
  })
}

shinyApp(ui = ui, server = server)