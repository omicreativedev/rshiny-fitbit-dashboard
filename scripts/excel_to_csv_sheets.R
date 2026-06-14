#!/usr/bin/env Rscript

# ====================================================================
# SCRIPT PURPOSE
# ====================================================================
# Excel to CSV converter - Convert each sheet of an Excel file to a separate CSV file.
# CSV files are named after the sheet names only (e.g., 'January.csv', 'Sheet2.csv').

# Run in Terminal with: Rscript scripts/excel_to_csv-sheets.R

# ====================================================================
# USER SETTINGS - EDIT THESE BEFORE RUNNING
# ====================================================================

# Path to your Excel file (.xls or .xlsx)
# Use relative path from project root (don't need ../ at start)
EXCEL_FILE_PATH <- "xlsx_source/FitbitDataSync.xlsx"

# Output directory where CSV files will be saved
OUTPUT_DIR <- "csvdata"

# CSV encoding (default: 'UTF-8' for universal compatibility, 
# use 'latin1' for special characters like accents or symbols)
CSV_ENCODING <- "UTF-8"

# ====================================================================
# SCRIPT STARTS HERE - DON'T EDIT BELOW UNLESS YOU KNOW WHAT YOU'RE DOING
# ====================================================================

# --------------------------------------------------------------------
# LIBRARY LOADING WITH AUTOMATIC INSTALLATION
# --------------------------------------------------------------------
# Check if 'readxl' package is installed (for reading Excel files)
# quietly=TRUE suppresses package startup messages
if (!require("readxl", quietly = TRUE)) {
  # If not installed, automatically install it
  install.packages("readxl")
  # Then load it into the current R session
  library(readxl)
}

# Note: dplyr is no longer needed since we're not using the rename() function
# The sanitize_column_names function uses base R instead

# --------------------------------------------------------------------
# FUNCTION: Get the directory where this script is located
# --------------------------------------------------------------------
# This works whether the script is run from command line or sourced interactively
get_script_dir <- function() {
  # Get all command line arguments passed to R
  cmd_args <- commandArgs(trailingOnly = FALSE)
  
  # Look for the --file= argument which contains the script's path
  file_arg <- "--file="
  if (any(grepl(file_arg, cmd_args))) {
    # Extract the file path by removing '--file=' prefix
    file_path <- sub(file_arg, "", cmd_args[grep(file_arg, cmd_args)])
    # Return just the directory part (remove filename)
    return(dirname(file_path))
  }
  
  # Alternative for interactive R sessions (when script is sourced)
  if (interactive() && !is.null(sys.calls())) {
    call_stack <- sys.calls()  # Get the call stack
    if (length(call_stack) > 0) {
      source_file <- call_stack[[1]]  # First call is usually the source command
      # Extract filename from source() call using regex
      if (grepl("source", source_file[1])) {
        file_path <- sub(".*\"(.*)\".*", "\\1", source_file[2])
        # Normalize path and return directory
        return(dirname(normalizePath(file_path)))
      }
    }
  }
  
  # Fallback: return current working directory if everything else fails
  return(getwd())
}

# --------------------------------------------------------------------
# FUNCTION: Find project root directory
# --------------------------------------------------------------------
# Looks for the parent directory containing standard folders (scripts/, xlsx_source/, etc.)
find_project_root <- function(script_dir) {
  # If we're already in a 'scripts' folder, parent is the project root
  if (basename(script_dir) == "scripts") {
    return(dirname(script_dir))
  }
  
  # Check if there's a 'scripts' subfolder in the current directory
  if (file.exists(file.path(script_dir, "scripts"))) {
    return(script_dir)  # Current directory is the project root
  }
  
  # Default: assume current directory is the project root
  return(script_dir)
}

# --------------------------------------------------------------------
# SET UP DYNAMIC PATH RESOLUTION
# --------------------------------------------------------------------
# Get script location and project root
script_dir <- get_script_dir()           # Where this script lives
project_root <- find_project_root(script_dir)  # Root directory of the project

# --------------------------------------------------------------------
# FUNCTION: Convert relative paths to absolute paths
# --------------------------------------------------------------------
# Takes a relative path and resolves it relative to project root
resolve_path <- function(relative_path) {
  # If the path already exists as given, return absolute version
  if (file.exists(relative_path)) {
    return(normalizePath(relative_path))
  }
  
  # Otherwise, try appending it to project root
  candidate <- file.path(project_root, relative_path)
  
  # Return candidate if it exists OR if it's an Excel file (might not exist yet)
  if (file.exists(candidate) || grepl("\\.xlsx?$", relative_path)) {
    return(candidate)
  }
  
  # Last resort: return candidate anyway (will fail later if invalid)
  return(candidate)
}

# --------------------------------------------------------------------
# CONVERT USER PATHS TO ABSOLUTE PATHS
# --------------------------------------------------------------------
# Apply path resolution to user-provided paths
EXCEL_FILE_PATH <- resolve_path(EXCEL_FILE_PATH)  # Full path to input Excel file
OUTPUT_DIR <- resolve_path(OUTPUT_DIR)            # Full path to output CSV directory

# --------------------------------------------------------------------
# FUNCTION: Remove invalid characters from filenames
# --------------------------------------------------------------------
# Ensures sheet names become valid CSV filenames across operating systems
sanitize_filename <- function(name) {
  # Pattern matches invalid filename characters: < > : " / \ | ? *
  # These are illegal in Windows, Linux, and/or macOS
  invalid_chars <- '[<>:"/\\|?*]'
  
  # Replace each invalid character with underscore
  name <- gsub(invalid_chars, "_", name)
  
  # Remove leading/trailing whitespace
  return(trimws(name))
}

# --------------------------------------------------------------------
# FUNCTION: Standardize column names across all sheets
# --------------------------------------------------------------------
# This ensures consistency in CSV outputs by fixing common naming issues:
# 1. Replaces hyphens with underscores (since hyphens can cause issues in R)
# 2. Standardizes case inconsistencies (e.g., participantId -> participantID)
# 
# The advantage of this universal approach is that any future column with 
# hyphens or casing inconsistencies gets fixed automatically without 
# needing to modify the script again for each new sheet or column.
sanitize_column_names <- function(df) {
  # Replace all hyphens with underscores in column names
  # Hyphens can be problematic in R because they look like minus signs
  # Underscores are safe and commonly used as word separators
  names(df) <- gsub("-", "_", names(df))
  
  # Fix specific case inconsistency: change "participantId" to "participantID"
  # The ^ and $ ensure we only match the exact column name, not partial matches
  # This converts lowercase 'd' to uppercase 'D' for consistency across sheets
  names(df) <- sub("^participantId$", "participantID", names(df))
  
  # Return the modified data frame with cleaned column names
  return(df)
}

# --------------------------------------------------------------------
# MAIN CONVERSION FUNCTION
# --------------------------------------------------------------------
# Converts all sheets in an Excel file to individual CSV files
convert_excel_to_csv <- function(excel_path, output_dir = NULL, encoding = "UTF-8") {
  
  # VALIDATION: Check if Excel file exists
  if (!file.exists(excel_path)) {
    stop(paste("Excel file not found:", excel_path))
  }
  
  # SET OUTPUT DIRECTORY: If none specified, use Excel file's directory
  if (is.null(output_dir) || output_dir == "") {
    output_dir <- dirname(excel_path)  # Same folder as Excel file
    if (output_dir == ".") output_dir <- getwd()  # Current directory if just "."
  }
  
  # CREATE OUTPUT DIRECTORY if it doesn't exist
  # recursive = TRUE creates parent directories as needed
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  # GET ALL SHEET NAMES from the Excel file
  sheet_names <- excel_sheets(excel_path)
  
  # Check if there are any sheets
  if (length(sheet_names) == 0) {
    warning("No sheets found in the Excel file.")
    return(c())  # Return empty vector
  }
  
  # Initialize vector to store paths of generated CSV files
  generated_files <- c()
  
  # Print progress information to console
  cat(paste("Processing:", excel_path, "\n"))
  cat(paste("Output folder:", output_dir, "\n\n"))
  
  # ------------------------------------------------------------------
  # LOOP THROUGH EACH SHEET IN THE EXCEL FILE
  # ------------------------------------------------------------------
  for (sheet in sheet_names) {
    # tryCatch handles errors gracefully without stopping the entire script
    tryCatch({
      # Read the current sheet into a data frame
      df <- read_excel(excel_path, sheet = sheet)
      
      # STANDARDIZE COLUMN NAMES (applies to EVERY sheet automatically)
      # This fixes hyphens, casing issues, and other naming inconsistencies
      # without needing sheet-specific conditional logic
      df <- sanitize_column_names(df)
      
      # Sanitize sheet name to create valid filename
      safe_sheet <- sanitize_filename(sheet)
      
      # Create CSV filename: sheetname.csv
      csv_filename <- paste0(safe_sheet, ".csv")
      
      # Create full output path by combining directory and filename
      csv_path <- file.path(output_dir, csv_filename)
      
      # Write data frame to CSV file
      # row.names = FALSE prevents adding an extra index column
      # fileEncoding specifies character encoding (UTF-8 or latin1)
      write.csv(df, csv_path, row.names = FALSE, fileEncoding = encoding)
      
      # Add this CSV path to our list of generated files
      generated_files <- c(generated_files, csv_path)
      
      # Print success message with row count
      cat(paste("  Created:", csv_filename, "(", nrow(df), "rows)\n"))
      
    }, error = function(e) {
      # ERROR HANDLING: If sheet fails to process, skip it and show warning
      cat(paste("  Skipping sheet '", sheet, "' due to error:", e$message, "\n"))
    })
  }
  
  # Return the list of all successfully created CSV files
  return(generated_files)
}

# --------------------------------------------------------------------
# MAIN FUNCTION: Entry point when script is run
# --------------------------------------------------------------------
main <- function() {
  # tryCatch ensures any fatal errors are caught and displayed nicely
  tryCatch({
    # Display configuration information
    cat(paste("Project root:", project_root, "\n"))
    cat(paste("Looking for Excel file:", EXCEL_FILE_PATH, "\n\n"))
    
    # Execute the conversion with user settings
    csv_files <- convert_excel_to_csv(EXCEL_FILE_PATH, OUTPUT_DIR, CSV_ENCODING)
    
    # Display completion summary
    cat(paste("\nConversion complete. Generated", length(csv_files), "CSV file(s).\n"))
    
  }, error = function(e) {
    # Catch and display any fatal errors
    cat(paste("Error:", e$message, "\n"))
  })
}

# --------------------------------------------------------------------
# SCRIPT EXECUTION CHECK
# --------------------------------------------------------------------
# sys.nframe() returns the number of frames in the call stack
# When script is run directly (not sourced), sys.nframe() == 0
# When sourced or loaded as module, we don't auto-execute
if (sys.nframe() == 0) {
  main()  # Run the main function only when script is executed directly
}