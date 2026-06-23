# ==============================================================================
# R/chart_card.R2
# ==============================================================================
# Reusable wrapper for every chart card in the dashboard. Provides:
#   - A collapse/expand toggle (eye / eye-slash-fill icon)
#   - An info popover (info-circle icon) with chart-specific explanatory
#     text, defined in CHART_INFO below
#   - A consistent card header layout (title left, icons right)
#
# CHART_INFO entries can be either:
#   - A single HTML() value (same content for users and admins)
#   - A list(user = HTML(...), admin = HTML(...)) for role-specific content
#
# chart_card_ui() selects the correct content based on is_admin.
# ==============================================================================

CHART_INFO <- list(
  
  # ============================================================
  # OVERVIEW TAB
  # ============================================================
  
  plot_hr = list(
    user = HTML("
      <b>What this shows:</b><br>
      Your average heart rate over time, summarized by date or study day.<br><br>
      <b>Data source:</b><br>
      Fitbit 5-minute heart rate readings<br><br>
      <b>View modes:</b><br>
      &bull; <b>By Date:</b> Heart rate plotted on calendar dates<br>
      &bull; <b>By Study Day:</b> One averaged point per study day
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Average heart rate over time, summarized by date or study day.<br><br>
      <b>Data source:</b><br>
      hr_intraday_5m.csv (5-minute intervals)<br><br>
      <b>View modes:</b><br>
      &bull; <b>By Date:</b> Calendar dates<br>
      &bull; <b>By Study Day:</b> One averaged point per study day<br><br>
      <b>All Participants mode:</b><br>
      Cohort average across all participants per study day.
    ")
  ),
  
  plot_steps = list(
    user = HTML("
      <b>What this shows:</b><br>
      Your total daily steps with a 10,000-step goal line for reference.<br><br>
      <b>Data source:</b><br>
      Fitbit step count data<br><br>
      <b>View modes:</b><br>
      &bull; <b>By Date:</b> Calendar dates<br>
      &bull; <b>By Study Day:</b> Totaled per study day
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Total daily steps with a 10,000-step goal line.<br><br>
      <b>Data source:</b><br>
      steps_intraday_5m.csv<br><br>
      <b>View modes:</b><br>
      &bull; <b>By Date:</b> Calendar dates<br>
      &bull; <b>By Study Day:</b> Totaled per study day<br><br>
      <b>All Participants mode:</b><br>
      Average daily steps across all participants per study day.
    ")
  ),
  
  plot_sleep = list(
    user = HTML("
      <b>What this shows:</b><br>
      Minutes spent in Deep, REM, and Light sleep each night, stacked by stage.<br><br>
      <b>Data source:</b><br>
      Fitbit sleep stage data<br><br>
      <b>Note:</b><br>
      Wake minutes are excluded from this chart.
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Minutes in Deep, REM, and Light sleep per night, stacked.<br><br>
      <b>Data source:</b><br>
      sleep_minute.csv<br><br>
      <b>Note:</b><br>
      Wake minutes are excluded.<br><br>
      <b>All Participants mode:</b><br>
      Average minutes per sleep stage per study day, averaged across participants.
    ")
  ),
  
  # ============================================================
  # HEART RATE TAB
  # ============================================================
  
  hr_timeseries = list(
    user = HTML("
      <b>What this shows:</b><br>
      Your heart rate trends over time from 5-minute Fitbit readings.<br><br>
      <b>Filters applied:</b><br>
      &bull; Values between 30–220 bpm only<br>
      &bull; Your selected date or study day range<br><br>
      <b>View modes:</b><br>
      &bull; <b>By Date:</b> Raw 5-minute points with a smoothed trend line<br>
      &bull; <b>By Study Day:</b> One averaged point per study day
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Heart rate trends over time from 5-minute interval averages.<br><br>
      <b>Data source:</b><br>
      hr_intraday_5m.csv<br><br>
      <b>Filters applied:</b><br>
      &bull; Values between 30–220 bpm only<br>
      &bull; Selected date or study day range<br><br>
      <b>View modes:</b><br>
      &bull; <b>By Date:</b> Raw 5-minute points with smoothed trend line<br>
      &bull; <b>By Study Day:</b> One averaged point per study day<br><br>
      <b>All Participants mode:</b><br>
      &bull; <b>Aggregate:</b> Single cohort-average line per study day<br>
      &bull; <b>Split by Participant:</b> One line per participant
    ")
  ),
  
  hr_distribution = list(
    user = HTML("
      <b>What this shows:</b><br>
      The distribution of your heart rate readings across the selected range.<br><br>
      <b>View modes:</b><br>
      &bull; <b>By Date:</b> One combined histogram<br>
      &bull; <b>By Study Day:</b> Color-coded histogram bars by study day
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Distribution of heart rate readings across the selected range.<br><br>
      <b>Data source:</b><br>
      hr_intraday_5m.csv<br><br>
      <b>View modes:</b><br>
      &bull; <b>By Date:</b> One combined histogram<br>
      &bull; <b>By Study Day:</b> Color-coded by study day<br><br>
      <b>All Participants mode:</b><br>
      Density histogram (y-axis = density not count) with one color
      per participant, so participants with different data volumes
      remain visually comparable.
    ")
  ),
  
  hr_by_hour = list(
    user = HTML("
      <b>What this shows:</b><br>
      Your average heart rate by hour of day, revealing daily rhythm patterns.<br><br>
      <b>View modes:</b><br>
      &bull; <b>By Date:</b> Bar chart with standard deviation error bars<br>
      &bull; <b>By Study Day:</b> One line per study day
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Average heart rate by hour of day, revealing daily rhythm patterns.<br><br>
      <b>Data source:</b><br>
      hr_intraday_5m.csv<br><br>
      <b>View modes:</b><br>
      &bull; <b>By Date:</b> Bar chart with standard deviation error bars<br>
      &bull; <b>By Study Day:</b> One line per study day<br><br>
      <b>All Participants mode:</b><br>
      &bull; <b>Aggregate:</b> Single bar chart averaged across all participants<br>
      &bull; <b>Split by Participant:</b> One line per participant
    ")
  ),
  
  hrv_chart = HTML("
    <b>What this shows:</b><br>
    Heart rate variability (RMSSD), a marker of autonomic nervous system
    activity and recovery. Higher values generally indicate better recovery.<br><br>
    <b>Data source:</b><br>
    hrv_intraday.csv<br><br>
    <b>Visibility:</b><br>
    Admin-only chart.<br><br>
    <b>View modes:</b><br>
    &bull; <b>By Date:</b> Raw HRV points over time<br>
    &bull; <b>By Study Day:</b> Averaged per study day<br><br>
    <b>All Participants mode:</b><br>
    Cohort average RMSSD per study day (y-axis label updates accordingly).
  "),
  
  # ============================================================
  # SLEEP TAB
  # ============================================================
  
  sleep_duration = list(
    user = HTML("
      <b>What this shows:</b><br>
      Total minutes of tracked sleep (Deep, REM, Light, and Wake) per night.<br><br>
      <b>View modes:</b><br>
      &bull; <b>By Date:</b> Calendar dates<br>
      &bull; <b>By Study Day:</b> Totaled per study day
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Total minutes of tracked sleep stages per night.<br><br>
      <b>Data source:</b><br>
      sleep_minute.csv<br><br>
      <b>View modes:</b><br>
      &bull; <b>By Date:</b> Calendar dates<br>
      &bull; <b>By Study Day:</b> Totaled per study day<br><br>
      <b>All Participants mode:</b><br>
      Average total sleep minutes per study day across all participants.
    ")
  ),
  
  sleep_stage_pie = list(
    user = HTML("
      <b>What this shows:</b><br>
      The overall proportion of time spent in each sleep stage across
      your selected range.<br><br>
      <b>Data source:</b><br>
      Fitbit sleep stage data
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Overall proportion of time in each sleep stage across the selected range.<br><br>
      <b>Data source:</b><br>
      sleep_minute.csv<br><br>
      <b>All Participants mode:</b><br>
      Pie combines all participants' sleep minutes together
      (title updates to indicate this). No per-participant breakdown here —
      use the Sleep Duration chart for that.
    ")
  ),
  
  breathing_rate_chart = list(
    user = HTML("
      <b>What this shows:</b><br>
      Your breathing rate during sleep, broken out by sleep stage
      (Deep, Light, REM) plus a Full Sleep aggregate line.<br><br>
      <b>View modes:</b><br>
      &bull; <b>By Date:</b> Calendar dates<br>
      &bull; <b>By Study Day:</b> Per study day
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Breathing rate during sleep by stage (Deep, Light, REM, Full Sleep).<br><br>
      <b>Data source:</b><br>
      breathing_rate_summary.csv<br><br>
      <b>View modes:</b><br>
      &bull; <b>By Date:</b> Calendar dates<br>
      &bull; <b>By Study Day:</b> Per study day<br><br>
      <b>All Participants mode:</b><br>
      Average breathing rate per stage per study day across all participants.
    ")
  ),
  
  hypnogram_chart = list(
    user = HTML("
      <b>What this shows:</b><br>
      Sleep stage transitions across a single selected night, displayed as
      a timeline from sleep onset to wake. Use the night selector above
      the chart to choose which date to view.<br><br>
      <b>Data source:</b><br>
      Fitbit minute-by-minute sleep data
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Sleep stage transitions across a single selected night (individual view),
      or average sleep stage composition per study day (All Participants view).<br><br>
      <b>Data source:</b><br>
      sleep_minute.csv<br><br>
      <b>Individual view:</b><br>
      Timeline of sleep stages from onset to wake for the selected night.
      Use the night selector to switch dates.<br><br>
      <b>All Participants mode:</b><br>
      Stacked bar chart showing average minutes in Deep, Light, and REM
      per study day across all participants. Night selector is hidden
      in this mode.
    ")
  ),
  
  sleep_efficiency_chart = list(
    user = HTML("
      <b>What this shows:</b><br>
      The percentage of time in bed actually spent asleep (not awake),
      with an 85% reference line. Higher is better.<br><br>
      <b>View modes:</b><br>
      &bull; <b>By Date:</b> Calendar dates<br>
      &bull; <b>By Study Day:</b> Per study day
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Percentage of time in bed spent asleep, with an 85% reference line.<br><br>
      <b>Data source:</b><br>
      sleep_minute.csv<br><br>
      <b>View modes:</b><br>
      &bull; <b>By Date:</b> Calendar dates<br>
      &bull; <b>By Study Day:</b> Per study day<br><br>
      <b>All Participants mode:</b><br>
      &bull; <b>Aggregate:</b> Average efficiency per study day across all participants<br>
      &bull; <b>Split by Participant:</b> One line per participant
    ")
  ),
  
  # ============================================================
  # ACTIVITY TAB
  # ============================================================
  
  zone_minutes_chart = list(
    user = HTML("
      <b>What this shows:</b><br>
      Minutes spent in each heart rate intensity zone: Fat Burn, Cardio,
      and Peak. Higher intensity zones indicate more vigorous activity.<br><br>
      <b>View modes:</b><br>
      &bull; <b>By Date:</b> Calendar dates<br>
      &bull; <b>By Study Day:</b> Per study day
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Minutes in Fat Burn, Cardio, and Peak heart rate zones.<br><br>
      <b>Data source:</b><br>
      zone_minutes_intraday_5m.csv<br><br>
      <b>View modes:</b><br>
      &bull; <b>By Date:</b> Calendar dates<br>
      &bull; <b>By Study Day:</b> Per study day<br><br>
      <b>All Participants mode:</b><br>
      Average zone minutes per study day across all participants.
    ")
  ),
  
  exercise_sessions_chart = list(
    user = HTML("
      <b>What this shows:</b><br>
      Your logged exercise sessions, sized by duration and colored by
      activity type. Hover over a dot to see details.<br><br>
      <b>Activity types:</b><br>
      Walk, Run, Bike, Sport, Workout, Swim, Yoga.
      Other types are grouped as \"Other.\"
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Logged exercise sessions, sized by duration and colored by activity type.<br><br>
      <b>Data source:</b><br>
      activity_sessions.csv<br><br>
      <b>Activity types:</b><br>
      Walk, Run, Bike, Sport, Workout, Swim, Yoga. Others grouped as \"Other.\"<br><br>
      <b>All Participants mode:</b><br>
      &bull; <b>By Activity Type:</b> All sessions shown, colored by type,
      hover shows participant name<br>
      &bull; <b>By Participant:</b> Sessions colored by participant ID
    ")
  ),
  
  sedentary_chart = list(
    user = HTML("
      <b>What this shows:</b><br>
      Total minutes spent sedentary per day based on periods of inactivity
      detected by your Fitbit.<br><br>
      <b>View modes:</b><br>
      &bull; <b>By Date:</b> Calendar dates<br>
      &bull; <b>By Study Day:</b> Per study day
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Total minutes sedentary per day.<br><br>
      <b>Data source:</b><br>
      sedentary_periods.csv<br><br>
      <b>View modes:</b><br>
      &bull; <b>By Date:</b> Calendar dates<br>
      &bull; <b>By Study Day:</b> Per study day<br><br>
      <b>All Participants mode:</b><br>
      Average sedentary minutes per study day across all participants.
    ")
  ),
  
  activity_steps_chart = list(
    user = HTML("
      <b>What this shows:</b><br>
      Your total daily steps with a 10,000-step goal line for reference.<br><br>
      <b>Note:</b><br>
      Same underlying data as the Overview tab's Daily Steps chart.
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Total daily steps with a 10,000-step goal line.<br><br>
      <b>Data source:</b><br>
      steps_intraday_5m.csv<br><br>
      <b>Note:</b><br>
      Same data as Overview tab Daily Steps chart.<br><br>
      <b>All Participants mode:</b><br>
      Average daily steps per study day across all participants.
    ")
  ),
  
  activity_steps_by_hour = list(
    user = HTML("
      <b>What this shows:</b><br>
      Your average steps by hour of day, revealing when you are most
      active during the day.<br><br>
      <b>View modes:</b><br>
      &bull; <b>By Date:</b> One combined bar chart across all dates<br>
      &bull; <b>By Study Day:</b> One line per study day
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Average steps by hour of day, revealing daily activity patterns.<br><br>
      <b>Data source:</b><br>
      steps_intraday_5m.csv<br><br>
      <b>View modes:</b><br>
      &bull; <b>By Date:</b> One combined bar chart<br>
      &bull; <b>By Study Day:</b> One line per study day<br><br>
      <b>All Participants mode:</b><br>
      One line per participant averaged across all study days.
    ")
  ),
  
  activity_distance_chart = list(
    user = HTML("
      <b>What this shows:</b><br>
      Total distance traveled per day, in meters, based on your Fitbit
      movement data.<br><br>
      <b>View modes:</b><br>
      &bull; <b>By Date:</b> Calendar dates<br>
      &bull; <b>By Study Day:</b> Per study day
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Total distance traveled per day in meters.<br><br>
      <b>Data source:</b><br>
      distance_intraday.csv<br><br>
      <b>View modes:</b><br>
      &bull; <b>By Date:</b> Calendar dates<br>
      &bull; <b>By Study Day:</b> Per study day<br><br>
      <b>All Participants mode:</b><br>
      Average distance per study day across all participants.
    ")
  ),
  
  # ============================================================
  # ANALYSIS TAB (admin-only tab, single version sufficient)
  # ============================================================
  
  admin_hr_comparison = HTML("
    <b>What this shows:</b><br>
    Average heart rate per participant over time, aligned by study day
    for cross-participant comparison.<br><br>
    <b>Data source:</b><br>
    hr_intraday_5m.csv<br><br>
    <b>Note:</b><br>
    Admin-only. Each line represents one participant.
  "),
  
  admin_steps_comparison = HTML("
    <b>What this shows:</b><br>
    Total daily steps per participant, displayed side by side for
    direct comparison.<br><br>
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
    Admin-only. Useful for identifying data gaps before analysis.
  "),
  
  admin_summary_table = HTML("
    <b>What this shows:</b><br>
    Per-participant averages across the selected date range for:
    resting heart rate, steps, sleep duration, SpO2, and HRV.<br><br>
    <b>Data source:</b><br>
    daily_metrics.csv<br><br>
    <b>Note:</b><br>
    Admin-only.
  "),
  
  # ============================================================
  # DATA VIEW TAB (admin-only)
  # ============================================================
  
  data_view_table = HTML("
    <b>What this shows:</b><br>
    Raw CSV data for any dataset, exactly as loaded and filtered by
    your current date or study day selection.<br><br>
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
#' @param chart_id Unique string ID for this chart.
#' @param title Display title shown in the card header.
#' @param output_fn The Shiny output UI function (e.g. plotlyOutput, DTOutput).
#' @param is_admin Logical. Controls default collapse state and popover content.
#' @param extra_ui Optional UI to render inside the card body above the chart.
#' @param ... Additional arguments passed to output_fn (e.g. height = "400px").
#'
#' @return A div containing the full chart card.
chart_card_ui <- function(chart_id, title, output_fn, is_admin = FALSE, extra_ui = NULL, ...) {
  
  body_id <- paste0(chart_id, "_body")
  
  # Select popover content based on role
  info_entry <- CHART_INFO[[chart_id]]
  if (is.null(info_entry)) {
    info_content <- HTML("<i>No description available for this chart yet.</i>")
  } else if (is.list(info_entry)) {
    info_content <- if (isTRUE(is_admin)) info_entry$admin else info_entry$user
  } else {
    info_content <- info_entry
  }
  
  div(class = "chart-card",
      
      # ---- Header ----
      div(style = "display: flex; justify-content: space-between; align-items: center; padding: 0 15px;",
          
          p(title, class = "chart-title", style = "margin: 0;"),
          
          div(style = "display: flex; align-items: center; gap: 14px;",
              
              uiOutput(paste0(chart_id, "_toggle_ui"), inline = TRUE),
              
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
      div(id = body_id,
          extra_ui,
          output_fn(chart_id, ...)
      )
  )
}