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

# Default prompts for different scopes
DEFAULT_PROMPTS <- list(
  code_overall = paste(
    "Analyze the student's code submission and provide comprehensive feedback.",
    "Focus on:",
    "1. Correctness and functionality",
    "2. Code style and best practices", 
    "3. Logic and algorithm efficiency",
    "4. Error handling and edge cases",
    "5. Documentation and readability",
    "Provide specific, actionable feedback with examples where appropriate.",
    "{file_contents}",
    sep = "\n"
  ),
  
  image_overall = paste(
    "Analyze the student's image/plot submission and provide detailed feedback.",
    "Evaluate:",
    "1. Data visualization accuracy",
    "2. Chart/plot type appropriateness",
    "3. Axis labels, titles, and legends",
    "4. Color choices and aesthetics",
    "5. Overall clarity and readability",
    "Provide specific suggestions for improvement.",
    "{submission_image}",
    sep = "\n"
  ),
  
  text_overall = paste(
    "Analyze the student's text submission and provide comprehensive feedback.",
    "Focus on:",
    "1. Content accuracy and completeness",
    "2. Writing clarity and organization",
    "3. Use of appropriate terminology",
    "4. Supporting evidence and examples",
    "5. Overall coherence and flow",
    "Provide constructive feedback with specific suggestions.",
    "{file_contents}",
    sep = "\n"
  )
)

#' Run LLM analysis using the ai-autograding-feedback-r package
#'
#' @param model Model to use ("claude", "openai", etc.)
#' @param scope Analysis scope ("code", "image", "text")
#' @param output Output format ("stdout", "direct")
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
  output,
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
    # Use default prompts
    if (prompt %in% names(DEFAULT_PROMPTS)) {
      prompt_content <- DEFAULT_PROMPTS[[prompt]]
      cat("✓ Using default prompt:", prompt, "\n")
    } else {
      cat("⚠ Warning: Predefined prompt '", prompt, "' not found. Using fallback.\n")
      prompt_content <- DEFAULT_PROMPTS[[paste0(scope, "_overall")]] %||% 
                       "Analyze the student's submission and provide detailed feedback."
    }
  } else {
    # Use default prompt based on scope
    default_prompt_key <- paste0(scope, "_overall")
    prompt_content <- DEFAULT_PROMPTS[[default_prompt_key]] %||% 
                     "Analyze the student's submission and provide detailed feedback."
  }
  
  tryCatch({
    # Create args list for the processing functions
    args <- list(
      submission = submission_file %||% "student_submission.R",
      solution = solution_file,
      model = model,
      remote_model = "",
      question = question,
      test_output = NULL
    )
    
    # Call the appropriate processing function directly
    if (scope == "image") {
      result <- process_image(args, prompt_content, "", NULL)
      # For image processing, result is list(request_text, list(prompt, response))
      # We want the response part: result[[2]]$response
      return(result[[2]]$response)
    } else if (scope == "text") {
      result <- process_text(args, prompt_content, "", NULL)
      # For text processing, result is list(request_text, response)
      return(result[[2]])
    } else {
      result <- process_code(args, prompt_content, "", NULL)
      # For code processing, result is list(request_text, response)
      return(result[[2]])
    }
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
    output = "direct",
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

# Utility function for null coalescing
`%||%` <- function(x, y) if (is.null(x)) y else x
