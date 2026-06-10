# rshiny_fitbit-dashboard
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

## Project Structure

rshiny_fitbit-dashboard/
├── app.R              # Main Shiny application
├── R/                 # Helper functions and color palettes
│   └── colours.R      # Custom color definitions
├── www/               # Web assets
│   └── custom.css     # Custom styling
├── scripts/           # Utility scripts
│   ├── excel_to_csv-sheets.R
│   └── install_packages.R
├── csvdata/           # Directory for csv files generated from xlsx workbook
├── xlsx_source/       # Directory for xlsx source files
└── renv/              # renv package management

## Troubleshooting
- Be sure you opened the .Rproj file, not just the folder
- The first run of renv::restore() may take several minutes

- If renv is not installed: install.packages("renv")

## Notes
- This project uses renv for reproducible package management
- Modify the data loading paths in app.R to point to your data source

## License
All Rights Reserved