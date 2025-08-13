#!/usr/bin/env Rscript

library(testthat)
library(aifeedbackr)
library(knitr)
library(R6)
library(jsonlite)
library(httr)

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

code_prompt_path    <- normalizePath("prompt.md", mustWork = TRUE)
submission_r_path   <- resolve_resource_path("markus_test_scripts/examples/submission.R")
helpers_path        <- resolve_resource_path("markus_test_scripts/examples/llm_helpers.R")

# Load submission file and helpers
suppressWarnings(try(source(submission_r_path), silent = TRUE))
source(helpers_path)

# Define %||% if not already defined
if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

# Get the main function from aifeedbackr package
main <- get("main", envir = asNamespace("aifeedbackr"))

as_feedback_text <- function(x) {
  if (is.null(x)) return("")
  if (is.character(x)) return(paste(x, collapse = "\n"))
  if (is.list(x)) {
    # Handle aifeedbackr main() return format
    if (!is.null(x$response)) return(x$response)
    if (!is.null(x$output)) return(x$output)
    if (!is.null(x$raw) && is.list(x$raw) && !is.null(x$raw$response)) {
      return(x$raw$response)
    }
    
    # Fallback for other list formats
    if (length(x) > 0 && all(vapply(x, is.character, logical(1)))) {
      return(paste(unlist(x, use.names = FALSE), collapse = "\n"))
    }
    if (length(x) >= 2 && is.list(x[[2]]) && !is.null(x[[2]]$response)) {
      return(x[[2]]$response)
    }
    return(paste(capture.output(str(x, max.level = 2)), collapse = "\n"))
  }
  paste(capture.output(str(x, max.level = 2)), collapse = "\n")
}

llm_feedback <- ""

test_that("Generates LLM feedback for code scope", {
  raw <- main(
    prompt = code_prompt_path,
    scope = "code",
    submission = submission_r_path,
    model = "claude"
  )
  
  feedback <- as_feedback_text(raw)
  llm_feedback <<- feedback
  
  if (nchar(feedback) == 0) {
    # For empty feedback, create a failure expectation but still set overall_comments
    expectation <- new_expectation(
      type = "failure",
      message = "LLM returned empty feedback for code scope."
    )
    attr(expectation, "markus_overall_comments") <- "[empty feedback]"
    exp_signal(expectation)
    fail("Empty feedback")
  } else {
    expectation <- new_expectation(
      type = "success",
      message = feedback
    )
    attr(expectation, "markus_overall_comments") <- feedback
    exp_signal(expectation)
    succeed()
  }
})

test_that("Emits code annotations when present", {
  feedback <- llm_feedback
  
  if (nchar(feedback) == 0) {
    expectation <- new_expectation(
      type = "failure",
      message = "No prior feedback to extract annotations from."
    )
    exp_signal(expectation)
    fail("No feedback for annotation extraction")
  } else {
    # Extract annotations
    anns <- find_annotations_object(feedback)
    
    if (length(anns) > 0) {
      # Create expectation for each annotation and set markus_annotation attribute
      for (i in seq_along(anns)) {
        a <- anns[[i]]
        
        # Read file to compute columns
        file_lines <- try(readLines(submission_r_path, warn = FALSE), silent = TRUE)
        if (inherits(file_lines, "try-error")) file_lines <- character()
        
        fn <- a$filename %||% basename(submission_r_path)
        txt <- a$content %||% a$description %||% ""
        ls <- as.integer(a$line_start %||% 1L)
        le <- as.integer(a$line_end %||% ls)
        
        # Skip empty content
        if (!nzchar(txt)) next
        
        # Compute columns
        cols <- compute_columns(file_lines, ls, le)
        
        # Create expectation with annotation attribute
        expectation <- new_expectation(
          type = "success",
          message = ""
        )
        attr(expectation, "markus_annotation") <- list(
          filename = fn,
          content = txt,
          line_start = cols$line_start,
          line_end = cols$line_end,
          column_start = cols$column_start,
          column_end = cols$column_end
        )
        exp_signal(expectation)
      }
      
      # Send final success message
      expectation <- new_expectation(
        type = "success",
        message = sprintf("Emitted %d code annotations.", length(anns))
      )
      exp_signal(expectation)
      succeed()
    } else {
      expectation <- new_expectation(
        type = "success",
        message = "No annotations found in LLM output; skipping emission."
      )
      exp_signal(expectation)
      succeed()
    }
  }
})