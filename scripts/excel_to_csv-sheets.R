#!/usr/bin/env Rscript

"""
Excel to CSV converter - Convert each sheet of an Excel file to a separate CSV file.
CSV files are named after the sheet names only (e.g., 'January.csv', 'Sheet2.csv').
"""

# ============================================================
# USER SETTINGS - EDIT THESE BEFORE RUNNING
# ============================================================

# Path to your Excel file (.xls or .xlsx)
EXCEL_FILE_PATH <- r"D:\Repos\stars_processing_scripts\FitbitDataSync.xlsx"

# Output directory for CSV files (leave as "" to use same folder as Excel file)
OUTPUT_DIR <- r"D:\Repos\stars_processing_scripts\output"

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

sanitize_filename <- function(name) {
    """Replace characters invalid in filenames with underscores."""
    invalid_chars <- '[<>:"/\\|?*]'
    name <- gsub(invalid_chars, "_", name)
    return(trimws(name))
}

convert_excel_to_csv <- function(excel_path, output_dir = NULL, encoding = "UTF-8") {
    """
    Convert each sheet in an Excel file to a CSV file.
    CSV files are saved as '<sheet_name>.csv' in the output directory.
    """
    if (!file.exists(excel_path)) {
        stop(paste("Excel file not found:", excel_path))
    }
    
    # Determine output directory
    if (is.null(output_dir) || output_dir == "") {
        output_dir <- dirname(excel_path)
        if (output_dir == ".") output_dir <- getwd()
    }
    if (!dir.exists(output_dir)) {
        dir.create(output_dir, recursive = TRUE)
    }
    
    # Get sheet names
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
            # Read the sheet
            df <- read_excel(excel_path, sheet = sheet)
            
            # Create CSV filename from sheet name only
            safe_sheet <- sanitize_filename(sheet)
            csv_filename <- paste0(safe_sheet, ".csv")
            csv_path <- file.path(output_dir, csv_filename)
            
            # Write to CSV
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
        csv_files <- convert_excel_to_csv(EXCEL_FILE_PATH, OUTPUT_DIR, CSV_ENCODING)
        cat(paste("\nConversion complete. Generated", length(csv_files), "CSV file(s).\n"))
    }, error = function(e) {
        cat(paste("Error:", e$message, "\n"))
    })
}

# Run the script if executed directly
if (sys.nframe() == 0) {
    main()
}