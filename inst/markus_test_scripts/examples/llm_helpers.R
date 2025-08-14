# llm_helpers.R
# LLM helper functions for MarkUs R testing

library(httr)
library(jsonlite)

# Load environment variables
if (file.exists(".env")) {
  try({
    if (requireNamespace("dotenv", quietly = TRUE)) dotenv::load_dot_env(".env")
  }, silent = TRUE)
}

# Constants
ANNOTATION_PROMPT <- "These are the student mistakes you previously identified in the last message. For each of the mistakes you identified, return a JSON object containing an array of annotations, referencing the student's submission file for line and column #s. Each annotation should include: filename: The name of the student's file. content: A short description of the mistake. line_start and line_end: The line number(s) where the mistake occurs. Ensure the JSON is valid and properly formatted. Here is a sample format of the json array to return: { \"annotations\": [{\"filename\": \"submission.R\", \"content\": \"Variable 'x' is unused.\", \"line_start\": 5, \"line_end\": 5}]}. ONLY return the json object and nothing else. Make sure the line #s don't exceed the number of lines in the file. You can use markdown syntax in the annotation's content, especially when denoting code."

#' Get file paths for submission and prompt
#' @return List with submission_path and prompt_path
get_file_paths <- function() {
  # Both files are submitted through MarkUs, so they should be in current directory
  prompt_path <- normalizePath("prompt.md", mustWork = TRUE)
  submission_path <- normalizePath("submission.R", mustWork = TRUE)
  
  list(
    submission_path = submission_path,
    prompt_path = prompt_path
  )
}

#' Call Claude API for LLM feedback
#' @param submission Path to submission file
#' @param model Claude model to use
#' @param scope Scope of analysis (e.g., "code")
#' @param output Output format
#' @param prompt_custom Custom prompt flag
#' @param question Question text
#' @param prompt_text Custom prompt text
#' @param prompt Path to prompt file
#' @return LLM response text
run_llm <- function(
  submission,
  model,
  scope,
  output,
  prompt_custom = NULL,
  question = NULL,
  prompt_text = NULL,
  prompt = NULL
) {
  # Get Claude API key
  api_key <- Sys.getenv("CLAUDE_API_KEY")
  if (api_key == "") {
    stop("CLAUDE_API_KEY not set in environment variables")
  }
  
  # Build prompt content
  prompt_content <- ""
  if (!is.null(prompt)) {
    prompt_content <- paste(readLines(prompt), collapse = "\n")
  }
  if (!is.null(prompt_text)) {
    prompt_content <- paste0(prompt_content, prompt_text)
  }
  if (prompt_content == "") {
    stop("No prompt provided. Please specify a prompt file or text.")
  }
  
  # Read submission file
  submission_content <- paste(readLines(submission), collapse = "\n")
  
  # Combine prompt with submission
  full_prompt <- paste0(
    prompt_content, "\n\n",
    "File: ", basename(submission), "\n",
    submission_content
  )
  
  # Prepare API request
  body <- list(
    model = "claude-3-5-sonnet-20241022",
    max_tokens = 2000,
    temperature = 0.3,
    system = "You are an instructor evaluating student code.",
    messages = list(
      list(
        role = "user",
        content = full_prompt
      )
    )
  )
  
  # Make API call
  response <- POST(
    url = "https://api.anthropic.com/v1/messages",
    body = toJSON(body, auto_unbox = TRUE),
    add_headers(
      `x-api-key` = api_key,
      `content-type` = "application/json",
      `anthropic-version` = "2023-06-01"
    )
  )
  
  if (status_code(response) != 200) {
    error_content <- content(response, "text")
    stop(paste("Claude API call failed [HTTP", status_code(response), "]:", error_content))
  }
  
  # Parse response
  parsed <- content(response, "parsed")
  response_text <- parsed$content[[1]]$text
  
  return(response_text)
}

#' Extract JSON objects from LLM response
#' @param response Raw LLM response text
#' @return List of parsed JSON objects
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

#' Add column information to annotations for MarkUs display
#' @param annotations List of annotation objects
#' @param submission_file_path Path to submission file
#' @return List of annotations with column information added
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
    
    if (is.null(file_lines) || line_start > length(file_lines) || line_end > length(file_lines)) {
      cat("Skipping invalid line numbers for", filename, ":", line_start, "-", line_end, "\n")
      next
    }
    
    column_starts <- c()
    column_ends <- c()
    
    for (i in line_start:line_end) {
      if (i > length(file_lines)) next
      
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

#' Generate LLM feedback for code evaluation
#' @param submission_path Path to student submission
#' @param prompt_path Path to evaluation prompt
#' @return LLM feedback text
generate_llm_feedback <- function(submission_path, prompt_path) {
  run_llm(
    submission = submission_path,
    model = "claude-3.7-sonnet",
    scope = "code",
    output = "stdout",
    prompt = prompt_path
  )
}

#' Generate LLM annotations based on previous feedback
#' @param llm_feedback Previous LLM feedback text
#' @param submission_path Path to student submission
#' @return List of processed annotations
generate_llm_annotations <- function(llm_feedback, submission_path) {
  prompt_text <- paste0("Previous message: ", llm_feedback, ". ", ANNOTATION_PROMPT)
  
  raw_annotation <- run_llm(
    submission = submission_path,
    model = "claude-3.7-sonnet",
    scope = "code",
    output = "direct",
    prompt_text = prompt_text
  )
  
  annotations_json_list <- extract_json(raw_annotation)
  
  if (length(annotations_json_list) > 0) {
    annotations <- NULL
    for (obj in annotations_json_list) {
      if (!is.null(obj$annotations)) {
        annotations <- obj$annotations
        break
      }
    }
    
    if (!is.null(annotations) && length(annotations) > 0) {
      return(add_annotation_columns(annotations, submission_path))
    }
  }
  
  return(list())
}

#' Signal MarkUs annotation
#' @param annotation Single annotation object with all required fields
signal_markus_annotation <- function(annotation) {
  expectation <- new_expectation(
    type = "success",
    message = ""
  )
  attr(expectation, "markus_annotation") <- list(
    filename = basename(annotation$filename),
    content = annotation$content,
    line_start = as.integer(annotation$line_start),
    line_end = as.integer(annotation$line_end),
    column_start = as.integer(annotation$column_start),
    column_end = as.integer(annotation$column_end)
  )
  exp_signal(expectation)
}

#' Signal MarkUs overall comments
#' @param feedback LLM feedback text
signal_markus_overall_comments <- function(feedback) {
  expectation <- new_expectation(
    type = "success",
    message = ""
  )
  attr(expectation, "markus_overall_comments") <- feedback
  exp_signal(expectation)
}
