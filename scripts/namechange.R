#!/usr/bin/env Rscript

# namechange.R
# Script to rename participant IDs in CSV files

# Hardcoded constants - modify these as needed
FROM_NAME <- "Salome"  # Change this to the name you want to replace
TO_NAME <- "Sarah"    # Change this to the new name

# Get the directory where THIS script is located
# This works regardless of where the project is
script_dir <- dirname(rstudioapi::getSourceEditorContext()$path)

# If not running in RStudio, use this fallback
if (script_dir == "") {
  script_dir <- getwd()
}

# Go up one level to project root, then into csvdata
project_root <- dirname(script_dir)  # This goes from scripts/ to project root
csv_data_dir <- file.path(project_root, "csvdata")

# Debug: Print paths to verify
cat("Script directory:", script_dir, "\n")
cat("Project root:", project_root, "\n")
cat("Looking for csvdata at:", csv_data_dir, "\n\n")

# Check if csvdata directory exists
if (!dir.exists(csv_data_dir)) {
  stop("Error: 'csvdata' folder not found at: ", csv_data_dir)
}

# Get all CSV files in the csvdata directory
csv_files <- list.files(csv_data_dir, pattern = "\\.csv$", full.names = TRUE)

if (length(csv_files) == 0) {
  stop("Error: No CSV files found in: ", csv_data_dir)
}

cat("Found", length(csv_files), "CSV file(s) to process.\n")
cat("Replacing '", FROM_NAME, "' with '", TO_NAME, "' in participant ID columns.\n\n", sep = "")

# Counter for modified files
modified_count <- 0

# Process each CSV file
for (file_path in csv_files) {
  cat("Processing:", basename(file_path), "... ")
  
  # Read the CSV file
  tryCatch({
    data <- read.csv(file_path, stringsAsFactors = FALSE, check.names = FALSE)
    
    # Check for participantId or participantID column
    col_names <- names(data)
    participant_col <- NULL
    
    # Look for exact matches (case-sensitive)
    if ("participantId" %in% col_names) {
      participant_col <- "participantId"
    } else if ("participantID" %in% col_names) {
      participant_col <- "participantID"
    } else {
      # Try case-insensitive search as fallback
      potential_cols <- grep("^participantid$", col_names, ignore.case = TRUE, value = TRUE)
      if (length(potential_cols) > 0) {
        participant_col <- potential_cols[1]
      } else {
        cat("No participantId/participantID column found. Skipping.\n")
        next
      }
    }
    
    # Check if the column exists and has data
    if (is.null(participant_col) || nrow(data) == 0) {
      cat("Column found but empty or invalid. Skipping.\n")
      next
    }
    
    # Check if FROM_NAME exists in the column
    matches <- which(data[[participant_col]] == FROM_NAME)
    
    if (length(matches) == 0) {
      cat("No matches found for '", FROM_NAME, "'. Skipping.\n", sep = "")
      next
    }
    
    # Replace the names
    data[[participant_col]][matches] <- TO_NAME
    
    # Write back to the same file - preserve quotes around strings
    write.csv(data, file = file_path, row.names = FALSE, quote = TRUE)
    
    cat(length(matches), "instance(s) renamed.\n")
    modified_count <- modified_count + 1
    
  }, error = function(e) {
    cat("ERROR:", e$message, "\n")
  })
}

cat("\nProcessing complete!", 
    modified_count, "file(s) modified.\n")

# Summary
if (modified_count == 0) {
  cat("\nNo files were modified. Check that:\n")
  cat("1. The participant column is named 'participantId' or 'participantID'\n")
  cat("2. The FROM_NAME '", FROM_NAME, "' exists in the data\n", sep = "")
}