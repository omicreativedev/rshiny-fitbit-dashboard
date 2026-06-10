# Fitbit Dashboard Template – No charts included
# STARS program

library(shiny)
library(tidyverse)
library(lubridate)
library(jsonlite)
library(scales)
library(DT)
library(plotly)

# Source external colour palette
source("R/colours.R")

# Set this to the path of your own Google Health export folder
JSON_FOLDER <- ""

# ------------------------------------------------------------
# Data loading functions
# ------------------------------------------------------------
load_hr <- function(folder) {
  files <- list.files(folder, pattern = "^heart_rate-.*\\.json", full.names = TRUE)
  if (length(files) == 0) return(NULL)
  map_dfr(files, function(f) {
    raw <- fromJSON(f)
    data.frame(
      datetime = mdy_hms(raw$dateTime),
      hr_val = raw$value$bpm,
      confidence = raw$value$confidence
    )
  })
}

load_steps <- function(folder) {
  files <- list.files(folder, pattern = "^steps-.*\\.json", full.names = TRUE)
  if (length(files) == 0) return(NULL)
  map_dfr(files, function(f) {
    raw <- fromJSON(f)
    data.frame(
      datetime = mdy_hms(raw$dateTime),
      steps_val = as.numeric(raw$value)
    )
  })
}

load_sleep <- function(folder) {
  files <- list.files(folder, pattern = "^sleep-.*\\.json", full.names = TRUE)
  if (length(files) == 0) return(NULL)
  map_dfr(files, function(f) {
    raw <- fromJSON(f)
    data.frame(
      date_only = as.Date(raw$dateOfSleep),
      deep_val = raw$levels$summary$deep$minutes,
      light_val = raw$levels$summary$light$minutes,
      rem_val = raw$levels$summary$rem$minutes,
      wake_val = raw$levels$summary$wake$minutes,
      efficiency = raw$efficiency
    )
  })
}

hr_data <- load_hr(JSON_FOLDER)
steps_data <- load_steps(JSON_FOLDER)
sleep_data <- load_sleep(JSON_FOLDER)

# ------------------------------------------------------------
# UI – links to external CSS, no inline styles
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
                     start = as.Date("2026-05-28"),
                     end = as.Date("2026-06-01"),
                     width = "280px")
  ),
  
  div(class = "main-container",
      tabsetPanel(
        tabPanel("Overview",
                 br(),
                 fluidRow(
                   column(3, div(class = "metric-card",
                                 p("AVG HEART RATE", class = "metric-label"),
                                 h2(textOutput("card_hr"), class = "metric-value"),
                                 p("bpm", class = "metric-unit"))),
                   column(3, div(class = "metric-card",
                                 p("AVG DAILY STEPS", class = "metric-label"),
                                 h2(textOutput("card_steps"), class = "metric-value"),
                                 p("steps", class = "metric-unit"))),
                   column(3, div(class = "metric-card",
                                 p("AVG DEEP SLEEP", class = "metric-label"),
                                 h2(textOutput("card_sleep"), class = "metric-value"),
                                 p("minutes", class = "metric-unit"))),
                   column(3, div(class = "metric-card",
                                 p("AVG SPO2", class = "metric-label"),
                                 h2(textOutput("card_spo2"), class = "metric-value"),
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
        tabPanel("Heart Rate", p("Heart Rate tab – add your charts")),
        tabPanel("Sleep", p("Sleep tab – add your charts")),
        tabPanel("Activity", p("Activity tab – add your charts"))
      )
  )
)

# ------------------------------------------------------------
# Server
# ------------------------------------------------------------
server <- function(input, output, session) {
  
  filtered_hr <- reactive({
    req(input$date_range)
    hr_data %>%
      mutate(date_only = as.Date(datetime)) %>%
      filter(date_only >= input$date_range[1], date_only <= input$date_range[2])
  })
  
  filtered_steps <- reactive({
    req(input$date_range)
    steps_data %>%
      mutate(date_only = as.Date(datetime)) %>%
      filter(date_only >= input$date_range[1], date_only <= input$date_range[2])
  })
  
  filtered_sleep <- reactive({
    req(input$date_range)
    sleep_data %>%
      filter(date_only >= input$date_range[1], date_only <= input$date_range[2])
  })
  
  output$card_hr <- renderText({
    d <- filtered_hr() %>% filter(!is.na(hr_val), hr_val > 30)
    if (nrow(d) == 0) return("—")
    paste(round(mean(d$hr_val)))
  })
  
  output$card_steps <- renderText({
    d <- filtered_steps() %>% filter(!is.na(steps_val))
    if (nrow(d) == 0) return("—")
    daily <- d %>% group_by(date_only) %>% summarise(total = sum(steps_val))
    format(round(mean(daily$total)), big.mark = ",")
  })
  
  output$card_sleep <- renderText({
    d <- filtered_sleep() %>% filter(!is.na(deep_val))
    if (nrow(d) == 0) return("—")
    paste(round(mean(d$deep_val)))
  })
  
  output$card_spo2 <- renderText("—")
}

shinyApp(ui = ui, server = server)