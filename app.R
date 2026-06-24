# ==============================================================================
# Fitbit Research Dashboard
# Simmons University
# STARS Program - Physiological & Psychological Effects of Discrimination
# ==============================================================================

# Load required libraries
library(bslib)           # popover() and tooltip()
library(bsicons)         # Info card icon, view chart icon
library(shinyWidgets)    # dropdownButton(), panel(), etc.
library(shinyBS)         # bsCollapse(), bsCollapsePanel()
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
# Source external chart card wrappers
source("R/chart_card.R")

# ============================================================================
# TAB & CHART PERMISSIONS
# ============================================================================
# Edit these constants to control which tabs/charts are visible to whom.
#
# IMPORTANT: Adding or renaming a tab here is NOT enough on its own.
# Every tab listed in ALL_USER_TABS or ADMIN_ONLY_TABS must also have a
# matching entry in `tab_registry`, inside output$dynamic_tabs (server
# section, search for "PERMISSION-WIRED"). The name used here and the
# name used as the key in tab_registry must match EXACTLY (case-sensitive).
# If they don't match, the tab will silently fail to render (a warning
# will print to the console, but the app will not crash).
#
# Chart-level visibility (ADMIN_ONLY_CHARTS) does not require a separate
# registry — it is checked directly against each chart's output ID
# wherever that chart is rendered. See "ADMIN-ONLY" comments throughout
# the tab content functions for exact wiring locations.

# Tabs visible to ALL logged-in users (including admins)
ALL_USER_TABS <- c(
  "Overview",
  "Heart Rate",
  "Sleep",
  "Activity",
  "Insights",
  "Projections"
)

# Tabs visible ONLY to admins (admin-only)
ADMIN_ONLY_TABS <- c(
  "Analysis",
  "Data View"
)

# Chart IDs visible ONLY to admins, regardless of which tab they live in.
# A chart's output ID only needs to be listed here if it lives inside an
# ALL_USER_TABS tab — charts inside ADMIN_ONLY_TABS tabs are already
# hidden by the tab-level lockout, so listing them here is redundant
# (but harmless, in case a chart later moves to a shared tab).
ADMIN_ONLY_CHARTS <- c(
  "hrv_chart",
  "weekday_hrv_chart",
  "weekday_hr_chart"
)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

#' Get date range for a participant from tokenSheet
#' 
#' Extracts the minimum start date and maximum end date from the tokenSheet 
#' dataframe for a specific participant or for all participants.
#' @param data_list List of all loaded dataframes. Must contain a tokenSheet 
#'   dataframe with columns participantID, start_date, and end_date.
#' @param participant_id Optional character or numeric participant ID to filter 
#'   for. If NULL, returns date range across all participants.
#' @return A list with two elements: \item{start}{Date object representing the 
#'   earliest start_date} \item{end}{Date object representing the latest 
#'   end_date}. If tokenSheet is missing, empty, or participant not found, 
#'   returns a default range of last 30 days to today.
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
#' Standardizes column names by replacing hyphens with underscores and ensuring 
#' consistent capitalization of participantID.
#' @param df Dataframe to sanitize. Column names will be modified in place.
#' @return Dataframe with standardized column names. The original dataframe is 
#'   returned with renamed columns.
sanitize_column_names <- function(df) {
  names(df) <- gsub("-", "_", names(df))
  names(df) <- sub("^participantId$", "participantID", names(df))
  df
}

#' Add study_day, day_of_week, and day_type columns to a dataframe
#' 
#' Handles different date column names (date vs dateOfSleep) and calculates 
#' study day relative to participant's start date. Requires system locale to be 
#' English, since day_of_week and day_type are derived from base R's weekdays(), 
#' which is locale-dependent.
#' @param df Dataframe with date or dateOfSleep column and participantID
#' @param token Token sheet dataframe with participant start dates containing 
#'   participantID and start_date columns
#' @return Dataframe with added study_day (integer days from start), 
#'   day_of_week (character, e.g., "Monday"), and day_type (factor or character, 
#'   "Weekday" or "Weekend") columns. Returns original df unchanged if 
#'   participantID or date column is missing.
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
      day_of_week = weekdays(as.Date(!!sym(date_col))),
      # --- Weekday/weekend classification
      day_type = ifelse(day_of_week %in% c("Saturday", "Sunday"), "Weekend", "Weekday")
    ) %>%
    select(-start_date)
}

#' Load all CSV files from the csvdata folder and add study_day, day_of_week, 
#' and day_type columns
#' 
#' Reads all CSV files in the csvdata directory, standardizes column names, 
#' and enriches applicable dataframes with study day metrics. Dataframes are 
#' enriched if they contain both participantID and a date column (either date 
#' or dateOfSleep). The tokenSheet is required for calculating study days and 
#' is excluded from enrichment.
#' @return List of dataframes containing all loaded CSV data. Dataframes with 
#'   participantID and a date column have additional columns study_day, 
#'   day_of_week, and day_type added. See add_study_day() for column details. 
#'   Dataframes without both required columns are returned unchanged.
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
#' Extracts and aggregates participant IDs from all dataframes in the data_list 
#' that contain a participantID column. Duplicates are removed and results 
#' are sorted alphabetically or numerically.
#' @param data_list List of loaded dataframes. Dataframes without a 
#'   participantID column are silently ignored.
#' @return Sorted vector of unique participant IDs aggregated across all 
#'   dataframes in the list.
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
#' Determines whether a given participant has administrative privileges by 
#' checking the is_admin flag in the roles dataframe.
#' @param participant_id Character or numeric participant ID to check
#' @param roles_df Dataframe containing participantID and is_admin columns. 
#'   If NULL or empty, returns FALSE.
#' @return TRUE if the participant is an admin, FALSE otherwise. Returns FALSE 
#'   if participant not found or roles_df is invalid.
is_admin_user <- function(participant_id, roles_df) {
  if (is.null(roles_df) || nrow(roles_df) == 0) return(FALSE)
  admin_check <- roles_df[roles_df$participantID == participant_id, "is_admin"]
  length(admin_check) > 0 && admin_check == TRUE
}

#' Load the roles configuration file
#' 
#' Reads the roles.csv file from the working directory and standardizes its 
#' column names. If the file does not exist, returns an empty dataframe with 
#' the expected structure.
#' @return Dataframe with participantID and is_admin columns. Returns an empty 
#'   dataframe with these columns if roles.csv does not exist.
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
#' Combines separate date and time columns into a single POSIXct datetime column. 
#' Extracts the time component (HH:MM:SS) from the time column, handling cases 
#' where the time string contains additional text. Falls back to 00:00:00 for 
#' invalid or missing time values.
#' @param df Dataframe with date and time columns. Date column should be in 
#'   YYYY-MM-DD format. Time column should contain a time string, optionally 
#'   with additional text.
#' @return Dataframe with an added datetime column (POSIXct, UTC timezone). 
#'   Returns original df unchanged if df is NULL, empty, or missing required 
#'   date or time columns.
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
#' Converts an ISO 8601 timestamp column (format: YYYY-MM-DDTHH:MM:SSZ) to 
#' POSIXct datetime in UTC timezone. Useful for parsing timestamps from APIs 
#' or other systems that use the ISO format.
#' @param df Dataframe containing a timestamp column
#' @param timestamp_col Name of the timestamp column to convert. Defaults to 
#'   "timestamp".
#' @return Dataframe with an added datetime column (POSIXct, UTC timezone). 
#'   Returns original df unchanged if df is NULL, empty, or the timestamp 
#'   column is not found.
add_datetime_from_timestamp <- function(df, timestamp_col = "timestamp") {
  if (!is.null(df) && nrow(df) > 0 && timestamp_col %in% names(df)) {
    df$datetime <- as.POSIXct(df[[timestamp_col]], format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  }
  df
}

#' Shared ggplot theme for all charts
#' 
#' Provides a consistent minimal theme for dashboard visualizations. Uses 
#' predefined color variables (clr$grid_line, clr$text_secondary) for 
#' maintaining visual consistency across all charts. Removes minor grid lines 
#' and positions legend at the bottom.
#' @return A ggplot theme object that can be added to any ggplot chart.
dash_theme <- function() {
  theme_minimal() +
    theme(
      panel.grid.major = element_line(color = clr$grid_line),
      panel.grid.minor = element_blank(),
      axis.text = element_text(size = 10, color = clr$text_secondary),
      axis.title = element_text(size = 11, color = clr$text_secondary),
      legend.position = "bottom",
      legend.text = element_text(size = 10, color = clr$text_secondary),
      legend.title = element_blank()
    )
}

#' Empty plot placeholder using ggplot (no Plotly warnings)
#' 
#' Creates a minimal placeholder plot with a centered text message. Uses 
#' ggplot for rendering and converts to Plotly for dashboard consistency. 
#' Avoids common Plotly warning messages that occur with empty plots.
#' @param message Character string to display as the placeholder message
#' @return A Plotly object with the placeholder message centered in a blank 
#'   plot area, ready for dashboard display.
create_empty_plot <- function(message) {
  p <- ggplot() + 
    annotate("text", x = 0.5, y = 0.5, label = message, 
             size = 5, color = clr$text_secondary) +
    theme_void() +
    theme(plot.background = element_rect(fill = "transparent", color = NA))
  ggplotly(p) %>%
    layout(hoverlabel = list(bgcolor = clr$bg),
           margin = list(l = 20, r = 20, t = 20, b = 20))
}

# ============================================================================
# USER INTERFACE (UI)
# ============================================================================
# Popover colors need to be hardcoded because popover cannot reach into the 
# custom.css file
ui <- fluidPage(
  title = "Simmons University | FitBit Research Dashboard",
  theme = bslib::bs_theme(version = 5) |>
    bslib::bs_add_rules("
    .popover-header {
      background-color: #8da3c0;
      color: #ffffff;
    }
  "),
  useShinyjs(),
  
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = paste0("custom.css?v=", as.numeric(Sys.time()))
    )
  ),
  
  # ==================== TOP BAR ====================
  div(class = "top-bar",
      h3("Simmons University | Fitbit Research Dashboard"),
      p("Physiological & Psychological Effects of Discrimination - STARS Program & BU Labs")
  ),
  
  # ==================== LOGIN SECTION ====================
  div(class = "login-section",
      uiOutput("login_ui"),
      div(class = "user-info", textOutput("login_status")),
      uiOutput("device_warning")
  ),
  
  # ==================== MAIN APP (hidden until Logged In) ====================
  div(id = "main_app", style = "display: none;",
      
      # ========== FILTERS ROW ==========
      # Contains view mode toggle, date picker, and study day slider
      div(class = "filters-row",
          
          # View mode toggle: Switch between Date and Study Day views
          div(id = "view_toggle_container",
              div(class = "view-toggle",
                  radioButtons("view_mode", NULL, 
                               choices = c("By Date" = "date", "By Study Day" = "day"),
                               selected = "date", 
                               inline = TRUE)
              )
          ),
          
          div(id = "date_picker_container",
              conditionalPanel(
                condition = "input.view_mode == 'date'",
                div(
                  tags$label("Select Date:", `for` = "date_range"),
                  dateRangeInput("date_range", NULL, 
                                 start = NULL, end = NULL, 
                                 width = "280px")
                )
              )
          ),
          
          div(id = "day_picker_container",
              conditionalPanel(
                condition = "input.view_mode == 'day'",
                uiOutput("day_range_ui")
              )
          ),
          
          # Admin participant selector (hidden for non-admins)
          div(id = "admin_selector_container", class = "admin-selector", style = "display: none;",
              div(
                tags$label("Participant:", `for` = "admin_participant-selectized", id = "participant-label"),
                selectInput("admin_participant", NULL,
                            choices = c("All Participants" = "ALL"),
                            width = "220px")
              )
          )
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
  
  # Render device warning message for users not logged in
  output$device_warning <- renderUI({
    if (!auth$logged_in) {
      div(style = "font-size: 12px; color: #8da3c0; margin-top: 4px;",
          bsicons::bs_icon("info-circle"), 
          " This app only supports full screen mode on desktop or laptop computers.")
    }
  })
  
  # ==================== REACTIVE VALUES ====================
  
  # Store participant ID for pre-analysis filtering
  pre_analysis_participant <- reactiveVal(NULL)
  
  # Authentication state: tracks login status, user identity, and permissions
  auth <- reactiveValues(
    logged_in = FALSE,
    participant_id = NULL,
    is_admin = FALSE,
    selected_participant = NULL
  )
  
  # Tracks collapsed/expanded state per chart_id for this session.
  # TRUE = collapsed, FALSE = open. Populated lazily — a chart_id only
  # gets an entry here once init_chart_card(chart_id, is_admin) has run
  # for it at least once (see helper function below).
  chart_state <- reactiveValues()
  
  # ==================== CHART CARD INITIALIZATION ====================
  # Call this once per chart_id, anywhere in server, to wire up that
  # chart's collapse/expand toggle. This is the only server-side setup
  # required per chart — chart_card_ui() in the UI side handles the rest.
  #
  # is_admin here only matters the FIRST time this chart_id is seen in
  # this session (it seeds the starting collapsed/open state). After
  # that, chart_state persists for the session regardless of is_admin.
  #
  # SAFE TO CALL MULTIPLE TIMES: tab content functions (e.g.
  # heart_rate_tab_content()) can re-run whenever dynamic_tabs re-renders
  # (e.g. login state changes). chart_observers_registered guards against
  # duplicate observeEvent registration, so calling this again for the
  # same chart_id is a safe no-op for the observer/seed parts.
  chart_observers_registered <- reactiveValues()
  
  init_chart_card <- function(chart_id, is_admin) {
    
    toggle_ui_id    <- paste0(chart_id, "_toggle_ui")
    toggle_click_id <- paste0(chart_id, "_toggle_click")
    body_id         <- paste0(chart_id, "_body")
    
    # Seed initial state once. isolate() prevents this from creating a
    # reactive dependency on chart_state itself (which would cause this
    # whole function to needlessly re-run every time ANY chart's state
    # changes, not just this one).
    if (is.null(isolate(chart_state[[chart_id]]))) {
      starts_collapsed <- isTRUE(is_admin)
      chart_state[[chart_id]] <- starts_collapsed  # TRUE = start collapsed
      
      if (starts_collapsed) {
        shinyjs::delay(100, shinyjs::hide(body_id))
      } else {
        shinyjs::delay(100, shinyjs::show(body_id))
      }
    }
    
    # Render the toggle icon + its clickable link. Re-runs automatically
    # whenever chart_state[[chart_id]] changes (via the click observer
    # below, or any future code that sets it).
    output[[toggle_ui_id]] <- renderUI({
      collapsed <- isTRUE(chart_state[[chart_id]])
      
      icon_name  <- if (collapsed) "eye-slash-fill" else "eye"
      icon_class <- if (collapsed) "chart-toggle-collapsed" else "chart-toggle-open"
      
      actionLink(
        inputId = toggle_click_id,
        label = bsicons::bs_icon(icon_name),
        class = paste("chart-toggle-trigger", icon_class)
      )
    })
    
    # Guard: only register the click observer once per chart_id per
    # session, even if init_chart_card() is called again later (e.g. tab
    # content function re-runs on login state change). Without this guard,
    # repeated calls would stack duplicate observers on the same input,
    # causing a single click to fire the toggle logic multiple times.
    if (isTRUE(isolate(chart_observers_registered[[chart_id]]))) {
      return(invisible(NULL))
    }
    chart_observers_registered[[chart_id]] <- TRUE
    
    # Click handler: flips this chart's state and shows/hides its body.
    # ignoreInit = TRUE so this doesn't fire on app load, only on actual clicks.
    observeEvent(input[[toggle_click_id]], {
      new_collapsed <- !isTRUE(chart_state[[chart_id]])
      chart_state[[chart_id]] <- new_collapsed
      
      if (new_collapsed) {
        shinyjs::hide(body_id)
      } else {
        shinyjs::show(body_id)
        shinyjs::delay(300, shinyjs::runjs("window.dispatchEvent(new Event('resize'));"))
      }
    }, ignoreInit = TRUE)
  }
  
  # ==================== METRIC CARD INITIALIZATION ====================
  # Initializes toggle functionality for metric cards. Similar to chart card 
  # initialization but handles metric value display and hidden placeholder 
  # elements. Uses the same chart_state reactive values for consistency.
  init_metric_card <- function(card_id, is_admin) {
    toggle_ui_id    <- paste0(card_id, "_toggle_ui")
    toggle_click_id <- paste0(card_id, "_toggle_click")
    value_id        <- paste0(card_id, "_value")
    hidden_id       <- paste0(card_id, "_hidden")
    
    # Seed initial hidden state once per card per session
    if (is.null(isolate(chart_state[[card_id]]))) {
      starts_hidden <- isTRUE(is_admin)
      chart_state[[card_id]] <- starts_hidden
      
      if (starts_hidden) {
        shinyjs::delay(100, {
          shinyjs::hide(value_id)
          shinyjs::show(hidden_id)
        })
      } else {
        shinyjs::delay(100, {
          shinyjs::show(value_id)
          shinyjs::hide(hidden_id)
        })
      }
    }
    
    # Render toggle icon that shows/hides the metric value
    output[[toggle_ui_id]] <- renderUI({
      hidden <- isTRUE(chart_state[[card_id]])
      icon_name  <- if (hidden) "eye-slash-fill" else "eye"
      icon_class <- if (hidden) "chart-toggle-collapsed" else "chart-toggle-open"
      actionLink(
        inputId = toggle_click_id,
        label   = bsicons::bs_icon(icon_name, size = "0.8em"),
        class   = paste("chart-toggle-trigger", icon_class)
      )
    })
    
    # Guard against duplicate observer registration
    if (isTRUE(isolate(chart_observers_registered[[card_id]]))) {
      return(invisible(NULL))
    }
    chart_observers_registered[[card_id]] <- TRUE
    
    # Click handler toggles visibility between value and hidden placeholder
    observeEvent(input[[toggle_click_id]], {
      now_hidden <- !isTRUE(chart_state[[card_id]])
      chart_state[[card_id]] <- now_hidden
      
      if (now_hidden) {
        shinyjs::hide(value_id)
        shinyjs::show(hidden_id)
      } else {
        shinyjs::show(value_id)
        shinyjs::hide(hidden_id)
      }
    }, ignoreInit = TRUE)
  }
  
  # ==================== LOGIN UI (swaps form ↔ logout button) ====================
  
  # Render login form or logout button based on authentication state
  output$login_ui <- renderUI({
    if (auth$logged_in) {
      div(class = "login-form",
          actionButton("logout_btn", "Logout", class = "btn-danger")
      )
    } else {
      div(class = "login-form",
          textInput("participant_id", NULL,
                    placeholder = "Enter your Participant ID",
                    width = "220px"),
          actionButton("login_btn", "Login", class = "btn-primary")
      )
    }
  })
  
  # ==================== LOGOUT HANDLER ====================
  
  # Handle user logout: reset authentication state, clear chart states, 
  # hide main app and admin controls, and clear login status message
  observeEvent(input$logout_btn, {
    auth$logged_in         <- FALSE
    auth$participant_id    <- NULL
    auth$is_admin          <- FALSE
    auth$selected_participant <- NULL
    
    # Reset chart collapse state so the next login (possibly a different
    # user with a different is_admin) gets a fresh seed instead of
    # inheriting collapse states from this session.
    for (chart_id in names(chart_state)) {
      chart_state[[chart_id]] <- NULL
    }
    
    shinyjs::hide("main_app")
    shinyjs::hide("admin_selector_container")
    
    output$login_status <- renderText({ "" })
  })
  
  # ==================== DATA LOADING ====================
  
  # Load all data including study_day, day_of_week, and day_type columns
  all_data <- reactive({
    load_all_data()
  })
  
  # Load roles configuration from roles.csv
  roles_df <- reactive({
    load_roles()
  })
  
  # Extract and sort all unique participant IDs from loaded data
  all_participants <- reactive({
    data <- all_data()
    get_all_participants(data)
  })
  
  # Populate admin participant dropdown with available participants
  observe({
    participants <- all_participants()
    if (length(participants) > 0) {
      updateSelectInput(session, "admin_participant",
                        choices = c("All Participants" = "ALL", participants))
    }
  })
  
  # ==================== LOGIN HANDLER ====================
  
  # Process login attempt: validate credentials, set authentication state,
  # initialize UI, and configure admin access if applicable
  observeEvent(input$login_btn, {
    participant_id <- trimws(input$participant_id)
    
    # Validate that participant ID is not empty
    if (participant_id == "") {
      showNotification("Please enter a Participant ID", type = "error")
      return()
    }
    
    roles <- roles_df()
    is_admin <- is_admin_user(participant_id, roles)
    
    # For non-admin users, verify participant exists in the data
    if (!is_admin) {
      participants_list <- all_participants()
      if (!(participant_id %in% participants_list)) {
        showNotification("Participant ID not found. Please check and try again.", 
                         type = "error")
        return()
      }
    }
    
    # Set authentication state
    auth$logged_in <- TRUE
    auth$participant_id <- participant_id
    auth$is_admin <- is_admin
    auth$selected_participant <- participant_id
    
    # Show main application UI
    shinyjs::show("main_app")
    
    # Set initial date range from tokenSheet for this participant
    dates <- get_participant_dates(all_data(), participant_id)
    updateDateRangeInput(session, "date_range",
                         start = dates$start,
                         end   = dates$end)
    
    # Show admin controls if user has admin privileges
    if (is_admin) {
      shinyjs::show("admin_selector_container")
    }
    
    # Display login status message
    output$login_status <- renderText({
      if (is_admin) {
        paste("Logged in as:", participant_id, "(Admin)")
      } else {
        paste("Logged in as:", participant_id)
      }
    })
    # Trigger resize event to ensure proper rendering of all UI elements
    shinyjs::delay(300, shinyjs::runjs("window.dispatchEvent(new Event('resize'));"))
  })
  
  # ==================== UPDATE DATE RANGE WHEN ADMIN SWITCHES PARTICIPANT ====================
  
  # Update date range picker when admin selects a different participant
  observeEvent(input$admin_participant, {
    req(auth$logged_in, auth$is_admin)
    
    # Convert "ALL" selection to NULL for full date range, otherwise use selected participant
    participant <- if (input$admin_participant == "ALL") NULL else input$admin_participant
    dates <- get_participant_dates(all_data(), participant)
    
    updateDateRangeInput(session, "date_range",
                         start = dates$start,
                         end   = dates$end)
  })
  
  # ==================== TOOLBAR VISIBILITY ====================
  # Control visibility of toolbar elements based on current tab, user role, 
  # and participant selection context
  observe({
    req(auth$logged_in)
    
    tab <- input$main_tabs
    is_admin <- auth$is_admin
    participant <- if (is_admin) input$admin_participant else "INDIVIDUAL"
    is_all <- is_admin && participant == "ALL"
    is_analysis <- !is.null(tab) && tab == "Analysis"
    is_data_view <- !is.null(tab) && tab == "Data View"
    
    # Data View tab: show all toolbar elements unchanged
    if (is_data_view) {
      shinyjs::show("view_toggle_container")
      shinyjs::show("date_picker_container")
      shinyjs::show("day_picker_container")
      shinyjs::show("admin_selector_container")
      return()
    }
    
    # Analysis tab: simplify toolbar, force day view and ALL participants
    if (is_analysis) {
      # Save current participant selection before forcing ALL
      if (!is.null(input$admin_participant) && input$admin_participant != "ALL") {
        pre_analysis_participant(input$admin_participant)
      }
      shinyjs::hide("view_toggle_container")
      shinyjs::hide("date_picker_container")
      shinyjs::hide("admin_selector_container")
      updateRadioButtons(session, "view_mode", selected = "day")
      updateSelectInput(session, "admin_participant", selected = "ALL")
      return()
    }
    
    # Restore previous participant selection when leaving Analysis tab
    if (!is.null(pre_analysis_participant())) {
      updateSelectInput(session, "admin_participant", 
                        selected = pre_analysis_participant())
      pre_analysis_participant(NULL)
    }
    
    # All Participants view on user tabs: hide radio and date picker
    if (is_all) {
      shinyjs::hide("view_toggle_container")
      shinyjs::hide("date_picker_container")
      shinyjs::show("admin_selector_container")
      updateRadioButtons(session, "view_mode", selected = "day")
      return()
    }
    
    # Individual participant or regular user: show full toolbar
    shinyjs::show("view_toggle_container")
    shinyjs::show("date_picker_container")
    if (auth$is_admin) {
      shinyjs::show("admin_selector_container")
    } else {
      shinyjs::hide("admin_selector_container")
    }
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
    
    # Filter token sheet to current participant if one is selected
    participant <- current_participant()
    if (!is.null(participant)) {
      token <- token[token$participantID == participant, ]
    }
    
    if (nrow(token) == 0) {
      return(div("No data for selected participant"))
    }
    
    # Determine date range from token sheet
    start_date <- min(as.Date(token$start_date), na.rm = TRUE)
    end_date   <- max(as.Date(token$end_date),   na.rm = TRUE)
    
    # Build day labels: "Day 1 - Monday", "Day 2 - Tuesday", etc.
    n_days <- as.integer(end_date - start_date) + 1
    dates_seq <- seq(start_date, end_date, by = "day")
    #day_labels <- paste0("Day ", seq_len(n_days), " - ", weekdays(dates_seq))
    #day_labels <- paste0("Day ", seq_len(n_days), ": ", strftime(dates_seq, "%a"))
    # -- fix: show abbreviated weekday names only when a participant is selected
    day_labels <- if (is.null(current_participant())) {
      paste0("Day ", seq_len(n_days))
    } else {
      paste0("Day ", seq_len(n_days), ": ", strftime(dates_seq, "%a"))
    }
    
    # Render start and end day selectors
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
  
  # Filter data by participant and optionally by date or study day range
  filtered_data <- reactive({
    req(auth$logged_in)
    
    data <- all_data()
    participant <- current_participant()
    date_range <- input$date_range
    
    # Apply participant filter to all dataframes containing participantID
    if (!is.null(participant)) {
      data <- lapply(data, function(df) {
        if ("participantID" %in% names(df)) {
          df <- df[df$participantID == participant, ]
        }
        df
      })
    }
    
    # Apply date range filter (only used in "date" view mode)
    if (!is.null(date_range)) {
      data <- lapply(data, function(df) {
        # Filter by 'date' column if present
        if ("date" %in% names(df)) {
          df$date <- as.Date(df$date)
          df <- df[df$date >= date_range[1] & df$date <= date_range[2], ]
        }
        
        # Filter by 'dateOfSleep' column if 'date' not present
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
    
    # If in date view mode, return unfiltered by study day
    if (input$view_mode == "date") {
      return(data)
    }
    
    req(input$study_day_start, input$study_day_end)
    
    # Extract numeric day from label (e.g., "Day 3 - Wednesday" or "Day 3" → 3)
    #day_start <- as.integer(sub("Day (\\d+) - .*", "\\1", input$study_day_start))
    #day_end   <- as.integer(sub("Day (\\d+) - .*", "\\1", input$study_day_end))
    #day_start <- as.integer(sub("Day (\\d+):.*", "\\1", input$study_day_start))
    #day_end   <- as.integer(sub("Day (\\d+):.*", "\\1", input$study_day_end))
    day_start <- as.integer(sub("Day (\\d+).*", "\\1", input$study_day_start))
    day_end   <- as.integer(sub("Day (\\d+).*", "\\1", input$study_day_end))
    
    # Apply study day filter to all dataframes containing study_day column
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
      # Calculate rolling average for trend visualization
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
  
  # HRV vs Sleep data (joined for Projections tab)
  hrv_sleep_data <- reactive({
    req(auth$logged_in)
    hrv <- filtered_data_by_day()[["hrv_intraday"]]
    metrics <- filtered_data_by_day()[["daily_metrics"]]
    
    if (is.null(hrv) || nrow(hrv) == 0 || is.null(metrics) || nrow(metrics) == 0) {
      return(NULL)
    }
    
    # Aggregate HRV to daily level
    hrv_daily <- hrv %>%
      mutate(date = as.Date(substr(timestamp, 1, 10))) %>%
      group_by(participantID, date) %>%
      summarise(hrv_avg = mean(rmssd_ms, na.rm = TRUE), .groups = "drop")
    
    # Clean metrics and select relevant columns
    metrics_clean <- metrics %>%
      mutate(date = as.Date(date)) %>%
      select(participantID, date, total_sleep_minutes, study_day)
    
    # Join HRV with sleep metrics
    hrv_daily %>%
      inner_join(metrics_clean, by = c("participantID", "date")) %>%
      filter(!is.na(hrv_avg), !is.na(total_sleep_minutes),
             total_sleep_minutes > 0, hrv_avg > 0)
  })
  
  # ==================== METRIC CARDS ====================
  # Summary statistics shown at the top of the Overview tab
  
  # Average heart rate metric card
  output$card_hr <- renderText({
    req(auth$logged_in)
    df <- hr_data()
    if (is.null(df) || nrow(df) == 0) return("—")
    avg_hr <- mean(df$heart_rate_avg, na.rm = TRUE)
    paste(round(avg_hr))
  })
  
  # Average daily steps metric card
  output$card_steps <- renderText({
    req(auth$logged_in)
    df <- steps_data()
    if (is.null(df) || nrow(df) == 0) return("—")
    # Calculate total steps per day then average across days
    daily_steps <- df %>%
      mutate(date = as.Date(date)) %>%
      group_by(date) %>%
      summarise(total = sum(steps_5min, na.rm = TRUE))
    format(round(mean(daily_steps$total, na.rm = TRUE)), big.mark = ",")
  })
  
  # Average deep sleep minutes per night metric card
  output$card_sleep <- renderText({
    req(auth$logged_in)
    df <- sleep_data()
    if (is.null(df) || nrow(df) == 0) return("—")
    # Calculate deep sleep minutes per night
    deep_by_night <- df %>%
      filter(sleep_stage == "deep") %>%
      group_by(dateOfSleep) %>%
      summarise(deep_minutes = n())
    paste(round(mean(deep_by_night$deep_minutes, na.rm = TRUE), 0))
  })
  
  # Average SpO2 level metric card
  output$card_spo2 <- renderText({
    req(auth$logged_in)
    df <- spo2_data()
    if (is.null(df) || nrow(df) == 0) return("—")
    avg_spo2 <- mean(df$value, na.rm = TRUE)
    paste(round(avg_spo2, 1))
  })
  
  
  
  
  
  # ==================== DYNAMIC TABS ====================
  # --- PERMISSION-WIRED: tab visibility is driven by 
  # ALL_USER_TABS / ADMIN_ONLY_TABS, see top of file ---
  
  # Render dynamic tabs based on user permissions and tab registry
  output$dynamic_tabs <- renderUI({
    req(auth$logged_in)
    
    # Map of tab name -> content function.
    # Every tab must be registered here.
    tab_registry <- list(
      "Overview"    = overview_tab_content,
      "Heart Rate"  = heart_rate_tab_content,
      "Sleep"       = sleep_tab_content,
      "Activity"    = activity_tab_content,
      "Insights"    = insights_tab_content,
      "Projections" = projections_tab_content,
      "Analysis"    = analysis_tab_content,
      "Data View"   = data_view_tab_content
    )
    
    # Determine which tab names this user is allowed to see
    visible_tab_names <- if (auth$is_admin) {
      c(ALL_USER_TABS, ADMIN_ONLY_TABS)
    } else {
      ALL_USER_TABS
    }
    
    # Build tabPanel() calls only for visible tabs,
    # preserving the order given in ALL_USER_TABS / ADMIN_ONLY_TABS
    tab_panels <- lapply(visible_tab_names, function(tab_name) {
      content_fn <- tab_registry[[tab_name]]
      # Skip tabs that are listed but not registered
      if (is.null(content_fn)) {
        warning(paste0("Tab '", tab_name, "' is listed in ALL_USER_TABS or ",
                       "ADMIN_ONLY_TABS but has no entry in tab_registry. Skipping."))
        return(NULL)
      }
      tabPanel(tab_name, content_fn(is_admin = auth$is_admin))
    })
    
    # Drop any NULLs from unmatched tabs before passing to tabsetPanel
    tab_panels <- Filter(Negate(is.null), tab_panels)
    
    # Create tabsetPanel with all visible tabs
    do.call(tabsetPanel, c(list(id = "main_tabs"), tab_panels))
  })
  
  # ==================== TAB CONTENT FUNCTIONS ====================
  # Each function returns UI content for its respective tab
  
  # Overview tab: displays metric cards and key charts for heart rate, steps, and sleep
  overview_tab_content <- function(is_admin) {
    # Initialize chart and metric card toggle functionality
    init_chart_card("plot_hr", is_admin)
    init_chart_card("plot_steps", is_admin)
    init_chart_card("plot_sleep", is_admin)
    init_metric_card("kpi_hr", is_admin)
    init_metric_card("kpi_steps", is_admin)
    init_metric_card("kpi_sleep", is_admin)
    init_metric_card("kpi_spo2", is_admin)
    
    # Build UI layout: metric cards in top row, charts below
    tagList(
      br(),
      fluidRow(
        column(3, metric_card_ui("kpi_hr",    "AVG HEART RATE",  "card_hr",
                                 unit = "bpm",     is_admin = is_admin)),
        column(3, metric_card_ui("kpi_steps", "AVG DAILY STEPS", "card_steps",
                                 unit = "steps",   is_admin = is_admin)),
        column(3, metric_card_ui("kpi_sleep", "AVG DEEP SLEEP",  "card_sleep",
                                 unit = "minutes", is_admin = is_admin)),
        column(3, metric_card_ui("kpi_spo2",  "AVG SPO2",        "card_spo2",
                                 unit = "%",       is_admin = is_admin))
      ),
      
      br(),
      fluidRow(
        column(6, chart_card_ui(
          chart_id  = "plot_hr",
          title     = "Heart Rate Over Time",
          output_fn = plotlyOutput,
          is_admin  = is_admin,
          height    = "280px"
        )),
        column(6, chart_card_ui(
          chart_id  = "plot_steps",
          title     = "Daily Steps",
          output_fn = plotlyOutput,
          is_admin  = is_admin,
          height    = "280px"
        ))
      ),
      fluidRow(
        column(12, chart_card_ui(
          chart_id  = "plot_sleep",
          title     = "Sleep Stage Breakdown",
          output_fn = plotlyOutput,
          is_admin  = is_admin,
          height    = "280px"
        ))
      )
    )
  }
  
  # ================= Heart Rate Tab =================
  
  # Heart Rate tab: displays time series, distribution, hourly patterns, and HRV charts
  heart_rate_tab_content <- function(is_admin) {
    # Initialize chart toggle functionality for all heart rate charts
    init_chart_card("hr_timeseries", is_admin)
    init_chart_card("hr_distribution", is_admin)
    init_chart_card("hr_by_hour", is_admin)
    
    # Build UI layout with heart rate visualizations
    tagList(
      br(),
      fluidRow(
        # Heart Rate Time Series (with admin toggle for aggregate/split view)
        column(12, chart_card_ui(
          chart_id  = "hr_timeseries",
          title     = "Heart Rate Time Series",
          output_fn = plotlyOutput,
          is_admin  = is_admin,
          height    = "400px",
          extra_ui  = if (is_admin) {
            radioButtons("hr_timeseries_view", NULL,
                         choices = c("Aggregate" = "aggregate", "Split by Participant" = "split"),
                         selected = "aggregate", inline = TRUE)
          }
        ))
      ),
      # Heart Rate Distribution and Hourly Patterns
      fluidRow(
        column(6, chart_card_ui(
          chart_id  = "hr_distribution",
          title     = "Heart Rate Distribution",
          output_fn = plotlyOutput,
          is_admin  = is_admin,
          height    = "300px"
        )),
        # Heart Rate by Hour of Day (with admin toggle for aggregate/split view)
        column(6, chart_card_ui(
          chart_id  = "hr_by_hour",
          title     = "Heart Rate by Hour of Day",
          output_fn = plotlyOutput,
          is_admin  = is_admin,
          height    = "300px",
          extra_ui  = if (is_admin) {
            radioButtons("hr_by_hour_view", NULL,
                         choices = c("Aggregate" = "aggregate", "Split by Participant" = "split"),
                         selected = "aggregate", inline = TRUE)
          }
        ))
      ),
      # Heart Rate Variability (conditional on admin permissions or accessible to all)
      if (is_admin || !("hrv_chart" %in% ADMIN_ONLY_CHARTS)) {
        init_chart_card("hrv_chart", is_admin)
        fluidRow(
          column(12, chart_card_ui(
            chart_id  = "hrv_chart",
            title     = "Heart Rate Variability (HRV)",
            output_fn = plotlyOutput,
            is_admin  = is_admin,
            height    = "300px"
          ))
        )
      }
    )
  }
  
  # ================= SLEEP Tab =================
  
  # Sleep tab: displays sleep duration, stage distribution, breathing rate,
  # hypnogram, and sleep efficiency visualizations
  sleep_tab_content <- function(is_admin) {
    # Initialize chart toggle functionality for all sleep charts
    init_chart_card("sleep_duration", is_admin)
    init_chart_card("sleep_stage_pie", is_admin)
    init_chart_card("breathing_rate_chart", is_admin)
    init_chart_card("hypnogram_chart", is_admin)
    init_chart_card("sleep_efficiency_chart", is_admin)
    
    # Build UI layout with sleep visualizations
    tagList(
      br(),
      fluidRow(
        # Sleep duration time series and stage distribution
        column(6, chart_card_ui(
          chart_id  = "sleep_duration",
          title     = "Sleep Duration Over Time",
          output_fn = plotlyOutput,
          is_admin  = is_admin,
          height    = "300px"
        )),
        column(6, chart_card_ui(
          chart_id  = "sleep_stage_pie",
          title     = "Sleep Stage Distribution",
          output_fn = plotlyOutput,
          is_admin  = is_admin,
          height    = "300px"
        ))
      ),
      fluidRow(
        # Breathing rate during sleep
        column(12, chart_card_ui(
          chart_id  = "breathing_rate_chart",
          title     = "Breathing Rate During Sleep",
          output_fn = plotlyOutput,
          is_admin  = is_admin,
          height    = "300px"
        ))
      ),
      fluidRow(
        # Hypnogram with night selector
        column(12, chart_card_ui(
          chart_id  = "hypnogram_chart",
          title     = "Hypnogram",
          output_fn = plotlyOutput,
          is_admin  = is_admin,
          height    = "300px",
          extra_ui  = div(id = "hypnogram_date_container",
                          selectInput("hypnogram_date", "Select night:", choices = NULL, width = "200px"))
        ))
      ),
      fluidRow(
        # Sleep efficiency with admin toggle for aggregate/split view
        column(12, chart_card_ui(
          chart_id  = "sleep_efficiency_chart",
          title     = "Sleep Efficiency",
          output_fn = plotlyOutput,
          is_admin  = is_admin,
          height    = "300px",
          extra_ui  = if (is_admin) {
            radioButtons("sleep_efficiency_view", NULL,
                         choices = c("Aggregate" = "aggregate", "Split by Participant" = "split"),
                         selected = "aggregate", inline = TRUE)
          }
        ))
      )
    )
  }
  
  # ================= ACTIVITY TAB =================
  
  # Activity tab: displays zone minutes, exercise sessions, sedentary periods,
  # steps, and distance visualizations for comprehensive activity analysis
  activity_tab_content <- function(is_admin) {
    # Initialize chart toggle functionality for all activity charts
    init_chart_card("zone_minutes_chart", is_admin)
    init_chart_card("exercise_sessions_chart", is_admin)
    init_chart_card("sedentary_chart", is_admin)
    init_chart_card("activity_steps_chart", is_admin)
    init_chart_card("activity_steps_by_hour", is_admin)
    init_chart_card("activity_distance_chart", is_admin)
    
    # Build UI layout with activity visualizations
    tagList(
      br(),
      fluidRow(
        # Heart Rate Zones (Fat Burn / Cardio / Peak)
        column(12, chart_card_ui(
          chart_id  = "zone_minutes_chart",
          title     = "Heart Rate Zones",
          output_fn = plotlyOutput,
          is_admin  = is_admin,
          height    = "300px"
        ))
      ),
      fluidRow(
        # Exercise Sessions
        column(12, chart_card_ui(
          chart_id  = "exercise_sessions_chart",
          title     = "Exercise Sessions",
          output_fn = plotlyOutput,
          is_admin  = is_admin,
          height    = "300px"
        ))
      ),
      fluidRow(
        column(6, chart_card_ui(
          chart_id  = "activity_steps_chart",
          title     = "Daily Steps",
          output_fn = plotlyOutput,
          is_admin  = is_admin,
          height    = "300px"
        )),
        column(6, chart_card_ui(
          chart_id  = "activity_distance_chart",
          title     = "Daily Distance",
          output_fn = plotlyOutput,
          is_admin  = is_admin,
          height    = "300px"
        ))
      ),
      fluidRow(
        column(6, chart_card_ui(
          chart_id  = "activity_steps_by_hour",
          title     = "Steps by Hour of Day",
          output_fn = plotlyOutput,
          is_admin  = is_admin,
          height    = "300px"
        )),
        column(6, chart_card_ui(
          chart_id  = "sedentary_chart",
          title     = "Sedentary Time",
          output_fn = plotlyOutput,
          is_admin  = is_admin,
          height    = "300px"
        ))
      )
    )
  }
  
  # ================= INSIGHTS Tab =================
  
  # Insights tab: displays weekday/weekend comparisons and key behavioral insights
  # such as best sleep night, most active day, and typical bedtime
  insights_tab_content <- function(is_admin) {
    # Initialize metric and chart cards for insights visualizations
    init_metric_card("insight_best_sleep_card", is_admin)
    init_metric_card("insight_most_active_card", is_admin)
    init_metric_card("insight_bedtime_card", is_admin)
    init_chart_card("weekday_sleep_chart", is_admin)
    init_chart_card("weekday_steps_chart", is_admin)  # ← Add this line
    # Admin-only insights charts
    if (is_admin) {
      init_chart_card("weekday_hrv_chart", is_admin)
      init_chart_card("weekday_hr_chart", is_admin)
    }
    
    # Build UI layout with insight metrics and weekday/weekend comparisons
    tagList(
      br(),
      fluidRow(
        # Key insight metric cards
        column(4, metric_card_ui("insight_best_sleep_card", "BEST SLEEP NIGHT",
                                 "insight_best_sleep", is_admin = is_admin,
                                 value_size = "medium")),
        column(4, metric_card_ui("insight_most_active_card", "MOST ACTIVE DAY",
                                 "insight_most_active", is_admin = is_admin,
                                 value_size = "medium")),
        column(4, metric_card_ui("insight_bedtime_card", "TYPICAL BEDTIME",
                                 "insight_typical_bedtime", is_admin = is_admin,
                                 value_size = "medium"))
      ),
      br(),
      fluidRow(
        # Weekday vs weekend comparisons for all users
        column(6, chart_card_ui(
          chart_id  = "weekday_sleep_chart",
          title     = "Sleep Duration: Weekday vs Weekend",
          output_fn = plotlyOutput,
          is_admin  = is_admin,
          height    = "300px"
        )),
        column(6, chart_card_ui(
          chart_id  = "weekday_steps_chart",
          title     = "Steps: Weekday vs Weekend",
          output_fn = plotlyOutput,
          is_admin  = is_admin,
          height    = "300px"
        ))
      ),
      # Admin-only HRV and HR weekday/weekend comparisons
      if (is_admin) {
        fluidRow(
          column(6, chart_card_ui(
            chart_id  = "weekday_hrv_chart",
            title     = "HRV: Weekday vs Weekend",
            output_fn = plotlyOutput,
            is_admin  = is_admin,
            height    = "300px"
          )),
          column(6, chart_card_ui(
            chart_id  = "weekday_hr_chart",
            title     = "Resting Heart Rate: Weekday vs Weekend",
            output_fn = plotlyOutput,
            is_admin  = is_admin,
            height    = "300px"
          ))
        )
      }
    )
  }
  
  # ================= PROJECTIONS Tab =================
  
  # Projections tab: displays the relationship between HRV and sleep duration
  projections_tab_content <- function(is_admin) {
    # Initialize chart toggle functionality for HRV vs sleep chart
    init_chart_card("hrv_sleep_chart", is_admin)
    
    # Build UI layout with HRV vs sleep duration scatter plot
    tagList(
      br(),
      fluidRow(
        column(12, chart_card_ui(
          chart_id  = "hrv_sleep_chart",
          title     = "HRV vs Sleep Duration",
          output_fn = plotlyOutput,
          is_admin  = is_admin,
          height    = "450px"
        ))
      )
    )
  }
  
  # ================= ANALYSIS Tab =================
  
  # Analysis tab: admin-only multi-participant comparisons including heart rate,
  # steps, data completeness heatmap, and participant summary table
  analysis_tab_content <- function(is_admin) {
    # Initialize chart toggle functionality for all analysis charts
    init_chart_card("admin_hr_comparison", is_admin)
    init_chart_card("admin_steps_comparison", is_admin)
    init_chart_card("admin_completeness_heatmap", is_admin)
    init_chart_card("admin_summary_table", is_admin)
    
    # Build UI layout with multi-participant analysis visualizations
    tagList(
      br(),
      fluidRow(
        # Heart rate comparison across participants
        column(12, chart_card_ui(
          chart_id  = "admin_hr_comparison",
          title     = "Multi-Participant Heart Rate Comparison",
          output_fn = plotlyOutput,
          is_admin  = is_admin,
          height    = "320px"
        ))
      ),
      fluidRow(
        # Steps comparison across participants
        column(12, chart_card_ui(
          chart_id  = "admin_steps_comparison",
          title     = "Multi-Participant Steps Comparison",
          output_fn = plotlyOutput,
          is_admin  = is_admin,
          height    = "320px"
        ))
      ),
      fluidRow(
        # Data completeness heatmap showing missing data patterns
        column(12, chart_card_ui(
          chart_id  = "admin_completeness_heatmap",
          title     = "Data Completeness Heatmap",
          output_fn = plotlyOutput,
          is_admin  = is_admin,
          height    = "300px"
        ))
      ),
      fluidRow(
        # Participant activity summary table
        column(12, chart_card_ui(
          chart_id  = "admin_summary_table",
          title     = "Participant Activity Summary",
          output_fn = DTOutput,
          is_admin  = is_admin
        ))
      )
    )
  }
  
  # ================= DATA Tab =================
  
  # Data View tab: allows users to browse raw data from any dataset
  # with a dropdown selector for choosing which dataset to display
  data_view_tab_content <- function(is_admin) {
    # Initialize chart toggle functionality for data table
    init_chart_card("data_view_table", is_admin)
    
    # Build UI layout with dataset selector and data table
    tagList(
      br(),
      fluidRow(
        column(12, chart_card_ui(
          chart_id  = "data_view_table",
          title     = "Raw Data Viewer",
          output_fn = DT::dataTableOutput,
          is_admin  = is_admin,
          extra_ui  = tagList(
            p("Select a dataset to view its raw contents."),
            selectInput("data_view_select", "Choose Dataset",
                        choices = c("Heart Rate", "Steps", "Sleep", "Daily Metrics",
                                    "HRV", "Activity Level", "Zone Minutes",
                                    "Activity Sessions", "Sedentary Periods", "SpO2"),
                        width = "300px")
          )
        ))
      )
    )
  }
  
  # ================================================
  # ==================== CHARTS ====================
  # ================================================
  
  # ==================== OVERVIEW TAB CHARTS ====================
  
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
      is_all <- auth$is_admin && is.null(current_participant())
      
      if (is_all) {
        # Aggregate all participants by study day
        df <- df %>%
          group_by(study_day) %>%
          summarise(heart_rate_avg = mean(heart_rate_avg, na.rm = TRUE),
                    .groups = "drop")
        
        p <- ggplot(df, aes(x = study_day, y = heart_rate_avg)) +
          geom_line(color = clr$hr, linewidth = 0.5, alpha = 0.8) +
          geom_point(color = clr$hr, size = 2, alpha = 0.8) +
          labs(x = "Study Day", y = "Avg bpm (all participants)") +
          scale_x_continuous(breaks = scales::pretty_breaks()) +
          dash_theme()
      } else {
        # Single participant by study day
        df <- df %>%
          group_by(study_day) %>%
          summarise(heart_rate_avg = mean(heart_rate_avg, na.rm = TRUE)) %>%
          ungroup()
        
        p <- ggplot(df, aes(x = study_day, y = heart_rate_avg)) +
          geom_line(color = clr$hr, linewidth = 0.5, alpha = 0.8) +
          labs(x = "Study Day", y = "bpm") +
          dash_theme()
      }
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
      is_all <- auth$is_admin && is.null(current_participant())
      
      if (is_all) {
        # Aggregate all participants: calculate daily totals per participant, then average across participants
        daily_steps <- df %>%
          group_by(participantID, study_day) %>%
          summarise(total = sum(steps_5min, na.rm = TRUE), .groups = "drop") %>%
          group_by(study_day) %>%
          summarise(total = mean(total, na.rm = TRUE), .groups = "drop")
      } else {
        # Single participant: daily totals
        daily_steps <- df %>%
          group_by(study_day) %>%
          summarise(total = sum(steps_5min, na.rm = TRUE))
      }
      
      p <- ggplot(daily_steps, aes(x = study_day, y = total)) +
        geom_col(fill = clr$steps, width = 0.7, alpha = 0.9) +
        geom_hline(yintercept = 10000, linetype = "dashed", 
                   color = clr$target_line, linewidth = 0.5) +
        scale_y_continuous(labels = scales::comma) +
        labs(x = "Study Day", 
             y = if (is_all) "Avg steps (all participants)" else "steps") +
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
                   color = clr$target_line, linewidth = 0.5) +
        scale_y_continuous(labels = scales::comma) +
        scale_x_date(date_labels = "%b %d") +
        labs(x = NULL, y = "steps") +
        dash_theme()
    }
    
    ggplotly(p) %>% 
      layout(hoverlabel = list(bgcolor = clr$bg),
             margin = list(l = 50, r = 20, t = 20, b = 40))
  })
  
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
    
    # Summarize sleep stages by night
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
      # Fallback if no study_day column exists
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
    
    # Study day view
    if (input$view_mode == "day" && has_study_day) {
      is_all <- auth$is_admin && is.null(current_participant())
      
      if (is_all) {
        # Average sleep stages across all participants
        sleep_summary <- sleep_summary %>%
          group_by(study_day, sleep_stage) %>%
          summarise(minutes = mean(minutes, na.rm = TRUE), .groups = "drop")
      }
      
      p <- ggplot(sleep_summary, aes(x = study_day, y = minutes, fill = sleep_stage)) +
        geom_col(width = 0.7, alpha = 0.9) +
        scale_fill_manual(values = c(Deep = clr$deep, REM = clr$rem, Light = clr$light)) +
        labs(x = "Study Day",
             y = if (is_all) "Avg minutes (all participants)" else "minutes",
             fill = "Sleep Stage") +
        dash_theme()
    } else {
      # Date view: show calendar dates on x-axis
      p <- ggplot(sleep_summary, aes(x = as.Date(dateOfSleep), y = minutes, fill = sleep_stage)) +
        geom_col(width = 0.7, alpha = 0.9) +
        scale_fill_manual(values = c(Deep = clr$deep, REM = clr$rem, Light = clr$light)) +
        scale_x_date(date_labels = "%b %d") +
        labs(x = NULL, y = "minutes", fill = "Sleep Stage") +
        dash_theme()
      
      # If we're in day mode but no study_day, show a warning in the plot title
      if (input$view_mode == "day" && !has_study_day) {
        p <- p + labs(title = "Study Day view not available for sleep data (using dates instead)")
      }
    }
    
    ggplotly(p) %>% 
      layout(hoverlabel = list(bgcolor = clr$bg),
             legend = list(orientation = "h", xanchor = "center", 
                           x = 0.5, y = -0.5),
             margin = list(l = 50, r = 20, t = 50, b = 80))
  })
  

  # ==================== HEART RATE TAB CHARTS ====================
  
  # Heart Rate Time Series
  # Shows heart rate trends over time with aggregate or split views for admins
  output$hr_timeseries <- renderPlotly({
    req(auth$logged_in)
    df <- hr_data()
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No heart rate data available"))
    }
    
    if (input$view_mode == "day") {
      
      is_all <- auth$is_admin && is.null(current_participant())
      
      split_view <- is_all && !is.null(input$hr_timeseries_view) && 
        input$hr_timeseries_view == "split"
      
      if (split_view) {
        # Split view: show each participant as separate line
        chart_data <- df %>%
          group_by(participantID, study_day) %>%
          summarise(heart_rate_avg = mean(heart_rate_avg, na.rm = TRUE), .groups = "drop")
        
        p <- ggplot(chart_data, aes(x = study_day, y = heart_rate_avg,
                                    color = participantID, group = participantID)) +
          geom_line(linewidth = 0.8, alpha = 0.9) +
          geom_point(size = 2.5, alpha = 0.9) +
          labs(x = "Study Day", y = "Heart Rate (bpm)") +
          scale_x_continuous(breaks = scales::pretty_breaks()) +
          scale_y_continuous(breaks = scales::pretty_breaks(n = 6)) +
          dash_theme()
      } else {
        # Aggregate view: average across all participants
        chart_data <- df %>%
          group_by(study_day) %>%
          summarise(heart_rate_avg = mean(heart_rate_avg, na.rm = TRUE), .groups = "drop")
        
        p <- ggplot(chart_data, aes(x = study_day, y = heart_rate_avg)) +
          geom_line(color = clr$hr, linewidth = 0.8, alpha = 0.9) +
          geom_point(color = clr$hr, size = 2.5, alpha = 0.9) +
          labs(x = "Study Day",
               y = if (is_all) "Avg Heart Rate (bpm, all participants)" else "Heart Rate (bpm)") +
          scale_x_continuous(breaks = scales::pretty_breaks()) +
          scale_y_continuous(breaks = scales::pretty_breaks(n = 6)) +
          dash_theme()
      }
      
    } else {
      # Date view: show datetime on x-axis with LOESS smoothing
      chart_data <- df %>%
        filter(!is.na(datetime))
      
      p <- ggplot(chart_data, aes(x = datetime, y = heart_rate_avg)) +
        geom_line(color = clr$hr, linewidth = 0.3, alpha = 0.5) +
        geom_smooth(method = "loess", span = 0.1, se = FALSE,
                    color = clr$hr, linewidth = 0.8) +
        labs(x = "Date and Time", y = "Heart Rate (bpm)") +
        scale_x_datetime(date_labels = "%b %d, %H:%M", date_breaks = "12 hours") +
        #scale_y_continuous(limits = c(55, 150), breaks = seq(40, 150, by = 20)) +
        scale_y_continuous(breaks = scales::pretty_breaks(n = 6)) +
        dash_theme() +
        theme(axis.text.x = element_text(size = 8))
    }
    
    ggplotly(p, tooltip = c("x", "y")) %>%
      layout(
        xaxis = list(tickangle = -45),
        hoverlabel = list(bgcolor = clr$bg, font = list(size = 10)),
        legend = list(orientation = "h", xanchor = "center",
                      x = 0.5, y = -0.5, title = list(text = "")),
        margin = list(l = 50, r = 20, t = 20, b = 80)
      )
  })
  
  # Heart Rate Distribution
  # Shows histogram of heart rate values with different grouping by view mode
  output$hr_distribution <- renderPlotly({
    req(auth$logged_in)
    df <- hr_data()
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No heart rate data available"))
    }
    
    if (input$view_mode == "day") {
      is_all <- auth$is_admin && is.null(current_participant())
      
      if (is_all) {
        # Admin view: show distribution by participant
        p <- ggplot(df, aes(x = heart_rate_avg, y = after_stat(density), 
                            fill = participantID)) +
          geom_histogram(alpha = 0.7, bins = 25, color = clr$bg, linewidth = 0.2) +
          labs(x = "bpm", y = "density") +
          dash_theme()
      } else {
        # Single participant: color by study day
        p <- ggplot(df, aes(x = heart_rate_avg, fill = factor(study_day))) +
          geom_histogram(alpha = 0.7, bins = 25, color = clr$bg, linewidth = 0.2) +
          labs(x = "bpm", y = "count", fill = "Study Day") +
          dash_theme()
      }
    } else {
      # Date view: simple histogram
      p <- ggplot(df, aes(x = heart_rate_avg)) +
        geom_histogram(fill = clr$hr, alpha = 0.85, bins = 25,
                       color = clr$bg, linewidth = 0.2) +
        labs(x = "bpm", y = "count") +
        dash_theme()
    }
    
    ggplotly(p) %>%
      layout(hoverlabel = list(bgcolor = clr$bg),
             legend = list(orientation = "h", xanchor = "center",
                           x = 0.5, y = -0.5, title = list(text = "")),
             margin = list(l = 50, r = 20, t = 20, b = 80))
  })
  
  # Heart Rate by Hour of Day
  # Shows circadian patterns in heart rate with error bars in date view
  output$hr_by_hour <- renderPlotly({
    req(auth$logged_in)
    df <- hr_data()
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No heart rate data available"))
    }
    
    if (input$view_mode == "day") {
      is_all <- auth$is_admin && is.null(current_participant())
      
      if (is_all) {
        split_view <- !is.null(input$hr_by_hour_view) && input$hr_by_hour_view == "split"
        
        if (split_view) {
          # Split view: show each participant as separate line
          chart_data <- df %>%
            filter(!is.na(datetime)) %>%
            mutate(hour_of_day = hour(datetime)) %>%
            group_by(participantID, hour_of_day) %>%
            summarise(avg_heart_rate = mean(heart_rate_avg, na.rm = TRUE), .groups = "drop")
          
          p <- ggplot(chart_data, aes(x = hour_of_day, y = avg_heart_rate,
                                      color = participantID, group = participantID)) +
            geom_line(linewidth = 0.8, alpha = 0.8) +
            geom_point(size = 1.5, alpha = 0.7) +
            labs(x = "Hour of Day", y = "Average Heart Rate (bpm)") +
            scale_x_continuous(breaks = seq(0, 23, by = 2),
                               labels = sprintf("%02d:00", seq(0, 23, by = 2))) +
            dash_theme() +
            theme(axis.text.x = element_text(size = 8))
        } else {
          # Aggregate view: average across all participants
          chart_data <- df %>%
            filter(!is.na(datetime)) %>%
            mutate(hour_of_day = hour(datetime)) %>%
            group_by(hour_of_day) %>%
            summarise(avg_heart_rate = mean(heart_rate_avg, na.rm = TRUE), .groups = "drop")
          
          p <- ggplot(chart_data, aes(x = hour_of_day, y = avg_heart_rate)) +
            geom_col(fill = clr$hr, width = 0.7, alpha = 0.8) +
            labs(x = "Hour of Day", y = "Avg Heart Rate (bpm, all participants)") +
            scale_x_continuous(breaks = seq(0, 23, by = 2),
                               labels = sprintf("%02d:00", seq(0, 23, by = 2))) +
            dash_theme() +
            theme(axis.text.x = element_text(size = 8))
        }
      } else {
        # Single participant: color by study day
        chart_data <- df %>%
          filter(!is.na(datetime)) %>%
          mutate(hour_of_day = hour(datetime)) %>%
          group_by(study_day, hour_of_day) %>%
          summarise(avg_heart_rate = mean(heart_rate_avg, na.rm = TRUE), .groups = "drop")
        
        p <- ggplot(chart_data, aes(x = hour_of_day, y = avg_heart_rate,
                                    color = factor(study_day), group = factor(study_day))) +
          geom_line(linewidth = 0.8, alpha = 0.8) +
          geom_point(size = 1.5, alpha = 0.7) +
          labs(x = "Hour of Day", y = "Average Heart Rate (bpm)", color = "Study Day") +
          scale_x_continuous(breaks = seq(0, 23, by = 2),
                             labels = sprintf("%02d:00", seq(0, 23, by = 2))) +
          dash_theme() +
          theme(axis.text.x = element_text(size = 8))
      }
    } else {
      # Date view: show with standard deviation error bars
      chart_data <- df %>%
        filter(!is.na(datetime)) %>%
        mutate(hour_of_day = hour(datetime)) %>%
        group_by(hour_of_day) %>%
        summarise(
          avg_heart_rate = mean(heart_rate_avg, na.rm = TRUE),
          sd_heart_rate  = sd(heart_rate_avg, na.rm = TRUE),
          .groups = "drop"
        )
      
      p <- ggplot(chart_data, aes(x = hour_of_day, y = avg_heart_rate)) +
        geom_col(fill = clr$hr, width = 0.7, alpha = 0.8) +
        geom_errorbar(aes(ymin = avg_heart_rate - sd_heart_rate,
                          ymax = avg_heart_rate + sd_heart_rate),
                      width = 0.3, color = clr$error_bar, linewidth = 0.4) +
        labs(x = "Hour of Day", y = "Average Heart Rate (bpm)") +
        scale_x_continuous(breaks = seq(0, 23, by = 2),
                           labels = sprintf("%02d:00", seq(0, 23, by = 2))) +
        dash_theme() +
        theme(axis.text.x = element_text(size = 8),
              panel.grid.major.x = element_blank())
    }
    
    ggplotly(p, tooltip = c("x", "y")) %>%
      layout(hoverlabel = list(bgcolor = clr$bg),
             xaxis = list(tickangle = -45),
             legend = list(orientation = "h", xanchor = "center",
                           x = 0.5, y = -0.5, title = list(text = "")),
             margin = list(l = 50, r = 20, t = 20, b = 80))
  })
  
  # Heart Rate Variability (HRV)
  # Shows RMSSD trends over time
  output$hrv_chart <- renderPlotly({
    req(auth$logged_in)
    df <- hrv_data()
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No HRV data available"))
    }
    
    if (input$view_mode == "day") {
      # Study day view: aggregate by day
      chart_data <- df %>%
        filter(!is.na(rmssd_ms)) %>%
        group_by(study_day) %>%
        summarise(rmssd_ms = mean(rmssd_ms, na.rm = TRUE), .groups = "drop")
      
      p <- ggplot(chart_data, aes(x = study_day, y = rmssd_ms)) +
        geom_line(color = clr$hrv, linewidth = 0.8) +
        geom_point(color = clr$hrv, size = 3, alpha = 0.9) +
        scale_x_continuous(breaks = scales::pretty_breaks()) +
        labs(x = "Study Day", 
             y = if (isTRUE(auth$is_admin) && is.null(current_participant())) 
               "Avg RMSSD (ms, all participants)" else "RMSSD (ms)") +
        dash_theme()
    } else {
      # Date view: show datetime on x-axis
      chart_data <- df %>%
        filter(!is.na(rmssd_ms), !is.na(datetime))
      
      p <- ggplot(chart_data, aes(x = datetime, y = rmssd_ms)) +
        geom_line(color = clr$hrv, linewidth = 0.6, alpha = 0.85) +
        geom_point(size = 1.5, color = clr$hrv, alpha = 0.7) +
        labs(x = NULL, y = "RMSSD (ms)") +
        dash_theme()
    }
    
    ggplotly(p) %>%
      layout(hoverlabel = list(bgcolor = clr$bg),
             margin = list(l = 50, r = 20, t = 20, b = 40))
  })
  
  
  # ==================== SLEEP TAB CHARTS ====================
  
  # Sleep Duration Over Time
  # Shows total sleep minutes per night by date or study day
  output$sleep_duration <- renderPlotly({
    req(auth$logged_in)
    df <- sleep_data()
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No sleep data available"))
    }
    
    if (input$view_mode == "day") {
      is_all <- auth$is_admin && is.null(current_participant())
      
      if (is_all) {
        # Aggregate: average sleep duration across all participants by study day
        sleep_dur <- df %>%
          filter(sleep_stage %in% c("deep", "rem", "light", "wake")) %>%
          group_by(participantID, study_day) %>%
          summarise(total_minutes = n(), .groups = "drop") %>%
          group_by(study_day) %>%
          summarise(total_minutes = mean(total_minutes, na.rm = TRUE), .groups = "drop")
      } else {
        # Single participant: sleep duration by study day
        sleep_dur <- df %>%
          filter(sleep_stage %in% c("deep", "rem", "light", "wake")) %>%
          group_by(study_day) %>%
          summarise(total_minutes = n(), .groups = "drop")
      }
      
      p <- ggplot(sleep_dur, aes(x = study_day, y = total_minutes)) +
        geom_col(fill = clr$deep, width = 0.7, alpha = 0.85) +
        scale_x_continuous(breaks = scales::pretty_breaks()) +
        scale_y_continuous(breaks = scales::pretty_breaks()) +
        labs(x = "Study Day",
             y = if (is_all) "Avg minutes (all participants)" else "Minutes") +
        dash_theme()
    } else {
      # Date view: sleep duration by calendar date
      sleep_dur <- df %>%
        filter(sleep_stage %in% c("deep", "rem", "light", "wake")) %>%
        group_by(dateOfSleep) %>%
        summarise(total_minutes = n(), .groups = "drop") %>%
        mutate(dateOfSleep = as.Date(dateOfSleep))
      
      if (nrow(sleep_dur) == 0) {
        return(create_empty_plot("No sleep duration data available"))
      }
      
      p <- ggplot(sleep_dur, aes(x = dateOfSleep, y = total_minutes)) +
        geom_col(fill = clr$deep, width = 0.7, alpha = 0.85) +
        scale_x_date(date_labels = "%b %d") +
        scale_y_continuous(breaks = scales::pretty_breaks()) +
        labs(x = NULL, y = "Minutes") +
        dash_theme()
    }
    
    ggplotly(p) %>%
      layout(hoverlabel = list(bgcolor = clr$bg),
             margin = list(l = 50, r = 20, t = 20, b = 60))
  })
  
  # Sleep Stage Distribution
  # Donut chart showing proportion of time in each sleep stage
  output$sleep_stage_pie <- renderPlotly({
    req(auth$logged_in)
    df <- sleep_data()
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No sleep data available"))
    }
    
    # Aggregate sleep stages across all data
    stage_dist <- df %>%
      filter(sleep_stage %in% c("deep", "rem", "light", "wake")) %>%
      group_by(sleep_stage) %>%
      summarise(minutes = n(), .groups = "drop") %>%
      mutate(sleep_stage = recode(sleep_stage,
                                  deep = "Deep", rem = "REM",
                                  light = "Light", wake = "Wake"))
    
    if (nrow(stage_dist) == 0) {
      return(create_empty_plot("No sleep stage data available"))
    }
    
    is_all <- auth$is_admin && is.null(current_participant())
    
    plot_ly(
      data = stage_dist, labels = ~sleep_stage, values = ~minutes,
      type = "pie", hole = 0.6,
      textinfo = "label+percent",
      hoverinfo = "label+value+percent",
      marker = list(colors = c(Deep = clr$deep, REM = clr$rem,
                               Light = clr$light, Wake = clr$wake)[stage_dist$sleep_stage])
    ) %>%
      layout(
        title = if (is_all) list(text = "All Participants Combined", 
                                 font = list(size = 11, color = clr$text_secondary)) 
        else NULL,
        showlegend = TRUE,
        legend = list(orientation = "h", yanchor = "bottom", y = -0.5,
                      xanchor = "center", x = 0.5),
        margin = list(l = 20, r = 20, t = 30, b = 20)
      )
  })
  
  # Breathing Rate During Sleep
  # Shows breathing rate by sleep stage over time
  output$breathing_rate_chart <- renderPlotly({
    req(auth$logged_in)
    df <- breathing_data()
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No breathing rate data available"))
    }
    
    if (input$view_mode == "day") {
      is_all <- auth$is_admin && is.null(current_participant())
      
      # Reshape data: stages as columns to long format
      d <- df %>%
        filter(!is.na(study_day)) %>%
        select(study_day, full_sleep_breathing_rate, deep_sleep_breathing_rate,
               light_sleep_breathing_rate, rem_sleep_breathing_rate) %>%
        pivot_longer(-study_day, names_to = "stage", values_to = "bpm") %>%
        filter(!is.na(bpm)) %>%
        mutate(stage = recode(stage,
                              full_sleep_breathing_rate = "Full Sleep",
                              deep_sleep_breathing_rate = "Deep",
                              light_sleep_breathing_rate = "Light",
                              rem_sleep_breathing_rate = "REM"))
      
      if (is_all) {
        # Aggregate: average across all participants
        d <- d %>%
          group_by(study_day, stage) %>%
          summarise(bpm = mean(bpm, na.rm = TRUE), .groups = "drop")
      }
      
      p <- ggplot(d, aes(x = study_day, y = bpm, color = stage, group = stage)) +
        geom_line(linewidth = 0.8) +
        geom_point(size = 2) +
        scale_color_manual(values = c(
          "Full Sleep" = clr$full_sleep, Deep = clr$deep,
          Light = clr$light, REM = clr$rem)) +
        scale_x_continuous(breaks = scales::pretty_breaks()) +
        scale_y_continuous(breaks = scales::pretty_breaks()) +
        labs(x = "Study Day",
             y = if (is_all) "Avg breaths/min (all participants)" else "breaths/min",
             color = "Sleep Stage") +
        dash_theme()
    } else {
      # Date view: breathing rate by calendar date
      d <- df %>%
        mutate(date = as.Date(date)) %>%
        select(date, full_sleep_breathing_rate, deep_sleep_breathing_rate,
               light_sleep_breathing_rate, rem_sleep_breathing_rate) %>%
        pivot_longer(-date, names_to = "stage", values_to = "bpm") %>%
        filter(!is.na(bpm)) %>%
        mutate(stage = recode(stage,
                              full_sleep_breathing_rate = "Full Sleep",
                              deep_sleep_breathing_rate = "Deep",
                              light_sleep_breathing_rate = "Light",
                              rem_sleep_breathing_rate = "REM"))
      
      p <- ggplot(d, aes(x = date, y = bpm, color = stage, group = stage)) +
        geom_line(linewidth = 0.8) +
        geom_point(size = 2) +
        scale_color_manual(values = c(
          "Full Sleep" = clr$full_sleep, Deep = clr$deep,
          Light = clr$light, REM = clr$rem)) +
        scale_x_date(date_labels = "%b %d") +
        scale_y_continuous(breaks = scales::pretty_breaks()) +
        labs(x = NULL, y = "breaths/min") +
        dash_theme()
    }
    
    ggplotly(p) %>%
      layout(hoverlabel = list(bgcolor = clr$bg),
             legend = list(orientation = "h", xanchor = "center",
                           x = 0.5, y = -0.5, title = list(text = "")),
             margin = list(l = 50, r = 20, t = 20, b = 80))
  })
  
  # Populate hypnogram night dropdown
  # Updates the night selector based on available sleep data
  observe({
    req(auth$logged_in)
    is_all <- isTRUE(auth$is_admin) && is.null(current_participant())
    if (is_all) {
      # Hide night selector for aggregate admin view
      shinyjs::delay(200, shinyjs::hide("hypnogram_date_container"))
      return()
    }
    shinyjs::delay(200, shinyjs::show("hypnogram_date_container"))
    df <- sleep_data()
    if (is.null(df) || nrow(df) == 0) return()
    nights <- sort(unique(df$dateOfSleep), decreasing = TRUE)
    updateSelectInput(session, "hypnogram_date", choices = nights, selected = nights[1])
  })
  
  # Hypnogram
  # Shows sleep stage transitions throughout the night
  output$hypnogram_chart <- renderPlotly({
    req(auth$logged_in)
    df <- sleep_data()
    is_all <- auth$is_admin && is.null(current_participant())
    
    if (is_all) {
      # All Participants: stacked bar of avg sleep stage minutes per study day
      if (is.null(df) || nrow(df) == 0) {
        return(create_empty_plot("No sleep data available"))
      }
      
      has_study_day <- "study_day" %in% names(df)
      if (!has_study_day) {
        return(create_empty_plot("Study day data not available"))
      }
      
      # Aggregate sleep stages across all participants
      sleep_summary <- df %>%
        filter(sleep_stage %in% c("deep", "rem", "light", "wake", "asleep")) %>%
        mutate(sleep_stage = case_when(
          tolower(sleep_stage) %in% c("deep") ~ "Deep",
          tolower(sleep_stage) %in% c("rem") ~ "REM",
          tolower(sleep_stage) %in% c("light", "asleep") ~ "Light",
          tolower(sleep_stage) %in% c("wake") ~ "Wake",
          TRUE ~ "Light"
        )) %>%
        filter(sleep_stage != "Wake") %>%
        group_by(participantID, study_day, sleep_stage) %>%
        summarise(minutes = n(), .groups = "drop") %>%
        group_by(study_day, sleep_stage) %>%
        summarise(minutes = mean(minutes, na.rm = TRUE), .groups = "drop")
      
      if (nrow(sleep_summary) == 0) {
        return(create_empty_plot("No sleep stage data available"))
      }
      
      p <- ggplot(sleep_summary, aes(x = study_day, y = minutes, fill = sleep_stage)) +
        geom_col(width = 0.7, alpha = 0.9) +
        scale_fill_manual(values = c(Deep = clr$deep, REM = clr$rem, Light = clr$light)) +
        labs(x = "Study Day", y = "Avg minutes (all participants)",
             fill = "Sleep Stage") +
        scale_x_continuous(breaks = scales::pretty_breaks()) +
        dash_theme()
      
      return(ggplotly(p) %>%
               layout(hoverlabel = list(bgcolor = clr$bg),
                      legend = list(orientation = "h", xanchor = "center",
                                    x = 0.5, y = -0.5, title = list(text = "")),
                      margin = list(l = 50, r = 20, t = 20, b = 80)))
    }
    
    # Individual participant: normal hypnogram
    req(input$hypnogram_date)
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No sleep data available"))
    }
    
    target_date <- as.Date(input$hypnogram_date)
    
    # Prepare hypnogram data with numeric stage mapping
    hypnogram_data <- df %>%
      filter(dateOfSleep == target_date,
             sleep_stage %in% c("wake", "light", "deep", "rem", "asleep")) %>%
      mutate(
        datetime_utc = as.POSIXct(datetime, format = "%Y-%m-%d %H:%M:%S", tz = "UTC"),
        time_num = hour(datetime_utc) + minute(datetime_utc) / 60,
        stage_numeric = case_when(
          sleep_stage == "wake"                  ~ 4,
          sleep_stage == "rem"                   ~ 3,
          sleep_stage %in% c("light", "asleep") ~ 2,
          sleep_stage == "deep"                  ~ 1
        ),
        stage_label = case_when(
          sleep_stage == "wake"   ~ "Wake",
          sleep_stage == "rem"    ~ "REM",
          sleep_stage == "light"  ~ "Light",
          sleep_stage == "deep"   ~ "Deep",
          sleep_stage == "asleep" ~ "Asleep"
        )
      )
    
    if (nrow(hypnogram_data) == 0) {
      return(create_empty_plot(paste("No sleep stage data for", target_date)))
    }
    
    # Create hypnogram with lines and colored markers
    plot_ly() %>%
      add_lines(data = hypnogram_data, x = ~time_num, y = ~stage_numeric,
                line = list(color = clr$text_primary, width = 2),
                showlegend = FALSE, hoverinfo = "skip") %>%
      add_markers(data = hypnogram_data, x = ~time_num, y = ~stage_numeric,
                  color = ~stage_label,
                  colors = c(Wake = clr$wake, REM = clr$rem, Light = clr$light,
                             Deep = clr$deep, Asleep = clr$asleep),
                  marker = list(size = 8, opacity = 0.7)) %>%
      layout(
        xaxis = list(title = "Time", tickmode = "array",
                     tickvals = seq(0, 24, 4),
                     ticktext = c("12 AM", "4 AM", "8 AM", "12 PM", "4 PM", "8 PM", "12 AM"),
                     range = c(0, 24)),
        yaxis = list(title = NULL, tickmode = "array",
                     tickvals = c(1, 2, 3, 4),
                     ticktext = c("Deep", "Light", "REM", "Wake"),
                     range = c(0.5, 4.5)),
        legend = list(orientation = "h", yanchor = "bottom", y = -0.3,
                      xanchor = "center", x = 0.5),
        margin = list(l = 60, r = 40, t = 20, b = 80)
      )
  })
  
  # Sleep Efficiency
  # Shows percentage of time in bed spent asleep
  output$sleep_efficiency_chart <- renderPlotly({
    req(auth$logged_in)
    df <- sleep_data()
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No sleep data available"))
    }
    
    if (input$view_mode == "day") {
      is_all <- auth$is_admin && is.null(current_participant())
      
      if (is_all) {
        split_view <- !is.null(input$sleep_efficiency_view) && 
          input$sleep_efficiency_view == "split"
        
        if (split_view) {
          # Split view: show each participant as separate line
          eff <- df %>%
            group_by(participantID, study_day) %>%
            summarise(
              efficiency = round(sum(sleep_stage != "wake") / n() * 100, 1),
              .groups = "drop"
            )
          
          p <- ggplot(eff, aes(x = study_day, y = efficiency,
                               color = participantID, group = participantID)) +
            geom_line(linewidth = 1) +
            geom_point(size = 3) +
            geom_hline(yintercept = 85, linetype = "dashed", color = clr$target_line) +
            scale_x_continuous(breaks = scales::pretty_breaks()) +
            scale_y_continuous(breaks = scales::pretty_breaks()) +
            labs(x = "Study Day", y = "Efficiency (%)") +
            dash_theme()
          
          return(ggplotly(p) %>%
                   layout(hoverlabel = list(bgcolor = clr$bg),
                          legend = list(orientation = "h", xanchor = "center",
                                        x = 0.5, y = -0.5, title = list(text = "")),
                          margin = list(l = 50, r = 20, t = 20, b = 80)))
        }
        
        # Aggregate: average efficiency across all participants
        eff <- df %>%
          group_by(participantID, study_day) %>%
          summarise(
            efficiency = round(sum(sleep_stage != "wake") / n() * 100, 1),
            .groups = "drop"
          ) %>%
          group_by(study_day) %>%
          summarise(efficiency = mean(efficiency, na.rm = TRUE), .groups = "drop")
      } else {
        # Single participant: efficiency by study day
        eff <- df %>%
          group_by(study_day) %>%
          summarise(
            efficiency = round(sum(sleep_stage != "wake") / n() * 100, 1),
            .groups = "drop"
          )
      }
      
      p <- ggplot(eff, aes(x = study_day, y = efficiency)) +
        geom_line(color = clr$steps, linewidth = 1) +
        geom_point(color = clr$steps, size = 3) +
        geom_hline(yintercept = 85, linetype = "dashed", color = clr$target_line) +
        scale_x_continuous(breaks = scales::pretty_breaks()) +
        scale_y_continuous(breaks = scales::pretty_breaks()) +
        labs(x = "Study Day",
             y = if (is_all) "Avg Efficiency % (all participants)" else "Efficiency (%)") +
        dash_theme()
      
      ggplotly(p) %>%
        layout(hoverlabel = list(bgcolor = clr$bg),
               margin = list(l = 50, r = 20, t = 20, b = 60))
    } else {
      # Date view: efficiency by calendar date
      eff <- df %>%
        group_by(dateOfSleep) %>%
        summarise(
          efficiency = round(sum(sleep_stage != "wake") / n() * 100, 1),
          .groups = "drop"
        ) %>%
        mutate(dateOfSleep = as.Date(dateOfSleep))
      
      if (nrow(eff) == 0) {
        return(create_empty_plot("No sleep efficiency data available"))
      }
      
      plot_ly() %>%
        add_trace(data = eff, x = ~dateOfSleep, y = ~efficiency,
                  type = "scatter", mode = "lines+markers",
                  line = list(color = clr$steps, width = 2),
                  marker = list(color = clr$steps, size = 8),
                  name = "Efficiency") %>%
        add_trace(x = range(eff$dateOfSleep), y = c(85, 85),
                  type = "scatter", mode = "lines",
                  line = list(color = clr$target_line, dash = "dash"),
                  name = "Target (85%)") %>%
        layout(
          xaxis = list(title = "", tickformat = "%b %d"),
          yaxis = list(title = "Efficiency (%)"),
          legend = list(orientation = "h", xanchor = "center", x = 0.5, y = -0.2),
          margin = list(l = 50, r = 20, t = 20, b = 60)
        )
    }
  })
  
  
  # ==================== ACTIVITY TAB CHARTS ====================
  
  # Zone Minutes (Fat Burn / Cardio / Peak)
  # Shows stacked bar chart of time spent in each heart rate zone
  output$zone_minutes_chart <- renderPlotly({
    req(auth$logged_in)
    df <- zone_minutes_data()
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No zone minutes data available"))
    }
    
    if (input$view_mode == "day") {
      is_all <- auth$is_admin && is.null(current_participant())
      
      # Aggregate zone minutes by study day
      chart_data <- if (is_all) {
        df %>%
          group_by(participantID, study_day) %>%
          summarise(
            fat_burn = sum(fat_burn_minutes, na.rm = TRUE),
            cardio   = sum(cardio_minutes,   na.rm = TRUE),
            peak     = sum(peak_minutes,     na.rm = TRUE),
            .groups  = "drop"
          ) %>%
          group_by(study_day) %>%
          summarise(
            fat_burn = mean(fat_burn, na.rm = TRUE),
            cardio   = mean(cardio,   na.rm = TRUE),
            peak     = mean(peak,     na.rm = TRUE),
            .groups  = "drop"
          )
      } else {
        df %>%
          group_by(study_day) %>%
          summarise(
            fat_burn = sum(fat_burn_minutes, na.rm = TRUE),
            cardio   = sum(cardio_minutes,   na.rm = TRUE),
            peak     = sum(peak_minutes,     na.rm = TRUE),
            .groups  = "drop"
          )
      }
      
      plot_ly() %>%
        add_bars(data = chart_data, x = ~study_day, y = ~fat_burn,
                 name = "Fat Burn Zone", marker = list(color = clr$fat_burn, opacity = 0.9)) %>%
        add_bars(data = chart_data, x = ~study_day, y = ~cardio,
                 name = "Cardio Zone", marker = list(color = clr$cardio, opacity = 0.9)) %>%
        add_bars(data = chart_data, x = ~study_day, y = ~peak,
                 name = "Peak Zone", marker = list(color = clr$peak, opacity = 0.9)) %>%
        layout(
          barmode = "stack",
          xaxis = list(title = "Study Day"),
          yaxis = list(title = if (is_all) "Avg Minutes (all participants)" else "Minutes"),
          legend = list(orientation = "h", xanchor = "center", x = 0.5,
                        yanchor = "top", y = -0.5, title = list(text = "")),
          hoverlabel = list(bgcolor = clr$bg),
          margin = list(l = 50, r = 20, t = 20, b = 80)
        )
    } else {
      # Date view: zone minutes by calendar date
      chart_data <- df %>%
        filter(!is.na(datetime)) %>%
        mutate(date_only = as.Date(datetime)) %>%
        group_by(date_only) %>%
        summarise(
          fat_burn = sum(fat_burn_minutes, na.rm = TRUE),
          cardio   = sum(cardio_minutes,   na.rm = TRUE),
          peak     = sum(peak_minutes,     na.rm = TRUE),
          .groups  = "drop"
        )
      
      if (nrow(chart_data) == 0) {
        return(create_empty_plot("No zone minutes data for selected filters"))
      }
      
      plot_ly() %>%
        add_bars(data = chart_data, x = ~date_only, y = ~fat_burn,
                 name = "Fat Burn Zone", marker = list(color = clr$fat_burn, opacity = 0.9)) %>%
        add_bars(data = chart_data, x = ~date_only, y = ~cardio,
                 name = "Cardio Zone", marker = list(color = clr$cardio, opacity = 0.9)) %>%
        add_bars(data = chart_data, x = ~date_only, y = ~peak,
                 name = "Peak Zone", marker = list(color = clr$peak, opacity = 0.9)) %>%
        layout(
          barmode = "stack",
          xaxis = list(title = "Date", tickformat = "%b %d"),
          yaxis = list(title = "Minutes"),
          legend = list(orientation = "h", xanchor = "center", x = 0.5,
                        yanchor = "top", y = -0.5, title = list(text = "")),
          hoverlabel = list(bgcolor = clr$bg),
          margin = list(l = 50, r = 20, t = 20, b = 80)
        )
    }
  })
  
  # Exercise Sessions
  # Shows exercise sessions as bubble chart with duration and type
  output$exercise_sessions_chart <- renderPlotly({
    req(auth$logged_in)
    df <- activity_sessions_data()
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No exercise session data available"))
    }
    
    # Calculate duration and extract date
    d <- df %>%
      filter(!is.na(start_datetime), !is.na(end_datetime)) %>%
      mutate(
        duration_min = as.numeric(difftime(end_datetime, start_datetime, units = "mins")),
        date = as.Date(start_datetime)
      ) %>%
      arrange(start_datetime)
    
    if (input$view_mode == "day") {
      d <- d %>% filter(!is.na(study_day))
    }
    
    if (nrow(d) == 0) {
      return(create_empty_plot("No exercise session data for selected filters"))
    }
    
    # Build color mapping - known types use clr, unknown fall back to clr$steps
    activity_color_map <- c(
      walk    = clr$walk,
      run     = clr$run,
      bike    = clr$bike,
      sport   = clr$sport,
      workout = clr$workout,
      swim    = clr$swim,
      yoga    = clr$yoga
    )
    
    has_type <- "exercise_type" %in% names(d)
    
    is_all <- auth$is_admin && is.null(current_participant())
    split_by_participant <- is_all && !is.null(input$exercise_sessions_view) &&
      input$exercise_sessions_view == "participant"
    
    full_color_map <- c(activity_color_map, other = clr$steps)
    label_color_map <- setNames(full_color_map, tools::toTitleCase(names(full_color_map)))
    
    # Prepare data with hover text
    if (has_type) {
      d <- d %>%
        mutate(
          activity_type  = tolower(trimws(exercise_type)),
          activity_label = ifelse(activity_type %in% names(activity_color_map),
                                  activity_type, "other"),
          color_label    = tools::toTitleCase(activity_label),
          hover_text     = paste0(
            if (is_all) paste0("Participant: ", participantID, "<br>") else "",
            "Type: ", activity_type,
            "<br>Duration: ", round(duration_min), " min",
            "<br>Date: ", format(date, "%b %d"))
        )
    } else {
      d <- d %>%
        mutate(
          color_label = "Other",
          hover_text  = paste0(
            if (is_all) paste0("Participant: ", participantID, "<br>") else "",
            "Duration: ", round(duration_min), " min",
            "<br>Date: ", format(date, "%b %d"))
        )
    }
    
    # Set color scale based on view mode
    if (split_by_participant) {
      d <- d %>%
        mutate(color_label = participantID)
      okabe_ito <- c(clr$hr, clr$steps, clr$deep, clr$rem, clr$light, clr$hrv, clr$green)
      participant_ids <- unique(d$participantID)
      participant_colors <- setNames(okabe_ito[seq_along(participant_ids)], participant_ids)
      color_scale <- scale_color_manual(values = participant_colors, guide = "legend")
    } else {
      color_scale <- scale_color_manual(
        values = label_color_map,
        guide  = if (has_type) "legend" else "none"
      )
    }
    
    # Create plot with x-axis based on view mode
    if (input$view_mode == "day") {
      p <- ggplot(d, aes(x = study_day, y = duration_min,
                         size = duration_min, color = color_label,
                         text = hover_text)) +
        scale_x_continuous(breaks = scales::pretty_breaks())
    } else {
      p <- ggplot(d, aes(x = date, y = duration_min,
                         size = duration_min, color = color_label,
                         text = hover_text)) +
        scale_x_date(date_labels = "%b %d")
    }
    
    p <- p +
      geom_point(alpha = 0.85) +
      color_scale +
      scale_size_continuous(range = c(4, 16), guide = "none") +
      scale_y_continuous(breaks = scales::pretty_breaks()) +
      labs(x = if (input$view_mode == "day") "Study Day" else "Date",
           y = "Duration (minutes)") +
      dash_theme()
    
    ggplotly(p, tooltip = "text") %>%
      layout(hoverlabel = list(bgcolor = clr$bg),
             legend = list(orientation = "h", xanchor = "center",
                           x = 0.5, y = -0.5, title = list(text = "")),
             margin = list(l = 50, r = 20, t = 20, b = 80))
  })
  
  # Sedentary Periods
  # Shows total sedentary time per day
  output$sedentary_chart <- renderPlotly({
    req(auth$logged_in)
    df <- sedentary_data()
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No sedentary data available"))
    }
    
    d <- df %>%
      filter(!is.na(duration_minutes)) %>%
      mutate(date = as.Date(period_start))
    
    if (input$view_mode == "day") {
      is_all <- auth$is_admin && is.null(current_participant())
      
      if (is_all) {
        # Aggregate: average sedentary time across all participants
        daily_sedentary <- d %>%
          filter(!is.na(study_day)) %>%
          group_by(participantID, study_day) %>%
          summarise(total_minutes = sum(duration_minutes, na.rm = TRUE), .groups = "drop") %>%
          group_by(study_day) %>%
          summarise(total_minutes = mean(total_minutes, na.rm = TRUE), .groups = "drop")
      } else {
        # Single participant: sedentary time by study day
        daily_sedentary <- d %>%
          filter(!is.na(study_day)) %>%
          group_by(study_day) %>%
          summarise(total_minutes = sum(duration_minutes, na.rm = TRUE), .groups = "drop")
      }
      
      p <- ggplot(daily_sedentary, aes(x = study_day, y = total_minutes)) +
        geom_col(fill = clr$green, alpha = 0.85, width = 0.65) +
        scale_x_continuous(breaks = scales::pretty_breaks()) +
        scale_y_continuous(breaks = scales::pretty_breaks()) +
        labs(x = "Study Day",
             y = if (is_all) "Avg Minutes Sedentary (all participants)" else "Minutes Sedentary") +
        dash_theme()
    } else {
      # Date view: sedentary time by calendar date
      daily_sedentary <- d %>%
        group_by(date) %>%
        summarise(total_minutes = sum(duration_minutes, na.rm = TRUE), .groups = "drop")
      
      if (nrow(daily_sedentary) == 0) {
        return(create_empty_plot("No sedentary data for selected filters"))
      }
      
      p <- ggplot(daily_sedentary, aes(x = date, y = total_minutes)) +
        geom_col(fill = clr$green, alpha = 0.85, width = 0.65) +
        scale_x_date(date_labels = "%b %d") +
        scale_y_continuous(breaks = scales::pretty_breaks()) +
        labs(x = NULL, y = "Minutes Sedentary") +
        dash_theme()
    }
    
    ggplotly(p) %>%
      layout(hoverlabel = list(bgcolor = clr$bg),
             margin = list(l = 50, r = 20, t = 20, b = 40))
  })
  
  # Daily Steps with Goal Line
  # Shows daily step counts with 10,000 step target line
  output$activity_steps_chart <- renderPlotly({
    req(auth$logged_in)
    df <- steps_data()
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No steps data available"))
    }
    
    if (input$view_mode == "day") {
      is_all <- auth$is_admin && is.null(current_participant())
      
      if (is_all) {
        # Aggregate: average steps across all participants
        daily <- df %>%
          group_by(participantID, study_day) %>%
          summarise(total = sum(steps_5min, na.rm = TRUE), .groups = "drop") %>%
          group_by(study_day) %>%
          summarise(total = mean(total, na.rm = TRUE), .groups = "drop")
      } else {
        # Single participant: steps by study day
        daily <- df %>%
          group_by(study_day) %>%
          summarise(total = sum(steps_5min, na.rm = TRUE), .groups = "drop")
      }
      
      p <- ggplot(daily, aes(x = study_day, y = total)) +
        geom_col(fill = clr$steps, width = 0.7, alpha = 0.9) +
        geom_hline(yintercept = 10000, linetype = "dashed",
                   color = clr$target_line, linewidth = 0.5) +
        scale_x_continuous(breaks = scales::pretty_breaks()) +
        scale_y_continuous(labels = scales::comma,
                           breaks = scales::pretty_breaks()) +
        labs(x = "Study Day",
             y = if (is_all) "Avg Steps (all participants)" else "Steps") +
        dash_theme()
    } else {
      # Date view: steps by calendar date
      daily <- df %>%
        mutate(date = as.Date(date)) %>%
        group_by(date) %>%
        summarise(total = sum(steps_5min, na.rm = TRUE), .groups = "drop")
      
      if (nrow(daily) == 0) return(create_empty_plot("No steps data for selected filters"))
      
      p <- ggplot(daily, aes(x = date, y = total)) +
        geom_col(fill = clr$steps, width = 0.7, alpha = 0.9) +
        geom_hline(yintercept = 10000, linetype = "dashed",
                   color = clr$target_line, linewidth = 0.5) +
        scale_x_date(date_labels = "%b %d") +
        scale_y_continuous(labels = scales::comma,
                           breaks = scales::pretty_breaks()) +
        labs(x = NULL, y = "Steps") +
        dash_theme()
    }
    
    ggplotly(p) %>%
      layout(hoverlabel = list(bgcolor = clr$bg),
             margin = list(l = 50, r = 20, t = 20, b = 40))
  })
  
  # Steps by Hour of Day
  # Shows daily step patterns across hours
  output$activity_steps_by_hour <- renderPlotly({
    req(auth$logged_in)
    df <- steps_data()
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No steps data available"))
    }
    
    if (input$view_mode == "day") {
      is_all <- auth$is_admin && is.null(current_participant())
      
      if (is_all) {
        # Aggregate: average steps by hour across all participants
        hourly <- df %>%
          filter(!is.na(study_day)) %>%
          mutate(hour = hour(datetime)) %>%
          group_by(participantID, hour) %>%
          summarise(avg = mean(steps_5min, na.rm = TRUE), .groups = "drop")
        
        p <- ggplot(hourly, aes(x = hour, y = avg,
                                color = participantID,
                                group = participantID)) +
          geom_line(linewidth = 0.8, alpha = 0.8) +
          scale_x_continuous(breaks = c(0, 6, 12, 18, 23),
                             labels = c("12am", "6am", "12pm", "6pm", "11pm")) +
          scale_y_continuous(breaks = scales::pretty_breaks()) +
          labs(x = "Hour of Day", y = "Avg Steps") +
          dash_theme()
      } else {
        # Single participant: steps by hour colored by study day
        hourly <- df %>%
          filter(!is.na(study_day)) %>%
          mutate(hour = hour(datetime)) %>%
          group_by(study_day, hour) %>%
          summarise(avg = mean(steps_5min, na.rm = TRUE), .groups = "drop")
        
        p <- ggplot(hourly, aes(x = hour, y = avg,
                                color = factor(study_day),
                                group = factor(study_day))) +
          geom_line(linewidth = 0.8, alpha = 0.8) +
          scale_x_continuous(breaks = c(0, 6, 12, 18, 23),
                             labels = c("12am", "6am", "12pm", "6pm", "11pm")) +
          scale_y_continuous(breaks = scales::pretty_breaks()) +
          labs(x = "Hour of Day", y = "Avg Steps", color = "Study Day") +
          dash_theme()
      }
    } else {
      # Date view: average steps by hour across all dates
      hourly <- df %>%
        mutate(hour = hour(datetime)) %>%
        group_by(hour) %>%
        summarise(avg = mean(steps_5min, na.rm = TRUE), .groups = "drop")
      
      if (nrow(hourly) == 0) return(create_empty_plot("No steps data for selected filters"))
      
      p <- ggplot(hourly, aes(x = hour, y = avg)) +
        geom_col(fill = clr$steps, alpha = 0.85, width = 0.8) +
        scale_x_continuous(breaks = c(0, 6, 12, 18, 23),
                           labels = c("12am", "6am", "12pm", "6pm", "11pm")) +
        scale_y_continuous(breaks = scales::pretty_breaks()) +
        labs(x = "Hour of Day", y = "Avg Steps") +
        dash_theme()
    }
    
    ggplotly(p) %>%
      layout(hoverlabel = list(bgcolor = clr$bg),
             legend = list(orientation = "h", xanchor = "center",
                           x = 0.5, y = -0.5, title = list(text = "")),
             margin = list(l = 50, r = 20, t = 20, b = 80))
  })
  
  # Distance per Day
  # Shows daily distance in meters
  output$activity_distance_chart <- renderPlotly({
    req(auth$logged_in)
    df <- filtered_data_by_day()[["distance_intraday"]]
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No distance data available"))
    }
    
    if (input$view_mode == "day") {
      is_all <- auth$is_admin && is.null(current_participant())
      
      if (is_all) {
        # Aggregate: average distance across all participants
        daily <- df %>%
          filter(!is.na(study_day)) %>%
          group_by(participantID, study_day) %>%
          summarise(total = sum(distance_meters, na.rm = TRUE), .groups = "drop") %>%
          group_by(study_day) %>%
          summarise(total = mean(total, na.rm = TRUE), .groups = "drop")
      } else {
        # Single participant: distance by study day
        daily <- df %>%
          filter(!is.na(study_day)) %>%
          group_by(study_day) %>%
          summarise(total = sum(distance_meters, na.rm = TRUE), .groups = "drop")
      }
      
      p <- ggplot(daily, aes(x = study_day, y = total)) +
        geom_col(fill = clr$calories, width = 0.65, alpha = 0.85) +
        scale_x_continuous(breaks = scales::pretty_breaks()) +
        scale_y_continuous(breaks = scales::pretty_breaks()) +
        labs(x = "Study Day",
             y = if (is_all) "Avg Meters (all participants)" else "Meters") +
        dash_theme()
    } else {
      # Date view: distance by calendar date
      daily <- df %>%
        mutate(date = as.Date(date)) %>%
        group_by(date) %>%
        summarise(total = sum(distance_meters, na.rm = TRUE), .groups = "drop")
      
      if (nrow(daily) == 0) return(create_empty_plot("No distance data for selected filters"))
      
      p <- ggplot(daily, aes(x = date, y = total)) +
        geom_col(fill = clr$calories, width = 0.65, alpha = 0.85) +
        scale_x_date(date_labels = "%b %d") +
        scale_y_continuous(breaks = scales::pretty_breaks()) +
        labs(x = NULL, y = "Meters") +
        dash_theme()
    }
    
    ggplotly(p) %>%
      layout(hoverlabel = list(bgcolor = clr$bg),
             margin = list(l = 50, r = 20, t = 20, b = 40))
  })
  
  # ==================== INSIGHTS TAB CHARTS ====================
  
  # Best Sleep Night Insight
  # Identifies the night with the highest sleep duration
  output$insight_best_sleep <- renderText({
    req(auth$logged_in)
    df <- daily_metrics()
    if (is.null(df) || nrow(df) == 0) return("—")
    is_all <- auth$is_admin && is.null(current_participant())
    
    if (is_all) {
      # Aggregate: find study day with highest average sleep across participants
      v <- df %>%
        filter(!is.na(total_sleep_minutes)) %>%
        group_by(study_day) %>%
        summarise(total_sleep_minutes = mean(total_sleep_minutes, na.rm = TRUE),
                  .groups = "drop") %>%
        arrange(desc(total_sleep_minutes)) %>%
        head(1)
      if (nrow(v) == 0) return("—")
      paste0("Day ", v$study_day, " — ", round(v$total_sleep_minutes), " min avg")
    } else {
      # Single participant: find night with highest sleep duration
      v <- df %>%
        filter(!is.na(total_sleep_minutes)) %>%
        arrange(desc(total_sleep_minutes)) %>%
        head(1)
      if (nrow(v) == 0) return("—")
      if (input$view_mode == "day") {
        paste0("Day ", v$study_day, " — ", v$total_sleep_minutes, " min")
      } else {
        paste0(format(as.Date(v$date), "%b %d"), " — ", v$total_sleep_minutes, " min")
      }
    }
  })
  
  # Most Active Day Insight
  # Identifies the day with the highest step count
  output$insight_most_active <- renderText({
    req(auth$logged_in)
    df <- steps_data()
    if (is.null(df) || nrow(df) == 0) return("—")
    is_all <- auth$is_admin && is.null(current_participant())
    
    if (is_all) {
      # Aggregate: find study day with highest average steps across participants
      daily <- df %>%
        group_by(participantID, study_day) %>%
        summarise(total = sum(steps_5min, na.rm = TRUE), .groups = "drop") %>%
        group_by(study_day) %>%
        summarise(total = mean(total, na.rm = TRUE), .groups = "drop") %>%
        arrange(desc(total)) %>%
        head(1)
      if (nrow(daily) == 0) return("—")
      paste0("Day ", daily$study_day, " — ", format(round(daily$total), big.mark = ","), " avg steps")
    } else {
      # Single participant: find day with highest steps
      if (input$view_mode == "day") {
        daily <- df %>%
          group_by(study_day) %>%
          summarise(total = sum(steps_5min, na.rm = TRUE), .groups = "drop") %>%
          arrange(desc(total)) %>%
          head(1)
        if (nrow(daily) == 0) return("—")
        paste0("Day ", daily$study_day, " — ", format(daily$total, big.mark = ","), " steps")
      } else {
        daily <- df %>%
          mutate(date = as.Date(date)) %>%
          group_by(date) %>%
          summarise(total = sum(steps_5min, na.rm = TRUE), .groups = "drop") %>%
          arrange(desc(total)) %>%
          head(1)
        if (nrow(daily) == 0) return("—")
        paste0(format(daily$date, "%b %d"), " — ", format(daily$total, big.mark = ","), " steps")
      }
    }
  })
  
  # Typical Bedtime Insight
  # Calculates the average bedtime across all nights
  output$insight_typical_bedtime <- renderText({
    req(auth$logged_in)
    df <- sleep_data()
    if (is.null(df) || nrow(df) == 0) return("—")
    # Extract bedtime from first sleep record of each night
    bedtimes <- df %>%
      group_by(dateOfSleep, logId) %>%
      summarise(
        start = min(as.POSIXct(datetime, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")),
        .groups = "drop"
      ) %>%
      mutate(
        hour_dec = hour(start) + minute(start) / 60,
        hour_dec = ifelse(hour_dec < 12, hour_dec + 24, hour_dec)
      )
    if (nrow(bedtimes) == 0) return("—")
    avg_hr <- mean(bedtimes$hour_dec, na.rm = TRUE) %% 24
    is_all <- auth$is_admin && is.null(current_participant())
    suffix <- if (is_all) " (avg)" else ""
    paste0(sprintf("%02d:%02d", floor(avg_hr), round((avg_hr %% 1) * 60)), suffix)
  })
  
  # Sleep Duration: Weekday vs Weekend
  # Compares average sleep duration between weekdays and weekends
  output$weekday_sleep_chart <- renderPlotly({
    req(auth$logged_in)
    df <- sleep_data()
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No sleep data available"))
    }
    if (!"day_type" %in% names(df)) {
      return(create_empty_plot("Day type data not available"))
    }
    
    is_all <- auth$is_admin && is.null(current_participant())
    
    # Calculate total sleep minutes per night
    sleep_summary <- df %>%
      filter(sleep_stage %in% c("deep", "rem", "light", "wake")) %>%
      group_by(participantID, dateOfSleep, day_type) %>%
      summarise(total_minutes = n(), .groups = "drop")
    
    if (is_all) {
      # Aggregate: average sleep across all participants
      plot_data <- sleep_summary %>%
        group_by(day_type) %>%
        summarise(avg_minutes = mean(total_minutes, na.rm = TRUE), .groups = "drop")
      
      p <- ggplot(plot_data, aes(x = day_type, y = avg_minutes, fill = day_type)) +
        geom_col(width = 0.5, alpha = 0.9) +
        scale_fill_manual(values = c(Weekday = clr$deep, Weekend = clr$rem)) +
        labs(x = NULL, y = "Avg Sleep (minutes)") +
        dash_theme() +
        theme(legend.position = "none")
    } else {
      # Single participant: average sleep by day type
      plot_data <- sleep_summary %>%
        group_by(day_type) %>%
        summarise(avg_minutes = mean(total_minutes, na.rm = TRUE), .groups = "drop")
      
      p <- ggplot(plot_data, aes(x = day_type, y = avg_minutes, fill = day_type)) +
        geom_col(width = 0.5, alpha = 0.9) +
        scale_fill_manual(values = c(Weekday = clr$deep, Weekend = clr$rem)) +
        labs(x = NULL, y = "Sleep Duration (minutes)") +
        dash_theme() +
        theme(legend.position = "none")
    }
    
    ggplotly(p, tooltip = c("x", "y")) %>%
      layout(hoverlabel = list(bgcolor = clr$bg),
             margin = list(l = 50, r = 20, t = 20, b = 40))
  })
  
  # Steps: Weekday vs Weekend
  # Compares average step count between weekdays and weekends
  output$weekday_steps_chart <- renderPlotly({
    req(auth$logged_in)
    df <- steps_data()
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No steps data available"))
    }
    if (!"day_type" %in% names(df)) {
      return(create_empty_plot("Day type data not available"))
    }
    
    is_all <- auth$is_admin && is.null(current_participant())
    
    # Calculate total steps per day
    daily_steps <- df %>%
      mutate(date = as.Date(date)) %>%
      group_by(participantID, date, day_type) %>%
      summarise(total_steps = sum(steps_5min, na.rm = TRUE), .groups = "drop")
    
    if (is_all) {
      # Aggregate: average steps across all participants
      plot_data <- daily_steps %>%
        group_by(day_type) %>%
        summarise(avg_steps = mean(total_steps, na.rm = TRUE), .groups = "drop")
      
      p <- ggplot(plot_data, aes(x = day_type, y = avg_steps, fill = day_type)) +
        geom_col(width = 0.5, alpha = 0.9) +
        scale_fill_manual(values = c(Weekday = clr$steps, Weekend = clr$walk)) +
        scale_y_continuous(labels = scales::comma) +
        labs(x = NULL, y = "Avg Steps") +
        dash_theme() +
        theme(legend.position = "none")
    } else {
      # Single participant: average steps by day type
      plot_data <- daily_steps %>%
        group_by(day_type) %>%
        summarise(avg_steps = mean(total_steps, na.rm = TRUE), .groups = "drop")
      
      p <- ggplot(plot_data, aes(x = day_type, y = avg_steps, fill = day_type)) +
        geom_col(width = 0.5, alpha = 0.9) +
        scale_fill_manual(values = c(Weekday = clr$steps, Weekend = clr$walk)) +
        scale_y_continuous(labels = scales::comma) +
        labs(x = NULL, y = "Steps") +
        dash_theme() +
        theme(legend.position = "none")
    }
    
    ggplotly(p, tooltip = c("x", "y")) %>%
      layout(hoverlabel = list(bgcolor = clr$bg),
             margin = list(l = 50, r = 20, t = 20, b = 40))
  })
  
  # HRV: Weekday vs Weekend (Admin Only)
  # Compares average HRV between weekdays and weekends
  output$weekday_hrv_chart <- renderPlotly({
    req(auth$logged_in, auth$is_admin)
    df <- hrv_data()
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No HRV data available"))
    }
    if (!"day_type" %in% names(df)) {
      return(create_empty_plot("Day type data not available"))
    }
    
    is_all <- auth$is_admin && is.null(current_participant())
    
    if (is_all) {
      # Aggregate: average HRV across all participants
      plot_data <- df %>%
        filter(!is.na(rmssd_ms)) %>%
        group_by(day_type) %>%
        summarise(avg_hrv = mean(rmssd_ms, na.rm = TRUE), .groups = "drop")
      y_label <- "Avg HRV (RMSSD ms, all participants)"
    } else {
      # Single participant: average HRV by day type
      plot_data <- df %>%
        filter(!is.na(rmssd_ms)) %>%
        group_by(day_type) %>%
        summarise(avg_hrv = mean(rmssd_ms, na.rm = TRUE), .groups = "drop")
      y_label <- "Avg HRV (RMSSD ms)"
    }
    
    p <- ggplot(plot_data, aes(x = day_type, y = avg_hrv, fill = day_type)) +
      geom_col(width = 0.5, alpha = 0.9) +
      scale_fill_manual(values = c(Weekday = clr$hrv, Weekend = clr$green)) +
      labs(x = NULL, y = y_label) +
      dash_theme() +
      theme(legend.position = "none")
    
    ggplotly(p, tooltip = c("x", "y")) %>%
      layout(hoverlabel = list(bgcolor = clr$bg),
             margin = list(l = 50, r = 20, t = 20, b = 40))
  })
  
  # Resting Heart Rate: Weekday vs Weekend (Admin Only)
  # Compares average resting heart rate between weekdays and weekends
  output$weekday_hr_chart <- renderPlotly({
    req(auth$logged_in, auth$is_admin)
    df <- daily_metrics()
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No daily metrics data available"))
    }
    if (!"day_type" %in% names(df)) {
      return(create_empty_plot("Day type data not available"))
    }
    
    is_all <- auth$is_admin && is.null(current_participant())
    
    if (is_all) {
      # Aggregate: average resting HR across all participants
      plot_data <- df %>%
        filter(!is.na(resting_heart_rate)) %>%
        group_by(day_type) %>%
        summarise(avg_hr = mean(resting_heart_rate, na.rm = TRUE), .groups = "drop")
      y_label <- "Avg Resting HR (bpm, all participants)"
    } else {
      # Single participant: average resting HR by day type
      plot_data <- df %>%
        filter(!is.na(resting_heart_rate)) %>%
        group_by(day_type) %>%
        summarise(avg_hr = mean(resting_heart_rate, na.rm = TRUE), .groups = "drop")
      y_label <- "Avg Resting HR (bpm)"
    }
    
    p <- ggplot(plot_data, aes(x = day_type, y = avg_hr, fill = day_type)) +
      geom_col(width = 0.5, alpha = 0.9) +
      scale_fill_manual(values = c(Weekday = clr$hr, Weekend = clr$rem)) +
      labs(x = NULL, y = y_label) +
      dash_theme() +
      theme(legend.position = "none")
    
    ggplotly(p, tooltip = c("x", "y")) %>%
      layout(hoverlabel = list(bgcolor = clr$bg),
             margin = list(l = 50, r = 20, t = 20, b = 40))
  })
  
  # ==================== PROJECTIONS TAB CHARTS ====================
  
  # HRV vs Sleep Scatter Plot
  # Examines the relationship between HRV (RMSSD) and total sleep duration
  # with correlation coefficient annotation and linear regression line
  output$hrv_sleep_chart <- renderPlotly({
    req(auth$logged_in)
    df <- hrv_sleep_data()
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No HRV and sleep data available for the selected range"))
    }
    
    is_all <- auth$is_admin && is.null(current_participant())
    
    # Calculate Pearson correlation coefficient
    cor_value <- cor(df$total_sleep_minutes, df$hrv_avg, use = "complete.obs")
    
    if (is_all) {
      # Admin view: color points by participant
      p <- ggplot(df, aes(x = total_sleep_minutes, y = hrv_avg, color = participantID)) +
        geom_point(size = 3, alpha = 0.7) +
        geom_smooth(method = "lm", se = TRUE, color = clr$text_secondary,
                    fill = clr$grid_line, alpha = 0.3, linewidth = 0.8) +
        labs(x = "Total Sleep (minutes)", y = "Avg HRV (RMSSD ms)") +
        annotate("text",
                 x = quantile(df$total_sleep_minutes, 0.80, na.rm = TRUE),
                 y = quantile(df$hrv_avg, 0.95, na.rm = TRUE),
                 label = paste("r =", round(cor_value, 2)),
                 size = 4, color = clr$text_secondary) +
        dash_theme()
    }  else {
      # Individual participant view: single color
      x_pos <- quantile(df$total_sleep_minutes, 0.80, na.rm = TRUE)
      y_pos <- quantile(df$hrv_avg, 0.95, na.rm = TRUE)
      
      p <- ggplot(df, aes(x = total_sleep_minutes, y = hrv_avg)) +
        geom_point(color = clr$hr, size = 3, alpha = 0.7) +
        geom_smooth(method = "lm", se = TRUE, color = clr$hrv,
                    fill = clr$grid_line, alpha = 0.3, linewidth = 0.8) +
        labs(x = "Total Sleep (minutes)", y = "Avg HRV (RMSSD ms)") +
        annotate("text",
                 x = x_pos, y = y_pos,
                 label = paste("r =", round(cor_value, 2)),
                 size = 4, color = clr$text_secondary) +
        dash_theme()
    }
    
    ggplotly(p, tooltip = c("x", "y")) %>%
      layout(
        hoverlabel = list(bgcolor = clr$bg),
        legend = list(orientation = "h", xanchor = "center",
                      x = 0.5, y = -0.5, title = list(text = "")),
        margin = list(l = 50, r = 20, t = 20, b = 80)
      ) %>%
      config(
        toImageButtonOptions = list(
          format   = "png",
          filename = "hrv_vs_sleep",
          width    = 800,
          height   = 600,
          scale    = 3
        )
      )
  })
  
  # ==================== ANALYSIS TAB CHARTS ====================
  
  # Multi-Participant Heart Rate Comparison
  # Shows heart rate trends across all participants for admin analysis
  output$admin_hr_comparison <- renderPlotly({
    req(auth$is_admin)
    data <- all_data()
    df <- data[["hr_intraday_5m"]]
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No heart rate data available"))
    }
    
    # Clean and prepare heart rate data
    df <- add_datetime_column(df) %>%
      filter(!is.na(datetime), heart_rate_avg > 30, heart_rate_avg < 220)
    
    if (input$view_mode == "day") {
      # Study day view: aggregate by study day
      chart_data <- df %>%
        filter(!is.na(study_day)) %>%
        group_by(participantID, study_day) %>%
        summarise(avg_hr = mean(heart_rate_avg, na.rm = TRUE), .groups = "drop")
      
      p <- ggplot(chart_data, aes(x = study_day, y = avg_hr,
                                  color = participantID,
                                  group = participantID)) +
        geom_line(linewidth = 0.8) +
        geom_point(size = 2) +
        scale_x_continuous(breaks = scales::pretty_breaks()) +
        scale_y_continuous(breaks = scales::pretty_breaks()) +
        labs(x = "Study Day", y = "Avg HR (bpm)") +
        dash_theme()
    } else {
      # Date view: aggregate by calendar date
      chart_data <- df %>%
        mutate(date = as.Date(datetime)) %>%
        filter(date >= input$date_range[1], date <= input$date_range[2]) %>%
        group_by(participantID, date) %>%
        summarise(avg_hr = mean(heart_rate_avg, na.rm = TRUE), .groups = "drop")
      
      if (nrow(chart_data) == 0) {
        return(create_empty_plot("No heart rate data for selected filters"))
      }
      
      p <- ggplot(chart_data, aes(x = date, y = avg_hr,
                                  color = participantID,
                                  group = participantID)) +
        geom_line(linewidth = 0.8) +
        geom_point(size = 2) +
        scale_x_date(date_labels = "%b %d") +
        scale_y_continuous(breaks = scales::pretty_breaks()) +
        labs(x = NULL, y = "Avg HR (bpm)") +
        dash_theme()
    }
    
    ggplotly(p, tooltip = c("x", "y", "colour")) %>%
      layout(hoverlabel = list(bgcolor = clr$bg),
             legend = list(orientation = "h", xanchor = "center",
                           x = 0.5, y = -0.5, title = list(text = "")),
             margin = list(l = 50, r = 20, t = 20, b = 80))
  })
  
  # Multi-Participant Steps Comparison
  # Shows daily step counts across all participants for admin analysis
  output$admin_steps_comparison <- renderPlotly({
    req(auth$is_admin)
    data <- all_data()
    df <- data[["steps_intraday_5m"]]
    if (is.null(df) || nrow(df) == 0) {
      return(create_empty_plot("No steps data available"))
    }
    
    if (input$view_mode == "day") {
      # Study day view: aggregate by study day
      chart_data <- df %>%
        filter(!is.na(study_day)) %>%
        group_by(participantID, study_day) %>%
        summarise(total = sum(steps_5min, na.rm = TRUE), .groups = "drop")
      
      p <- ggplot(chart_data, aes(x = study_day, y = total, fill = participantID)) +
        geom_col(position = "dodge", alpha = 0.9) +
        scale_x_continuous(breaks = scales::pretty_breaks()) +
        scale_y_continuous(labels = scales::comma,
                           breaks = scales::pretty_breaks()) +
        labs(x = "Study Day", y = "Steps") +
        dash_theme()
    } else {
      # Date view: aggregate by calendar date
      chart_data <- df %>%
        mutate(date = as.Date(date)) %>%
        filter(date >= input$date_range[1], date <= input$date_range[2]) %>%
        group_by(participantID, date) %>%
        summarise(total = sum(steps_5min, na.rm = TRUE), .groups = "drop")
      
      if (nrow(chart_data) == 0) {
        return(create_empty_plot("No steps data for selected filters"))
      }
      
      p <- ggplot(chart_data, aes(x = date, y = total, fill = participantID)) +
        geom_col(position = "dodge", alpha = 0.9) +
        scale_x_date(date_labels = "%b %d") +
        scale_y_continuous(labels = scales::comma,
                           breaks = scales::pretty_breaks()) +
        labs(x = NULL, y = "Steps") +
        dash_theme()
    }
    
    ggplotly(p, tooltip = c("x", "y", "fill")) %>%
      layout(hoverlabel = list(bgcolor = clr$bg),
             legend = list(orientation = "h", xanchor = "center",
                           x = 0.5, y = -0.5, title = list(text = "")),
             margin = list(l = 50, r = 20, t = 20, b = 80))
  })
  
  # Data Completeness Heatmap
  # Visualizes data availability across participants and dates
  output$admin_completeness_heatmap <- renderPlotly({
    req(auth$is_admin)
    data <- all_data()
    
    # Helper function to extract presence data for a given dataset
    get_presence <- function(df, label) {
      if (is.null(df) || nrow(df) == 0 || !"date" %in% names(df)) return(NULL)
      df %>%
        mutate(date = as.Date(date)) %>%
        filter(date >= input$date_range[1], date <= input$date_range[2]) %>%
        distinct(participantID, date) %>%
        mutate(source = label)
    }
    
    # Collect presence from multiple data sources
    presence <- bind_rows(
      get_presence(data[["hr_intraday_5m"]], "hr"),
      get_presence(data[["steps_intraday_5m"]], "steps")
    )
    
    # Add sleep data (uses dateOfSleep column)
    sleep_df <- data[["sleep_minute"]]
    if (!is.null(sleep_df) && nrow(sleep_df) > 0) {
      sleep_presence <- sleep_df %>%
        mutate(date = as.Date(dateOfSleep)) %>%
        filter(date >= input$date_range[1], date <= input$date_range[2]) %>%
        distinct(participantID, date) %>%
        mutate(source = "sleep")
      presence <- bind_rows(presence, sleep_presence)
    }
    
    if (nrow(presence) == 0) {
      return(create_empty_plot("No data available for completeness check"))
    }
    
    # Calculate number of sources present per participant per date
    completeness <- presence %>%
      group_by(participantID, date) %>%
      summarise(sources_present = n_distinct(source), .groups = "drop") %>%
      complete(participantID, date, fill = list(sources_present = 0))
    
    # Create heatmap with color scale from grey (0) to green (3 sources)
    plot_ly(
      data = completeness,
      x = ~date, y = ~participantID, z = ~sources_present,
      type = "heatmap",
      colorscale = list(
        c(0, clr$lightgrey),
        c(0.5, clr$lightblue),
        c(1, clr$green)
      ),
      hovertemplate = paste(
        "Participant: %{y}<br>",
        "Date: %{x}<br>",
        "Data sources present: %{z}/3<extra></extra>"
      )
    ) %>%
      layout(
        xaxis = list(title = "Date", tickformat = "%b %d"),
        yaxis = list(title = "Participant"),
        margin = list(l = 80, r = 20, t = 20, b = 60)
      )
  })
  
  # Participant Activity Summary Table
  # Displays aggregated metrics for each participant
  output$admin_summary_table <- renderDT({
    req(auth$is_admin)
    data <- all_data()
    df <- data[["daily_metrics"]]
    if (is.null(df) || nrow(df) == 0) {
      return(datatable(data.frame(Message = "No daily metrics data available")))
    }
    
    # Aggregate daily metrics by participant within date range
    summary_table <- df %>%
      mutate(date = as.Date(date)) %>%
      filter(date >= input$date_range[1], date <= input$date_range[2]) %>%
      group_by(participantID) %>%
      summarise(
        `Avg Resting HR`  = round(mean(resting_heart_rate,    na.rm = TRUE), 1),
        `Avg Steps`       = round(mean(steps_daily_total,     na.rm = TRUE)),
        `Avg Sleep (min)` = round(mean(total_sleep_minutes,   na.rm = TRUE)),
        `Avg SpO2`        = round(mean(spo2_average_value,    na.rm = TRUE), 1),
        `Avg HRV`         = round(mean(hrv_avg_nightly,       na.rm = TRUE), 1),
        .groups = "drop"
      )
    
    datatable(summary_table,
              options = list(pageLength = 15, scrollX = TRUE, dom = "ftip"),
              rownames = FALSE,
              class = "compact stripe")
  })
  
  # ==================== DATA VIEW TABLE ====================
  
  # Render raw data table for selected dataset
  # Allows users to browse the underlying data from any available dataset
  output$data_view_table <- DT::renderDataTable({
    req(auth$logged_in)
    req(input$data_view_select)
    dataset_name <- input$data_view_select
    
    # Map dataset name to reactive data source
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
    
    # Return placeholder if no data available
    if (is.null(df) || nrow(df) == 0) {
      return(DT::datatable(data.frame(Message = "No data available for this dataset")))
    }
    
    # Display dataset with scroll and pagination options
    DT::datatable(df, options = list(scrollX = TRUE, pageLength = 20))
  })
}

# ============================================================================
# RUN THE APPLICATION
# ============================================================================

# Launch the Shiny application with the defined UI and server
shinyApp(ui = ui, server = server)