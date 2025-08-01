#!/usr/bin/env Rscript

# rscript_tester_custom_prompt.R - R-based Markus tester with custom prompts

# Source helper functions
source("r_helpers.R")

# Configuration - modify as needed
SUBMISSION_FILE <- "student_submission.R"
SOLUTION_FILE <- "solution.R"
QUESTION_TEXT <- ""

# Global variable to store LLM feedback
llm_feedback <- ""

test_with_feedback <- function() {
  if (!file.exists(SUBMISSION_FILE)) {
    cat("Error: Submission file", SUBMISSION_FILE, "not found\n")
    return("")
  }
  
  # Check for custom prompt file first
  if (file.exists("custom_prompt.txt")) {
    custom_prompt <- paste(readLines("custom_prompt.txt", warn = FALSE), collapse = "\n")
    
    llm_feedback <<- run_llm_r(
      prompt_text = custom_prompt,
      scope = "code",
      model = "claude",
      submission_file = SUBMISSION_FILE,
      solution_file = SOLUTION_FILE
    )
  } else {
    # Error if no custom prompt found
    llm_feedback <<- "Error: custom_prompt.txt file not found. This tester requires a custom prompt file."
    cat("Error: custom_prompt.txt file not found\n")
    cat("Please create a custom_prompt.txt file with your custom prompt content\n")
    return("")
  }
  
  add_markus_message(llm_feedback)
  add_markus_overall_comments(llm_feedback)
  
  return(llm_feedback)
}

test_with_annotations <- function() {
  if (llm_feedback == "") {
    return()
  }
  
  annotation_prompt <- paste(
    "Based on your previous evaluation, identify specific locations in the code that demonstrate",
    "the issues or strengths you mentioned. For each point, provide:",
    "1. The specific line(s) of code",
    "2. What the issue or strength is", 
    "3. How it could be improved (if applicable)",
    "",
    "Format as JSON with filename, content, line_start, and line_end.",
    "Previous evaluation:", llm_feedback
  )
  
  tryCatch({
    annotations <- generate_annotations_r(
      llm_feedback = llm_feedback,
      model = "claude",
      submission_file = SUBMISSION_FILE
    )
    
    if (length(annotations) > 0) {
      for (annotation in annotations) {
        add_markus_annotation(
          filename = annotation$filename,
          content = annotation$content,
          line_start = annotation$line_start,
          line_end = annotation$line_end,
          column_start = annotation$column_start,
          column_end = annotation$column_end
        )
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

if (!interactive()) {
  main()
} 
