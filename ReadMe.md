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

rshiny_fitbit-dashboard/
├── app.R              # Main Shiny application
├── R/                 # Helper functions and color palettes
│   └── colours.R      # Custom color definitions
├── www/               # Web assets
│   └── custom.css     # Custom CSS styling (default lightmode)
│   └── darkmode.css   # TBD
├── scripts/           # Utility scripts
│   ├── excel_to_csv-sheets.R # Converts 1 workbook to csv by sheet(tab)
│   └── install_packages.R # Some helpful packages
│   └── merge_excel_files.R # Draft script for merging multiple workbooks
├── csvdata/           # Directory for csv files generated from xlsx workbook
├── xlsx_source/       # Directory for xlsx source files
└── renv/              # renv package management

## Troubleshooting
- Be sure you opened the .Rproj file, not just the folder
- The first run of renv::restore() may take several minutes
- If renv is not installed: install.packages("renv") first

## Notes
- This project uses renv for reproducible package management
- Modify the data loading paths in app.R to point to your data source

## License
All Rights Reserved

## Version
0.02