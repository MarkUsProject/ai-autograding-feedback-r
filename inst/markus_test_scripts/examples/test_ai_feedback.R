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
tryCatch({
  source(helpers_path)
}, error = function(e) {
  stop(paste("Failed to load llm_helpers.R:", e$message))
})

# Test if functions are available
if (!exists("get_file_paths")) {
  stop("get_file_paths function not found after loading llm_helpers.R")
}

# Get file paths using helper function
file_paths <- get_file_paths()
submission_path <- file_paths$submission_path
prompt_path <- file_paths$prompt_path

# Global variable to store LLM feedback
llm_feedback <- NULL

test_that("Generates LLM feedback for code scope", {
  # Generate LLM feedback
  llm_feedback <<- generate_llm_feedback(submission_path, prompt_path)
  
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
