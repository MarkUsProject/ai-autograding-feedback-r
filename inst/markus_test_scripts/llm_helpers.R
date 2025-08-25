library(jsonlite)
library(aifeedbackr)

ANNOTATION_PROMPT <- "These are the student mistakes you previously identified in the last message. For each of the mistakes you identified, return a JSON object containing an array of annotations, referencing the student's submission file for line and column #s. Each annotation should include: filename: The name of the student's file. content: A short description of the mistake. line_start and line_end: The line number(s) where the mistake occurs. Ensure the JSON is valid and properly formatted. Here is a sample format of the json array to return: { \"annotations\": [{\"filename\": \"submission.R\", \"content\": \"Variable 'x' is unused.\", \"line_start\": 5, \"line_end\": 5}]}. ONLY return the json object and nothing else. Make sure the line #s don't exceed the number of lines in the file. You can use markdown syntax in the annotation's content, especially when denoting code."

capture_main_output <- function(...) {
  output <- capture.output({
    aifeedbackr::main(...)
  })
  return(paste(output, collapse = "\n"))
}

extract_json <- function(response) {
  matches <- regmatches(response, gregexpr("\\{(?:[^{}]|(?:\\{(?:[^{}]|(?:\\{[^{}]*\\}))*\\}))*\\}", response, perl = TRUE))[[1]]
  
  json_objects <- list()
  for (match in matches) {
    parsed <- try(fromJSON(match, simplifyVector = FALSE), silent = TRUE)
    if (!inherits(parsed, "try-error")) {
      json_objects[[length(json_objects) + 1]] <- parsed
    }
  }
  
  return(json_objects)
}

add_annotation_columns <- function(annotations, submission_file_path) {
  tryCatch({
    file_lines <- readLines(submission_file_path, warn = FALSE)
  }, error = function(e) {
    cat("Error reading submission file:", e$message, "\n")
    return(list())
  })
  
  annotations_with_columns <- list()
  
  for (annotation in annotations) {
    filename <- annotation$filename
    line_start <- annotation$line_start
    line_end <- annotation$line_end
    
    if (is.null(line_start) || is.na(line_start) || 
        is.null(line_end) || is.na(line_end)) {
      cat("Skipping annotation with invalid line numbers: start =", line_start, ", end =", line_end, "\n")
      next
    }
    
    line_start <- as.numeric(line_start)
    line_end <- as.numeric(line_end)
    
    if (is.null(file_lines) || line_start > length(file_lines) || 
        line_end > length(file_lines) || line_start < 1 || line_end < 1) {
      cat("Skipping invalid line numbers for", filename, ":", line_start, "-", line_end, "\n")
      next
    }
    
    column_starts <- c()
    column_ends <- c()
    
    for (i in max(line_start, 1):min(line_end, length(file_lines))) {
      line <- file_lines[i]
      stripped_line <- sub("\n$", "", line)
      
      if (nzchar(trimws(stripped_line))) {
        start_col <- nchar(line) - nchar(sub("^\\s*", "", line))
        end_col <- nchar(stripped_line)
      } else {
        start_col <- 0
        end_col <- 1
      }
      
      column_starts <- c(column_starts, start_col)
      column_ends <- c(column_ends, end_col)
    }
    
    if (length(column_starts) > 0 && length(column_ends) > 0) {
      column_start <- min(column_starts)
      column_end <- max(column_ends)
    } else {
      column_start <- 0
      column_end <- 1
    }
    
    annotation$column_start <- column_start
    annotation$column_end <- column_end
    annotations_with_columns[[length(annotations_with_columns) + 1]] <- annotation
  }
  
  return(annotations_with_columns)
}
