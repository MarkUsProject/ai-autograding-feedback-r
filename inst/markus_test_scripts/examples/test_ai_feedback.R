#!/usr/bin/env Rscript

source("submission.R")

library(testthat)
library(aifeedbackr)
library(knitr)
library(R6)

main <- get("main", envir = asNamespace("aifeedbackr"))

{
  ns <- asNamespace("aifeedbackr")
  MockModel <- R6::R6Class("MockModel",
    public = list(
      initialize = function(...) {},
      generate_response = function(prompt, system_instructions, submission_images = NULL, solution_image = NULL) {
        list(prompt = prompt, response = "Mock feedback: analysis complete.")
      }
    )
  )
  if (bindingIsLocked("model_mapping", ns)) unlockBinding("model_mapping", ns)
  assign("model_mapping", list(openai = MockModel, claude = MockModel, remote = MockModel), envir = ns)
  lockBinding("model_mapping", ns)
}

resolve_prompt_path <- function(...) {
  pkg_path <- system.file(..., package = "aifeedbackr")
  if (nzchar(pkg_path) && file.exists(pkg_path)) {
    return(pkg_path)
  }
  local_path <- file.path("inst", "markus_test_scripts", "examples", "prompts", basename(..1))
  if (file.exists(local_path)) {
    return(local_path)
  }
  local_path2 <- file.path("markus_test_scripts", "examples", "prompts", basename(..1))
  if (file.exists(local_path2)) {
    return(local_path2)
  }
  stop(paste("Prompt file not found:", ..1))
}

code_prompt_path <- resolve_prompt_path("markus_test_scripts/examples/prompts/code_prompt.md")
image_prompt_path <- resolve_prompt_path("markus_test_scripts/examples/prompts/image_prompt.md")

test_that("AI feedback using prompt file", {
  feedback <- main(
    submission = "submission.R",
    scope = "code", 
    model = "claude",
    prompt = code_prompt_path
  )
  expect_true(is.character(feedback))
  expect_true(nchar(feedback) > 0)
})

test_that("AI feedback with MarkUs metadata using prompt file", {
  feedback <- main(
    submission = "submission.R",
    scope = "code",
    model = "claude", 
    prompt = code_prompt_path
  )
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
  feedback <- main(
    submission = "submission.qmd",
    scope = "image",
    model = "claude",
    prompt = image_prompt_path,
    solution = NULL
  )
  expect_true(is.character(feedback))
  expect_true(nchar(feedback) > 0)
})
