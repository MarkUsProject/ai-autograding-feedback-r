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

as_feedback_text <- function(x) {
  if (is.null(x)) return("")
  if (is.character(x)) return(paste(x, collapse = "\n"))
  if (is.list(x)) {
    if (!is.null(x$response)) {
      return(as_feedback_text(x$response))
    }
    if (length(x) >= 2 && is.list(x[[2]]) && !is.null(x[[2]]$response)) {
      return(as_feedback_text(x[[2]]$response))
    }
    return(paste(capture.output(str(x, max.level = 2)), collapse = "\n"))
  }
  paste(capture.output(str(x, max.level = 2)), collapse = "\n")
}

.state <- new.env(parent = emptyenv())
.state$llm_feedback_code <- ""

test_that("Generates LLM feedback for code scope", {
  raw <- main(
    submission = submission_r_path,
    scope = "code",
    model = "claude",
    prompt = code_prompt_path
  )
  feedback <- as_feedback_text(raw)
  .state$llm_feedback_code <- feedback

  if (nchar(feedback) == 0) {
    exp_signal(new_expectation(
      type = "failure",
      message = "LLM returned empty feedback for code scope.",
      markus_overall_comment = "[empty feedback]"
    ))
    fail("Empty feedback")
  } else {
    exp_signal(new_expectation(
      type = "success",
      message = "Posted LLM overall feedback for code scope.",
      markus_overall_comment = feedback
    ))
    succeed()
  }
})

test_that("Emits code annotations when present", {
  feedback <- .state$llm_feedback_code
  if (nchar(feedback) == 0) {
    exp_signal(new_expectation(
      type = "failure",
      message = "No prior feedback to extract annotations from.",
      markus_overall_comment = "No feedback captured in previous step."
    ))
    fail("No feedback for annotation extraction")
  } else {
    anns <- find_annotations_object(feedback)
    if (!length(anns)) {
      exp_signal(new_expectation(
        type = "success",
        message = "No annotations found in LLM output; skipping emission."
      ))
      succeed()
    } else {
      try(add_code_annotations(submission_r_path, feedback), silent = TRUE)
      exp_signal(new_expectation(
        type = "success",
        message = sprintf("Emitted %d code annotations.", length(anns))
      ))
      succeed()
    }
  }
})

test_that("Generates LLM feedback for Quarto (image scope)", {
  if (!file.exists(submission_qmd_path)) testthat::skip("No .qmd present; skipping image test")
  if (Sys.which("quarto") == "")        testthat::skip("quarto not available; skipping image test")

  raw <- main(
    submission = submission_qmd_path,
    scope = "image",
    model = "claude",
    prompt = image_prompt_path,
    solution = NULL
  )
  feedback <- as_feedback_text(raw)

  if (nchar(feedback) == 0) {
    exp_signal(new_expectation(
      type = "failure",
      message = "LLM returned empty feedback for image scope.",
      markus_overall_comment = "[empty feedback]"
    ))
    fail("Empty image-scope feedback")
  } else {
    exp_signal(new_expectation(
      type = "success",
      message = "Posted LLM overall feedback for image scope.",
      markus_overall_comment = feedback
    ))
    anns <- find_annotations_object(feedback)
    if (length(anns)) {
      try(add_image_annotations(basename(submission_qmd_path), feedback), silent = TRUE)
    }
    succeed()
  }
})
