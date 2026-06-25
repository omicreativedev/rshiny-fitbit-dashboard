# Fitbit Research Dashboard: Comprehensive Chart and Metric Documentation

**Version:** Final  
**Created:** June 2026  
**Audience:** Research team, masters-level readers  
**Note:** This document describes all tabs, charts, metrics, and tables available in the Simmons University Fitbit Research Dashboard for the STARS Program and Boston University Labs.

---

# Tabs Visible to All Users

## Overview

The Overview tab is visible to all logged-in users. It provides a high-level snapshot of a participant's key health metrics and daily trends.

### Key Performance Indicators (KPIs)

Four summary metric cards appear at the top of the Overview tab, displaying:

#### Average Heart Rate

**Data source:** `hr_intraday_5m.csv`

**What it shows:** Mean heart rate in beats per minute (bpm) across all 5-minute interval readings in the selected date or study day range. Values are filtered to the physiologically valid range of 30 to 220 bpm.

**Notes:** A typical resting heart rate for adults is 60-100 bpm. Lower resting heart rate often indicates better cardiovascular fitness.

**Admin note:** The admin version displays this as a cohort-wide mean in All Participants mode. The same metric is applied; only the aggregation level changes.

#### Average Daily Steps

**Data source:** `steps_intraday_5m.csv`

**What it shows:** Mean total daily step count across the selected range. Steps are summed per day before averaging across days.

**Notes:** The commonly cited goal is 10,000 steps per day, though research suggests benefits begin at lower counts.

**Admin note:** In All Participants mode, this is the mean daily step count across all participants combined.

#### Average Deep Sleep

**Data source:** `sleep_minute.csv` (records with sleep_stage == "deep")

**What it shows:** Mean duration of deep sleep (in minutes) per night across the selected range. Each minute in the deep sleep stage is counted; other stages are excluded.

**Notes:** Deep sleep is the most restorative stage. Adults typically get 1-2 hours of deep sleep per night, roughly 13-23 percent of total sleep time.

**Admin note:** In All Participants mode, this is the mean nightly deep sleep minutes across all participants.

#### Average Blood Oxygen Saturation (SpO2)

**Data source:** `spo2_intraday.csv`

**What it shows:** Mean blood oxygen saturation as a percentage across the selected range. Values are filtered to the range 70-100 percent.

**Notes:** Normal SpO2 is typically 95-100 percent. Values below 90 percent may warrant medical attention.

**Admin note:** In All Participants mode, this is the cohort mean SpO2 across all readings combined.

---

### Heart Rate Over Time

**Type:** Line chart

**Visibility:** All users

**Data source:** `hr_intraday_5m.csv` (5-minute heart rate interval averages)

**What this chart shows:**

Average heart rate over time, displayed as a line chart. Each point represents the mean heart rate for a given date or study day. Values are filtered to the physiologically valid range of 30 to 220 bpm before averaging.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| View mode toggle | By Date / By Study Day | Shared toolbar control (applies to all charts) |
| Participant selector (admin only) | Individual participant / All Participants | Shared toolbar control |

**How the chart changes by view:**

- **By Date (individual participant):** Heart rate plotted against calendar dates on the x-axis. Shows the raw time-series trend for the selected date range.
- **By Study Day (individual participant):** Heart rate averaged to one point per study day. Study days are numbered starting from Day 1 of the participant's enrollment, making it easier to compare across participants who started on different calendar dates.
- **By Study Day, All Participants (admin only):** A single line showing the cohort average heart rate per study day. All participants' readings are combined and averaged for each study day.

**Research context:**

This chart can help answer questions such as:

- Is there a visible change in average heart rate following a reported stressful event?
- Does a participant's heart rate trend upward or downward over the course of the study period?
- In All Participants mode, do cohort-level heart rate patterns shift around specific study days that correspond to shared experiences or interventions?

**Filters applied:** Only heart rate readings between 30 and 220 bpm are included. Readings outside this range are treated as sensor artifacts and excluded.

---

### Daily Steps

**Type:** Bar chart with goal line reference

**Visibility:** All users

**Data source:** `steps_intraday_5m.csv` (5-minute step counts)

**What this chart shows:**

Total steps per day displayed as a bar chart with a 10,000-step goal line as a visual reference. Each bar represents the sum of all steps recorded in a single date or study day.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| View mode toggle | By Date / By Study Day | Shared toolbar control |
| Participant selector (admin only) | Individual participant / All Participants | Shared toolbar control |

**How the chart changes by view:**

- **By Date (individual participant):** Bars represent calendar dates. The 10,000-step goal line provides a daily target reference.
- **By Study Day (individual participant):** Bars represent study days. Steps are summed across all readings for each study day.
- **By Study Day, All Participants (admin only):** A single set of bars showing the mean daily step count per study day, averaged across all participants.

**Research context:**

This chart helps address questions such as:

- Did a participant meet the 10,000-step daily target on specific days?
- Is there variation in activity level across study days, possibly corresponding to weekdays versus weekends or stressful events?
- In All Participants mode, is there a cohort-wide dip in activity on certain study days?

---

### Sleep Stage Breakdown

**Type:** Stacked bar chart

**Visibility:** All users

**Data source:** `sleep_minute.csv` (minute-by-minute sleep stage data)

**What this chart shows:**

Total minutes spent in each sleep stage (Deep, REM, Light) per night, displayed as stacked bars. Each bar represents one night; wake minutes are excluded to show only time in sleep.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| View mode toggle | By Date / By Study Day | Shared toolbar control |
| Participant selector (admin only) | Individual participant / All Participants | Shared toolbar control |

**How the chart changes by view:**

- **By Date (individual participant):** Bars represent calendar dates. The stacked colors show the distribution of sleep stages for each night.
- **By Study Day (individual participant):** Bars represent study days. Sleep stage minutes are summed across all nights within each study day.
- **By Study Day, All Participants (admin only):** Bars show the mean minutes in each sleep stage per study day, averaged across all participants.

**Research context:**

This chart supports questions such as:

- Does the participant's sleep stage distribution shift on certain study days (e.g., reduced deep sleep on high-stress days)?
- Is there more or less REM sleep on weekends versus weekdays?
- In All Participants mode, do cohort-level sleep stages change around key study events?

---

## Heart Rate

The Heart Rate tab is visible to all users. It provides detailed analysis of heart rate patterns, including circadian rhythms, distribution, and heart rate variability (HRV). Some charts are admin-only.

### Heart Rate Time Series

**Type:** Line chart (study day view) or scatter plot with smoothed trend (date view)

**Visibility:** All users

**Data source:** `hr_intraday_5m.csv` (5-minute heart rate readings)

**What this chart shows:**

Heart rate trends over time from 5-minute Fitbit readings. In date view, raw 5-minute points are plotted with a smoothed trend line. In study day view, each point is the average heart rate for that study day. Values are filtered to 30-220 bpm.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| View mode toggle | By Date / By Study Day | Shared toolbar control |
| Participant selector (admin only) | Individual participant / All Participants | Shared toolbar control |
| Admin aggregate toggle (study day, all participants only) | Aggregate / Split by Participant | Radio buttons appear in admin view only |

**How the chart changes by view:**

- **By Date (individual participant):** Raw 5-minute points with a LOESS smoothed trend line. Shows fine-grained variation.
- **By Study Day (individual participant):** One averaged point per study day, connected by lines to show trends.
- **By Study Day, All Participants, Aggregate (admin only):** A single line showing cohort-average heart rate per study day.
- **By Study Day, All Participants, Split by Participant (admin only):** One line per participant, all overlaid for visual comparison.

**Research context:**

This chart helps researchers explore:

- Is there a sustained elevation in heart rate following a stressful event, or does it recover quickly?
- Does a participant show consistent daily rhythms, or are patterns disrupted on certain days?
- In split view, do all participants respond similarly to the same study events, or is there individual variation?

---

### Heart Rate Distribution

**Type:** Histogram

**Visibility:** All users

**Data source:** `hr_intraday_5m.csv`

**What this chart shows:**

Distribution of heart rate readings as a histogram, showing the frequency of readings at each heart rate level. This reveals whether a participant tends to run "hot" (higher average HR) or "cool" (lower average HR) and how much variability exists.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| View mode toggle | By Date / By Study Day | Shared toolbar control |
| Participant selector (admin only) | Individual participant / All Participants | Shared toolbar control |

**How the chart changes by view:**

- **By Date (individual participant):** Combined histogram of all readings across the selected date range.
- **By Study Day (individual participant):** Histogram bars colored by study day, showing which days contributed more readings at each heart rate level.
- **By Study Day, All Participants (admin only):** Density histogram (y-axis shows density, not count) with one color per participant, allowing visual comparison despite different data volumes.

**Research context:**

This helps answer:

- Does a participant's heart rate distribution appear bimodal (e.g., distinct resting and active populations) or unimodal?
- Are there outlier days with unusually high or low heart rates?
- In cohort view, do all participants show similar distributions, or are there marked differences?

---

### Heart Rate by Hour of Day

**Type:** Bar chart (date view) or line chart (study day view)

**Visibility:** All users

**Data source:** `hr_intraday_5m.csv`

**What this chart shows:**

Average heart rate broken down by hour of day (0:00 to 23:00), revealing circadian rhythm patterns. In date view, bars show mean HR per hour with standard deviation error bars. In study day view, one line per study day shows how HR varies across hours.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| View mode toggle | By Date / By Study Day | Shared toolbar control |
| Participant selector (admin only) | Individual participant / All Participants | Shared toolbar control |
| Admin aggregate toggle (study day, all participants only) | Aggregate / Split by Participant | Radio buttons appear in admin view only |

**How the chart changes by view:**

- **By Date (individual participant):** Bar chart with error bars showing the spread of readings at each hour.
- **By Study Day (individual participant):** One line per study day, showing how HR varies hourly across different days.
- **By Study Day, All Participants, Aggregate (admin only):** Single bar chart showing cohort-average HR per hour.
- **By Study Day, All Participants, Split by Participant (admin only):** One line per participant, overlaid to compare circadian patterns.

**Research context:**

This chart reveals:

- Does the participant show a typical circadian rhythm (lower HR at night, higher during day)?
- Are there unusual hours where HR is unexpectedly elevated (possible stress response)?
- In cohort view, do all participants show similar hourly patterns, or is there heterogeneity?

---

### Heart Rate Variability (HRV)

**Type:** Line chart with points

**Visibility:** Admin only

**Data source:** `hrv_intraday.csv` (RMSSD milliseconds)

**What this chart shows:**

Heart rate variability measured as RMSSD (root mean square of successive differences), a metric of autonomic nervous system activity. Higher HRV generally indicates better recovery and stress resilience. Each point is the daily average RMSSD.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| View mode toggle | By Date / By Study Day | Shared toolbar control |
| Participant selector | Individual participant / All Participants | Shared toolbar control |

**How the chart changes by view:**

- **By Date:** Raw HRV points over calendar dates.
- **By Study Day:** One averaged point per study day.
- **By Study Day, All Participants:** Single line showing cohort average RMSSD per study day.

**Research context:**

HRV is highly relevant to stress research. Lower HRV on certain study days may indicate:

- Acute stress response (sympathetic nervous system activation)
- Poor recovery from a stressor
- Chronic stress accumulation

In research on discrimination and stress, sustained low HRV may indicate physiological dysregulation.

---

### HRV Daily Summary

**Type:** Line chart with standard deviation ribbon

**Visibility:** Admin only

**Data source:** `hrv_intraday.csv`

**What this chart shows:**

Daily average HRV with a shaded ribbon representing plus or minus one standard deviation around the mean for that day. This shows not just the average HRV but also the variability of readings within each day. A reference line at 20 ms represents a general baseline for comparison.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| View mode toggle | By Date / By Study Day | Shared toolbar control |
| Participant selector | Individual participant / All Participants | Shared toolbar control |

**How the chart changes by view:**

- **By Date (individual participant):** Daily average HRV line with standard deviation ribbon, plotted against calendar dates.
- **By Study Day (individual participant):** Daily average HRV line with standard deviation ribbon, plotted against study days.
- **By Study Day, All Participants:** One bold line showing cohort-average HRV per study day, with a wide shaded ribbon representing plus or minus one standard deviation across participants.

**Research context:**

The width of the ribbon indicates consistency: a tight ribbon means readings clustered close to the mean (consistent physiology), while a wide ribbon suggests high within-day variability. In cohort view, the ribbon width shows heterogeneity in HRV across participants.

---

### HRV Heatmap

**Type:** Color-coded heatmap (hour of day vs date/study day)

**Visibility:** Admin only

**Data source:** `hrv_intraday.csv`

**What this chart shows:**

HRV (RMSSD) broken down by hour of day and displayed as a heatmap. Darker colors indicate lower HRV; greener colors indicate higher HRV. This reveals circadian patterns of autonomic recovery throughout the day.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| View mode toggle | By Date / By Study Day | Shared toolbar control |
| Participant selector | Individual participant / All Participants | Shared toolbar control |

**How the chart changes by view:**

- **By Date (individual participant):** Rows are calendar dates; columns are hours of day. Each cell shows the average HRV for that date-hour combination.
- **By Study Day (individual participant):** Rows are study days; columns are hours. Shows how HRV varies by hour across different study days.
- **By Study Day, All Participants:** Rows are study days; columns are hours. Each cell is the cohort average HRV for that study day-hour combination.

**Research context:**

This chart reveals:

- Are there hours of the day when HRV is consistently depressed (e.g., during typical work hours)?
- Does the hourly HRV pattern change on high-stress study days?
- In cohort view, do all participants show similar circadian HRV patterns?

---

### Heart Rate Heatmap

**Type:** Color-coded heatmap (hour of day vs date/study day)

**Visibility:** Admin only

**Data source:** `hr_intraday_5m.csv`

**What this chart shows:**

Heart rate broken down by hour of day and displayed as a heatmap. Cooler colors (dark blue) indicate lower HR; warmer colors (orange, red) indicate higher HR. This reveals daily activity and rest patterns at a glance.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| View mode toggle | By Date / By Study Day | Shared toolbar control |
| Participant selector | Individual participant / All Participants | Shared toolbar control |

**How the chart changes by view:**

- **By Date (individual participant):** Rows are calendar dates; columns are hours of day.
- **By Study Day (individual participant):** Rows are study days; columns are hours.
- **By Study Day, All Participants:** Rows are study days; columns are hours. Cohort average HR per study day-hour combination.

**Research context:**

Sleep hours should show cooler colors (lower HR); active hours should show warmer colors (higher HR). Disruptions to this pattern (e.g., elevated HR at night) may indicate sleep disturbance or nighttime stress arousal.

---

## Sleep

The Sleep tab is visible to all users. It provides comprehensive analysis of sleep duration, sleep stages, sleep quality metrics, and respiratory data during sleep. Some advanced charts are admin-only.

### Sleep Duration Over Time

**Type:** Bar chart

**Visibility:** All users

**Data source:** `sleep_minute.csv` (minute-by-minute sleep stage data)

**What this chart shows:**

Total minutes of tracked sleep per night, including all sleep stages (Deep, REM, Light, Wake). Each bar represents one calendar date or study day.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| View mode toggle | By Date / By Study Day | Shared toolbar control |
| Participant selector (admin only) | Individual participant / All Participants | Shared toolbar control |

**How the chart changes by view:**

- **By Date (individual participant):** Bars represent calendar dates.
- **By Study Day (individual participant):** Bars represent study days; sleep minutes are summed across all nights in that study day.
- **By Study Day, All Participants (admin only):** Bars show the mean total sleep minutes per study day, averaged across all participants.

**Research context:**

This helps researchers track:

- Does sleep duration change on or after high-stress days?
- Is there a consistent pattern (e.g., weekday vs weekend differences)?
- In cohort view, do all participants show similar sleep duration trends?

---

### Sleep Stage Distribution

**Type:** Donut (ring) pie chart

**Visibility:** All users

**Data source:** `sleep_minute.csv`

**What this chart shows:**

Proportional breakdown of time spent in each sleep stage (Deep, REM, Light) across the entire selected range. Wake minutes are excluded so the chart shows only time in sleep. Percentages and minutes are displayed.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| Participant selector (admin only) | Individual participant / All Participants | Shared toolbar control |

**How the chart changes:**

- **Individual participant:** Shows the stage distribution for the selected participant across the selected date range.
- **All Participants (admin only):** Shows the combined distribution across all participants. A title note clarifies that data is pooled.

**Research context:**

Typical adult sleep includes roughly 50-60 percent light sleep, 20-25 percent deep sleep, and 20-25 percent REM sleep. Deviations from this pattern may indicate:

- Sleep fragmentation (excessive light sleep)
- Poor deep sleep (REM rebound may follow)
- Changes related to stress or poor sleep quality

---

### Breathing Rate During Sleep

**Type:** Multi-line chart

**Visibility:** All users

**Data source:** `breathing_rate_summary.csv` (by sleep stage)

**What this chart shows:**

Breathing rate (breaths per minute) during sleep, broken down by sleep stage: Full Sleep (aggregate), Deep, Light, and REM. Each line represents one sleep stage. Breathing rate can indicate respiratory stress or changes in autonomic tone.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| View mode toggle | By Date / By Study Day | Shared toolbar control |
| Participant selector (admin only) | Individual participant / All Participants | Shared toolbar control |

**How the chart changes by view:**

- **By Date (individual participant):** Each point represents one calendar date; one line per sleep stage.
- **By Study Day (individual participant):** Each point represents one study day; one line per sleep stage.
- **By Study Day, All Participants (admin only):** Cohort average breathing rate per sleep stage per study day.

**Research context:**

Elevated breathing rate during sleep may indicate:

- Sleep apnea or breathing disturbances
- Elevated autonomic arousal or stress response
- Changes in sleep quality

Stage-specific breathing rates can reveal whether a particular stage is affected (e.g., elevated REM breathing despite normal deep sleep).

---

### Hypnogram

**Type:** Timeline (individual night) or stacked bar chart (all participants aggregate)

**Visibility:** All users

**Data source:** `sleep_minute.csv` (minute-by-minute sleep stage transitions)

**What this chart shows:**

A visualization of sleep architecture for a single selected night (individual view) or average sleep stage composition per study day (all participants view).

**Individual view:** Timeline of sleep stage transitions from sleep onset to final wake. The y-axis shows sleep stages (Wake, Light, REM, Deep); the x-axis shows time elapsed during the sleep session. Each color represents a sleep stage.

**All Participants view:** Stacked bar chart showing the proportion or average minutes in each sleep stage per study day across all participants combined.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| Night selector (individual view only) | Dropdown menu of available sleep dates | Allows user to inspect individual nights |

**How the chart changes:**

- **Individual participant, individual night:** Timeline showing sleep stage transitions for the selected night only.
- **Individual participant, all nights:** (Not shown; use Sleep Stage Breakdown chart instead.)
- **All Participants (admin only):** Stacked bar chart showing average minutes per stage per study day. Night selector is hidden.

**Research context:**

The hypnogram reveals sleep architecture:

- Normal sleep shows a progression from light to deep sleep, with REM cycles.
- Fragmented sleep shows frequent stage changes and wake episodes.
- Sleep latency (time to first sleep stage) can be estimated from the x-axis.

In individual night view, researchers can visually inspect the quality and stability of sleep. In all participants view, cohort-level patterns can be compared across study days.

---

### Sleep Efficiency

**Type:** Line chart with reference line

**Visibility:** All users

**Data source:** `sleep_minute.csv`

**What this chart shows:**

Percentage of time in bed actually spent asleep (not awake). Sleep efficiency is calculated as 100 times the minutes in any sleep stage divided by total minutes in the sleep session. An 85 percent reference line marks a clinical threshold for normal sleep efficiency.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| View mode toggle | By Date / By Study Day | Shared toolbar control |
| Participant selector (admin only) | Individual participant / All Participants | Shared toolbar control |
| Admin aggregate toggle (study day, all participants only) | Aggregate / Split by Participant | Radio buttons appear in admin view only |

**How the chart changes by view:**

- **By Date (individual participant):** One point per calendar date, connected by lines.
- **By Study Day (individual participant):** One point per study day, connected by lines.
- **By Study Day, All Participants, Aggregate (admin only):** Single line showing cohort-average sleep efficiency per study day.
- **By Study Day, All Participants, Split by Participant (admin only):** One line per participant, overlaid for comparison.

**Research context:**

Sleep efficiency below 85 percent may indicate:

- Insomnia (long time to fall asleep or frequent awakenings)
- Fragmented sleep related to stress or anxiety
- Sleep disturbances related to environmental or physiological factors

Tracking efficiency across study days can reveal whether stress or interventions affect sleep quality.

---

### Sleep Latency

**Type:** Line chart with reference lines (Good: 15 min, Fair: 30 min)

**Visibility:** All users

**Data source:** `sleep_minute.csv` (time from first wake to first sleep stage per session)

**What this chart shows:**

Minutes required to fall asleep for each sleep session. If a participant has multiple sleep sessions per night (e.g., naps or fragmented sleep), each session is shown separately with a label (S2, S3, etc.). Two reference lines indicate clinical thresholds: green (under 15 minutes = good latency), yellow (15-30 minutes = fair latency). Above 30 minutes may indicate difficulty falling asleep.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| View mode toggle | By Date / By Study Day | Shared toolbar control |
| Participant selector (admin only) | Individual participant / All Participants | Shared toolbar control |

**How the chart changes by view:**

- **By Date (individual participant):** X-axis shows calendar dates. If multiple sessions per date, they are labeled (e.g., "May 28 (S2)").
- **By Study Day (individual participant):** X-axis shows study days. Multiple sessions per day are labeled.
- **By Study Day, All Participants (admin only):** Sessions are averaged within each participant-day first, then averaged across participants per study day. One point per study day.

**Research context:**

Sleep latency is clinically relevant:

- Consistently short latency (under 10 minutes) may indicate sleep deprivation or narcolepsy.
- Consistently long latency (over 30 minutes) is associated with insomnia, anxiety, and stress.
- Increases in latency on specific study days may indicate acute stress or worry.

In cohort view, researchers can identify whether all participants show elevated latency on shared high-stress days.

---

### Blood Oxygen Saturation (SpO2) Over Time

**Type:** Line chart with min-max ribbon and error bars

**Visibility:** All users

**Data source:** `spo2_intraday.csv` (recorded during sleep)

**What this chart shows:**

Blood oxygen saturation during sleep, displayed as a daily average with a shaded ribbon showing the range (min to max) and error bars showing standard deviation around the mean. A reference line at 95 percent marks the clinical normal threshold.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| View mode toggle | By Date / By Study Day | Shared toolbar control |
| Participant selector (admin only) | Individual participant / All Participants | Shared toolbar control |

**How the chart changes by view:**

- **By Date (individual participant):** Daily average SpO2 plotted against calendar dates, with min-max ribbon.
- **By Study Day (individual participant):** Average SpO2 per study day, with min-max ribbon.
- **By Study Day, All Participants (admin only):** Cohort average SpO2 per study day, with a wide ribbon showing the range of lows and highs across all participants.

**Research context:**

SpO2 below 90 percent during sleep may indicate:

- Sleep apnea or other sleep-disordered breathing
- Cardiovascular or respiratory compromise
- Altitude or environmental effects

Sustained low SpO2 warrants medical evaluation. In stress research, respiratory responses to stress can manifest as SpO2 changes during sleep.

---

## Activity

The Activity tab is visible to all users. It provides detailed analysis of movement, activity intensity, sedentary behavior, and exercise patterns.

### Zone Minutes

**Type:** Stacked bar chart

**Visibility:** All users

**Data source:** `zone_minutes_intraday_5m.csv`

**What this chart shows:**

Minutes spent in three heart rate intensity zones: Fat Burn (moderate intensity), Cardio (higher intensity), and Peak (maximum intensity). Each bar is divided into colored segments representing time in each zone. Higher intensity zones indicate more vigorous activity.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| View mode toggle | By Date / By Study Day | Shared toolbar control |
| Participant selector (admin only) | Individual participant / All Participants | Shared toolbar control |

**How the chart changes by view:**

- **By Date (individual participant):** One stacked bar per calendar date.
- **By Study Day (individual participant):** One stacked bar per study day; zone minutes summed across all readings in that day.
- **By Study Day, All Participants (admin only):** One stacked bar per study day showing average zone minutes across all participants.

**Research context:**

Zone minutes reflect activity intensity:

- High Fat Burn minutes with low Cardio/Peak may indicate light to moderate activity (walking, casual exercise).
- High Cardio/Peak minutes indicate intense exercise sessions.
- Changes in zone distribution on specific study days may reflect changes in exercise behavior related to stress or mood.

---

### Exercise Sessions

**Type:** Bubble scatter chart (duration as bubble size)

**Visibility:** All users

**Data source:** `activity_sessions.csv` (logged exercise with type and duration)

**What this chart shows:**

Logged exercise sessions displayed as bubbles, with x-axis as date or study day, y-axis as duration in minutes, and bubble size proportional to duration. Color represents exercise type (Walk, Run, Bike, Sport, Workout, Swim, Yoga, or Other). Hover over a bubble to see session details.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| View mode toggle | By Date / By Study Day | Shared toolbar control |
| Participant selector (admin only) | Individual participant / All Participants | Shared toolbar control |
| Admin view type toggle (all participants only) | By Activity Type / By Participant | Radio buttons appear in admin view only |

**How the chart changes by view:**

- **By Date (individual participant):** Bubbles plotted against calendar dates, colored by activity type.
- **By Study Day (individual participant):** Bubbles plotted against study days, colored by activity type.
- **By Study Day, All Participants, By Activity Type (admin only):** Bubbles colored by activity type; hover shows participant name.
- **By Study Day, All Participants, By Participant (admin only):** Bubbles colored by participant ID (one color per participant).

**Research context:**

This chart reveals:

- Does the participant engage in structured exercise, and if so, on which days?
- What types of exercise does the participant prefer?
- Do exercise patterns change on or after high-stress days (increase or decrease)?
- In cohort view, do all participants show similar exercise patterns?

---

### Sedentary Periods

**Type:** Bar chart

**Visibility:** All users

**Data source:** `sedentary_periods.csv` (periods of inactivity)

**What this chart shows:**

Total minutes spent sedentary per day. Sedentary periods are detected automatically by the Fitbit based on the absence of step activity. Each bar represents the sum of all sedentary minutes for a given date or study day.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| View mode toggle | By Date / By Study Day | Shared toolbar control |
| Participant selector (admin only) | Individual participant / All Participants | Shared toolbar control |

**How the chart changes by view:**

- **By Date (individual participant):** One bar per calendar date.
- **By Study Day (individual participant):** One bar per study day; sedentary minutes summed.
- **By Study Day, All Participants (admin only):** One bar per study day showing average sedentary minutes across all participants.

**Research context:**

Prolonged sedentary time is associated with health risks. This chart reveals:

- Does the participant accumulate excessive sedentary time on specific days?
- Do sedentary patterns change around high-stress events (sitting more under stress)?
- In cohort view, are there study days when all participants become more sedentary?

---

### Daily Steps (Activity Tab)

**Type:** Bar chart with 10,000-step goal line

**Visibility:** All users

**Data source:** `steps_intraday_5m.csv`

**What this chart shows:**

Total daily steps with a 10,000-step goal line as a reference. This is the same underlying data as the Overview tab's Daily Steps chart but presented in the Activity tab for detailed analysis.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| View mode toggle | By Date / By Study Day | Shared toolbar control |
| Participant selector (admin only) | Individual participant / All Participants | Shared toolbar control |

**How the chart changes by view:**

- **By Date (individual participant):** One bar per calendar date.
- **By Study Day (individual participant):** One bar per study day; steps summed.
- **By Study Day, All Participants (admin only):** One bar per study day showing average daily steps across all participants.

**Research context:**

The 10,000-step goal is a common physical activity target. This chart helps researchers explore:

- Does the participant consistently meet the goal?
- Are there specific days or study periods with reduced activity?
- In cohort view, do all participants show similar step patterns?

---

### Steps by Hour of Day

**Type:** Bar chart (date view) or multi-line chart (study day view)

**Visibility:** All users

**Data source:** `steps_intraday_5m.csv`

**What this chart shows:**

Average steps per hour of day, revealing when during the day the participant is most active. In date view, a bar chart shows mean and standard deviation for each hour. In study day view, one line per study day overlaid to compare activity patterns across different days.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| View mode toggle | By Date / By Study Day | Shared toolbar control |
| Participant selector (admin only) | Individual participant / All Participants | Shared toolbar control |

**How the chart changes by view:**

- **By Date (individual participant):** Bar chart with error bars showing mean and standard deviation per hour.
- **By Study Day (individual participant):** One line per study day, showing how hourly step patterns vary across different study days.
- **By Study Day, All Participants (admin only):** One line per participant, overlaid to compare cohort activity patterns across hours.

**Research context:**

This chart reveals:

- Does the participant show typical daytime activity (peaks during work/exercise hours) and nighttime rest?
- Are there hours of unusual inactivity (sitting for prolonged periods)?
- Do hourly activity patterns change on high-stress days?
- In cohort view, are there common hours when all participants show elevated or reduced activity?

---

### Distance per Day

**Type:** Bar chart

**Visibility:** All users

**Data source:** `distance_intraday.csv` (distance in meters)

**What this chart shows:**

Total distance traveled per day in meters. Distance is calculated from step count and stride length as measured by the Fitbit. Each bar represents one calendar date or study day.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| View mode toggle | By Date / By Study Day | Shared toolbar control |
| Participant selector (admin only) | Individual participant / All Participants | Shared toolbar control |

**How the chart changes by view:**

- **By Date (individual participant):** One bar per calendar date.
- **By Study Day (individual participant):** One bar per study day; distance summed.
- **By Study Day, All Participants (admin only):** One bar per study day showing average distance across all participants.

**Research context:**

Distance is a complementary measure to step count. A participant with the same step count may travel different distances depending on stride length and pace. This chart reveals:

- Does the participant cover more or less distance on specific days?
- Is there a relationship between distance and reported stress or activity level?
- In cohort view, do participants show similar distance patterns?

---

## Insights

The Insights tab is visible to all users. It provides summary metrics and comparative analysis (weekday vs weekend) of key health markers.

### Key Insight Metric Cards

Three summary metric cards appear at the top of the Insights tab, displaying snapshot insights about the participant's behavior during the selected range.

#### Best Sleep Night

**Data source:** `daily_metrics.csv` (total_sleep_minutes) or `sleep_minute.csv`

**What it shows:** The single night within the selected date or study day range with the highest total sleep duration, and the number of minutes slept that night.

**Notes:** This metric is updated in real time as the date range filter changes. It reflects the single best night only, not an average.

**Admin note:** In All Participants mode, this shows the study day with the highest cohort-average sleep minutes.

#### Most Active Day

**Data source:** `steps_intraday_5m.csv`

**What it shows:** The single day with the highest total step count in the selected range, and the number of steps taken that day.

**Notes:** This metric reflects the single most active day only.

**Admin note:** In All Participants mode, this shows the study day with the highest cohort-average step count.

#### Typical Bedtime

**Data source:** `sleep_minute.csv` (first sleep stage timestamp per session)

**What it shows:** The average time of sleep onset across all sleep sessions in the selected range. Times after midnight are handled correctly (e.g., 1:00 AM is treated as early morning, not late night) to calculate a meaningful average.

**Notes:** This represents the typical clock time when the participant falls asleep, averaged across all nights. If bedtime varies significantly, the average may not be representative of any single night.

**Admin note:** In All Participants mode, this shows the average bedtime across all participants combined, with an "(avg)" suffix appended to the time.

---

### Sleep Duration: Weekday vs Weekend

**Type:** Bar chart (two categories)

**Visibility:** All users

**Data source:** `sleep_minute.csv` with day-of-week classification

**What this chart shows:**

Average total sleep duration on weekdays compared to weekends, displayed as two bars. This reveals whether the participant sleeps more or less on days off.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| Participant selector (admin only) | Individual participant / All Participants | Shared toolbar control |

**How the chart changes:**

- **Individual participant:** Average sleep minutes on weekdays and weekends for the selected participant.
- **All Participants (admin only):** Cohort average sleep minutes per day type across all participants.

**Research context:**

Differences in weekday versus weekend sleep can reflect:

- Work-related sleep disruption (shorter weekday sleep due to early wake times or stress)
- Sleep recovery on weekends ("social jetlag")
- Lifestyle factors (e.g., more relaxation on weekends)

In stress research, changes in weekday sleep duration may relate to chronic occupational stress.

---

### Steps: Weekday vs Weekend

**Type:** Bar chart (two categories)

**Visibility:** All users

**Data source:** `steps_intraday_5m.csv` with day-of-week classification

**What this chart shows:**

Average daily step count on weekdays compared to weekends. This reveals whether the participant is more or less active on work days versus rest days.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| Participant selector (admin only) | Individual participant / All Participants | Shared toolbar control |

**How the chart changes:**

- **Individual participant:** Average steps on weekdays and weekends.
- **All Participants (admin only):** Cohort average steps per day type.

**Research context:**

Activity patterns often differ between work days and leisure days:

- Higher weekday steps may indicate a job requiring movement.
- Higher weekend steps may indicate leisure or exercise time.
- Lower weekday steps may reflect desk work or stress-related inactivity.

---

### HRV: Weekday vs Weekend

**Type:** Bar chart (two categories)

**Visibility:** Admin only

**Data source:** `hrv_intraday.csv` with day-of-week classification

**What this chart shows:**

Average heart rate variability (RMSSD) on weekdays compared to weekends. Lower HRV on weekdays may indicate elevated stress or reduced recovery during the work week, which is directly relevant to the STARS study of discrimination and stress.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| Participant selector | Individual participant / All Participants | Shared toolbar control |

**How the chart changes:**

- **Individual participant:** Average RMSSD on weekdays and weekends.
- **All Participants:** Cohort average HRV per day type.

**Research context:**

The weekday-weekend HRV differential is a key biomarker in stress research:

- Sustained lower HRV on weekdays suggests chronic occupational stress.
- Better HRV on weekends suggests recovery when stress is reduced.
- In discrimination research, HRV patterns may reveal the physiological burden of chronic stress exposure.

---

### Resting Heart Rate: Weekday vs Weekend

**Type:** Bar chart (two categories)

**Visibility:** Admin only

**Data source:** `daily_metrics.csv` (resting_heart_rate) with day-of-week classification

**What this chart shows:**

Average resting heart rate on weekdays compared to weekends. Elevated resting heart rate on weekdays compared to weekends is a marker of sustained physiological stress, relevant to discrimination and stress research.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| Participant selector | Individual participant / All Participants | Shared toolbar control |

**How the chart changes:**

- **Individual participant:** Average resting HR on weekdays and weekends.
- **All Participants:** Cohort average resting HR per day type.

**Research context:**

Resting heart rate elevation is an autonomic marker of stress:

- Consistently higher resting HR on weekdays suggests physiological arousal or sympathetic activation.
- Weekday-weekend differences may indicate whether stress is work-related or chronic.
- In stress research, this pattern is a clinically meaningful sign of stress-related cardiovascular burden.

---

## Projections

The Projections tab is visible to all users and contains research-focused charts examining the relationship between sleep and HRV across time.

### HRV vs Sleep Duration

**Type:** Scatter plot with linear regression line

**Visibility:** All users

**Data source:** `hrv_intraday.csv` (daily average RMSSD) joined with `daily_metrics.csv` (total_sleep_minutes) by participant and date

**What this chart shows:**

Scatter plot of total sleep minutes (x-axis) versus daily average HRV (y-axis). Each dot represents one participant-night. A linear regression line and confidence interval show the overall trend. The Pearson correlation coefficient (r value) quantifies the strength and direction of the relationship.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| Participant selector (admin only) | Individual participant / All Participants | Shared toolbar control |

**How the chart changes by view:**

- **Individual participant:** Dots represent all nights for that participant. The regression line and r value are fitted to that participant's data only.
- **All Participants (admin only):** All participant-nights are plotted and colored by participant. The regression line and r value are fitted to the combined cohort data.

**Research context:**

This chart explores a fundamental question in sleep and recovery research: Is sleep duration associated with autonomic recovery (as measured by HRV)?

Expected patterns:

- A positive correlation (upward slope) would suggest that better sleep is associated with higher HRV (better recovery).
- A weak or negative correlation might suggest that sleep duration alone is not the primary driver of HRV, or that other factors (stress, activity, sleep quality) are more important.

In discrimination and stress research, a weak relationship might emerge because stress reduces both sleep duration and HRV independently, rather than one causing the other.

---

### HRV vs Sleep: Lag Analysis

**Type:** Scatter plot with three marker types and linear regression line

**Visibility:** Admin only

**Data source:** `hrv_intraday.csv` joined with `sleep_minute.csv` by participant and date

**What this chart shows:**

A 1-day lag analysis exploring whether sleep and HRV influence each other across days. Three relationship types are plotted simultaneously:

- **Same Day (circles):** Sleep duration and HRV measured on the same calendar date. Tests whether they co-occur.
- **Sleep → HRV (squares):** Previous night's sleep duration versus next day's HRV. Tests whether better sleep predicts better autonomic recovery the following day.
- **HRV → Sleep (diamonds):** Previous day's HRV versus next night's sleep duration. Tests whether better recovery predicts longer sleep the following night.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| Participant selector | Individual participant / All Participants | Shared toolbar control |

**How the chart changes by view:**

- **Individual participant:** Three marker types show all three temporal relationships for that participant's data.
- **All Participants:** All participant-nights for all three relationships are pooled together. Hover over a marker to see which participant it belongs to.

**Research context:**

This chart tests bidirectional relationships between sleep and recovery:

- If the Sleep → HRV relationship (squares) is stronger than the HRV → Sleep relationship (diamonds), it suggests sleep drives recovery more than recovery drives sleep.
- If the HRV → Sleep relationship is stronger, it suggests that better daytime recovery promotes better sleep at night.
- Same-day correlations provide a baseline for comparison.

In stress research, disrupted patterns (e.g., all points clustered at low HRV regardless of sleep) may indicate that stress overrides normal sleep-recovery relationships.

---

# Admin-Only Tabs

## Analysis

The Analysis tab is visible to admins only. It provides multi-participant comparison charts and data completeness assessment.

### Multi-Participant Heart Rate Comparison

**Type:** Multi-line chart

**Visibility:** Admin only

**Data source:** `hr_intraday_5m.csv` (all participants)

**What this chart shows:**

Average heart rate per participant plotted against study day or date. One line per participant is overlaid for direct comparison. This allows researchers to visually assess whether participants show similar heart rate patterns or if some individuals respond differently to the study.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| View mode toggle | By Date / By Study Day | Shared toolbar control |

**How the chart changes by view:**

- **By Date:** All participants' lines plotted against calendar dates. Useful for identifying whether all participants experienced the same external event.
- **By Study Day:** All participants' lines aligned by study day (Day 1, Day 2, etc.). Makes it easier to compare across participants who enrolled on different dates.

**Research context:**

This chart reveals:

- Do all participants show similar heart rate trends, or is there marked heterogeneity?
- Are there specific study days when all participants' heart rates spike (possible shared stressor)?
- Do some participants show elevated baseline HR compared to others?

---

### Multi-Participant Steps Comparison

**Type:** Side-by-side bar chart (dodged bars)

**Visibility:** Admin only

**Data source:** `steps_intraday_5m.csv` (all participants)

**What this chart shows:**

Daily step totals per participant, displayed as bars grouped by study day or date. Each participant has a different color. This allows direct comparison of activity levels across participants and time.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| View mode toggle | By Date / By Study Day | Shared toolbar control |

**How the chart changes by view:**

- **By Date:** Bars grouped by calendar date, one bar per participant.
- **By Study Day:** Bars grouped by study day, one bar per participant.

**Research context:**

This chart reveals:

- Which participants are consistently more or less active?
- Do all participants show similar activity changes on specific study days?
- Are there participants with unusually low or high activity (outliers)?

---

### Data Completeness Heatmap

**Type:** Color-coded heatmap (data sources by participant and date)

**Visibility:** Admin only

**Data source:** `hr_intraday_5m.csv`, `steps_intraday_5m.csv`, `sleep_minute.csv` (presence indicator)

**What this chart shows:**

A grid showing which data sources (heart rate, steps, sleep) are present for each participant on each date. Darker or more saturated colors indicate the presence of more data sources (up to 3 sources total). Grey or lighter colors indicate missing data.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| Date range picker | Start and end dates | Shared toolbar control |

**How the chart works:**

- Each row represents a participant.
- Each column represents a calendar date.
- Each cell is colored based on how many of the three data sources are present for that participant-date combination.
  - 0 sources: no data collected that day.
  - 1 source: one type of data available (e.g., steps but no sleep).
  - 2 sources: two types available.
  - 3 sources: all three types available (complete data).

**Research context:**

Data completeness is critical for research quality. This chart reveals:

- Are there participants or dates with systematically missing data (device non-wear)?
- Did all participants collect data consistently, or are there gaps?
- Are there particular dates when multiple participants have missing data (possible external event, e.g., device failure)?

---

### Participant Activity Summary Table

**Type:** Interactive data table (DT)

**Visibility:** Admin only

**Data source:** `daily_metrics.csv` (aggregated)

**What this table shows:**

One row per participant with the following per-participant averages across the selected date range:

- Resting heart rate (bpm)
- Daily steps
- Total sleep duration (minutes)
- Blood oxygen saturation, lower bound (percent)
- Heart rate variability average nightly (RMSSD milliseconds)

**Features:**

- Sortable columns (click column headers to sort)
- Searchable (type in the search box to filter rows)
- Pageable (navigate through pages of results)
- Scrollable (table scrolls horizontally if needed on small screens)

**Research context:**

This summary table provides a bird's-eye view of participant metrics:

- Identify which participants have the lowest or highest values in any metric.
- Spot outliers or participants with unusual patterns.
- Quickly compare multiple health dimensions for a single participant.
- Use as a starting point for deeper dives into specific participants' data.

---

## Clinical Signals

The Clinical Signals tab is visible to admins only. It provides clinically integrated analysis of multiple physiological signals and derived risk flags.

### Clinical Signal Heatmap

**Type:** Color-coded heatmap (clinical flags by study day)

**Visibility:** Admin only

**Data source:** `daily_metrics.csv`, `sleep_minute.csv`, `sedentary_periods.csv` (derived flags)

**What this chart shows:**

A grid of seven clinical signals (rows) by study day (columns). Each cell is colored to indicate:

- Green: Normal (no flag).
- Red: Flagged (clinical concern).
- Grey: No data available.

**Clinical signals and thresholds:**

1. **Short Sleep:** Total sleep under 6 hours (360 minutes).
2. **Fragmented Sleep:** Wake After Sleep Onset (WASO) over 30 minutes OR more than 5 awakenings after sleep onset.
3. **Low Activity:** Fewer than 5,000 daily steps.
4. **Long Sedentary Bout:** Single longest sedentary period exceeding 60 minutes.
5. **Low HRV:** Daily HRV (RMSSD) below the participant's personal mean minus one standard deviation (indicating reduced autonomic recovery).
6. **High Resting Heart Rate:** Resting HR above the participant's personal mean plus one standard deviation (indicating elevated autonomic arousal).
7. **Low Blood Oxygen:** Lowest recorded SpO2 below 90 percent (potential respiratory concern).

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| Participant selector | Individual participant / All Participants | Shared toolbar control |

**How the chart changes:**

- **Individual participant:** Flags calculated using that participant's personal thresholds (e.g., their individual mean and standard deviation for HRV and HR).
- **All Participants:** Flags calculated using cohort-level thresholds (cohort mean +/- 1 SD for HRV and HR), making patterns comparable across participants.

**Research context:**

This heatmap provides a clinical snapshot:

- Identify clusters of red flags on specific study days (possible acute stress response).
- Spot participants who are consistently flagged across multiple signals (possible chronic stress or health issue).
- Compare patterns across the cohort to identify common stress response days.
- Use as a rapid screening tool to prioritize which participants need closer investigation.

---

### Sleep Fragmentation

**Type:** Dual-axis chart (bar and line)

**Visibility:** Admin only

**Data source:** `sleep_minute.csv` (wake episodes after sleep onset)

**What this chart shows:**

Two measures of sleep disruption:

- **WASO (left y-axis, bars):** Wake After Sleep Onset in minutes. The total time awake after initially falling asleep.
- **Awakenings (right y-axis, line):** Number of distinct wake episodes after sleep onset.

Each study day shows both measures, making it easy to compare disruption across days.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| Participant selector | Individual participant / All Participants | Shared toolbar control |

**How the chart changes:**

- **Individual participant:** WASO minutes and awakening count for that participant across study days.
- **All Participants:** Average WASO minutes and awakening count per study day, averaged across all participants.

**Research context:**

Sleep fragmentation is clinically relevant to stress, anxiety, and trauma research:

- Elevated WASO suggests difficulty maintaining sleep (possible anxiety or environmental disruption).
- High awakening counts indicate a restless sleep pattern (associated with insomnia, hyperarousal, PTSD-like responses).
- Both metrics may spike on or after high-stress days, indicating sleep disruption as a stress response.

---

### Longest Sedentary Bout per Day

**Type:** Bar chart with threshold reference line

**Visibility:** Admin only

**Data source:** `sedentary_periods.csv` (maximum duration per day)

**What this chart shows:**

The longest single sedentary period recorded each study day, in minutes. A yellow dashed reference line at 60 minutes marks a commonly used threshold for "prolonged sedentary behavior."

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| Participant selector | Individual participant / All Participants | Shared toolbar control |

**How the chart changes:**

- **Individual participant:** Longest sedentary bout per study day for that participant.
- **All Participants:** Average longest bout per study day, averaged across all participants.

**Research context:**

Prolonged sedentary behavior is associated with health risks, including cardiovascular disease and metabolic dysfunction. In stress research, this metric may reveal:

- Does the participant sit for long unbroken periods on high-stress days (stress-related inactivity)?
- Are there study days when all participants show longer sedentary bouts (possible environmental constraint)?

---

### Recovery Flags

**Type:** Mini heatmap (three recovery signals by study day)

**Visibility:** Admin only

**Data source:** `daily_metrics.csv` (HRV, resting HR, sleep duration)

**What this chart shows:**

A focused clinical assessment of three key recovery signals:

1. **Low HRV:** Below participant's personal mean minus one standard deviation (reduced autonomic recovery).
2. **High Resting Heart Rate:** Above participant's personal mean plus one standard deviation (elevated arousal or poor recovery).
3. **Short Sleep:** Total sleep under 6 hours (insufficient restorative sleep).

Each study day is a column; rows show the three signals. Cells are colored green (normal), red (flagged), or grey (no data). Hover over a cell to see the actual value and deviation from the participant's personal baseline.

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| Participant selector | Individual participant / All Participants | Shared toolbar control |

**How the chart changes:**

- **Individual participant:** Flags use that participant's personal thresholds.
- **All Participants:** Flags use cohort-level thresholds for comparison.

**Research context:**

Recovery is a multidimensional construct combining autonomic recovery (HRV), arousal level (resting HR), and sleep. Days with multiple red flags simultaneously indicate poor overall recovery, possibly in response to stress. In discrimination and stress research, sustained patterns of poor recovery are clinically significant markers of physiological burden.

---

### Daily Clinical Summary Table

**Type:** Interactive data table (DT)

**Visibility:** Admin only

**Data source:** `daily_metrics.csv`, `sleep_minute.csv`, `sedentary_periods.csv` (derived metrics)

**What this table shows:**

One row per study day with the following columns:

- Study Day
- Sleep (minutes)
- WASO (minutes awake after sleep onset)
- Awakenings (number of wake episodes)
- Steps
- Active Minutes
- Longest Sedentary Bout (minutes)
- HRV (RMSSD milliseconds)
- Resting Heart Rate (bpm)

**Features:**

- Sortable columns
- Searchable rows
- Pageable
- Horizontally scrollable

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| Participant selector | Individual participant / All Participants | Shared toolbar control |

**How the table changes:**

- **Individual participant:** One row per study day for that participant.
- **All Participants:** One row per study day showing averages across all participants.

**Research context:**

This table is the foundation of the Clinical Signals tab. It consolidates eight key health dimensions into a single reference that researchers can scan quickly:

- Identify patterns (e.g., high steps but short sleep).
- Spot days with multiple concerning values.
- Export or reference for manuscript tables.
- Use as a basis for deeper investigation into specific study days or participants.

---

## Data View

The Data View tab is visible to admins only. It allows raw inspection of any loaded dataset.

### Raw Data Viewer

**Type:** Interactive data table (DT)

**Visibility:** Admin only

**Data source:** Any of the loaded CSV datasets (user selectable)

**What this table shows:**

The complete raw data for the selected dataset, filtered by the current date or study day range. All columns from the CSV are displayed. Data is pageable, searchable, and sortable.

**Available datasets:**

- Heart Rate (hr_intraday_5m.csv)
- Steps (steps_intraday_5m.csv)
- Sleep (sleep_minute.csv)
- Daily Metrics (daily_metrics.csv)
- HRV (hrv_intraday.csv)
- Activity Level (activity_level_intraday.csv)
- Zone Minutes (zone_minutes_intraday_5m.csv)
- Activity Sessions (activity_sessions.csv)
- Sedentary Periods (sedentary_periods.csv)
- Blood Oxygen (SpO2) (spo2_intraday.csv)

**View options:**

| Control | Options | Notes |
|---------|---------|-------|
| Dataset selector | Dropdown menu of all 10 datasets | User selects which CSV to view |
| Date/Study Day filter | Shared toolbar controls | Rows are filtered to selected range |

**How the table works:**

1. Select a dataset from the dropdown.
2. The table populates with all rows from that dataset that fall within the current date or study day range.
3. Use the search box to find specific rows (e.g., search for a participant ID).
4. Click column headers to sort.
5. Navigate pages to browse large datasets.

**Research context:**

Raw data inspection is essential for quality assurance:

- Verify that data was loaded correctly from the CSV files.
- Spot missing values, outliers, or data quality issues.
- Trace a specific data point back to its source.
- Audit the data before conducting statistical analysis.
- Check for inconsistencies or anomalies in the raw measurements.

---

# Summary

This dashboard provides a comprehensive suite of tools for analyzing physiological data from Fitbit wearables in the context of a study on discrimination and stress (STARS Program, Simmons University, in collaboration with Boston University Labs).

All charts and tables are designed with both users (individual participants viewing their own data) and admins (researchers comparing across participants) in mind. Key features include:

- **View modes** allowing flexible analysis by calendar date or study day (for cross-participant alignment).
- **Role-based visibility** ensuring that advanced research charts are available only to authorized staff.
- **Clinical integration** through the Clinical Signals tab, which translates raw Fitbit data into clinically meaningful patterns and risk flags.
- **Research context** integrated into every chart description, linking metrics to stress, recovery, and physiological burden concepts relevant to the study.

For questions about specific charts or technical details, refer to the corresponding entry in this documentation.