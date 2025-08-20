#!/usr/bin/env Rscript

library(testthat)
library(jsonlite)

# Load environment variables
if (file.exists(".env")) {
  try({
    if (requireNamespace("dotenv", quietly = TRUE)) dotenv::load_dot_env(".env")
  }, silent = TRUE)
}

resolve_resource_path <- function(rel) {
  p2 <- rel
  if (file.exists(p2)) return(normalizePath(p2, mustWork = TRUE))
  p1 <- file.path("inst", rel)
  if (file.exists(p1)) return(normalizePath(p1, mustWork = TRUE))
  p <- system.file(rel, package = "aifeedbackr")
  if (nzchar(p) && file.exists(p)) return(p)
  stop("Resource not found: ", rel)
}

code_prompt_path <- normalizePath("prompt.md", mustWork = TRUE)
submission_r_path <- if (file.exists("submission.R")) {
  normalizePath("submission.R", mustWork = TRUE)
} else {
  resolve_resource_path("markus_test_scripts/examples/submission.R")
}

ANNOTATION_PROMPT <- "These are the student mistakes you previously identified in the last message. For each of the mistakes you identified, return a JSON object containing an array of annotations, referencing the student's submission file for line and column #s. Each annotation should include: filename: The name of the student's file. content: A short description of the mistake. line_start and line_end: The line number(s) where the mistake occurs. Ensure the JSON is valid and properly formatted. Here is a sample format of the json array to return: { \"annotations\": [{\"filename\": \"submission.R\", \"content\": \"Variable 'x' is unused.\", \"line_start\": 5, \"line_end\": 5}]}. ONLY return the json object and nothing else. Make sure the line #s don't exceed the number of lines in the file. You can use markdown syntax in the annotation's content, especially when denoting code."

# Initialize global variable for feedback
llm_feedback <- NULL

run_llm_with_subprocess <- function(
  submission,
  model,
  scope,
  output,
  prompt_custom = NULL,
  question = NULL,
  prompt_text = NULL,
  prompt = NULL
) {
  # Create a temporary R script to avoid complex shell escaping
  temp_script <- tempfile(fileext = ".R")
  
  # Build the R code to execute - use current environment and relative paths
  r_code <- paste0(
    "# Load environment variables from .env if exists\n",
    "if (file.exists('.env')) {\n",
    "  try({\n",
    "    if (requireNamespace('dotenv', quietly = TRUE)) dotenv::load_dot_env('.env')\n",
    "  }, silent = TRUE)\n",
    "}\n",
    "library(jsonlite)\n",
    "library(httr)\n",
    "# Try multiple library locations for aifeedbackr\n",
    "aifeedbackr_loaded <- FALSE\n",
    "lib_paths <- c('/usr/local/lib/R/site-library', .libPaths())\n",
    "for (lib_path in lib_paths) {\n",
    "  if (dir.exists(file.path(lib_path, 'aifeedbackr'))) {\n",
    "    tryCatch({\n",
    "      library(aifeedbackr, lib.loc = lib_path)\n",
    "      aifeedbackr_loaded <- TRUE\n",
    "      break\n",
    "    }, error = function(e) { })\n",
    "  }\n",
    "}\n",
    "if (!aifeedbackr_loaded) {\n",
    "  library(aifeedbackr)\n",
    "}\n",
    "result <- aifeedbackr:::main(\n",
    "  prompt_custom = ", if (!is.null(prompt)) {
      prompt_content <- paste(readLines(prompt), collapse = "\n")
      deparse(prompt_content)
    } else if (!is.null(prompt_text)) {
      deparse(prompt_text)
    } else "NULL", ",\n",
    "  scope = ", deparse(scope), ",\n",
    "  submission = ", deparse(submission), ",\n",
    "  model = ", deparse(model), ",\n",
    "  output = ", deparse(if (output == "stdout") "" else output), ",\n",
    "  question = ", if (!is.null(question)) deparse(question) else "NULL", "\n",
    ")\n",
    "cat(result$response)\n"
  )
  
  # Write the R code to temporary file
  writeLines(r_code, temp_script)
  
  # Execute the temporary script and capture both stdout and stderr
  cmd <- paste("Rscript", temp_script, "2>&1")
  result <- system(cmd, intern = TRUE)
  exit_status <- attr(result, "status")
  
  # Clean up
  unlink(temp_script)
  
  # Check if command failed
  if (!is.null(exit_status) && exit_status != 0) {
    error_msg <- paste("Rscript command failed with status", exit_status)
    if (length(result) > 0) {
      error_msg <- paste(error_msg, "Output:", paste(result, collapse = "\n"))
    }
    stop(error_msg)
  }
  
  if (length(result) == 0) {
    stop("No output from LLM command")
  }
  
  return(paste(result, collapse = "\n"))
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
    return(list())
  })
  
  annotations_with_columns <- list()
  
  for (annotation in annotations) {
    filename <- annotation$filename
    line_start <- annotation$line_start
    line_end <- annotation$line_end
    
    if (is.null(file_lines) || line_start > length(file_lines) || line_end > length(file_lines)) {
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

test_that("Generates LLM feedback for code scope", {
  llm_feedback <<- run_llm_with_subprocess(
    submission = submission_r_path,
    model = "claude",
    scope = "code",
    output = "stdout",
    prompt = code_prompt_path
  )
  
  expect_true(FALSE, info = llm_feedback)
  expectation <- new_expectation(
    type = "success",
    message = ""
  )
  attr(expectation, "markus_overall_comments") <- llm_feedback
  exp_signal(expectation)
})

test_that("Generates LLM Annotations", {
  if (is.null(llm_feedback) || llm_feedback == "") {
    expect_true(TRUE, info = "Skipping annotations test - no LLM feedback available from previous test")
    return()
  }
  
  prompt_text <- paste0("Previous message: ", llm_feedback, ". ", ANNOTATION_PROMPT)
  
  raw_annotation <- run_llm_with_subprocess(
    submission = submission_r_path,
    model = "claude", 
    scope = "code",
    output = "direct",
    prompt_text = prompt_text,
    prompt = NULL
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
      annotations_with_columns <- add_annotation_columns(annotations, submission_r_path)
      
      for (annotation in annotations_with_columns) {
        filename <- annotation$filename
        content <- annotation$content
        line_start <- annotation$line_start
        line_end <- annotation$line_end
        column_start <- annotation$column_start
        column_end <- annotation$column_end
        
        rel_filename <- basename(filename)
        
        expectation <- new_expectation(
          type = "success",
          message = ""
        )
        attr(expectation, "markus_annotation") <- list(
          filename = rel_filename,
          content = content,
          line_start = as.integer(line_start),
          line_end = as.integer(line_end),
          column_start = as.integer(column_start),
          column_end = as.integer(column_end)
        )
        exp_signal(expectation)
      }
      
      annotation_summary <- paste("Generated", length(annotations_with_columns), "annotations successfully")
      expect_true(TRUE, info = annotation_summary)
    } else {
      expect_true(TRUE, info = "No annotations generated")
    }
  } else {
    expect_true(TRUE, info = "Failed to parse annotation response")
  }
})
