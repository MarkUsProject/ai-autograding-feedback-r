#!/usr/bin/env Rscript

# rscript_tester_llm_code.R - R-based Markus tester for code analysis

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
  
  # Create actual prompt content instead of referencing non-existent predefined prompts
  prompt_content <- paste(
    "Compare the student's code and solution code. Create a final evaluation table with three columns:",
    "the task requirements, the student's attempt, potential issue.",
    "If possible, identify the root causes of errors that lead to further issues later in the code.",
    "Prioritize fixing the earliest instances where the code breaks to prevent cascading failures.",
    "",
    "{file_references}",
    "",
    "Files to Reference:",
    "{file_contents}",
    sep = "\n"
  )
  
  llm_feedback <<- run_llm_r(
    prompt_text = prompt_content,
    scope = "code",
    model = "claude",
    output = "stdout",
    question = QUESTION_TEXT,
    submission_file = SUBMISSION_FILE,
    solution_file = if(file.exists(SOLUTION_FILE)) SOLUTION_FILE else NULL
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
    "Based on your previous evaluation, identify specific locations in the code that demonstrate ",
    "the issues or strengths you mentioned. For each point, provide: ",
    "1. The specific line(s) of code, ",
    "2. What the issue or strength is, ",
    "3. How it could be improved (if applicable). ",
    "Format as JSON with filename, content, line_start, and line_end."
  )
  
  tryCatch({
    raw_annotation <- run_llm_r(
      prompt_text = annotation_prompt,
      scope = "code",
      model = "claude",
      output = "direct",
      submission_file = SUBMISSION_FILE
    )
    
    annotations_json_list <- extract_json_r(raw_annotation)
    
    if (length(annotations_json_list) > 0 && "annotations" %in% names(annotations_json_list[[1]])) {
      annotations <- annotations_json_list[[1]]$annotations
      annotations_with_columns <- add_annotation_columns_r(annotations, SUBMISSION_FILE)
      
      for (annotation in annotations_with_columns) {
        filename <- annotation$filename
        content <- annotation$content
        line_start <- annotation$line_start
        line_end <- annotation$line_end
        column_start <- annotation$column_start
        column_end <- annotation$column_end
        
        rel_filename <- normalizePath(filename, mustWork = FALSE)
        if (startsWith(rel_filename, getwd())) {
          rel_filename <- substr(rel_filename, nchar(getwd()) + 2, nchar(rel_filename))
        }
        
        add_markus_annotation(
          filename = rel_filename,
          content = content,
          line_start = line_start,
          line_end = line_end,
          column_start = column_start,
          column_end = column_end
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

# Execute main function if script is run directly
if (!interactive()) {
  main()
}
