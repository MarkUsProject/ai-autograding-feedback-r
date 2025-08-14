#!/usr/bin/env Rscript

# Load required libraries
library(testthat)

# Source helper functions
source("llm_helpers.R")

# Get file paths
file_paths <- get_file_paths()
submission_path <- file_paths$submission_path
prompt_path <- file_paths$prompt_path

# Global variable to store LLM feedback
llm_feedback <- NULL

test_that("Generates LLM feedback for code scope", {
  # Generate LLM feedback
  llm_feedback <<- generate_llm_feedback(submission_path, prompt_path)
  
  expect_true(FALSE, info = llm_feedback)
  
  signal_markus_overall_comments(llm_feedback)
})

test_that("Generates LLM Annotations", {
  annotations <- generate_llm_annotations(llm_feedback, submission_path)
  
  if (length(annotations) > 0) {
    for (annotation in annotations) {
      signal_markus_annotation(annotation)
    }
    
    annotation_summary <- paste("Generated", length(annotations), "annotations successfully")
    expect_true(TRUE, info = annotation_summary)
  } else {
    expect_true(TRUE, info = "No annotations generated")
  }
})
