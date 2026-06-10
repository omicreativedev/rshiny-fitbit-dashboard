#!/usr/bin/env Rscript

# Excel to CSV converter - Convert each sheet of an Excel file to a separate CSV file.
# CSV files are named after the sheet names only (e.g., 'January.csv', 'Sheet2.csv').

# Run in Terminal
# Rscript scripts/excel_to_csv-sheets.R

# ============================================================
# USER SETTINGS - EDIT THESE BEFORE RUNNING
# ============================================================

# Path to your Excel file (.xls or .xlsx)
# Just put the path relative to project root (no ../ needed)
EXCEL_FILE_PATH <- "xlsx_source/FitbitDataSync.xlsx"

# Output directory for CSV files
OUTPUT_DIR <- "csvdata"

# CSV encoding (default: 'UTF-8', use 'latin1' for special characters)
CSV_ENCODING <- "UTF-8"

# ============================================================
# SCRIPT STARTS HERE - DON'T EDIT BELOW UNLESS YOU KNOW WHAT YOU'RE DOING
# ============================================================

# Load required libraries
if (!require("readxl", quietly = TRUE)) {
  install.packages("readxl")
  library(readxl)
}

# Get the directory where THIS script is located
get_script_dir <- function() {
  cmd_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- "--file="
  if (any(grepl(file_arg, cmd_args))) {
    return(dirname(sub(file_arg, "", cmd_args[grep(file_arg, cmd_args)])))
  }
  if (interactive() && !is.null(sys.calls())) {
    call_stack <- sys.calls()
    if (length(call_stack) > 0) {
      source_file <- call_stack[[1]]
      if (grepl("source", source_file[1])) {
        return(dirname(normalizePath(sub(".*\"(.*)\".*", "\\1", source_file[2]))))
      }
    }
  }
  return(getwd())
}

# Find project root (where scripts/, xlsx_source/, csvdata/ live)
find_project_root <- function(script_dir) {
  if (basename(script_dir) == "scripts") {
    return(dirname(script_dir))
  }
  if (file.exists(file.path(script_dir, "scripts"))) {
    return(script_dir)
  }
  return(script_dir)
}

# Set up paths dynamically
script_dir <- get_script_dir()
project_root <- find_project_root(script_dir)

# Resolve paths relative to project root
resolve_path <- function(relative_path) {
  if (file.exists(relative_path)) {
    return(normalizePath(relative_path))
  }
  candidate <- file.path(project_root, relative_path)
  if (file.exists(candidate) || grepl("\\.xlsx?$", relative_path)) {
    return(candidate)
  }
  return(candidate)
}

# Convert user settings to absolute paths
EXCEL_FILE_PATH <- resolve_path(EXCEL_FILE_PATH)
OUTPUT_DIR <- resolve_path(OUTPUT_DIR)

sanitize_filename <- function(name) {
  invalid_chars <- '[<>:"/\\|?*]'
  name <- gsub(invalid_chars, "_", name)
  return(trimws(name))
}

convert_excel_to_csv <- function(excel_path, output_dir = NULL, encoding = "UTF-8") {
  if (!file.exists(excel_path)) {
    stop(paste("Excel file not found:", excel_path))
  }
  
  if (is.null(output_dir) || output_dir == "") {
    output_dir <- dirname(excel_path)
    if (output_dir == ".") output_dir <- getwd()
  }
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  sheet_names <- excel_sheets(excel_path)
  if (length(sheet_names) == 0) {
    warning("No sheets found in the Excel file.")
    return(c())
  }
  
  generated_files <- c()
  cat(paste("Processing:", excel_path, "\n"))
  cat(paste("Output folder:", output_dir, "\n\n"))
  
  for (sheet in sheet_names) {
    tryCatch({
      df <- read_excel(excel_path, sheet = sheet)
      safe_sheet <- sanitize_filename(sheet)
      csv_filename <- paste0(safe_sheet, ".csv")
      csv_path <- file.path(output_dir, csv_filename)
      write.csv(df, csv_path, row.names = FALSE, fileEncoding = encoding)
      generated_files <- c(generated_files, csv_path)
      cat(paste("  Created:", csv_filename, "(", nrow(df), "rows)\n"))
    }, error = function(e) {
      cat(paste("  Skipping sheet '", sheet, "' due to error:", e$message, "\n"))
    })
  }
  
  return(generated_files)
}

main <- function() {
  tryCatch({
    cat(paste("Project root:", project_root, "\n"))
    cat(paste("Looking for Excel file:", EXCEL_FILE_PATH, "\n\n"))
    csv_files <- convert_excel_to_csv(EXCEL_FILE_PATH, OUTPUT_DIR, CSV_ENCODING)
    cat(paste("\nConversion complete. Generated", length(csv_files), "CSV file(s).\n"))
  }, error = function(e) {
    cat(paste("Error:", e$message, "\n"))
  })
}

if (sys.nframe() == 0) {
  main()
}