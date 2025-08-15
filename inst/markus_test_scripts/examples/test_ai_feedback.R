#!/usr/bin/env Rscript

# Load required libraries
library(testthat)

# First, we need to define resolve_resource_path to find llm_helpers.R
resolve_resource_path <- function(rel) {
  p2 <- rel
  if (file.exists(p2)) return(normalizePath(p2, mustWork = TRUE))
  p1 <- file.path("inst", rel)
  if (file.exists(p1)) return(normalizePath(p1, mustWork = TRUE))
  p <- system.file(rel, package = "aifeedbackr")
  if (nzchar(p) && file.exists(p)) return(p)
  stop("Resource not found: ", rel)
}

# Load helpers and handle any errors
helpers_path <- resolve_resource_path("markus_test_scripts/examples/llm_helpers.R")

# Try to source with more detailed error handling
tryCatch({
  source(helpers_path)
}, error = function(e) {
  stop(paste("Failed to load llm_helpers.R from", helpers_path, "Error:", e$message))
})

# Check what functions are actually available after loading
available_functions <- ls(envir = .GlobalEnv)
if (!"get_file_paths" %in% available_functions) {
  stop(paste("get_file_paths function not found. Available functions:", paste(available_functions, collapse = ", ")))
}

# If we get here, the function should exist
file_paths <- get_file_paths()
submission_path <- file_paths$submission_path
prompt_path <- file_paths$prompt_path

# Global variable to store LLM feedback
llm_feedback <- NULL

test_that("Generates LLM feedback for code scope", {
  # Generate LLM feedback
  llm_feedback <<- generate_llm_feedback(submission_path, prompt_path)
  
  # Strategy: Intentionally fail the test to display LLM feedback in test details
  # This is required because R's testthat framework only shows messages for failed tests
  expect_true(FALSE, info = llm_feedback)
  
  # Signal MarkUs overall comments (separate metadata expectation)
  signal_markus_overall_comments(llm_feedback)
})

test_that("Generates LLM Annotations", {
  # Generate annotations based on previous feedback
  annotations <- generate_llm_annotations(llm_feedback, submission_path)
  
  if (length(annotations) > 0) {
    # Signal each annotation to MarkUs
    for (annotation in annotations) {
      signal_markus_annotation(annotation)
    }
    
    # Create success message for this test
    annotation_summary <- paste("Generated", length(annotations), "annotations successfully")
    expect_true(TRUE, info = annotation_summary)
  } else {
    expect_true(TRUE, info = "No annotations generated")
  }
})
