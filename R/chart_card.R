# ==============================================================================
# R/chart_card.R
# ==============================================================================
# Reusable wrapper for every chart card in the dashboard. Provides:
#   - A collapse/expand toggle (eye / eye-slash-fill icon)
#   - An info popover (info-circle icon) with chart-specific explanatory
#     text, defined in CHART_INFO below
#   - A consistent card header layout (title left, icons right)
#
# ICON ACTIVE-STATE COLOR: rather than swapping icon shapes when the info
# popover is open/closed (which would require custom JS to hook Bootstrap's
# shown.bs.popover / hidden.bs.popover events), the info icon's COLOR
# changes instead, driven entirely by CSS. Bootstrap automatically adds an
# aria-describedby attribute to a popover's trigger element while — and
# only while — that popover is open. custom.css targets this attribute
# directly (.chart-info-trigger[aria-describedby] { ... }) to recolor the
# icon. No JavaScript, no server-side state needed for this one.
#
# This file is intentionally stateless and has no knowledge of this app's
# data structures, reactives, or auth system. It only needs:
#   - a unique chart_id (string)
#   - a title (string)
#   - a UI output function (e.g. plotlyOutput, DTOutput) and its args
#   - whether the chart should start collapsed (is_admin, passed in by caller)
#
# The actual collapse/expand SERVER LOGIC lives in app.R's server function.
# For each chart_id, app.R must register TWO things:
#   1. output[[paste0(chart_id, "_toggle_ui")]] <- renderUI({...})
#      Renders the clickable icon (eye / eye-slash-fill) as an actionLink,
#      reading current state from chart_state[[chart_id]]. Re-renders
#      automatically whenever chart_state[[chart_id]] changes.
#   2. observeEvent(input[[paste0(chart_id, "_toggle_click")]], {...})
#      Flips chart_state[[chart_id]] and toggles the body div's visibility
#      via shinyjs::toggle(paste0(chart_id, "_body")).
# Both are registered generically via a small loop over a known list of
# chart_ids — see init_chart_card_observers() in app.R. This file only
# builds the static UI shell; app.R supplies all reactive behavior.
# ==============================================================================

# ------------------------------------------------------------------------------
# CHART_INFO
# ------------------------------------------------------------------------------
# Popover text for each chart, keyed by chart_id. Add one entry per chart as
# the audit reaches it. Charts without an entry here will show a generic
# fallback message (see chart_card_ui() below) rather than erroring.
# ------------------------------------------------------------------------------

CHART_INFO <- list(
  
  # Overview
  
  plot_hr = HTML("
  <b>What this shows:</b><br>
  Average heart rate trends, summarized by date or study day.<br><br>
  <b>Data source:</b><br>
  hr_intraday_5m.csv<br><br>
  <b>View modes:</b><br>
  &bull; <b>By Date:</b> Calendar dates<br>
  &bull; <b>By Study Day:</b> Averaged per study day
"),
  
  plot_steps = HTML("
  <b>What this shows:</b><br>
  Total daily steps, with a 10,000-step goal line for reference.<br><br>
  <b>Data source:</b><br>
  steps_intraday_5m.csv<br><br>
  <b>View modes:</b><br>
  &bull; <b>By Date:</b> Calendar dates<br>
  &bull; <b>By Study Day:</b> Totaled per study day
"),
  
  plot_sleep = HTML("
  <b>What this shows:</b><br>
  Minutes spent in Deep, REM, and Light sleep stages, stacked per night.<br><br>
  <b>Data source:</b><br>
  sleep_minute.csv<br><br>
  <b>Note:</b><br>
  Wake minutes are excluded from this chart.
"),
  
  # Heart Rate Tab
  
  hr_timeseries = HTML("
  <b>What this shows:</b><br>
  Heart rate trends over time, plotted from 5-minute interval averages.<br><br>
  <b>Data source:</b><br>
  hr_intraday_5m.csv (5-minute intervals from Fitbit)<br><br>
  <b>Filters applied:</b><br>
  &bull; Values between 30-220 bpm only<br>
  &bull; Your selected date range or study day range<br><br>
  <b>View modes:</b><br>
  &bull; <b>By Date:</b> Calendar dates, raw 5-minute points with a smoothed trend line<br>
  &bull; <b>By Study Day:</b> One averaged point per study day
"),
  
  hr_distribution = HTML("
  <b>What this shows:</b><br>
  Distribution of heart rate readings across the selected range.<br><br>
  <b>Data source:</b><br>
  hr_intraday_5m.csv<br><br>
  <b>View modes:</b><br>
  &bull; <b>By Date:</b> One combined histogram<br>
  &bull; <b>By Study Day:</b> Color-coded by study day
"),
  
  hr_by_hour = HTML("
  <b>What this shows:</b><br>
  Average heart rate by hour of day, revealing daily rhythm patterns.<br><br>
  <b>Data source:</b><br>
  hr_intraday_5m.csv<br><br>
  <b>View modes:</b><br>
  &bull; <b>By Date:</b> Bars with standard deviation error bars<br>
  &bull; <b>By Study Day:</b> Separate line per study day
"),
  
  hrv_chart = HTML("
  <b>What this shows:</b><br>
  Heart rate variability (RMSSD), a marker of autonomic nervous system activity.<br><br>
  <b>Data source:</b><br>
  hrv_intraday.csv<br><br>
  <b>Visibility:</b><br>
  Admin-only chart.<br><br>
  <b>View modes:</b><br>
  &bull; <b>By Date:</b> Raw points over time<br>
  &bull; <b>By Study Day:</b> Averaged per study day
"),
  
  # Sleep Tab
  
  sleep_duration = HTML("
  <b>What this shows:</b><br>
  Total minutes of tracked sleep stages (Deep, REM, Light, Wake) per night.<br><br>
  <b>Data source:</b><br>
  sleep_minute.csv<br><br>
  <b>View modes:</b><br>
  &bull; <b>By Date:</b> Calendar dates<br>
  &bull; <b>By Study Day:</b> Totaled per study day
"),
  
  sleep_stage_pie = HTML("
  <b>What this shows:</b><br>
  Overall proportion of time spent in each sleep stage across the selected range.<br><br>
  <b>Data source:</b><br>
  sleep_minute.csv
"),
  
  breathing_rate_chart = HTML("
  <b>What this shows:</b><br>
  Breathing rate during sleep, broken out by sleep stage plus a Full Sleep aggregate line.<br><br>
  <b>Data source:</b><br>
  breathing_rate_summary.csv<br><br>
  <b>View modes:</b><br>
  &bull; <b>By Date:</b> Calendar dates<br>
  &bull; <b>By Study Day:</b> Per study day
"),
  
  hypnogram_chart = HTML("
  <b>What this shows:</b><br>
  Sleep stage transitions across a single selected night.<br><br>
  <b>Data source:</b><br>
  sleep_minute.csv<br><br>
  <b>Note:</b><br>
  Use the night selector to choose which date's hypnogram to view.
"),
  
  sleep_efficiency_chart = HTML("
  <b>What this shows:</b><br>
  Percent of time in bed actually spent asleep (not awake), with an 85% target line.<br><br>
  <b>Data source:</b><br>
  sleep_minute.csv<br><br>
  <b>View modes:</b><br>
  &bull; <b>By Date:</b> Calendar dates<br>
  &bull; <b>By Study Day:</b> Per study day
"),
  
  # Activity
  
  zone_minutes_chart = HTML("
  <b>What this shows:</b><br>
  Minutes spent in each heart rate intensity zone: Fat Burn, Cardio, and Peak.<br><br>
  <b>Data source:</b><br>
  zone_minutes_intraday_5m.csv<br><br>
  <b>View modes:</b><br>
  &bull; <b>By Date:</b> Calendar dates<br>
  &bull; <b>By Study Day:</b> Per study day
"),
  
  exercise_sessions_chart = HTML("
  <b>What this shows:</b><br>
  Individual logged exercise sessions, sized by duration and colored by activity type.<br><br>
  <b>Data source:</b><br>
  activity_sessions.csv<br><br>
  <b>Note:</b><br>
  Activity types outside the standard set (walk, run, bike, sport, workout, swim, yoga) are grouped as \"Other.\"
"),
  
  sedentary_chart = HTML("
  <b>What this shows:</b><br>
  Total minutes spent sedentary per day.<br><br>
  <b>Data source:</b><br>
  sedentary_periods.csv<br><br>
  <b>View modes:</b><br>
  &bull; <b>By Date:</b> Calendar dates<br>
  &bull; <b>By Study Day:</b> Per study day
"),
  
  activity_steps_chart = HTML("
  <b>What this shows:</b><br>
  Total daily steps with a 10,000-step goal line.<br><br>
  <b>Data source:</b><br>
  steps_intraday_5m.csv<br><br>
  <b>Note:</b><br>
  Same underlying data as the Overview tab's Daily Steps chart.
"),
  
  activity_steps_by_hour = HTML("
  <b>What this shows:</b><br>
  Average steps by hour of day, revealing activity patterns across the day.<br><br>
  <b>Data source:</b><br>
  steps_intraday_5m.csv<br><br>
  <b>View modes:</b><br>
  &bull; <b>By Date:</b> One combined bar chart<br>
  &bull; <b>By Study Day:</b> Separate line per study day
"),
  
  activity_distance_chart = HTML("
  <b>What this shows:</b><br>
  Total distance traveled per day, in meters.<br><br>
  <b>Data source:</b><br>
  distance_intraday.csv<br><br>
  <b>View modes:</b><br>
  &bull; <b>By Date:</b> Calendar dates<br>
  &bull; <b>By Study Day:</b> Per study day
"),
  
  #analysis
  
  admin_hr_comparison = HTML("
  <b>What this shows:</b><br>
  Average heart rate per participant over time, aligned by study day for
  cross-participant comparison.<br><br>
  <b>Data source:</b><br>
  hr_intraday_5m.csv<br><br>
  <b>Note:</b><br>
  Admin-only. Each line represents one participant.
"),
  
  admin_steps_comparison = HTML("
  <b>What this shows:</b><br>
  Total daily steps per participant, side by side for direct comparison.<br><br>
  <b>Data source:</b><br>
  steps_intraday_5m.csv<br><br>
  <b>Note:</b><br>
  Admin-only. Each color represents one participant.
"),
  
  admin_completeness_heatmap = HTML("
  <b>What this shows:</b><br>
  Which data sources (heart rate, steps, sleep) are present for each
  participant on each date. Darker = more sources present.<br><br>
  <b>Data source:</b><br>
  hr_intraday_5m.csv, steps_intraday_5m.csv, sleep_minute.csv<br><br>
  <b>Note:</b><br>
  Admin-only. Useful for spotting data gaps before analysis.
"),
  
  admin_summary_table = HTML("
  <b>What this shows:</b><br>
  Per-participant averages for key metrics across the selected date range:
  resting heart rate, steps, sleep duration, SpO2, and HRV.<br><br>
  <b>Data source:</b><br>
  daily_metrics.csv<br><br>
  <b>Note:</b><br>
  Admin-only.
"),
  # data view
  
  data_view_table = HTML("
  <b>What this shows:</b><br>
  Raw CSV data for any dataset, exactly as loaded and filtered by your
  current date or study day selection.<br><br>
  <b>Available datasets:</b><br>
  Heart Rate, Steps, Sleep, Daily Metrics, HRV, Activity Level,
  Zone Minutes, Activity Sessions, Sedentary Periods, SpO2<br><br>
  <b>Note:</b><br>
  Admin-only. Use the dataset selector to switch between tables.
")
  
)

# ------------------------------------------------------------------------------
# chart_card_ui()
# ------------------------------------------------------------------------------
#' Build a standardized, collapsible chart card with a title, collapse
#' toggle, and info popover.
#'
#' @param chart_id Unique string ID for this chart. Must match the Shiny
#'   output ID used in the corresponding render*() call in server (e.g.
#'   "hr_timeseries"). No two charts in the app may share a chart_id.
#' @param title Display title shown in the card header.
#' @param output_fn The Shiny output UI function to call, e.g. plotlyOutput,
#'   DT::dataTableOutput. Passed as a function reference, not a call.
#' @param is_admin Logical. Whether the current user is an admin. Used only
#'   to set this chart's DEFAULT collapse state on first render (admins
#'   default to collapsed, regular users default to open). After the
#'   initial render, collapse state is controlled by chart_state in server
#'   and persists for the session regardless of is_admin.
#' @param ... Additional arguments passed through to output_fn (e.g.
#'   height = "400px").
#'
#' @return A tagList containing the full chart card: header (title + icons)
#'   and a collapsible body wrapping the chart output.
chart_card_ui <- function(chart_id, title, output_fn, is_admin = FALSE, extra_ui = NULL, ...) {
  
  body_id <- paste0(chart_id, "_body")
  
  info_content <- CHART_INFO[[chart_id]]
  if (is.null(info_content)) {
    info_content <- HTML("<i>No description available for this chart yet.</i>")
  }
  
  div(class = "chart-card",
      
      # ---- Header: title (left) + eye toggle + info icon (right) ----
      div(style = "display: flex; justify-content: space-between; align-items: center; padding: 0 15px;",
          
          p(title, class = "chart-title", style = "margin: 0;"),
          
          div(style = "display: flex; align-items: center; gap: 14px;",
              
              # Collapse/expand toggle. Fully server-rendered by app.R's
              # output[[paste0(chart_id, "_toggle_ui")]] <- renderUI({...}),
              # which emits an actionLink (input ID: chart_id + "_toggle_click")
              # whose icon reflects chart_state[[chart_id]]. This must be a
              # full renderUI rather than a static icon here, because Shiny
              # cannot reactively swap an actionLink's icon from the UI side.
              uiOutput(paste0(chart_id, "_toggle_ui"), inline = TRUE),
              
              # Info icon with popover (purely client-side, no server
              # observer needed — bslib::popover() handles its own
              # open/close state). Color (default vs. active-while-open)
              # is handled entirely by CSS in custom.css via the
              # .chart-info-trigger class and Bootstrap's own
              # aria-describedby attribute, which Bootstrap automatically
              # adds to this span only while its popover is open. No JS
              # is needed for the active-state color change.
              popover(
                span(
                  bsicons::bs_icon("info-circle"),
                  class = "chart-info-trigger"
                ),
                title = "About This Chart",
                info_content,
                placement = "left"
              )
          )
      ),
      
      # ---- Collapsible body ----
      # Visibility is controlled entirely by chart_state[[chart_id]] in
      # app.R's server (seeded from is_admin the first time this chart_id
      # is encountered, then driven by toggle clicks after that). This div
      # starts with no inline display style; app.R's initialization step
      # sets the correct starting visibility via shinyjs once, on app load.
      div(id = body_id,
          extra_ui,
          output_fn(chart_id, ...)
      )
  )
}