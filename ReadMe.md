# R Shiny Fitbit Dashboard
#### Fitbit Research Dashboard for STARS Program Simmons University

## About
This Shiny application visualizes physiological data from Fitbit devices for research on discrimination and health outcomes.

## Prerequisites
- R (version 4.0 or higher)
- RStudio (recommended)

## Setup Instructions
Clone this repository

Open the project in RStudio by double-clicking rshiny_fitbit-dashboard.Rproj

In the R console, run:

```renv::restore()```

Wait for all packages to install (this may take a few minutes)

Run the app:

```shiny::runApp()```

Login:

Enter participantID or admin-username
Click Login

Note! The csvdata and xlsx_source is empty.
To use this app you must have the properly formatted xlsx file.
Or you must have csvs that are each named after the xlsx workbook tabs.
To convert your workbook to the correct csv files,
put your workbook copy (downloaded as xlsx) into the xlsx_source folder
then run scripts/excel_to_csv-sheet.R

## Project Structure

```text
## Project Structure
```text
rshiny_fitbit-dashboard/
├── rshiny_fitbit-dashboard.Rproj # Project file to click to open project
├── app.R                         # Main Shiny application entry point
├── roles.csv                     # Role definitions used by the app
├── renv.lock                     # Locked package versions for reproducibility
├── R/                            # Include R scripts
│   └── colours.R                 # Custom color palette definitions
│   └── chart_card.R              # Information popover card descriptions
├── www/
│   └── custom.css                # Custom CSS styling (light mode)
│   └── darkmode.css              # Example darkmode styling
├── scripts/
│   ├── excel_to_csv-sheets.R     # Converts an xlsx workbook to CSVs per sheet
│   ├── merge_excel_files.R       # Draft script for merging multiple workbooks
│   └── install_packages.R        # Helper to install required packages
├── csvdata/                      # CSV files exported from the xlsx source (mock data)
│   ├── daily_metrics.csv             # < Gitignored: Your csv's must be named
│   ├── activity_sessions.csv         # < these exact names based on the tab
│   ├── activity_level_intraday.csv   # < names in the Source Fitbit data workbook
│   ├── steps_intraday_5m.csv         # < 
│   ├── hr_intraday_5m.csv            # <
│   ├── hrv_intraday.csv              # <
│   ├── breathing_rate_summary.csv    # <
│   ├── distance_intraday.csv         # <
│   ├── zone_minutes_intraday_5m.csv  # <
│   ├── spo2_intraday.csv             # <
│   ├── sleep_minute.csv              # <
│   ├── sedentary_periods.csv         # <
│   ├── fetch_log.csv                 # <
│   └── tokenSheet.csv                # Fitbit API token storage (emptied!)
├── xlsx_source/                  # Source Fitbit data workbook (gitignored)
│   └── [YOUR FILE HERE]          # Google Sheet App downloaded as .xlsx
└── renv/                         # renv package management (auto-managed)
```

## Troubleshooting
- Be sure you opened the .Rproj file, not just the folder
- The first run of renv::restore() may take several minutes
- If renv is not installed: install.packages("renv") first

## Notes
- This project uses renv for reproducible package management
- Modify the data loading paths in app.R to point to your data source

## License
All Rights Reserved
Contact Professor Lauren Trichtinger, Advisor
lauren.trichtinger@simmons.edu

## Version
1.0
