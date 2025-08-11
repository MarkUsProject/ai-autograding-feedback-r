#!/usr/bin/env Rscript

library(testthat)
library(aifeedbackr)
library(knitr)
library(R6)
library(jsonlite)
library(httr)

resolve_resource_path <- function(rel) {
  p2 <- rel
  if (file.exists(p2)) return(normalizePath(p2, mustWork = TRUE))
  p1 <- file.path("inst", rel)
  if (file.exists(p1)) return(normalizePath(p1, mustWork = TRUE))
  p <- system.file(rel, package = "aifeedbackr")
  if (nzchar(p) && file.exists(p)) return(p)
  stop("Resource not found: ", rel)
}

code_prompt_path    <- resolve_resource_path("markus_test_scripts/examples/prompts/code_prompt.md")
image_prompt_path   <- resolve_resource_path("markus_test_scripts/examples/prompts/image_prompt.md")
submission_r_path   <- resolve_resource_path("markus_test_scripts/examples/submission.R")
submission_qmd_path <- resolve_resource_path("markus_test_scripts/examples/submission.qmd")
helpers_path        <- resolve_resource_path("markus_test_scripts/examples/llm_helpers.R")

suppressWarnings(try(source(submission_r_path), silent = TRUE))
source(helpers_path)

main <- get("main", envir = asNamespace("aifeedbackr"))

.state <- new.env(parent = emptyenv())
.state$llm_feedback_code <- NULL

test_that("Generates LLM feedback for code scope", {
  feedback <- main(
    submission = submission_r_path,
    scope = "code",
    model = "claude",
    prompt = code_prompt_path
  )
  .state$llm_feedback_code <- feedback

  exp_signal(new_expectation(
    type = "success",
    message = "",
    markus_overall_comments = feedback
  ))
  exp_signal(new_expectation(
    type = "success",
    message = substr(feedback, 1L, min(nchar(feedback), 3000L))
  ))
})

test_that("Generates LLM annotations for code scope", {
  if (is.null(.state$llm_feedback_code) || !nzchar(.state$llm_feedback_code)) {
    testthat::skip("No prior feedback to base annotations on.")
  }
  add_code_annotations(submission_r_path, .state$llm_feedback_code)
})

test_that("Generates LLM feedback for Quarto (image scope)", {
  if (!file.exists(submission_qmd_path)) testthat::skip("No .qmd present; skipping image test")
  if (Sys.which("quarto") == "")        testthat::skip("quarto not available; skipping image test")

  feedback <- main(
    submission = submission_qmd_path,
    scope = "image",
    model = "claude",
    prompt = image_prompt_path,
    solution = NULL
  )

  exp_signal(new_expectation(
    type = "success",
    message = "",
    markus_overall_comments = feedback
  ))

  add_image_annotations(basename(submission_qmd_path), feedback)
})
