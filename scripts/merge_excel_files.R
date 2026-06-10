#!/usr/bin/env Rscript

# Multi-file Excel to CSV Merger
# Scans xlsx_source/ for all .xlsx files, merges sheets by name across files

# Run in Terminal
# Rscript scripts/merge_excel_files.R

# ============================================================
# USER SETTINGS - EDIT THESE BEFORE RUNNING
# ============================================================

# Folder containing Excel files (relative to project root)
SOURCE_FOLDER <- "xlsx_source"

# Output directory for CSV files
OUTPUT_DIR <- "csvdata"

# Log file for tracking merges
LOG_FILE <- file.path(OUTPUT_DIR, ".merge_log.json")

# CSV encoding
CSV_ENCODING <- "UTF-8"

# ============================================================
# SCRIPT STARTS HERE - DON'T EDIT BELOW UNLESS YOU KNOW WHAT YOU'RE DOING
# ============================================================

# Load required libraries
if (!require("readxl", quietly = TRUE)) {
  install.packages("readxl")
  library(readxl)
}

if (!require("jsonlite", quietly = TRUE)) {
  install.packages("jsonlite")
  library(jsonlite)
}

if (!require("digest", quietly = TRUE)) {
  install.packages("digest")
  library(digest)
}

if (!require("dplyr", quietly = TRUE)) {
  install.packages("dplyr")
  library(dplyr)
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
  if (file.exists(candidate) || grepl("\\.xlsx?$|/", relative_path)) {
    return(candidate)
  }
  return(candidate)
}

# Convert user settings to absolute paths
SOURCE_FOLDER <- resolve_path(SOURCE_FOLDER)
OUTPUT_DIR <- resolve_path(OUTPUT_DIR)
LOG_FILE <- resolve_path(LOG_FILE)

# Create output directory if it doesn't exist
if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR, recursive = TRUE)
}

# Function to get file hash
get_file_hash <- function(file_path) {
  if (!file.exists(file_path)) {
    return(NULL)
  }
  info <- file.info(file_path)
  mod_time <- as.character(info$mtime)
  size <- info$size
  
  tryCatch({
    sheet_names <- excel_sheets(file_path)
    first_sheet <- sheet_names[1]
    sample_data <- read_excel(file_path, sheet = first_sheet, n_max = 100)
    sample_hash <- digest(sample_data, algo = "md5")
  }, error = function(e) {
    sample_hash <- "error_reading"
  })
  
  combined <- paste(mod_time, size, sample_hash, file_path)
  return(digest(combined, algo = "md5"))
}

# Function to read log file
read_log <- function() {
  if (file.exists(LOG_FILE)) {
    return(fromJSON(LOG_FILE, simplifyVector = FALSE))
  }
  return(list(
    last_run = NULL,
    files_processed = list(),
    merged_sheets = list()
  ))
}

# Function to write log file
write_log <- function(log_data) {
  log_data$last_run <- as.character(Sys.time())
  write_json(log_data, LOG_FILE, pretty = TRUE, auto_unbox = TRUE)
}

# Function to scan Excel files
scan_excel_files <- function() {
  excel_files <- list.files(SOURCE_FOLDER, pattern = "\\.xlsx$", full.names = TRUE, ignore.case = TRUE)
  if (length(excel_files) == 0) {
    cat("No Excel files found in", SOURCE_FOLDER, "\n")
    return(NULL)
  }
  
  cat("Scanning", SOURCE_FOLDER, "...\n")
  cat("  Found", length(excel_files), "Excel files:\n")
  
  file_info <- list()
  all_sheets <- list()
  
  for (f in excel_files) {
    file_name <- basename(f)
    sheets <- excel_sheets(f)
    file_info[[file_name]] <- list(
      path = f,
      sheets = sheets,
      sheet_count = length(sheets),
      hash = get_file_hash(f)
    )
    cat("    -", file_name, "(", length(sheets), "sheets)\n")
    
    for (sheet in sheets) {
      if (!sheet %in% names(all_sheets)) {
        all_sheets[[sheet]] <- list()
      }
      all_sheets[[sheet]] <- c(all_sheets[[sheet]], file_name)
    }
  }
  
  return(list(files = file_info, sheets = all_sheets))
}

# Function to display sheet inventory
display_sheet_inventory <- function(sheets_info, files_info, total_files) {
  sheet_names <- names(sheets_info)
  if (length(sheet_names) == 0) {
    cat("No sheets found.\n")
    return()
  }
  
  cat("\nSheet inventory:\n")
  all_file_names <- names(files_info)
  
  for (i in seq_along(sheet_names)) {
    sheet <- sheet_names[i]
    file_count <- length(sheets_info[[sheet]])
    missing_count <- total_files - file_count
    
    if (missing_count == 0) {
      cat(i, ".", sheet, ".............", file_count, "files\n")
    } else {
      present_files <- sheets_info[[sheet]]
      missing_files <- setdiff(all_file_names, present_files)
      cat(i, ".", sheet, ".............", file_count, "files (missing in", 
          paste(missing_files, collapse = ", "), ")\n")
    }
  }
}

# Function to check column consistency
check_columns <- function(df_list, file_names) {
  col_sets <- lapply(df_list, names)
  first_cols <- col_sets[[1]]
  all_identical <- all(sapply(col_sets, function(x) identical(x, first_cols)))
  
  if (all_identical) {
    return(list(consistent = TRUE, union_cols = first_cols, common_cols = first_cols))
  }
  
  union_cols <- unique(unlist(col_sets))
  common_cols <- Reduce(intersect, col_sets)
  
  differences <- list()
  for (i in seq_along(df_list)) {
    extra <- setdiff(col_sets[[i]], common_cols)
    if (length(extra) > 0) {
      differences[[file_names[i]]] <- extra
    }
  }
  
  return(list(
    consistent = FALSE,
    union_cols = union_cols,
    common_cols = common_cols,
    differences = differences
  ))
}

# Function to handle column mismatch
handle_column_mismatch <- function(sheet_name, col_check, file_names) {
  cat("\nColumn mismatch detected for sheet '", sheet_name, "':\n", sep = "")
  for (file in names(col_check$differences)) {
    cat("  ", file, "has extra columns:", 
        paste(col_check$differences[[file]], collapse = ", "), "\n")
  }
  cat("\nOptions:\n")
  cat("  A) Keep all columns (fill missing with NA)\n")
  cat("  B) Use only common columns (drop extras)\n")
  cat("  C) Abort this sheet\n")
  
  repeat {
    choice <- readline(prompt = "Your choice (A/B/C): ")
    choice <- toupper(trimws(choice))
    if (choice %in% c("A", "B", "C")) {
      return(choice)
    }
    cat("Invalid choice. Please enter A, B, or C.\n")
  }
}

# Function to merge dataframes
merge_dataframes <- function(df_list, file_names, sheet_name, col_choice, add_source_col = TRUE) {
  if (col_choice == "B") {
    common_cols <- Reduce(intersect, lapply(df_list, names))
    df_list <- lapply(df_list, function(df) df[, common_cols, drop = FALSE])
    cat("  Using only common columns:", paste(common_cols, collapse = ", "), "\n")
  } else if (col_choice == "A") {
    all_cols <- unique(unlist(lapply(df_list, names)))
    cat("  Keeping all columns. Total columns:", length(all_cols), "\n")
  }
  
  if (add_source_col) {
    for (i in seq_along(df_list)) {
      df_list[[i]]$source_file <- file_names[i]
    }
  }
  
  merged <- bind_rows(df_list)
  return(merged)
}

# Function to process a single sheet
process_sheet <- function(sheet_name, files_info, sheet_files, log_data, total_files, add_source_col = TRUE) {
  cat("\nProcessing", sheet_name, "...\n")
  
  file_list <- sheet_files[[sheet_name]]
  cat("  Found in", length(file_list), "of", total_files, "files.\n")
  
  if (sheet_name %in% names(log_data$merged_sheets)) {
    existing <- log_data$merged_sheets[[sheet_name]]
    if (setequal(existing$files_merged, file_list)) {
      current_hashes <- sapply(file_list, function(f) files_info[[f]]$hash)
      previous_hashes <- existing$file_hashes
      if (identical(current_hashes, previous_hashes)) {
        cat("  Already up to date. Skipping.\n")
        return(NULL)
      } else {
        cat("  Files have changed. Re-merging.\n")
      }
    }
  }
  
  df_list <- list()
  valid_files <- c()
  
  for (file_name in file_list) {
    file_path <- files_info[[file_name]]$path
    tryCatch({
      df <- read_excel(file_path, sheet = sheet_name)
      df_list[[length(df_list) + 1]] <- df
      valid_files <- c(valid_files, file_name)
      cat("    Read from", file_name, "(", nrow(df), "rows)\n")
    }, error = function(e) {
      cat("    ERROR reading", file_name, ":", e$message, "- skipping this file\n")
    })
  }
  
  if (length(df_list) == 0) {
    cat("  No valid data found. Skipping.\n")
    return(NULL)
  }
  
  col_check <- check_columns(df_list, valid_files)
  
  if (!col_check$consistent) {
    col_choice <- handle_column_mismatch(sheet_name, col_check, valid_files)
    if (col_choice == "C") {
      cat("  Aborting sheet", sheet_name, "\n")
      return(NULL)
    }
  } else {
    col_choice <- "A"
  }
  
  merged_df <- merge_dataframes(df_list, valid_files, sheet_name, col_choice, add_source_col)
  
  output_path <- file.path(OUTPUT_DIR, paste0(sheet_name, ".csv"))
  write.csv(merged_df, output_path, row.names = FALSE, fileEncoding = CSV_ENCODING)
  
  log_data$merged_sheets[[sheet_name]] <- list(
    files_merged = valid_files,
    file_hashes = sapply(valid_files, function(f) files_info[[f]]$hash),
    row_count = nrow(merged_df),
    last_merged = as.character(Sys.time())
  )
  
  cat("  Created:", basename(output_path), "(", nrow(merged_df), "rows)\n")
  
  return(log_data)
}

# Main execution
main <- function() {
  if (!dir.exists(SOURCE_FOLDER)) {
    cat("ERROR: Source folder not found:", SOURCE_FOLDER, "\n")
    cat("Please create the folder and add Excel files.\n")
    return()
  }
  
  cat(paste("Project root:", project_root, "\n"))
  cat(paste("Source folder:", SOURCE_FOLDER, "\n"))
  cat(paste("Output folder:", OUTPUT_DIR, "\n\n"))
  
  scan_result <- scan_excel_files()
  if (is.null(scan_result)) {
    return()
  }
  
  files_info <- scan_result$files
  sheets_info <- scan_result$sheets
  total_files <- length(files_info)
  
  repeat {
    response <- readline(prompt = "\nDo you want to do a sheet inventory (Y) or abort (N)? ")
    response <- toupper(trimws(response))
    if (response == "Y") {
      display_sheet_inventory(sheets_info, files_info, total_files)
      break
    } else if (response == "N") {
      cat("Aborted.\n")
      return()
    } else {
      cat("Invalid choice. Please enter Y or N.\n")
    }
  }
  
  repeat {
    response <- readline(prompt = "\nDo you want to proceed to merging files (Y) or abort (N)? ")
    response <- toupper(trimws(response))
    if (response == "Y") {
      break
    } else if (response == "N") {
      cat("Aborted.\n")
      return()
    } else {
      cat("Invalid choice. Please enter Y or N.\n")
    }
  }
  
  log_data <- read_log()
  sheet_names <- names(sheets_info)
  
  while (TRUE) {
    cat("\n")
    response <- readline(prompt = "Do you want to proceed to merging files (Y) or abort (N)? ")
    response <- toupper(trimws(response))
    
    if (response == "N") {
      cat("Exiting.\n")
      write_log(log_data)
      break
    } else if (response != "Y") {
      cat("Invalid choice. Please enter Y or N.\n")
      next
    }
    
    cat("\nAvailable sheets:\n")
    for (i in seq_along(sheet_names)) {
      cat(i, ".", sheet_names[i], "\n")
    }
    
    sheet_num_str <- readline(prompt = "\nWhich number sheet do you want to work on? ")
    sheet_num <- suppressWarnings(as.integer(trimws(sheet_num_str)))
    
    if (is.na(sheet_num) || sheet_num < 1 || sheet_num > length(sheet_names)) {
      cat("Invalid sheet number. Please enter a number between 1 and", length(sheet_names), "\n")
      next
    }
    
    sheet_name <- sheet_names[sheet_num]
    new_log <- process_sheet(sheet_name, files_info, sheets_info, log_data, total_files, add_source_col = TRUE)
    
    if (!is.null(new_log)) {
      log_data <- new_log
      write_log(log_data)
    }
  }
}

if (sys.nframe() == 0) {
  main()
}