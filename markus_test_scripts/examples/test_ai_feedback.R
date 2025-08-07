#!/usr/bin/env Rscript

# Load the student's submission
source("submission.R")

library(testthat)
library(aifeedbackr)

test_that("AI feedback using prompt file", {
  # Use a prompt file (like the library normally handles)
  feedback <- main(
    submission = "submission.R",
    scope = "code", 
    model = "claude",
    prompt = "prompts/code_prompt.md"
  )
  
  # Basic test that feedback was generated
  expect_true(is.character(feedback))
  expect_true(nchar(feedback) > 0)
})

test_that("AI feedback with MarkUs metadata using prompt file", {
  # Generate AI feedback using prompt file
  feedback <- main(
    submission = "submission.R",
    scope = "code",
    model = "claude", 
    prompt = "prompts/code_prompt.md"
  )
  
  # Use MarkUs metadata pattern from official examples
  exp_signal(new_expectation(
    type = "success",
    message = "",
    markus_overall_comments = feedback,
    markus_tag = "needs_improvement",
    markus_annotation = list(
      filename = "submission.R",
      content = "Check logic error in comparison operator",
      line_start = 26,
      line_end = 26,
      column_start = 1,
      column_end = 50
    )
  ))
})

test_that("AI feedback with custom prompt", {
  # Demonstrate custom prompt alongside prompt files
  custom_prompt <- paste(
    "Review this R code focusing on:",
    "1. Syntax correctness and best practices",
    "2. Logic errors and algorithm efficiency", 
    "3. Code style and readability improvements",
    "4. Missing error handling or edge cases",
    "Provide specific line-by-line feedback where appropriate.",
    sep = "\n"
  )
  
  feedback <- main(
    submission = "submission.R",
    scope = "code",
    model = "claude",
    prompt_custom = custom_prompt
  )
  
  expect_true(is.character(feedback))
  expect_true(nchar(feedback) > 0)
  
  # MarkUs metadata for custom prompt analysis
  exp_signal(new_expectation(
    type = "success", 
    message = "",
    markus_overall_comments = feedback,
    markus_tag = "good",
    markus_annotation = list(
      filename = "submission.R",
      content = "Consider using vectorized operations instead of loops",
      line_start = 12,
      line_end = 15,
      column_start = 1,
      column_end = 20
    )
  ))
})

test_that("AI feedback for Quarto document using prompt file", {
  library(knitr)
  
  # Generate AI feedback for QMD file using prompt file
  feedback <- main(
    submission = "submission.qmd",
    scope = "image",
    model = "claude",
    prompt = "prompts/image_prompt.md"
  )
  
  expect_true(is.character(feedback))
  expect_true(nchar(feedback) > 0)
})
