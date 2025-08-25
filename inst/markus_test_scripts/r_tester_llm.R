#!/usr/bin/env Rscript

.libPaths(c("/usr/local/lib/R/site-library", .libPaths()))
library(testthat)

source("llm_helpers.R")

if (file.exists(".env")) {
  try({
    if (requireNamespace("dotenv", quietly = TRUE)) dotenv::load_dot_env(".env")
  }, silent = TRUE)
}

code_prompt_path <- normalizePath("prompt.md", mustWork = TRUE)
if (!file.exists("submission.R")) {
  stop("submission.R must exist in the current directory for this MarkUs example.")
}
submission_r_path <- normalizePath("submission.R", mustWork = TRUE)

llm_feedback <- NULL

test_that("Generates LLM feedback for code scope", {
  prompt_content <- paste(readLines(code_prompt_path), collapse = "\n")
  
  llm_feedback <<- capture_main_output(
    prompt_custom = prompt_content,
    scope = "code",
    submission = submission_r_path,
    model = "claude"
  )
  
  if (is.null(llm_feedback) || llm_feedback == "") {
    fail("No valid LLM feedback generated")
  }
  
  expectation <- new_expectation(
    type = "success",
    message = ""
  )
  attr(expectation, "markus_overall_comments") <- llm_feedback
  exp_signal(expectation)
  
  succeed(message = llm_feedback)
})

test_that("Generates LLM Annotations", {
  if (is.null(llm_feedback) || llm_feedback == "") {
    fail("No LLM feedback available from previous test")
  }
  
  prompt_text <- paste0("Previous message: ", llm_feedback, ". ", ANNOTATION_PROMPT)
  
  raw_annotation <- capture_main_output(
    prompt_custom = prompt_text,
    scope = "code",
    submission = submission_r_path,
    model = "claude"
  )
  
  if (is.null(raw_annotation) || raw_annotation == "") {
    fail("No annotation response from model")
  }
  
  if (!grepl("\\}\\s*$", raw_annotation)) {
    fail(paste("JSON response appears to be truncated. Raw response:", raw_annotation))
  }
  
  annotations_json_list <- extract_json(raw_annotation)
  
  if (length(annotations_json_list) == 0) {
    fail(paste("Failed to parse JSON from annotation response. Raw response:", raw_annotation))
  }
  
  annotations <- NULL
  for (obj in annotations_json_list) {
    annotations <- obj$annotations
    break
  }
  
  if (is.null(annotations) || length(annotations) == 0) {
    fail("No annotations found in parsed JSON response")
  }
  
  annotations_with_columns <- add_annotation_columns(annotations, submission_r_path)
  
  for (annotation in annotations_with_columns) {
    filename <- annotation$filename
    content <- annotation$content
    line_start <- annotation$line_start
    line_end <- annotation$line_end
    column_start <- annotation$column_start
    column_end <- annotation$column_end
    
    rel_filename <- "submission.R"
    
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
  
  succeed(message = paste("Generated", length(annotations_with_columns), "annotations successfully"))
})
