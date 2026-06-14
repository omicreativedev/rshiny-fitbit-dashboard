#!/usr/bin/env Rscript

# newuser.R - Complete project setup script
# Run this when you first download the project

cat("========================================\n")
cat("Fitbit Dashboard - Project Setup\n")
cat("========================================\n\n")

# 1. Check if renv is installed
cat("Step 1: Setting up renv...\n")
if (!requireNamespace("renv", quietly = TRUE)) {
  cat("Installing renv...\n")
  install.packages("renv")
}
cat("✓ renv ready\n\n")

# 2. Activate renv for this project
cat("Step 2: Activating renv...\n")
renv::activate()
cat("✓ renv activated\n\n")

# 3. Define all required packages based on your code
required_packages <- c(
  # Core data manipulation and plotting
  "tidyverse",        # dplyr, ggplot2, tidyr, readr, purrr, tibble
  "lubridate",        # Date/time handling
  "zoo",              # Rolling averages and time series
  "scales",           # Axis formatting
  
  # Visualization
  "plotly",           # Interactive plots
  "DT",               # Interactive datatables
  
  # Shiny app packages
  "shiny",            # Web framework
  "shinyfullscreen",  # Fullscreen charts
  "shinyjs",          # JavaScript functionality
  "rmarkdown",        # For Rmd files
  
  # Data import
  "readxl",           # Excel files
  "jsonlite",         # JSON parsing
  
  # Utilities
  "digest",           # For merge_excel_files.R
  "renv"              # Package management
)

# 4. Install packages
cat("Step 3: Installing required packages...\n")
cat("This may take 5-10 minutes depending on your connection...\n\n")

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat("Installing:", pkg, "\n")
    renv::install(pkg)
  } else {
    cat("✓ Already installed:", pkg, "\n")
  }
}
cat("\n✓ All packages installed\n\n")

# 5. Snapshot the environment
cat("Step 4: Recording package versions...\n")
renv::snapshot()
cat("✓ Environment saved to renv.lock\n\n")

# 6. Create .Rprofile for auto-activation
cat("Step 5: Setting up auto-activation...\n")
if (!file.exists(".Rprofile")) {
  writeLines('source("renv/activate.R")', ".Rprofile")
  cat("✓ .Rprofile created\n")
} else {
  cat("✓ .Rprofile already exists\n")
}
cat("\n")

# 7. Test that everything works
cat("Step 7: Testing setup...\n")
test_packages <- required_packages[!required_packages %in% c("renv", "shinyfullscreen")]
missing <- test_packages[!test_packages %in% installed.packages()[, "Package"]]

if (length(missing) == 0) {
  cat("✓ All packages verified\n")
} else {
  cat("⚠ Missing packages:", paste(missing, collapse = ", "), "\n")
  cat("  Run: renv::install(c('", paste(missing, collapse = "', '"), "'))\n", sep = "")
}
cat("\n")

# 9. Success message
cat("========================================\n")
cat("✅ Setup Complete!\n")
cat("========================================\n")
cat("\nTo run the dashboard:\n")
cat("  1. In RStudio: Load data into csvdata\n")
cat("  2. In RStudio: Open app.R and click 'Run App'\n")
cat("  3. In R console: shiny::runApp()\n")
cat("\nTo generate example charts:\n")
cat("  rmarkdown::render('example_charts.Rmd')\n")
cat("\nIf you have Excel files in data/ folder:\n")
cat("  source('scripts/excel_to_csv-sheets.R')\n")
cat("========================================\n")