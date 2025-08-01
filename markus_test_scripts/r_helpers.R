#!/usr/bin/env Rscript

# r_helpers.R - Core helper functions for RScript-based Markus testers
# This file provides R equivalents of the Python llm_helpers.py functionality
# NOTE: The ai-autograding-feedback-r package should be loaded before sourcing this file

suppressWarnings(suppressMessages({
  library(jsonlite)
  library(testthat)
}))

# Global constants
ANNOTATION_PROMPT <- "These are the student mistakes you previously identified in the
last message. For each of the mistakes you identified, return a JSON object containing
an array of annotations, referencing the student's submission file for line and column #s.
Each annotation should include: filename: The name of the student's file. content:
A short description of the mistake. line_start and line_end: The line number(s) where the
mistake occurs. Ensure the JSON is valid and properly formatted. Here is a sample format
of the json array to return: { \"annotations\": [{\"filename\": \"student_code.R\",
\"content\": \"Variable 'x' is unused.\", \"line_start\": 5, \"line_end\": 5}]}.
ONLY return the json object and nothing else. Make sure the line #s don't exceed
the number of lines in the file. You can use markdown syntax in the annotation's content,
especially when denoting code."

MINIMUM_ANNOTATION_WIDTH <- 8

#' Read prompt from file
#'
#' @param prompt_name Name of the prompt file (without extension)
#' @param prompts_dir Directory containing prompt files
#' @return String containing prompt content or NULL if file not found
read_prompt_from_file <- function(prompt_name, prompts_dir = "examples/prompts") {
  # All prompts are in markdown format
  prompt_file <- file.path(prompts_dir, paste0(prompt_name, ".md"))
  if (file.exists(prompt_file)) {
    return(paste(readLines(prompt_file, warn = FALSE), collapse = "\n"))
  }
  return(NULL)
}

#' Run LLM analysis using the ai-autograding-feedback-r package
#'
#' @param model Model to use ("claude", "openai", etc.)
#' @param scope Analysis scope ("code", "image", "text")
#' @param prompt_custom Custom prompt text
#' @param question Optional question context
#' @param prompt_text Prompt text to use
#' @param prompt Prompt key for default prompts
#' @param submission_file Path to submission file
#' @param solution_file Path to solution file (optional)
#' @return String containing LLM response
run_llm_r <- function(
  model, 
  scope,
  prompt_custom = NULL,
  question = NULL,
  prompt_text = NULL,
  prompt = NULL,
  submission_file = NULL,
  solution_file = NULL
) {
  # Handle prompt selection
  if (!is.null(prompt_custom)) {
    prompt_content <- prompt_custom
  } else if (!is.null(prompt_text)) {
    prompt_content <- prompt_text
  } else if (!is.null(prompt)) {
    prompt_content <- read_prompt_from_file(prompt)
    if (is.null(prompt_content)) {
      stop(paste("Prompt file not found:", prompt, ". Please ensure the prompt file exists in examples/prompts/"))
    }
  } else {
    default_prompt_key <- paste0(scope, "_prompt")
    prompt_content <- read_prompt_from_file(default_prompt_key)
    
    if (is.null(prompt_content)) {
      stop(paste("Prompt file not found:", default_prompt_key, ". Please ensure the prompt file exists in examples/prompts/"))
    }
  }
  
  tryCatch({
    # Prepare arguments list for main function
    args <- list(
      prompt_custom = prompt_content,
      scope = scope,
      submission = submission_file %||% "student_submission.R",
      solution = solution_file %||% "",
      model = model,
      remote_model = "",
      question = question
    )
    
    pkg_env <- as.environment("package:aifeedbackr")
    if (exists("main", envir = pkg_env)) {
      main_fn <- get("main", envir = pkg_env)
    } else {
      # Fallback: search in loaded namespaces
      main_fn <- get("main", envir = asNamespace("aifeedbackr"))
    }
    
    output <- capture.output(do.call(main_fn, args))
    
    result_text <- paste(output, collapse = "\n")
    return(result_text)
  }, error = function(e) {
    return(paste("Error calling LLM API:", e$message))
  })
}

#' Extract JSON objects from a string response
#'
#' @param response String potentially containing JSON objects
#' @return List of parsed JSON objects
extract_json_r <- function(response) {
  # Find JSON objects in the response using regex
  json_pattern <- "\\{(?:[^{}]|(?:\\{(?:[^{}]|(?:\\{[^{}]*\\}))*\\}))*\\}"
  matches <- regmatches(response, gregexpr(json_pattern, response, perl = TRUE))[[1]]
  
  json_objects <- list()
  for (match in matches) {
    tryCatch({
      json_obj <- fromJSON(match)
      json_objects <- append(json_objects, list(json_obj))
    }, error = function(e) {
      # Skip invalid JSON
    })
  }
  
  return(json_objects)
}

#' Add column information to annotations based on file content
#'
#' @param annotations List of annotation objects
#' @param submission_file Path to the submission file
#' @return List of annotations with column information added
add_annotation_columns_r <- function(annotations, submission_file = "student_submission.R") {
  if (!file.exists(submission_file)) {
    cat("Error reading submission file:", submission_file, "\n")
    return(list())
  }
  
  file_lines <- readLines(submission_file, warn = FALSE)
  annotations_with_columns <- list()
  
  for (annotation in annotations) {
    filename <- annotation$filename
    line_start <- as.numeric(annotation$line_start)
    line_end <- as.numeric(annotation$line_end)
    
    if (length(file_lines) == 0 || line_start > length(file_lines) || line_end > length(file_lines)) {
      cat("Skipping invalid line numbers for", filename, ":", line_start, "-", line_end, "\n")
      next
    }
    
    column_starts <- c()
    column_ends <- c()
    
    for (i in line_start:line_end) {
      if (i > length(file_lines)) next
      
      line <- file_lines[i]
      stripped_line <- trimws(line, which = "right")
      
      if (nchar(trimws(stripped_line)) > 0) {
        start_col <- nchar(line) - nchar(trimws(line, which = "left"))
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
    annotations_with_columns <- append(annotations_with_columns, list(annotation))
  }
  
  return(annotations_with_columns)
}

#' Add Markus message marker (R equivalent of pytest.mark.markus_message)
#'
#' @param message Message content to add
add_markus_message <- function(message) {
  cat("MARKUS_MESSAGE:", message, "\n")
}

#' Add Markus overall comments marker (R equivalent of pytest.mark.markus_overall_comments)
#'
#' @param comments Comments content to add
add_markus_overall_comments <- function(comments) {
  cat("MARKUS_OVERALL_COMMENTS:", comments, "\n")
}

#' Add Markus annotation marker (R equivalent of pytest.mark.markus_annotation)
#'
#' @param filename Filename for the annotation
#' @param content Annotation content
#' @param line_start Starting line number
#' @param line_end Ending line number
#' @param column_start Starting column number
#' @param column_end Ending column number
add_markus_annotation <- function(filename, content, line_start, line_end, column_start, column_end) {
  # Convert to relative path
  rel_filename <- basename(filename)
  
  annotation_json <- toJSON(list(
    filename = rel_filename,
    content = content,
    line_start = line_start,
    line_end = line_end,
    column_start = column_start,
    column_end = column_end
  ), auto_unbox = TRUE)
  
  cat("MARKUS_ANNOTATION:", annotation_json, "\n")
}

#' Generate annotations from LLM feedback
#'
#' @param llm_feedback Previous LLM feedback message
#' @param model Model to use for annotation generation
#' @param submission_file Path to submission file
#' @return List of annotations with column information
generate_annotations_r <- function(llm_feedback, model = "claude", submission_file = "student_submission.R") {
  # Create annotation prompt
  prompt <- paste("Previous message:", llm_feedback, ".", ANNOTATION_PROMPT)
  
  # Generate annotations using LLM
  raw_annotation <- run_llm_r(
    model = model,
    prompt_text = prompt,
    scope = "code",
    submission_file = submission_file
  )
  
  # Extract JSON annotations
  annotations_json_list <- extract_json_r(raw_annotation)
  
  if (length(annotations_json_list) > 0 && "annotations" %in% names(annotations_json_list[[1]])) {
    annotations <- annotations_json_list[[1]]$annotations
    # Add column information
    annotations_with_columns <- add_annotation_columns_r(annotations, submission_file)
    return(annotations_with_columns)
  }
  
  return(list())
}

#' Generate MarkUs metadata attributes (following the Python tester PR pattern)
#'
#' @param type Test result type ("success", "failure", "warning")
#' @param message Optional message
#' @param overall_comments Overall feedback comments
#' @param tag Tag for categorizing the result ("good", "needs_improvement", "excellent")
#' @param annotations List of annotation objects
#' @return JSON string with MarkUs metadata
generate_markus_metadata <- function(type = "success", message = "", overall_comments = "", tag = "good", annotations = list()) {
  metadata <- list(
    type = type,
    message = message,
    markus_overall_comments = overall_comments,
    markus_tag = tag,
    markus_annotation = annotations
  )
  
  return(toJSON(metadata, auto_unbox = TRUE))
}

#' Create a MarkUs annotation object
#'
#' @param filename Name of the file being annotated
#' @param content Annotation content/message
#' @param line_start Starting line number
#' @param line_end Ending line number  
#' @param column_start Starting column number
#' @param column_end Ending column number
#' @return List representing an annotation
create_markus_annotation <- function(filename, content, line_start, line_end, column_start = 1, column_end = 1) {
  return(list(
    filename = filename,
    content = content,
    line_start = line_start,
    line_end = line_end,
    column_start = column_start,
    column_end = column_end
  ))
}

#' Output MarkUs metadata in the expected format
#'
#' @param metadata_json JSON string with MarkUs metadata
output_markus_metadata <- function(metadata_json) {
  cat("MARKUS_METADATA:", metadata_json, "\n")
}

# Utility function for null coalescing
`%||%` <- function(x, y) {
  if (is.null(x)) {
    return(y)
  } else {
    return(x)
  }
}
