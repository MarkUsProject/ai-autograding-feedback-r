#!/usr/bin/env Rscript

# rscript_tester_llm_image.R - R-based Markus tester for image analysis

# Source helper functions
source("r_helpers.R")

# Configuration - modify as needed
SUBMISSION_FILE <- "student_submission.png"
SOLUTION_FILE <- "solution.png"
QUESTION_TEXT <- ""

# Global variable to store LLM feedback
llm_feedback <- ""

test_with_feedback <- function() {
  if (!file.exists(SUBMISSION_FILE)) {
    cat("Error: Submission file", SUBMISSION_FILE, "not found\n")
    return("")
  }
  
  llm_feedback <<- run_llm_r(
    prompt = "image_prompt",
    scope = "image",
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
    "Based on your previous image evaluation, identify specific visual elements or regions ",
    "that demonstrate the issues or strengths you mentioned. For each point, provide: ",
    "1. What visual element or region you're referring to, ",
    "2. What the issue or strength is, ",
    "3. How it could be improved (if applicable). ",
    "Format as descriptive annotations for the image analysis."
  )
  
  tryCatch({
    descriptive_analysis <- run_llm_r(
      prompt_text = annotation_prompt,
      scope = "image",
      model = "claude",
      submission_file = SUBMISSION_FILE
    )
    
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
 