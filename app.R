# ==============================================================================
# Fitbit Research Dashboard
# STARS Program - Physiological & Psychological Effects of Discrimination
# Boston University Labs
# ==============================================================================
# This dashboard provides visualization and analysis of Fitbit data for 
# research participants. It includes:
#   - Authentication system with admin roles
#   - Date-based AND study-day-based views
#   - Interactive charts for heart rate, sleep, activity, and more
#   - Multi-participant comparison for admins
# ==============================================================================

# Load required libraries
library(shiny)           # Web application framework
library(shinyjs)         # For showing/hiding UI elements
library(tidyverse)       # Data manipulation (dplyr, ggplot2, etc.)
library(lubridate)       # Date/time handling
library(plotly)          # Interactive charts
library(DT)              # Interactive data tables
library(shinyfullscreen) # Lets wrapped charts go fullscreen when double clicked
library(zoo)             # For rolling averages (HRV)

# Source external colour palette (used across all charts)
source("R/colours.R")

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

#' Get date range for a participant from tokenSheet
#' 
#' @param data_list List of all loaded dataframes
#' @param participant_id Optional participant ID to filter for
#' @return List with start and end dates
get_participant_dates <- function(data_list, participant_id = NULL) {
  token <- data_list[["tokenSheet"]]
  if (is.null(token) || nrow(token) == 0) {
    return(list(start = Sys.Date() - 30, end = Sys.Date()))
  }
  
  if (!is.null(participant_id)) {
    token <- token[token$participantID == participant_id, ]
  }
  
  if (nrow(token) == 0) {
    return(list(start = Sys.Date() - 30, end = Sys.Date()))
  }
  
  list(
    start = as.Date(min(token$start_date, na.rm = TRUE)),
    end   = as.Date(max(token$end_date,   na.rm = TRUE))
  )
}

#' Sanitize column names to ensure consistency across old and new CSV files
#' 
#' @param df Dataframe to sanitize
#' @return Dataframe with standardized column names
sanitize_column_names <- function(df) {
  names(df) <- gsub("-", "_", names(df))
  names(df) <- sub("^participantId$", "participantID", names(df))
  df
}

#' Add study_day column to a dataframe, handling different date column names
#' 
#' @param df Dataframe with date or dateOfSleep column and participantID
#' @param token Token sheet dataframe with participant start dates
#' @return Dataframe with added study_day and day_of_week columns
add_study_day <- function(df, token) {
  # Check if we have participantID and a date column
  if (!"participantID" %in% names(df)) return(df)
  
  # Determine which date column to use
  date_col <- NULL
  if ("date" %in% names(df)) {
    date_col <- "date"
  } else if ("dateOfSleep" %in% names(df)) {
    date_col <- "dateOfSleep"
  } else {
    return(df)  # No date column found
  }
  
  # Ensure dates are Date objects
  df <- df %>%
    mutate(!!sym(date_col) := as.Date(!!sym(date_col)))
  
  token <- token %>%
    mutate(start_date = as.Date(start_date))
  
  # Join with token sheet to get start_date, then calculate study day
  df %>%
    left_join(token %>% select(participantID, start_date), by = "participantID") %>%
    mutate(
      study_day = as.integer(as.Date(!!sym(date_col)) - as.Date(start_date)) + 1,
      day_of_week = weekdays(as.Date(!!sym(date_col)))
    ) %>%
    select(-start_date)
}

#' Load all CSV files from the csvdata folder and add study_day column
#' 
#' @return List of dataframes with study_day added to all applicable tables
load_all_data <- function() {
  # Get all CSV files from the csvdata folder
  csv_files <- list.files("csvdata", pattern = "\\.csv$", full.names = TRUE)
  names(csv_files) <- gsub("\\.csv$", "", basename(csv_files))
  
  # Load each CSV file
  data_list <- list()
  for (file_name in names(csv_files)) {
    df <- read.csv(csv_files[[file_name]], stringsAsFactors = FALSE)
    df <- sanitize_column_names(df)
    data_list[[file_name]] <- df
  }
  
  # Add study_day to all dataframes that have participantID and a date column
  # This is done at load time so the study_day is available for all views
  if ("tokenSheet" %in% names(data_list)) {
    token <- data_list[["tokenSheet"]]
    for (name in names(data_list)) {
      # Skip tokenSheet itself
      if (name != "tokenSheet" && "participantID" %in% names(data_list[[name]])) {
        # Check if the dataframe has a date column (either 'date' or 'dateOfSleep')
        has_date <- "date" %in% names(data_list[[name]]) || "dateOfSleep" %in% names(data_list[[name]])
        if (has_date) {
          data_list[[name]] <- add_study_day(data_list[[name]], token)
        }
      }
    }
  }
  
  data_list
}

#' Get all unique participant IDs from the data
#' 
#' @param data_list List of loaded dataframes
#' @return Sorted vector of unique participant IDs
get_all_participants <- function(data_list) {
  participants <- c()
  for (df in data_list) {
    if ("participantID" %in% names(df)) {
      participants <- c(participants, unique(df$participantID))
    }
  }
  sort(unique(participants))
}

#' Check if a user is an admin
#' 
#' @param participant_id Participant ID to check
#' @param roles_df Roles dataframe
#' @return TRUE if user is an admin, FALSE otherwise
is_admin_user <- function(participant_id, roles_df) {
  if (is.null(roles_df) || nrow(roles_df) == 0) return(FALSE)
  admin_check <- roles_df[roles_df$participantID == participant_id, "is_admin"]
  length(admin_check) > 0 && admin_check == TRUE
}

#' Load the roles configuration file
#' 
#' @return Dataframe with participantID and is_admin columns
load_roles <- function() {
  if (file.exists("roles.csv")) {
    roles_df <- read.csv("roles.csv", stringsAsFactors = FALSE)
    sanitize_column_names(roles_df)
  } else {
    data.frame(participantID = character(), is_admin = logical())
  }
}

#' Create a datetime column from date and time columns (handles Excel date bug)
#' 
#' @param df Dataframe with date and time columns
#' @return Dataframe with added datetime column
add_datetime_column <- function(df) {
  if (!is.null(df) && nrow(df) > 0 && "date" %in% names(df) && "time" %in% names(df)) {
    df %>%
      mutate(
        time_clean = case_when(
          str_detect(time, "\\d{2}:\\d{2}:\\d{2}") ~ str_extract(time, "\\d{2}:\\d{2}:\\d{2}"),
          TRUE ~ "00:00:00"
        ),
        datetime = as.POSIXct(paste(date, time_clean), 
                              format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
      ) %>%
      select(-time_clean)
  } else {
    df
  }
}

#' Convert ISO timestamp to datetime
#' 
#' @param df Dataframe with timestamp column
#' @param timestamp_col Name of timestamp column
#' @return Dataframe with added datetime column
add_datetime_from_timestamp <- function(df, timestamp_col = "timestamp") {
  if (!is.null(df) && nrow(df) > 0 && timestamp_col %in% names(df)) {
    df$datetime <- as.POSIXct(df[[timestamp_col]], format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  }
  df
}

#' Shared ggplot theme for all charts
#' 
#' @return ggplot theme object
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

#' Empty plot placeholder using ggplot (no Plotly warnings)
#' 
#' @param message Message to display
#' @return Plotly object with placeholder message
create_empty_plot <- function(message) {
  p <- ggplot() + 
    annotate("text", x = 0.5, y = 0.5, label = message, 
             size = 5, color = "#6B7280") +
    theme_void() +
    theme(plot.background = element_rect(fill = "transparent", color = NA))
  ggplotly(p) %>%
    layout(hoverlabel = list(bgcolor = "white"),
           margin = list(l = 20, r = 20, t = 20, b = 20))
}

# ============================================================================
# USER INTERFACE (UI)
# ============================================================================

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
      div(class = "login-form",
          textInput("participant_id", NULL, 
                    placeholder = "Enter your Participant ID",
                    width = "220px"),
          actionButton("login_btn", "Login", class = "btn-primary")
      ),
      div(class = "user-info", textOutput("login_status"))
  ),
  
  # ==================== MAIN APP (hidden until login) ====================
  div(id = "main_app", style = "display: none;",
      
      # ========== FILTERS ROW ==========
      # Contains view mode toggle, date picker, and study day slider
      div(class = "filters-row",
          
          # View mode toggle: Switch between Date and Study Day views
          div(class = "view-toggle",
              radioButtons("view_mode", NULL, 
                           choices = c("By Date" = "date", "By Study Day" = "day"),
                           selected = "date", 
                           inline = TRUE)
          ),
          
          # Date picker (shown when "date" selected)
          # Allows filtering by calendar date range
          conditionalPanel(
            condition = "input.view_mode == 'date'",
            dateRangeInput("date_range", NULL, 
                           start = NULL, end = NULL, 
                           width = "280px")
          ),
          
          # Day picker (shown when "day" selected)
          # Dynamically generates slider with "Day 1 - Monday" labels
          conditionalPanel(
            condition = "input.view_mode == 'day'",
            uiOutput("day_range_ui")
          ),
          
          # Admin participant selector (hidden for non-admins)
          div(id = "admin_selector_container", class = "admin-selector", style = "display: none;",
              selectInput("admin_participant", "View Participant:",
                          choices = c("All Participants" = "ALL"),
                          width = "220px"))
      ),
      
      # ========== MAIN CONTENT AREA ==========
      div(class = "main-container",
          uiOutput("dynamic_tabs")
      )
  )
)

# ============================================================================
# SERVER LOGIC
# ============================================================================

server <- function(input, output, session) {
  
  # ==================== REACTIVE VALUES ====================
  
  # Authentication state
  auth <- reactiveValues(
    logged_in = FALSE,
    participant_id = NULL,
    is_admin = FALSE,
    selected_participant = NULL
  )
  
  # ==================== DATA LOADING ====================
  
  # Load all data including study_day column
  all_data <- reactive({
    load_all_data()
  })
  
  # Load roles configuration
  roles_df <- reactive({
    load_roles()
  })
  
  # Get all unique participants
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
    
    # Set initial date range from tokenSheet for this participant
    dates <- get_participant_dates(all_data(), participant_id)
    updateDateRangeInput(session, "date_range",
                         start = dates$start,
                         end   = dates$end)
    
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
  
  # ==================== UPDATE DATE RANGE WHEN ADMIN SWITCHES PARTICIPANT ====================
  
  observeEvent(input$admin_participant, {
    req(auth$logged_in, auth$is_admin)
    
    participant <- if (input$admin_participant == "ALL") NULL else input$admin_participant
    dates <- get_participant_dates(all_data(), participant)
    
    updateDateRangeInput(session, "date_range",
                         start = dates$start,
                         end   = dates$end)
  })
  
  # ==================== STUDY DAY RANGE UI ====================
  
  # Dynamically generate the study day slider with day labels
  # This creates "Day 1 - Monday", "Day 2 - Tuesday", etc.
  output$day_range_ui <- renderUI({
    req(auth$logged_in)
    
    data <- all_data()  # fixed: no circular dependency
    token <- data[["tokenSheet"]]
    
    if (is.null(token) || nrow(token) == 0) {
      return(div("No participant data available"))
    }
    
    participant <- current_participant()
    if (!is.null(participant)) {
      token <- token[token$participantID == participant, ]
    }
    
    if (nrow(token) == 0) {
      return(div("No data for selected participant"))
    }
    
    start_date <- min(as.Date(token$start_date), na.rm = TRUE)
    end_date   <- max(as.Date(token$end_date),   na.rm = TRUE)
    
    # Build "Day 1 - Monday", "Day 2 - Tuesday", etc.
    n_days <- as.integer(end_date - start_date) + 1
    dates_seq <- seq(start_date, end_date, by = "day")
    #day_labels <- paste0("Day ", seq_len(n_days), " - ", weekdays(dates_seq))
    day_labels <- paste0("Day ", seq_len(n_days), ": ", strftime(dates_seq, "%a"))
    
    fluidRow(
      column(6, selectInput("study_day_start", "From:",
                            choices = day_labels,
                            selected = day_labels[1],
                            width = "130px")),
      column(6, selectInput("study_day_end", "To:",
                            choices = day_labels,
                            selected = day_labels[min(7, n_days)],
                            width = "130px"))
    )
  })
  
  # ==================== PARTICIPANT FILTERING ====================
  
  # Determine which participant(s) to show based on login status and admin selection
  current_participant <- reactive({
    if (!auth$logged_in) return(NULL)
    
    if (auth$is_admin) {
      req(input$admin_participant)
      if (input$admin_participant == "ALL") {
        return(NULL)  # NULL means show all participants
      } else {
        return(input$admin_participant)
      }
    } else {
      return(auth$participant_id)  # Regular users only see their own data
    }
  })
  
  # Filter data by participant (and optionally by date or study day)
  filtered_data <- reactive({
    req(auth$logged_in)
    
    data <- all_data()
    participant <- current_participant()
    date_range <- input$date_range
    
    # Filter by participant
    if (!is.null(participant)) {
      data <- lapply(data, function(df) {
        if ("participantID" %in% names(df)) {
          df <- df[df$participantID == participant, ]
        }
        df
      })
    }
    
    # Filter by date range (only used in "date" view mode)
    if (!is.null(date_range)) {
      data <- lapply(data, function(df) {
        if ("date" %in% names(df)) {
          df$date <- as.Date(df$date)
          df <- df[df$date >= date_range[1] & df$date <= date_range[2], ]
        }
        
        if ("dateOfSleep" %in% names(df) && !"date" %in% names(df)) {
          df$dateOfSleep <- as.Date(df$dateOfSleep)
          df <- df[df$dateOfSleep >= date_range[1] & df$dateOfSleep <= date_range[2], ]
        }
        df
      })
    }
    
    data
  })
  
  # ==================== STUDY DAY FILTERING ====================
  
  # Further filter data by study day range when in "day" view mode
  filtered_data_by_day <- reactive({
    req(auth$logged_in)
    
    data <- filtered_data()
    
    if (input$view_mode == "date") {
      return(data)
    }
    
    req(input$study_day_start, input$study_day_end)
    
    # Extract the number from "Day 3 - Wednesday" → 3
    #day_start <- as.integer(sub("Day (\\d+) - .*", "\\1", input$study_day_start))
    #day_end   <- as.integer(sub("Day (\\d+) - .*", "\\1", input$study_day_end))
    day_start <- as.integer(sub("Day (\\d+):.*", "\\1", input$study_day_start))
    day_end   <- as.integer(sub("Day (\\d+):.*", "\\1", input$study_day_end))
    
    lapply(data, function(df) {
      if ("study_day" %in% names(df)) {
        df <- df[df$study_day >= day_start & df$study_day <= day_end, ]
      }
      df
    })
  })
  
  # ==================== EXTRACT SPECIFIC DATAFRAMES ====================
  # Each reactive function extracts a specific dataset and applies 
  # necessary data cleaning and transformations
  
  # Heart rate data (5-minute intervals)
  hr_data <- reactive({
    req(auth$logged_in)
    data <- filtered_data_by_day()  # Uses study day or date filtering
    df <- data[["hr_intraday_5m"]]
    if (!is.null(df) && nrow(df) > 0) {
      df <- df %>%
        add_datetime_column() %>%
        filter(!is.na(datetime), heart_rate_avg > 30, heart_rate_avg < 220)
    }
    df
  })
  
  # Steps data (5-minute intervals)
  steps_data <- reactive({
    req(auth$logged_in)
    data <- filtered_data_by_day()
    df <- data[["steps_intraday_5m"]]
    if (!is.null(df) && nrow(df) > 0) {
      df <- df %>%
        add_datetime_column() %>%
        filter(!is.na(datetime))
    }
    df
  })
  
  # Sleep data (minute-by-minute)
  sleep_data <- reactive({
    req(auth$logged_in)
    data <- filtered_data_by_day()
    df <- data[["sleep_minute"]]
    if (!is.null(df) && nrow(df) > 0) {
      df <- df %>%
        mutate(dateOfSleep = as.Date(dateOfSleep))
      # Ensure study_day is present (it should be from load_all_data)
      # If not, we'll add it here as a fallback
      if (!"study_day" %in% names(df)) {
        token <- all_data()[["tokenSheet"]]
        if (!is.null(token) && nrow(token) > 0) {
          df <- add_study_day(df, token)
        }
      }
    }
    df
  })
  
  # Daily metrics (aggregated daily data)
  daily_metrics <- reactive({
    req(auth$logged_in)
    data <- filtered_data_by_day()
    data[["daily_metrics"]]
  })
  
  # Heart Rate Variability data
  hrv_data <- reactive({
    req(auth$logged_in)
    data <- filtered_data_by_day()
    df <- data[["hrv_intraday"]]
    if (!is.null(df) && nrow(df) > 0 && "timestamp" %in% names(df)) {
      df <- df %>%
        add_datetime_from_timestamp() %>%
        filter(!is.na(datetime), rmssd_ms > 0, rmssd_ms < 200)
      if (nrow(df) > 0) {
        df <- df %>%
          arrange(datetime) %>%
          mutate(rolling_avg = zoo::rollapply(rmssd_ms, width = min(10, n()), 
                                              FUN = mean, fill = NA, align = "center"))
      }
    }
    df
  })
  
  # Activity level data
  activity_level_data <- reactive({
    req(auth$logged_in)
    data <- filtered_data_by_day()
    df <- data[["activity_level_intraday"]]
    if (!is.null(df) && nrow(df) > 0) {
      df <- df %>%
        add_datetime_column() %>%
        filter(!is.na(datetime))
    }
    df
  })
  
  # Zone minutes data
  zone_minutes_data <- reactive({
    req(auth$logged_in)
    data <- filtered_data_by_day()
    df <- data[["zone_minutes_intraday_5m"]]
    if (!is.null(df) && nrow(df) > 0) {
      df <- df %>%
        add_datetime_column() %>%
        filter(!is.na(datetime))
    }
    df
  })
  
  # Activity sessions data
  activity_sessions_data <- reactive({
    req(auth$logged_in)
    data <- filtered_data_by_day()
    df <- data[["activity_sessions"]]
    if (!is.null(df) && nrow(df) > 0 && "start_time" %in% names(df)) {
      df <- df %>%
        mutate(
          start_datetime = as.POSIXct(start_time, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
          end_datetime = as.POSIXct(end_time, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
        ) %>%
        filter(!is.na(start_datetime))
    }
    df
  })
  
  # Sedentary periods data
  sedentary_data <- reactive({
    req(auth$logged_in)
    data <- filtered_data_by_day()
    df <- data[["sedentary_periods"]]
    if (!is.null(df) && nrow(df) > 0 && "period_start" %in% names(df)) {
      df <- df %>%
        mutate(
          start_datetime = as.POSIXct(period_start, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
          end_datetime = as.POSIXct(period_end, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
        ) %>%
        filter(!is.na(start_datetime))
    }
    df
  })
  
  # SpO2 data
  spo2_data <- reactive({
    req(auth$logged_in)
    data <- filtered_data_by_day()
    df <- data[["spo2_intraday"]]
    if (!is.null(df) && nrow(df) > 0 && "timestamp" %in% names(df)) {
      df <- df %>%
        add_datetime_from_timestamp() %>%
        filter(!is.na(datetime), value > 70, value < 100)
    }
    df
  })
  
  # Breathing rate data
  breathing_data <- reactive({
    req(auth$logged_in)
    data <- filtered_data_by_day()
    df <- data[["breathing_rate_summary"]]
    if (!is.null(df) && nrow(df) > 0) {
      df <- df %>%
        mutate(date = as.Date(date))
    }
    df
  })
  
  # ==================== METRIC CARDS ====================
  # Summary statistics shown at the top of the Overview tab
  
  output$card_hr <- renderText({
    req(auth$logged_in)
    df <- hr_data()
    if (is.null(df) || nrow(df) == 0) return("—")
    avg_hr <- mean(df$heart_rate_avg, na.rm = TRUE)
    paste(round(avg_hr))
  })
  
  output$card_steps <- renderText({
    req(auth$logged_in)
    df <- steps_data()
    if (is.null(df) || nrow(df) == 0) return("—")
    daily_steps <- df %>%
      mutate(date = as.Date(date)) %>%
      group_by(date) %>%
      summarise(total = sum(steps_5min, na.rm = TRUE))
    format(round(mean(daily_steps$total, na.rm = TRUE)), big.mark = ",")
  })
  
  output$card_sleep <- renderText({
    req(auth$logged_in)
    df <- sleep_data()
    if (is.null(df) || nrow(df) == 0) return("—")
    deep_by_night <- df %>%
      filter(sleep_stage == "deep") %>%
      group_by(dateOfSleep) %>%
      summarise(deep_minutes = n())
    paste(round(mean(deep_by_night$deep_minutes, na.rm = TRUE), 0))
  })
  
  output$card_spo2 <- renderText({
    req(auth$logged_in)
    df <- spo2_data()
    if (is.null(df) || nrow(df) == 0) return("—")
    avg_spo2 <- mean(df$value, na.rm = TRUE)
    paste(round(avg_spo2, 1))
  })
  
  # ==================== DYNAMIC TABS ====================
  
  # Render tabs dynamically based on user role
  # Admins see additional tabs (Analysis, Data View)
  output$dynamic_tabs <- renderUI({
    req(auth$logged_in)
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
  # Each function returns UI content for its respective tab
  
  overview_tab_content <- function() {
    tagList(
      br(),
      # Metric cards row
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
      # Chart row 1: Heart Rate + Steps
      fluidRow(
        column(6, div(class = "chart-card",
                      p("Heart Rate Over Time", class = "chart-title"),
                      plotlyOutput("plot_hr", height = "280px"))),
        column(6, div(class = "chart-card",
                      p("Daily Steps", class = "chart-title"),
                      plotlyOutput("plot_steps", height = "280px")))
      ),
      # Chart row 2: Sleep
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
  
  # ==================== CHARTS (OVERVIEW TAB) ====================
  # These charts adapt to both "date" and "study day" view modes
  
  # 1. Heart Rate Over Time
  # Shows either calendar dates or study days on x-axis
  output$plot_hr <- renderPlotly({
    req(auth$logged_in)
    df <- hr_data()
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No heart rate data available"))
    }
    
    # Determine x-axis based on view mode
    if (input$view_mode == "day") {
      # Study Day view: aggregate by study_day and show as line chart
      df <- df %>%
        group_by(study_day) %>%
        summarise(heart_rate_avg = mean(heart_rate_avg, na.rm = TRUE)) %>%
        ungroup()
      
      p <- ggplot(df, aes(x = study_day, y = heart_rate_avg)) +
        geom_line(color = clr$hr, linewidth = 0.5, alpha = 0.8) +
        labs(x = "Study Day", y = "bpm") +
        dash_theme()
    } else {
      # Date view: show datetime on x-axis
      p <- ggplot(df, aes(x = datetime, y = heart_rate_avg)) +
        geom_line(color = clr$hr, linewidth = 0.5, alpha = 0.8) +
        labs(x = NULL, y = "bpm") +
        dash_theme()
    }
    
    ggplotly(p) %>% 
      layout(hoverlabel = list(bgcolor = "white"),
             margin = list(l = 50, r = 20, t = 20, b = 40))
  })
  
  # 2. Daily Steps
  # Shows either calendar dates or study days on x-axis
  output$plot_steps <- renderPlotly({
    req(auth$logged_in)
    df <- steps_data()
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No steps data available"))
    }
    
    if (input$view_mode == "day") {
      # Study Day view: aggregate by study_day
      daily_steps <- df %>%
        group_by(study_day) %>%
        summarise(total = sum(steps_5min, na.rm = TRUE))
      
      p <- ggplot(daily_steps, aes(x = study_day, y = total)) +
        geom_col(fill = clr$steps, width = 0.7, alpha = 0.9) +
        geom_hline(yintercept = 10000, linetype = "dashed", 
                   color = "#9CA3AF", linewidth = 0.5) +
        scale_y_continuous(labels = scales::comma) +
        labs(x = "Study Day", y = "steps") +
        dash_theme()
    } else {
      # Date view: show calendar dates on x-axis
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
    }
    
    ggplotly(p) %>% 
      layout(hoverlabel = list(bgcolor = "white"),
             margin = list(l = 50, r = 20, t = 20, b = 40))
  })
  
  # 3. Sleep Stage Breakdown
  # Shows sleep stages (Deep, REM, Light) stacked by date or study day
  # 3. Sleep Stage Breakdown
  # Shows sleep stages (Deep, REM, Light) stacked by date or study day
  output$plot_sleep <- renderPlotly({
    req(auth$logged_in)
    df <- sleep_data()
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No sleep data available"))
    }
    if (!"sleep_stage" %in% names(df)) {
      return(create_empty_plot("Sleep stage data not available"))
    }
    
    # Check if we have study_day column
    has_study_day <- "study_day" %in% names(df)
    
    # Summarize sleep stages
    if (has_study_day) {
      sleep_summary <- df %>%
        group_by(dateOfSleep, sleep_stage, study_day) %>%
        summarise(minutes = n(), .groups = "drop") %>%
        filter(sleep_stage %in% c("deep", "rem", "light", "asleep", "awake")) %>%
        mutate(
          sleep_stage = case_when(
            tolower(sleep_stage) %in% c("deep", "deep sleep") ~ "Deep",
            tolower(sleep_stage) %in% c("rem", "rem sleep") ~ "REM",
            tolower(sleep_stage) %in% c("light", "light sleep", "asleep") ~ "Light",
            tolower(sleep_stage) %in% c("awake", "wake") ~ "Wake",
            TRUE ~ "Light"
          )
        ) %>%
        filter(sleep_stage != "Wake")
    } else {
      # Fallback if no study_day
      sleep_summary <- df %>%
        group_by(dateOfSleep, sleep_stage) %>%
        summarise(minutes = n(), .groups = "drop") %>%
        filter(sleep_stage %in% c("deep", "rem", "light", "asleep", "awake")) %>%
        mutate(
          sleep_stage = case_when(
            tolower(sleep_stage) %in% c("deep", "deep sleep") ~ "Deep",
            tolower(sleep_stage) %in% c("rem", "rem sleep") ~ "REM",
            tolower(sleep_stage) %in% c("light", "light sleep", "asleep") ~ "Light",
            tolower(sleep_stage) %in% c("awake", "wake") ~ "Wake",
            TRUE ~ "Light"
          )
        ) %>%
        filter(sleep_stage != "Wake")
    }
    
    if (nrow(sleep_summary) == 0) {
      return(create_empty_plot("No sleep stage data available"))
    }
    
    if (input$view_mode == "day" && has_study_day) {
      # Study Day view: show study_day on x-axis
      p <- ggplot(sleep_summary, aes(x = study_day, y = minutes, fill = sleep_stage)) +
        geom_col(width = 0.7, alpha = 0.9) +
        scale_fill_manual(values = c(Deep = clr$deep, REM = clr$rem, Light = clr$light)) +
        labs(x = "Study Day", y = "minutes") +
        dash_theme()
    } else {
      # Date view: show calendar dates on x-axis
      # Or fallback if study_day not available but user is in day mode
      p <- ggplot(sleep_summary, aes(x = as.Date(dateOfSleep), y = minutes, fill = sleep_stage)) +
        geom_col(width = 0.7, alpha = 0.9) +
        scale_fill_manual(values = c(Deep = clr$deep, REM = clr$rem, Light = clr$light)) +
        scale_x_date(date_labels = "%b %d") +
        labs(x = NULL, y = "minutes") +
        dash_theme()
      
      # If we're in day mode but no study_day, show a warning in the plot title
      if (input$view_mode == "day" && !has_study_day) {
        p <- p + labs(title = "Study Day view not available for sleep data (using dates instead)")
      }
    }
    
    ggplotly(p) %>% 
      layout(hoverlabel = list(bgcolor = "white"),
             margin = list(l = 50, r = 20, t = 50, b = 40))
  })
  
  # ==================== PLACEHOLDER CHARTS (OTHER TABS) ====================
  # These charts will be implemented in future updates
  
  output$plot_activity_levels <- renderPlotly({
    req(auth$logged_in)
    create_empty_plot("Activity levels chart coming soon")
  })
  
  output$hr_timeseries <- renderPlotly({
    req(auth$logged_in)
    create_empty_plot("Heart rate time series coming soon")
  })
  output$hr_distribution <- renderPlotly({
    req(auth$logged_in)
    create_empty_plot("HR distribution coming soon")
  })
  output$hr_by_hour <- renderPlotly({
    req(auth$logged_in)
    create_empty_plot("HR by hour coming soon")
  })
  output$hrv_chart <- renderPlotly({
    req(auth$logged_in)
    create_empty_plot("HRV chart coming soon")
  })
  
  output$sleep_duration <- renderPlotly({
    req(auth$logged_in)
    create_empty_plot("Sleep duration coming soon")
  })
  output$sleep_stage_pie <- renderPlotly({
    req(auth$logged_in)
    create_empty_plot("Sleep stage distribution coming soon")
  })
  output$breathing_rate_chart <- renderPlotly({
    req(auth$logged_in)
    create_empty_plot("Breathing rate coming soon")
  })
  
  output$zone_minutes_chart <- renderPlotly({
    req(auth$logged_in)
    create_empty_plot("Zone minutes coming soon")
  })
  output$exercise_sessions_chart <- renderPlotly({
    req(auth$logged_in)
    create_empty_plot("Exercise sessions coming soon")
  })
  output$sedentary_chart <- renderPlotly({
    req(auth$logged_in)
    create_empty_plot("Sedentary periods coming soon")
  })
  
  # ==================== DATA VIEW TABLE ====================
  
  output$data_view_table <- DT::renderDataTable({
    req(auth$logged_in)
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

# ============================================================================
# RUN THE APPLICATION
# ============================================================================

shinyApp(ui = ui, server = server)