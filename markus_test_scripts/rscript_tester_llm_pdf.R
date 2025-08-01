#!/usr/bin/env Rscript

# rscript_tester_llm_pdf.R - R-based Markus tester for PDF/text analysis

# Source helper functions
source("r_helpers.R")

# Configuration - modify as needed
SUBMISSION_FILE <- "student_submission.pdf"
SOLUTION_FILE <- "solution.pdf"
QUESTION_TEXT <- ""

# Global variable to store LLM feedback
llm_feedback <- ""

test_with_feedback <- function() {
  if (!file.exists(SUBMISSION_FILE)) {
    cat("Error: Submission file", SUBMISSION_FILE, "not found\n")
    return("")
  }
  
  llm_feedback <<- run_llm_r(
    prompt = "text_prompt",
    scope = "text",
    model = "claude",
    submission_file = SUBMISSION_FILE,
    solution_file = SOLUTION_FILE
  )
  
  add_markus_message(llm_feedback)
  add_markus_overall_comments(llm_feedback)
  
  return(llm_feedback)
}

test_with_annotations <- function() {
  if (llm_feedback == "") {
    return()
  }
  
  annotation_prompt <- paste0(
    "Previous message: ", llm_feedback, ". ",
    "Based on your previous text/PDF evaluation, identify specific sections or passages ",
    "that demonstrate the issues or strengths you mentioned. For each point, provide: ",
    "1. The specific text passage or section, ",
    "2. What the issue or strength is, ",
    "3. How it could be improved (if applicable). ",
    "Format as descriptive annotations for the text analysis."
  )
  
  tryCatch({
    raw_annotation <- run_llm_r(
      prompt_text = annotation_prompt,
      scope = "text",
      model = "claude",
      submission_file = SUBMISSION_FILE
    )
    
    annotations_json_list <- extract_json_r(raw_annotation)
    
    if (length(annotations_json_list) > 0 && "annotations" %in% names(annotations_json_list[[1]])) {
      annotations <- annotations_json_list[[1]]$annotations
      
      for (annotation in annotations) {
        if ("content" %in% names(annotation)) {
          cat("TEXT_ANNOTATION:", toJSON(annotation, auto_unbox = TRUE), "\n")
        }
      }
      
    } else if (length(annotations_json_list) > 0) {
      for (annotation_obj in annotations_json_list) {
        cat("TEXT_ANNOTATION:", toJSON(annotation_obj, auto_unbox = TRUE), "\n")
      }
    }
    
  }, error = function(e) {
    cat("Error generating annotations:", e$message, "\n")
  })
}

main <- function() {
  feedback <- test_with_feedback()
  
  if (nchar(feedback) > 0) {
    test_with_annotations()
  }
}

# Execute main function if script is run directly
if (!interactive()) {
  main()
}
