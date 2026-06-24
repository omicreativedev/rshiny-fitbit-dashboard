# ==============================================================================
# R/chart_card.R
# Simmons University Fitbit Research Dashboard
# STARS Program / Boston University Labs
# ==============================================================================
#
# PURPOSE
# -------
# This file provides two reusable UI components used throughout the dashboard:
#
#   1. chart_card_ui()  — wraps every Plotly/DT chart in a collapsible card
#                         with a title, eye toggle, and info popover.
#
#   2. metric_card_ui() — wraps every KPI/insight text metric in a card
#                         with an eye toggle and info popover.
#
# It also defines CHART_INFO, a named list of popover content for every
# chart and metric card in the app. Entries support either:
#   - A single HTML() value (shown to both users and admins), or
#   - A list(user = HTML(...), admin = HTML(...)) for role-specific content.
#
# The correct version is selected at render time by chart_card_ui() and
# metric_card_ui() based on the is_admin argument.
#
#
# SERVER-SIDE WIRING (in app.R)
# ------------------------------
# chart_card_ui() builds the static HTML shell only. All reactive behavior
# (collapse/expand toggling) is wired in app.R via two helpers:
#
#   init_chart_card(chart_id, is_admin)
#     — Seeds collapse state, renders the eye icon, registers the click handler.
#     — Must be called once per chart_id inside the relevant tab content function.
#
#   init_metric_card(card_id, is_admin)
#     — Same pattern as above but for metric cards (show/hide value vs "Hidden").
#     — Must be called once per card_id inside the relevant tab content function.
#
# Both functions are safe to call multiple times — a deduplication guard
# (chart_observers_registered) prevents duplicate observer registration.
#
#
# ADDING A NEW CHART OR METRIC CARD
# -----------------------------------
# 1. Add a CHART_INFO entry below (single HTML or list(user=, admin=)).
# 2. Call chart_card_ui() or metric_card_ui() in the appropriate tab content
#    function in app.R.
# 3. Call init_chart_card() or init_metric_card() at the top of that same
#    tab content function.
# 4. Add the render block (output$chart_id <- renderPlotly({...})) in app.R.
#
# ==============================================================================

CHART_INFO <- list(
  
  
  # ============================================================================
  # OVERVIEW TAB — KPI METRIC CARDS
  # Four summary cards shown at the top of the Overview tab.
  # Shown to all users; hidden by default for admins (value replaced by
  # "Hidden" until the admin clicks the eye icon to reveal).
  # ============================================================================
  
  # Average heart rate across all 5-minute readings in the selected range.
  kpi_hr = list(
    user = HTML("
      <b>What this shows:</b><br>
      Your average heart rate across all readings in the selected range,
      measured in beats per minute (bpm).<br><br>
      <b>Data source:</b><br>
      Fitbit 5-minute heart rate readings<br><br>
      <b>Note:</b><br>
      A typical resting heart rate for adults is 60–100 bpm.
      Lower resting HR often indicates better cardiovascular fitness.
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Mean heart rate across all 5-minute interval readings
      in the selected range, in bpm.<br><br>
      <b>Data source:</b><br>
      hr_intraday_5m.csv<br><br>
      <b>Filters:</b><br>
      Values between 30–220 bpm only.<br><br>
      <b>All Participants mode:</b><br>
      Average across all participants' readings combined.
    ")
  ),
  
  # Average daily step total across the selected range.
  kpi_steps = list(
    user = HTML("
      <b>What this shows:</b><br>
      Your average daily step count across the selected range.<br><br>
      <b>Data source:</b><br>
      Fitbit step count data<br><br>
      <b>Note:</b><br>
      The commonly cited goal is 10,000 steps per day,
      though research suggests benefits begin at lower counts.
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Mean daily step total across the selected range.<br><br>
      <b>Data source:</b><br>
      steps_intraday_5m.csv<br><br>
      <b>All Participants mode:</b><br>
      Average daily steps across all participants combined.
    ")
  ),
  
  # Average nightly deep sleep duration in minutes.
  kpi_sleep = list(
    user = HTML("
      <b>What this shows:</b><br>
      Your average nightly deep sleep duration in minutes
      across the selected range.<br><br>
      <b>Data source:</b><br>
      Fitbit sleep stage data<br><br>
      <b>Note:</b><br>
      Deep sleep is the most restorative stage. Adults typically
      get 1–2 hours of deep sleep per night (roughly 13–23% of
      total sleep time).
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Mean nightly deep sleep minutes across the selected range.<br><br>
      <b>Data source:</b><br>
      sleep_minute.csv (sleep_stage == 'deep')<br><br>
      <b>All Participants mode:</b><br>
      Average deep sleep minutes per night across all participants.
    ")
  ),
  
  # Average SpO2 (blood oxygen saturation) percentage.
  kpi_spo2 = list(
    user = HTML("
      <b>What this shows:</b><br>
      Your average blood oxygen saturation (SpO2) across the
      selected range, as a percentage.<br><br>
      <b>Data source:</b><br>
      Fitbit SpO2 sensor data<br><br>
      <b>Note:</b><br>
      Normal SpO2 is typically 95–100%. Values below 90%
      may warrant medical attention.
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Mean SpO2 percentage across the selected range.<br><br>
      <b>Data source:</b><br>
      spo2_intraday.csv<br><br>
      <b>Filters:</b><br>
      Values between 70–100% only.<br><br>
      <b>All Participants mode:</b><br>
      Average SpO2 across all participants' readings combined.
    ")
  ),
  
  
  # ============================================================================
  # OVERVIEW TAB — CHARTS
  # Three charts shown below the KPI cards on the Overview tab.
  # Left column: plot_hr, plot_steps (side by side).
  # Full width: plot_sleep.
  # ============================================================================
  
  # Heart Rate Over Time — line chart of average HR by date or study day.
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
  
  # Daily Steps — bar chart of total steps per day with 10,000-step goal line.
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
  
  # Sleep Stage Breakdown — stacked bar of Deep/REM/Light minutes per night.
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
  
  
  # ============================================================================
  # HEART RATE TAB — CHARTS
  # Full width: hr_timeseries.
  # Side by side: hr_distribution (left), hr_by_hour (right).
  # Full width: hrv_chart (admin only).
  # ============================================================================
  
  # Heart Rate Time Series — raw 5-min readings or study-day averages.
  # Admins get Aggregate / Split by Participant toggle in All Participants mode.
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
  
  # Heart Rate Distribution — histogram of HR readings.
  # In All Participants mode switches to density (y-axis) for comparability.
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
  
  # Heart Rate by Hour of Day — reveals circadian rhythm patterns.
  # Admins get Aggregate / Split by Participant toggle in All Participants mode.
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
  
  # Heart Rate Variability (HRV) — admin-only chart.
  # Single HTML() entry since only admins ever see this chart.
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
  
  hrv_daily_chart = HTML("
    <b>What this shows:</b><br>
    Daily average HRV (RMSSD) with a standard deviation ribbon showing
    the spread of readings within each day. The dashed line at 20 ms
    is a general baseline reference — values consistently below this
    may indicate elevated physiological stress.<br><br>
    <b>Data source:</b><br>
    hrv_intraday.csv (averaged to one value per day)<br><br>
    <b>Admin-only chart.</b><br><br>
    <b>All Participants mode:</b><br>
    Individual participant lines shown in color with a bold cohort
    average line overlaid. The shaded ribbon represents ±1 SD across
    participants per study day. All participants are aligned by study day.
  "),
  
  hrv_heatmap_chart = HTML("
    <b>What this shows:</b><br>
    HRV (RMSSD) by hour of day across dates, displayed as a color-coded
    heatmap. Darker colors indicate lower HRV; greener colors indicate
    higher HRV. Useful for identifying circadian patterns — when during
    the day is autonomic recovery highest or lowest.<br><br>
    <b>Data source:</b><br>
    hrv_intraday.csv<br><br>
    <b>Admin-only chart.</b><br><br>
    <b>All Participants mode:</b><br>
    Averaged across participants by study day and hour. Y-axis switches
    from calendar date to study day for alignment.
  "),
  
  hr_heatmap_chart = HTML("
    <b>What this shows:</b><br>
    Heart rate by hour of day across dates, displayed as a color-coded
    heatmap. Cooler colors indicate lower HR; warmer colors (orange, red)
    indicate higher HR. Reveals daily activity and rest patterns at a
    glance — sleep hours should show lower HR, active hours higher.<br><br>
    <b>Data source:</b><br>
    hr_intraday_5m.csv<br><br>
    <b>Admin-only chart.</b><br><br>
    <b>All Participants mode:</b><br>
    Averaged across participants by study day and hour. Y-axis switches
    from calendar date to study day for alignment.
  "),
  
  
  # ============================================================================
  # SLEEP TAB — CHARTS
  # Side by side: sleep_duration (left), sleep_stage_pie (right).
  # Full width:   breathing_rate_chart.
  # Full width:   hypnogram_chart (with night selector dropdown).
  # Full width:   sleep_efficiency_chart (with Aggregate/Split toggle for admins).
  # ============================================================================
  
  # Sleep Duration Over Time — total sleep minutes per night.
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
  
  # Sleep Stage Distribution — donut chart of proportional time per stage.
  # In All Participants mode, combines all participants' minutes with a title note.
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
  
  # Breathing Rate During Sleep — lines per sleep stage plus full-sleep aggregate.
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
  
  # Hypnogram — timeline of sleep stage transitions for a single selected night.
  # In All Participants mode shows a stacked bar chart instead (night selector hidden).
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
  
  # Sleep Efficiency — % of time in bed actually spent asleep, with 85% target line.
  # Admins get Aggregate / Split by Participant toggle in All Participants mode.
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
  
  # Sleep Latency — minutes to fall asleep
  sleep_latency_chart = list(
    user = HTML("
      <b>What this shows:</b><br>
      How many minutes it takes you to fall asleep each night. Each dot
      represents one sleep session. If you have multiple sleep sessions
      in one night, they are shown separately (labeled S2, S3, etc.).<br><br>
      <b>Data source:</b><br>
      Fitbit minute-by-minute sleep data<br><br>
      <b>Reference lines:</b><br>
      &bull; Green dashed: Good (under 15 minutes)<br>
      &bull; Yellow dashed: Fair (15–30 minutes)<br>
      Above 30 minutes may indicate difficulty falling asleep.
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Sleep latency (minutes from first recorded wake to first sleep stage)
      per session per night. Multiple sessions per night are shown separately.<br><br>
      <b>Data source:</b><br>
      sleep_minute.csv (session boundaries detected by gaps > 120 minutes)<br><br>
      <b>All Participants mode:</b><br>
      Sessions are averaged within each participant-day first, then averaged
      across participants by study day — one data point per study day.<br><br>
      <b>Reference lines:</b><br>
      Green = Good (< 15 min), Yellow = Fair (15–30 min).
    ")
  ),
  
  spo2_chart = list(
    user = HTML("
      <b>What this shows:</b><br>
      Your blood oxygen saturation (SpO2) recorded during sleep each night.
      The line shows your nightly average, the shaded area shows the range
      between your lowest and highest readings, and the error bars show
      the standard deviation (how much readings varied).<br><br>
      <b>Data source:</b><br>
      Fitbit SpO2 sensor (recorded overnight during sleep)<br><br>
      <b>Reference line:</b><br>
      The dashed line at 95% is the clinical normal threshold. Consistently
      healthy SpO2 is 95–100%. Readings below 90% may warrant medical
      attention and could indicate sleep-disordered breathing.<br><br>
      <b>Note:</b><br>
      Nights with fewer than 5 SpO2 readings are excluded.
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Daily SpO2 summary: average with min-max range ribbon and ±1 SD
      error bars. The 95% reference line marks the clinical normal threshold.<br><br>
      <b>Data source:</b><br>
      spo2_intraday.csv (recorded during sleep)<br><br>
      <b>Filters:</b><br>
      Values between 70–100% only. Nights with fewer than 5 readings excluded.<br><br>
      <b>All Participants mode:</b><br>
      Average SpO2 per participant per study day, then averaged across
      participants. Min-max range reflects the extremes across all
      participants. SD reflects between-participant variation.
    ")
  ),
  
  # ============================================================================
  # ACTIVITY TAB — CHARTS
  # Side by side: zone_minutes_chart (left), exercise_sessions_chart (right).
  # Full width:   sedentary_chart.
  # Full width:   activity_steps_chart.
  # Side by side: activity_steps_by_hour (left), activity_distance_chart (right).
  # ============================================================================
  
  # Zone Minutes — stacked bar of Fat Burn / Cardio / Peak minutes per day.
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
  
  # Exercise Sessions — bubble chart of logged sessions sized by duration.
  # Admins get By Activity Type / By Participant toggle in All Participants mode.
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
  
  # Sedentary Periods — total minutes sedentary per day.
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
  
  # Daily Steps with Goal Line — same data as Overview plot_steps, more detailed view.
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
  
  # Steps by Hour of Day — reveals when the participant is most active.
  # In All Participants mode shows one line per participant.
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
  
  # Distance per Day — total meters traveled per day.
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
  
  
  # ============================================================================
  # INSIGHTS TAB — METRIC CARDS
  # Three summary cards at the top of the Insights tab.
  # Shown to all users; hidden by default for admins.
  # ============================================================================
  
  # Best Sleep Night — study day or date with the highest total sleep minutes.
  insight_best_sleep_card = list(
    user = HTML("
      <b>What this shows:</b><br>
      The single night with the highest total sleep duration
      in your selected range, and how many minutes you slept.<br><br>
      <b>Data source:</b><br>
      Fitbit nightly sleep totals
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      The study day with the highest average total sleep minutes
      across the selected range.<br><br>
      <b>Data source:</b><br>
      daily_metrics.csv (total_sleep_minutes)<br><br>
      <b>All Participants mode:</b><br>
      The study day with the highest cohort-average sleep duration.
    ")
  ),
  
  # Most Active Day — day with the highest step count.
  insight_most_active_card = list(
    user = HTML("
      <b>What this shows:</b><br>
      The single day with the highest step count in your
      selected range, and the total steps taken.<br><br>
      <b>Data source:</b><br>
      Fitbit step count data
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      The study day with the highest total or average step count
      across the selected range.<br><br>
      <b>Data source:</b><br>
      steps_intraday_5m.csv<br><br>
      <b>All Participants mode:</b><br>
      The study day with the highest cohort-average step count.
    ")
  ),
  
  # Typical Bedtime — average sleep onset time across all nights in the range.
  insight_bedtime_card = list(
    user = HTML("
      <b>What this shows:</b><br>
      Your typical bedtime — the average time you fell asleep
      across all nights in the selected range.<br><br>
      <b>Data source:</b><br>
      Fitbit sleep onset time data<br><br>
      <b>Note:</b><br>
      Times after midnight are treated as early morning
      to calculate the average correctly.
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Average sleep onset time across the selected range.<br><br>
      <b>Data source:</b><br>
      sleep_minute.csv (earliest datetime per sleep session)<br><br>
      <b>All Participants mode:</b><br>
      Average bedtime across all participants combined.
      The (avg) suffix is appended to the displayed time.
    ")
  ),
  
  
  # ============================================================================
  # INSIGHTS TAB — WEEKDAY VS WEEKEND CHARTS
  # Side by side: weekday_sleep_chart (left), weekday_steps_chart (right).
  # Side by side (admin only): weekday_hrv_chart (left), weekday_hr_chart (right).
  #
  # The HRV and Resting HR charts are admin-only and use single HTML() entries
  # since regular users never see them. They carry particular research relevance
  # for the physiological stress study — lower weekday HRV and higher weekday
  # resting HR are markers of sustained stress responses.
  # ============================================================================
  
  # Sleep Duration: Weekday vs Weekend — avg sleep minutes by day type.
  weekday_sleep_chart = list(
    user = HTML("
      <b>What this shows:</b><br>
      Your average sleep duration on weekdays compared to weekends,
      so you can see whether your sleep patterns shift on days off.<br><br>
      <b>Data source:</b><br>
      Fitbit minute-by-minute sleep data<br><br>
      <b>Note:</b><br>
      Based on your selected study day range.
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Average total sleep duration on weekdays vs weekends.<br><br>
      <b>Data source:</b><br>
      sleep_minute.csv<br><br>
      <b>All Participants mode:</b><br>
      Cohort average across all participants per day type.
    ")
  ),
  
  # Steps: Weekday vs Weekend — avg daily steps by day type.
  weekday_steps_chart = list(
    user = HTML("
      <b>What this shows:</b><br>
      Your average daily step count on weekdays compared to weekends,
      revealing whether you are more active on work days or rest days.<br><br>
      <b>Data source:</b><br>
      Fitbit step count data<br><br>
      <b>Note:</b><br>
      Based on your selected study day range.
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Average daily steps on weekdays vs weekends.<br><br>
      <b>Data source:</b><br>
      steps_intraday_5m.csv<br><br>
      <b>All Participants mode:</b><br>
      Cohort average across all participants per day type.
    ")
  ),
  
  # HRV: Weekday vs Weekend — admin only. Key stress biomarker for the study.
  weekday_hrv_chart = HTML("
    <b>What this shows:</b><br>
    Average HRV (RMSSD) on weekdays vs weekends. Lower HRV on weekdays
    may indicate elevated stress or reduced recovery during the work week,
    which is directly relevant to studying physiological stress responses.<br><br>
    <b>Data source:</b><br>
    hrv_intraday.csv<br><br>
    <b>Admin-only chart.</b><br><br>
    <b>All Participants mode:</b><br>
    Cohort average RMSSD per day type across all participants.
  "),
  
  # Resting HR: Weekday vs Weekend — admin only. Elevated weekday HR = stress marker.
  weekday_hr_chart = HTML("
    <b>What this shows:</b><br>
    Average resting heart rate on weekdays vs weekends. Elevated resting HR
    on weekdays compared to weekends can be a marker of sustained physiological
    stress, relevant to discrimination and stress research.<br><br>
    <b>Data source:</b><br>
    daily_metrics.csv (resting_heart_rate column)<br><br>
    <b>Admin-only chart.</b><br><br>
    <b>All Participants mode:</b><br>
    Cohort average resting HR per day type across all participants.
  "),
  
  
  # ============================================================================
  # PROJECTIONS TAB — CHARTS
  # Full width: hrv_sleep_chart.
  # Visible to all users and admins.
  # In All Participants mode, dots are colored by participant.
  # ============================================================================
  
  # HRV vs Sleep Duration — scatter with linear regression line and r value.
  hrv_sleep_chart = list(
    user = HTML("
      <b>What this shows:</b><br>
      The relationship between your total sleep duration and your heart rate
      variability (HRV) — a measure of how recovered your body is. Each dot
      represents one night. The trend line shows whether sleeping more is
      associated with higher HRV for you personally.<br><br>
      <b>Data sources:</b><br>
      Fitbit HRV readings and nightly sleep totals<br><br>
      <b>Note:</b><br>
      The r value shown is the correlation coefficient — closer to 1 means
      a stronger positive relationship between sleep and HRV.
    "),
    admin = HTML("
      <b>What this shows:</b><br>
      Scatter plot of nightly total sleep minutes vs average HRV (RMSSD),
      with a linear regression line and confidence interval. Each dot
      represents one participant-night. The r value is the Pearson
      correlation coefficient.<br><br>
      <b>Data sources:</b><br>
      hrv_intraday.csv (daily average RMSSD) joined with
      daily_metrics.csv (total_sleep_minutes) by participantID and date<br><br>
      <b>All Participants mode:</b><br>
      All participant-nights plotted together, colored by participant.
      The regression line is fitted across the full cohort.<br><br>
      <b>Note:</b><br>
      Use the high-resolution download button (camera icon) for
      publication-quality exports at 3x scale.
    ")
  ),
  
  hrv_sleep_lag_chart = HTML("
    <b>What this shows:</b><br>
    Explores how sleep and HRV influence each other across days
    using a 1-day lag analysis. Three relationship types are plotted:<br>
    <b>Same Day</b> (circles):<br>
    Sleep duration vs HRV on the same date.<br>
    <b>Sleep → HRV</b> (squares):<br>
    Previous night's sleep vs today's HRV. Tests whether better
    sleep predicts better autonomic recovery the next day.<br>
    <b>HRV → Sleep</b> (diamonds):<br>
    Previous day's HRV vs tonight's sleep. Tests whether better
    recovery predicts longer sleep the following night.<br><br>
    <b>Data sources:</b><br>
    hrv_intraday.csv + sleep_minute.csv, joined by participant and date<br><br>
    <b>All Participants:</b><br>
    All participant-days pooled together. Hover for participant ID.<br><br>
    <b>Interpretation:</b><br>
    An upward slope indicates a positive relationship. Compare the
    three marker shapes to see which temporal direction shows the
    strongest pattern. Days following stressful events may show
    compressed clusters with lower HRV regardless of sleep duration.
  "),
  
  # ============================================================================
  # ANALYSIS TAB — CHARTS (admin-only tab)
  # All charts here use single HTML() entries since only admins see this tab.
  # Full width: admin_hr_comparison, admin_steps_comparison,
  #             admin_completeness_heatmap, admin_summary_table.
  # ============================================================================
  
  # Multi-Participant Heart Rate Comparison — one line per participant.
  admin_hr_comparison = HTML("
    <b>What this shows:</b><br>
    Average heart rate per participant over time, aligned by study day
    for cross-participant comparison.<br><br>
    <b>Data source:</b><br>
    hr_intraday_5m.csv<br><br>
    <b>Note:</b><br>
    Admin-only. Each line represents one participant.
  "),
  
  # Multi-Participant Steps Comparison — side-by-side bars per participant.
  admin_steps_comparison = HTML("
    <b>What this shows:</b><br>
    Total daily steps per participant, displayed side by side for
    direct comparison.<br><br>
    <b>Data source:</b><br>
    steps_intraday_5m.csv<br><br>
    <b>Note:</b><br>
    Admin-only. Each color represents one participant.
  "),
  
  # Data Completeness Heatmap — shows which data sources are present per day.
  admin_completeness_heatmap = HTML("
    <b>What this shows:</b><br>
    Which data sources (heart rate, steps, sleep) are present for each
    participant on each date. Darker = more sources present.<br><br>
    <b>Data source:</b><br>
    hr_intraday_5m.csv, steps_intraday_5m.csv, sleep_minute.csv<br><br>
    <b>Note:</b><br>
    Admin-only. Useful for identifying data gaps before analysis.
  "),
  
  # Participant Activity Summary — DT table of per-participant metric averages.
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
  # CLINICAL SIGNALS TAB (admin-only)
  # ============================================================
  
  clinical_heatmap = HTML("
    <b>What this shows:</b><br>
    A daily snapshot of 7 clinical signals, one column per study day.
    Green cells indicate normal values; red cells indicate a flagged
    concern; grey cells indicate missing data.<br><br>
    <b>Signals and thresholds:</b><br>
    &bull; <b>Short Sleep:</b> Total sleep < 6 hours (360 min)<br>
    &bull; <b>Fragmented Sleep:</b> WASO > 30 min or > 5 awakenings<br>
    &bull; <b>Low Activity:</b> < 5,000 daily steps<br>
    &bull; <b>Long Sedentary Bout:</b> Longest sedentary period > 60 min<br>
    &bull; <b>Low HRV:</b> Below participant's personal mean minus 1 SD<br>
    &bull; <b>High Resting HR:</b> Above participant's personal mean plus 1 SD<br>
    &bull; <b>Low SpO2:</b> Lower bound < 90%<br><br>
    <b>Data sources:</b><br>
    daily_metrics.csv, sleep_minute.csv, sedentary_periods.csv<br><br>
    <b>Admin-only chart.</b><br><br>
    <b>All Participants mode:</b><br>
    Metrics are averaged across participants per study day before
    flags are applied. HRV and HR flags use cohort-level mean ± 1 SD
    instead of individual baselines.
  "),
  
  sleep_fragmentation_chart = HTML("
    <b>What this shows:</b><br>
    Two measures of sleep disruption per study day:<br><br>
    <b>WASO (bars):</b> Wake After Sleep Onset — total minutes spent
    awake after initially falling asleep. Higher values indicate more
    disrupted sleep.<br><br>
    <b>Awakenings (line):</b> Number of distinct wake episodes after
    sleep onset. Frequent awakenings are associated with insomnia,
    anxiety, PTSD-like hyperarousal, and stress-related sleep
    disruption.<br><br>
    <b>Data source:</b><br>
    sleep_minute.csv (wake episodes counted after first sleep stage)<br><br>
    <b>Admin-only chart.</b><br><br>
    <b>All Participants mode:</b><br>
    Both metrics averaged across participants per study day.
  "),
  
  longest_sedentary_chart = HTML("
    <b>What this shows:</b><br>
    The longest single sedentary period recorded each study day, in minutes.
    The dashed yellow line at 60 minutes marks a commonly used threshold
    for prolonged sedentary behavior.<br><br>
    <b>Data source:</b><br>
    sedentary_periods.csv (max duration_minutes per day)<br><br>
    <b>Admin-only chart.</b><br><br>
    <b>All Participants mode:</b><br>
    Averaged across participants per study day.
  "),
  
  recovery_flag_chart = HTML("
    <b>What this shows:</b><br>
    A focused recovery assessment showing three key signals per study day.
    Green = normal, red = flagged, grey = no data.<br><br>
    <b>Signals and thresholds:</b><br>
    &bull; <b>Low HRV:</b> Below participant's personal mean minus 1 SD.
    Indicates reduced autonomic recovery.<br>
    &bull; <b>High Resting HR:</b> Above participant's personal mean plus 1 SD.
    May indicate physiological stress or poor recovery.<br>
    &bull; <b>Short Sleep:</b> Total sleep under 6 hours (360 min).<br><br>
    <b>Hover</b> over any cell to see the actual value and deviation
    from the participant's personal baseline.<br><br>
    <b>Data source:</b><br>
    daily_metrics.csv<br><br>
    <b>Admin-only chart.</b><br><br>
    <b>All Participants mode:</b><br>
    Metrics averaged across participants per study day. Flags use
    cohort-level mean ± 1 SD instead of individual baselines.
  "),
  
  clinical_summary_table = HTML("
    <b>What this shows:</b><br>
    One row per study day with key daily health metrics including
    sleep duration, wake after sleep onset (WASO), number of awakenings,
    step count, active minutes, longest sedentary bout, nightly HRV,
    and resting heart rate.<br><br>
    <b>Data sources:</b><br>
    daily_metrics.csv (sleep, steps, active minutes, HRV, resting HR),
    sleep_minute.csv (WASO, awakenings),
    sedentary_periods.csv (longest bout)<br><br>
    <b>Admin-only table.</b><br><br>
    <b>All Participants mode:</b><br>
    All values are averaged across participants per study day.
  "),
  
  # ============================================================================
  # DATA VIEW TAB (admin-only tab)
  # Single HTML() entry since only admins see this tab.
  # ============================================================================
  
  # Raw Data Viewer — DT table of any loaded CSV, filtered by current selection.
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
  
) # end CHART_INFO


# ==============================================================================
# chart_card_ui()
# ==============================================================================
#' Build a standardized collapsible chart card with title, eye toggle,
#' and info popover.
#'
#' Used for every Plotly and DT chart in the dashboard. The card header
#' shows the chart title on the left and two icons on the right:
#'   - Eye icon: collapses/expands the chart body (server-wired via
#'     init_chart_card() in app.R).
#'   - Info circle icon: opens a popover with chart-specific context,
#'     sourced from CHART_INFO[[chart_id]] and filtered by is_admin.
#'
#' @param chart_id  Unique string ID. Must match the Shiny output ID used in
#'                  the corresponding render*() call in app.R. No two charts
#'                  may share a chart_id.
#' @param title     Display title shown in the card header.
#' @param output_fn Shiny output UI function reference, e.g. plotlyOutput or
#'                  DT::dataTableOutput. Passed as a function, not a call.
#' @param is_admin  Logical. If TRUE, the card starts collapsed and the admin
#'                  version of the CHART_INFO popover is shown. Defaults FALSE.
#' @param extra_ui  Optional Shiny UI element rendered above the chart inside
#'                  the collapsible body (e.g. a radioButtons selector or a
#'                  selectInput for the hypnogram night picker).
#' @param ...       Additional arguments passed to output_fn, e.g. height = "400px".
#'
#' @return A div containing the complete chart card UI.
# ------------------------------------------------------------------------------
chart_card_ui <- function(chart_id, title, output_fn, is_admin = FALSE,
                          extra_ui = NULL, ...) {
  
  body_id <- paste0(chart_id, "_body")
  
  # Select popover content based on role.
  # Supports single HTML() (same for all roles) or list(user=, admin=).
  info_entry <- CHART_INFO[[chart_id]]
  if (is.null(info_entry)) {
    info_content <- HTML("<i>No description available for this chart yet.</i>")
  } else if (is.list(info_entry)) {
    info_content <- if (isTRUE(is_admin)) info_entry$admin else info_entry$user
  } else {
    info_content <- info_entry
  }
  
  div(class = "chart-card",
      
      # Header: title (left) + icons (right)
      div(
        style = "display: flex; justify-content: space-between; align-items: center; padding: 0 15px;",
        
        p(title, class = "chart-title", style = "margin: 0;"),
        
        div(
          style = "display: flex; align-items: center; gap: 14px;",
          
          # Eye toggle — rendered server-side by init_chart_card() in app.R.
          # The icon reflects chart_state[[chart_id]]: eye = open, eye-slash = collapsed.
          uiOutput(paste0(chart_id, "_toggle_ui"), inline = TRUE),
          
          # Info popover — purely client-side via bslib::popover().
          # Color change when open is handled by CSS (.chart-info-trigger[aria-describedby]).
          popover(
            span(
              bsicons::bs_icon("info-circle"),
              class = "chart-info-trigger"
            ),
            title     = "About This Chart",
            info_content,
            placement = "left"
          )
        )
      ),
      
      # Collapsible body — visibility controlled by init_chart_card() in app.R.
      # Starts hidden (admin) or visible (user) based on is_admin.
      div(id = body_id,
          extra_ui,
          output_fn(chart_id, ...)
      )
  )
}


# ==============================================================================
# metric_card_ui()
# ==============================================================================
#' Build a collapsible metric (KPI) card with eye toggle and info popover.
#'
#' Used for the four Overview KPI cards and the three Insights summary cards.
#' Mirrors chart_card_ui() in structure, but differs in that:
#'   - Icons are stacked vertically in the top-right corner (absolute position)
#'     rather than inline with a title, since metric cards have no title bar.
#'   - Instead of collapsing the body, toggling switches between showing the
#'     real value (textOutput) and a "Hidden" placeholder.
#'   - The "Hidden" state is the default for admins; values are visible by
#'     default for regular users.
#'
#' @param card_id     Unique string ID. Must match a key in CHART_INFO and be
#'                    used in the corresponding init_metric_card() call in app.R.
#' @param label       ALL-CAPS label displayed above the value (e.g. "AVG HEART RATE").
#' @param output_id   The textOutput() ID whose value this card displays.
#' @param unit        Optional unit label shown below the value (e.g. "bpm", "%").
#' @param is_admin    Logical. If TRUE, card starts hidden and shows admin popover.
#' @param value_size  "large" renders the value in h2 (Overview KPIs);
#'                    "medium" renders in h3 (Insights cards). Defaults "large".
#'
#' @return A div containing the complete metric card UI.
# ------------------------------------------------------------------------------
metric_card_ui <- function(card_id, label, output_id, unit = NULL,
                           is_admin = FALSE, value_size = "large") {
  
  # Choose h2 or h3 based on card context
  value_tag <- if (value_size == "large") {
    h2(textOutput(output_id), class = "metric-value")
  } else {
    h3(textOutput(output_id), class = "metric-value")
  }
  
  # Select popover content based on role (same logic as chart_card_ui)
  info_entry <- CHART_INFO[[card_id]]
  if (is.null(info_entry)) {
    info_content <- HTML("<i>No description available.</i>")
  } else if (is.list(info_entry)) {
    info_content <- if (isTRUE(is_admin)) info_entry$admin else info_entry$user
  } else {
    info_content <- info_entry
  }
  
  div(class = "metric-card",
      style = "position: relative;",
      
      # Icons stacked vertically in top-right corner.
      # Absolute positioning avoids interfering with the label/value layout.
      div(
        style = "position: absolute; top: 6px; right: 8px; display: flex; flex-direction: column; gap: 4px; align-items: center;",
        
        # Eye toggle — rendered server-side by init_metric_card() in app.R.
        uiOutput(paste0(card_id, "_toggle_ui"), inline = TRUE),
        
        # Info popover — same client-side pattern as chart_card_ui.
        popover(
          span(
            bsicons::bs_icon("info-circle"),
            class = "chart-info-trigger",
            style = "font-size: 0.7rem;"
          ),
          title     = "About This Metric",
          info_content,
          placement = "left"
        )
      ),
      
      # Label always visible regardless of hidden state
      p(label, class = "metric-label"),
      
      # Value div — shown when card is open, hidden when admin has toggled off.
      # Controlled by init_metric_card() via shinyjs::show/hide in app.R.
      div(id = paste0(card_id, "_value"),
          value_tag,
          if (!is.null(unit)) p(unit, class = "metric-unit")
      ),
      
      # Hidden placeholder — shown when admin has toggled the value off.
      # Starts hidden (display:none); init_metric_card() swaps visibility on toggle.
      div(id = paste0(card_id, "_hidden"),
          style = "display: none;",
          h2("Hidden", class = "metric-value",
             style = "color: #ccc; font-style: italic; font-size: 1.2rem;")
      )
  )
}