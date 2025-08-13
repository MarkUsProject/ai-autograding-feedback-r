#!/usr/bin/env Rscript

library(testthat)
library(httr)
library(jsonlite)

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
submission_r_path <- resolve_resource_path("markus_test_scripts/examples/submission.R")
helpers_path <- resolve_resource_path("markus_test_scripts/examples/llm_helpers.R")

suppressWarnings(try(source(submission_r_path), silent = TRUE))
source(helpers_path)

llm_feedback <- ""

test_that("Generates LLM feedback for code scope", {
  llm_feedback <<- run_llm(
    submission = submission_r_path,
    model = "claude-3.7-sonnet",
    scope = "code",
    output = "stdout",
    prompt = code_prompt_path
  )
  
  exp_signal(new_expectation(
    type = "success",
    message = llm_feedback,
    markus_overall_comments = llm_feedback
  ))
  
  succeed()
})

test_that("Generates LLM Annotations", {
  prompt_text <- paste0("Previous message: ", llm_feedback, ". ", ANNOTATION_PROMPT)
  
  raw_annotation <- run_llm(
    submission = submission_r_path,
    model = "claude-3.7-sonnet",
    scope = "code",
    output = "direct",
    prompt_text = prompt_text
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
    }
  }
  
  succeed()
})