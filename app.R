# Fitbit Dashboard with Authentication
# STARS Program - Physiological & Psychological Effects of Discrimination
# Boston University Labs

# Load required libraries
library(shiny)           # Web application framework
library(shinyjs)         # For showing/hiding UI elements
library(tidyverse)       # Data manipulation (dplyr, ggplot2, etc.)
library(lubridate)       # Date/time handling
library(plotly)          # Interactive charts
library(DT)              # Interactive data tables

# Source external colour palette (used across all charts)
source("R/colours.R")

# ------------------------------------------------------------
# HELPER FUNCTIONS
# ------------------------------------------------------------

#' Load all CSV files from the csvdata folder
load_all_data <- function() {
  csv_files <- list.files("csvdata", pattern = "\\.csv$", full.names = TRUE)
  names(csv_files) <- gsub("\\.csv$", "", basename(csv_files))
  
  data_list <- list()
  for (file_name in names(csv_files)) {
    data_list[[file_name]] <- read.csv(csv_files[[file_name]], stringsAsFactors = FALSE)
  }
  return(data_list)
}

#' Get all unique participant IDs from the data
get_all_participants <- function(data_list) {
  participants <- c()
  for (df in data_list) {
    if ("participantID" %in% names(df)) {
      participants <- c(participants, unique(df$participantID))
    }
  }
  return(sort(unique(participants)))
}

#' Check if a user is an admin
is_admin_user <- function(participant_id, roles_df) {
  if (is.null(roles_df) || nrow(roles_df) == 0) return(FALSE)
  admin_check <- roles_df[roles_df$participantID == participant_id, "is_admin"]
  return(length(admin_check) > 0 && admin_check == TRUE)
}

#' Load the roles configuration file
load_roles <- function() {
  if (file.exists("roles.csv")) {
    return(read.csv("roles.csv", stringsAsFactors = FALSE))
  } else {
    return(data.frame(participantID = character(), is_admin = logical()))
  }
}

#' Create a datetime column from date and time columns
add_datetime_column <- function(df) {
  if (!is.null(df) && nrow(df) > 0 && "date" %in% names(df) && "time" %in% names(df)) {
    # Extract just the time part (HH:MM:SS) from whatever format
    df <- df %>%
      mutate(
        # Extract time part using regex (HH:MM:SS at end of string)
        time_clean = str_extract(time, "\\d{2}:\\d{2}:\\d{2}"),
        # Create datetime by combining date and clean time
        datetime = as.POSIXct(paste(date, time_clean), format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
      ) %>%
      select(-time_clean)
  }
  return(df)
}

#' Shared ggplot theme for all charts
dash_theme <- function() {
  theme_minimal() +
    theme(
      panel.grid.major = element_line(color = "#F3F4F6"),
      panel.grid.minor = element_blank(),
      axis.text = element_text(size = 10, color = "#6B7280"),
      axis.title = element_text(size = 11, color = "#6B7280"),
      legend.position = "bottom",
      legend.text = element_text(size = 10, color = "#6B7280"),
      legend.title = element_blank()
    )
}

# Helper function for empty plot placeholders
create_empty_plot <- function(message) {
  plotly_empty() %>%
    layout(annotations = list(text = message, showarrow = FALSE, font = list(size = 12)))
}

# ------------------------------------------------------------
# USER INTERFACE (UI)
# ------------------------------------------------------------

ui <- fluidPage(
  title = "FitBit Research Dashboard",
  useShinyjs(),
  
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "custom.css")
  ),
  
  # ==================== TOP BAR ====================
  div(class = "top-bar",
      h3("Fitbit Research Dashboard"),
      p("Physiological & Psychological Effects of Discrimination - STARS Program & BU Labs")
  ),
  
  # ==================== LOGIN SECTION ====================
  div(class = "login-section",
      # Login form - inline (text box + button side by side)
      div(class = "login-form",
          textInput("participant_id", NULL, 
                    placeholder = "Enter your Participant ID",
                    width = "220px"),
          actionButton("login_btn", "Login", class = "btn-primary")
      ),
      # Login status display
      div(class = "user-info", textOutput("login_status"))
  ),
  
  # ==================== MAIN APP (hidden until login) ====================
  div(id = "main_app", style = "display: none;",
      
      # Filters row - Date Range and Admin Selector side by side
      div(class = "filters-row",
          dateRangeInput("date_range", "Date Range",
                         start = Sys.Date() - 7,
                         end = Sys.Date(),
                         width = "280px"),
          # Admin-only participant selector (hidden by default)
          div(id = "admin_selector_container", class = "admin-selector", style = "display: none;",
              selectInput("admin_participant", "View Participant:",
                          choices = c("All Participants" = "ALL"),
                          width = "220px"))
      ),
      
      # ==================== MAIN CONTENT ====================
      div(class = "main-container",
          uiOutput("dynamic_tabs")
      )
  )
)

# ------------------------------------------------------------
# SERVER LOGIC
# ------------------------------------------------------------

server <- function(input, output, session) {
  
  # ==================== REACTIVE VALUES ====================
  
  auth <- reactiveValues(
    logged_in = FALSE,
    participant_id = NULL,
    is_admin = FALSE,
    selected_participant = NULL
  )
  
  # ==================== DATA LOADING ====================
  
  all_data <- reactive({
    load_all_data()
  })
  
  roles_df <- reactive({
    load_roles()
  })
  
  all_participants <- reactive({
    data <- all_data()
    get_all_participants(data)
  })
  
  # Update admin dropdown when data loads
  observe({
    participants <- all_participants()
    if (length(participants) > 0) {
      updateSelectInput(session, "admin_participant",
                        choices = c("All Participants" = "ALL", participants))
    }
  })
  
  # ==================== LOGIN HANDLER ====================
  
  observeEvent(input$login_btn, {
    participant_id <- trimws(input$participant_id)
    
    if (participant_id == "") {
      showNotification("Please enter a Participant ID", type = "error")
      return()
    }
    
    roles <- roles_df()
    is_admin <- is_admin_user(participant_id, roles)
    
    if (!is_admin) {
      participants_list <- all_participants()
      if (!(participant_id %in% participants_list)) {
        showNotification("Participant ID not found. Please check and try again.", 
                         type = "error")
        return()
      }
    }
    
    auth$logged_in <- TRUE
    auth$participant_id <- participant_id
    auth$is_admin <- is_admin
    auth$selected_participant <- participant_id
    
    shinyjs::show("main_app")
    
    if (is_admin) {
      shinyjs::show("admin_selector_container")
    }
    
    output$login_status <- renderText({
      if (is_admin) {
        paste("Logged in as:", participant_id, "(Admin)")
      } else {
        paste("Logged in as:", participant_id)
      }
    })
  })
  
  # ==================== PARTICIPANT FILTERING ====================
  
  current_participant <- reactive({
    if (!auth$logged_in) return(NULL)
    
    if (auth$is_admin) {
      req(input$admin_participant)
      if (input$admin_participant == "ALL") {
        return(NULL)
      } else {
        return(input$admin_participant)
      }
    } else {
      return(auth$participant_id)
    }
  })
  
  filtered_data <- reactive({
    req(auth$logged_in)
    
    data <- all_data()
    participant <- current_participant()
    date_range <- input$date_range
    
    if (!is.null(participant)) {
      data <- lapply(data, function(df) {
        if ("participantID" %in% names(df)) {
          df <- df[df$participantID == participant, ]
        }
        return(df)
      })
    }
    
    if (!is.null(date_range)) {
      data <- lapply(data, function(df) {
        if ("date" %in% names(df)) {
          df$date <- as.Date(df$date)
          df <- df[df$date >= date_range[1] & df$date <= date_range[2], ]
        }
        return(df)
      })
    }
    
    return(data)
  })
  
  # ==================== EXTRACT SPECIFIC DATAFRAMES ====================
  
  hr_data <- reactive({
    df <- filtered_data()[["hr_intraday_5m"]]
    add_datetime_column(df)
  })
  
  steps_data <- reactive({
    df <- filtered_data()[["steps_intraday_5m"]]
    add_datetime_column(df)
  })
  
  sleep_data <- reactive({
    filtered_data()[["sleep_minute"]]
  })
  
  daily_metrics <- reactive({
    filtered_data()[["daily_metrics"]]
  })
  
  hrv_data <- reactive({
    df <- filtered_data()[["hrv_intraday"]]
    if (!is.null(df) && nrow(df) > 0 && "timestamp" %in% names(df)) {
      df$datetime <- as.POSIXct(df$timestamp, format = "%Y-%m-%dT%H:%M:%SZ")
    }
    df
  })
  
  activity_level_data <- reactive({
    df <- filtered_data()[["activity_level_intraday"]]
    add_datetime_column(df)
  })
  
  zone_minutes_data <- reactive({
    df <- filtered_data()[["zone_minutes_intraday_5m"]]
    add_datetime_column(df)
  })
  
  activity_sessions_data <- reactive({
    df <- filtered_data()[["activity_sessions"]]
    if (!is.null(df) && nrow(df) > 0 && "start_time" %in% names(df)) {
      df$start_datetime <- as.POSIXct(df$start_time, format = "%Y-%m-%dT%H:%M:%SZ")
      df$end_datetime <- as.POSIXct(df$end_time, format = "%Y-%m-%dT%H:%M:%SZ")
    }
    df
  })
  
  sedentary_data <- reactive({
    df <- filtered_data()[["sedentary_periods"]]
    if (!is.null(df) && nrow(df) > 0 && "period_start" %in% names(df)) {
      df$start_datetime <- as.POSIXct(df$period_start, format = "%Y-%m-%dT%H:%M:%SZ")
      df$end_datetime <- as.POSIXct(df$period_end, format = "%Y-%m-%dT%H:%M:%SZ")
    }
    df
  })
  
  spo2_data <- reactive({
    df <- filtered_data()[["spo2_intraday"]]
    if (!is.null(df) && nrow(df) > 0 && "timestamp" %in% names(df)) {
      df$datetime <- as.POSIXct(df$timestamp, format = "%Y-%m-%dT%H:%M:%SZ")
      df <- df[df$value > 70 & df$value < 100, ]
    }
    df
  })
  
  breathing_data <- reactive({
    filtered_data()[["breathing_rate_summary"]]
  })
  
  # ==================== METRIC CARDS ====================
  
  output$card_hr <- renderText({
    df <- hr_data()
    if (is.null(df) || nrow(df) == 0) return("—")
    avg_hr <- mean(df$heart_rate_avg, na.rm = TRUE)
    paste(round(avg_hr))
  })
  
  output$card_steps <- renderText({
    df <- steps_data()
    if (is.null(df) || nrow(df) == 0) return("—")
    daily_steps <- df %>%
      mutate(date = as.Date(date)) %>%
      group_by(date) %>%
      summarise(total = sum(steps_5min, na.rm = TRUE))
    format(round(mean(daily_steps$total, na.rm = TRUE)), big.mark = ",")
  })
  
  output$card_sleep <- renderText({
    df <- sleep_data()
    if (is.null(df) || nrow(df) == 0) return("—")
    deep_by_night <- df %>%
      filter(sleep_stage == "deep") %>%
      group_by(dateOfSleep) %>%
      summarise(deep_minutes = n())
    paste(round(mean(deep_by_night$deep_minutes, na.rm = TRUE), 0))
  })
  
  output$card_spo2 <- renderText({
    df <- spo2_data()
    if (is.null(df) || nrow(df) == 0) return("—")
    avg_spo2 <- mean(df$value, na.rm = TRUE)
    paste(round(avg_spo2, 1))
  })
  
  # ==================== DYNAMIC TABS ====================
  
  output$dynamic_tabs <- renderUI({
    if (!auth$logged_in) return(NULL)
    
    if (auth$is_admin) {
      tabsetPanel(
        tabPanel("Overview", overview_tab_content()),
        tabPanel("Heart Rate", heart_rate_tab_content()),
        tabPanel("Sleep", sleep_tab_content()),
        tabPanel("Activity", activity_tab_content()),
        tabPanel("Insights", insights_tab_content()),
        tabPanel("Projections", projections_tab_content()),
        tabPanel("Analysis", analysis_tab_content()),
        tabPanel("Data View", data_view_tab_content())
      )
    } else {
      tabsetPanel(
        tabPanel("Overview", overview_tab_content()),
        tabPanel("Heart Rate", heart_rate_tab_content()),
        tabPanel("Sleep", sleep_tab_content()),
        tabPanel("Activity", activity_tab_content()),
        tabPanel("Insights", insights_tab_content()),
        tabPanel("Projections", projections_tab_content())
      )
    }
  })
  
  # ==================== TAB CONTENT FUNCTIONS ====================
  
  overview_tab_content <- function() {
    tagList(
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
                      plotlyOutput("plot_hr", height = "280px"))),
        column(6, div(class = "chart-card",
                      p("Daily Steps", class = "chart-title"),
                      plotlyOutput("plot_steps", height = "280px")))
      ),
      fluidRow(
        column(12, div(class = "chart-card",
                       p("Sleep Stage Breakdown", class = "chart-title"),
                       plotlyOutput("plot_sleep", height = "280px")))
      )
    )
  }
  
  heart_rate_tab_content <- function() {
    tagList(
      br(),
      fluidRow(
        column(12, div(class = "chart-card",
                       p("Heart Rate Time Series", class = "chart-title"),
                       plotlyOutput("hr_timeseries", height = "400px")))
      ),
      fluidRow(
        column(6, div(class = "chart-card",
                      p("Heart Rate Distribution", class = "chart-title"),
                      plotlyOutput("hr_distribution", height = "300px"))),
        column(6, div(class = "chart-card",
                      p("Heart Rate by Hour of Day", class = "chart-title"),
                      plotlyOutput("hr_by_hour", height = "300px")))
      ),
      fluidRow(
        column(12, div(class = "chart-card",
                       p("Heart Rate Variability (HRV)", class = "chart-title"),
                       plotlyOutput("hrv_chart", height = "300px")))
      )
    )
  }
  
  sleep_tab_content <- function() {
    tagList(
      br(),
      fluidRow(
        column(6, div(class = "chart-card",
                      p("Sleep Duration Over Time", class = "chart-title"),
                      plotlyOutput("sleep_duration", height = "300px"))),
        column(6, div(class = "chart-card",
                      p("Sleep Stage Distribution", class = "chart-title"),
                      plotlyOutput("sleep_stage_pie", height = "300px")))
      ),
      fluidRow(
        column(12, div(class = "chart-card",
                       p("Breathing Rate During Sleep", class = "chart-title"),
                       plotlyOutput("breathing_rate_chart", height = "300px")))
      )
    )
  }
  
  activity_tab_content <- function() {
    tagList(
      br(),
      fluidRow(
        column(6, div(class = "chart-card",
                      p("Zone Minutes (Fat Burn / Cardio / Peak)", class = "chart-title"),
                      plotlyOutput("zone_minutes_chart", height = "300px"))),
        column(6, div(class = "chart-card",
                      p("Exercise Sessions", class = "chart-title"),
                      plotlyOutput("exercise_sessions_chart", height = "300px")))
      ),
      fluidRow(
        column(12, div(class = "chart-card",
                       p("Sedentary Periods", class = "chart-title"),
                       plotlyOutput("sedentary_chart", height = "250px")))
      )
    )
  }
  
  insights_tab_content <- function() {
    tagList(
      br(),
      fluidRow(
        column(12, div(class = "chart-card",
                       p("Coming Soon - Correlation Analysis", class = "chart-title"),
                       p("Charts showing relationships between heart rate, sleep, and activity will appear here.")))
      )
    )
  }
  
  projections_tab_content <- function() {
    tagList(
      br(),
      fluidRow(
        column(12, div(class = "chart-card",
                       p("Coming Soon - Trend Projections", class = "chart-title"),
                       p("Machine learning forecasts and trend analysis will appear here.")))
      )
    )
  }
  
  analysis_tab_content <- function() {
    tagList(
      br(),
      fluidRow(
        column(12, div(class = "chart-card",
                       p("Participant Comparison", class = "chart-title"),
                       p("Compare metrics across all participants.")))
      ),
      fluidRow(
        column(6, div(class = "chart-card",
                      p("Aggregate Statistics", class = "chart-title"),
                      p("Summary statistics across all participants."))),
        column(6, div(class = "chart-card",
                      p("Data Completeness", class = "chart-title"),
                      p("Heatmap showing which participants have data for which dates.")))
      )
    )
  }
  
  data_view_tab_content <- function() {
    tagList(
      br(),
      fluidRow(
        column(12, div(class = "chart-card",
                       p("Raw Data Viewer", class = "chart-title"),
                       p("Select a dataset to view its raw contents."),
                       selectInput("data_view_select", "Choose Dataset",
                                   choices = c("Heart Rate", "Steps", "Sleep", "Daily Metrics", 
                                               "HRV", "Activity Level", "Zone Minutes", 
                                               "Activity Sessions", "Sedentary Periods", "SpO2"),
                                   width = "300px"),
                       DT::dataTableOutput("data_view_table")))
      )
    )
  }
  
  # ==================== RESTORED CHARTS (OVERVIEW TAB) ====================
  
  # 1. Heart Rate Over Time (Line chart)
  output$plot_hr <- renderPlotly({
    df <- hr_data()
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No heart rate data available"))
    }
    
    p <- ggplot(df, aes(x = datetime, y = heart_rate_avg)) +
      geom_line(color = clr$hr, linewidth = 0.5, alpha = 0.8) +
      labs(x = NULL, y = "bpm") +
      dash_theme()
    
    ggplotly(p) %>% 
      layout(hoverlabel = list(bgcolor = "white"),
             margin = list(l = 50, r = 20, t = 20, b = 40))
  })
  
  # 2. Daily Steps (Column chart with 10k target line)
  output$plot_steps <- renderPlotly({
    df <- steps_data()
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No steps data available"))
    }
    
    daily_steps <- df %>%
      mutate(date = as.Date(date)) %>%
      group_by(date) %>%
      summarise(total = sum(steps_5min, na.rm = TRUE))
    
    if (nrow(daily_steps) == 0) {
      return(create_empty_plot("No steps data for selected date range"))
    }
    
    p <- ggplot(daily_steps, aes(x = date, y = total)) +
      geom_col(fill = clr$steps, width = 0.7, alpha = 0.9) +
      geom_hline(yintercept = 10000, linetype = "dashed", 
                 color = "#9CA3AF", linewidth = 0.5) +
      scale_y_continuous(labels = scales::comma) +
      scale_x_date(date_labels = "%b %d") +
      labs(x = NULL, y = "steps") +
      dash_theme()
    
    ggplotly(p) %>% 
      layout(hoverlabel = list(bgcolor = "white"),
             margin = list(l = 50, r = 20, t = 20, b = 40))
  })
  
  # 3. Sleep Stage Breakdown (Stacked bar chart - Deep, REM, Light per day)
  output$plot_sleep <- renderPlotly({
    df <- sleep_data()
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No sleep data available"))
    }
    
    # Aggregate sleep stages per night
    sleep_summary <- df %>%
      group_by(dateOfSleep, sleep_stage) %>%
      summarise(minutes = n(), .groups = "drop") %>%
      filter(sleep_stage %in% c("deep", "rem", "light")) %>%
      mutate(sleep_stage = recode(sleep_stage,
                                  deep = "Deep",
                                  rem = "REM",
                                  light = "Light"))
    
    if (nrow(sleep_summary) == 0) {
      return(create_empty_plot("No sleep stage data available"))
    }
    
    p <- ggplot(sleep_summary, aes(x = as.Date(dateOfSleep), y = minutes, fill = sleep_stage)) +
      geom_col(width = 0.7, alpha = 0.9) +
      scale_fill_manual(values = c(Deep = clr$deep, REM = clr$rem, Light = clr$light)) +
      scale_x_date(date_labels = "%b %d") +
      labs(x = NULL, y = "minutes") +
      dash_theme()
    
    ggplotly(p) %>% 
      layout(hoverlabel = list(bgcolor = "white"),
             margin = list(l = 50, r = 20, t = 20, b = 40))
  })
  
  # ==================== PLACEHOLDER CHARTS (OTHER TABS) ====================
  
  output$plot_activity_levels <- renderPlotly({ create_empty_plot("Activity levels chart coming soon") })
  
  output$hr_timeseries <- renderPlotly({ create_empty_plot("Heart rate time series coming soon") })
  output$hr_distribution <- renderPlotly({ create_empty_plot("HR distribution coming soon") })
  output$hr_by_hour <- renderPlotly({ create_empty_plot("HR by hour coming soon") })
  output$hrv_chart <- renderPlotly({ create_empty_plot("HRV chart coming soon") })
  
  output$sleep_duration <- renderPlotly({ create_empty_plot("Sleep duration coming soon") })
  output$sleep_stage_pie <- renderPlotly({ create_empty_plot("Sleep stage distribution coming soon") })
  output$breathing_rate_chart <- renderPlotly({ create_empty_plot("Breathing rate coming soon") })
  
  output$zone_minutes_chart <- renderPlotly({ create_empty_plot("Zone minutes coming soon") })
  output$exercise_sessions_chart <- renderPlotly({ create_empty_plot("Exercise sessions coming soon") })
  output$sedentary_chart <- renderPlotly({ create_empty_plot("Sedentary periods coming soon") })
  
  # ==================== DATA VIEW TABLE (Admin only, already working) ====================
  
  output$data_view_table <- DT::renderDataTable({
    req(input$data_view_select)
    dataset_name <- input$data_view_select
    
    df <- switch(dataset_name,
                 "Heart Rate" = hr_data(),
                 "Steps" = steps_data(),
                 "Sleep" = sleep_data(),
                 "Daily Metrics" = daily_metrics(),
                 "HRV" = hrv_data(),
                 "Activity Level" = activity_level_data(),
                 "Zone Minutes" = zone_minutes_data(),
                 "Activity Sessions" = activity_sessions_data(),
                 "Sedentary Periods" = sedentary_data(),
                 "SpO2" = spo2_data(),
                 NULL)
    
    if (is.null(df) || nrow(df) == 0) {
      return(DT::datatable(data.frame(Message = "No data available for this dataset")))
    }
    
    DT::datatable(df, options = list(scrollX = TRUE, pageLength = 20))
  })
}

shinyApp(ui = ui, server = server)