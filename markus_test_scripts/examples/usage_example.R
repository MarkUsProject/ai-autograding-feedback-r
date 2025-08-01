#!/usr/bin/env Rscript

# Example usage of the Markus RScript testers

# Load helper functions
source("r_helpers.R")

# Example 1: Code Analysis with Fixture
example_code_analysis <- function() {
  cat("\n--- Example 1: Code Analysis ---\n")
    
  # Use the code fixtures
  submission_path <- "../tests/fixtures/code_example/fail_submission/fail_submission.R"
  solution_path <- "../tests/fixtures/code_example/solution.R"
  
  if (file.exists(submission_path)) {
    cat("Analyzing code submission:", submission_path, "\n")
    
    # Generate feedback using prompt file
    feedback <- run_llm_r(
      prompt = "code_prompt",
      scope = "code",
      model = "claude",
      submission_file = submission_path,
      solution_file = solution_path
    )
    
    # Output Markus format
    add_markus_message(feedback)
    add_markus_overall_comments(feedback)
    
    cat("Code analysis completed\n")
  } else {
    cat("Code fixture not found\n")
  }
}

# Example 2: PDF Analysis with Fixture
example_pdf_analysis <- function() {
  cat("\n--- Example 2: PDF Analysis ---\n")
  
  # Use the PDF fixtures
  submission_path <- "../tests/fixtures/pdf_example/student_pdf_submission.pdf"
  solution_path <- "../tests/fixtures/pdf_example/instructor_pdf_solution.pdf"
  
  if (file.exists(submission_path)) {
    cat("Analyzing PDF submission:", submission_path, "\n")
    
    # Generate feedback using prompt file
    feedback <- run_llm_r(
      prompt = "text_prompt",
      scope = "text",
      model = "claude",
      submission_file = submission_path,
      solution_file = solution_path
    )
    
    # Output Markus format
    add_markus_message(feedback)
    add_markus_overall_comments(feedback)
    
    cat("PDF analysis completed\n")
  } else {
    cat("PDF fixture not found\n")
  }
}

# Example 3: QMD Image Analysis with Fixture
example_qmd_image_analysis <- function() {
  cat("\n--- Example 3: QMD Image Analysis ---\n")
  
  # Use the image fixture (QMD file)
  qmd_path <- "../tests/fixtures/sta130_example/submission.qmd"
  
  if (file.exists(qmd_path)) {
    cat("Analyzing QMD submission (generates images):", qmd_path, "\n")
    
    # Generate feedback using prompt file
    feedback <- run_llm_r(
      prompt = "image_prompt",
      scope = "image",
      model = "openai",
      submission_file = qmd_path,
      question = "Question 1"
    )
    
    # Output Markus format
    add_markus_message(feedback)
    add_markus_overall_comments(feedback)
    
    cat("QMD image analysis completed\n")
  } else {
    cat("QMD fixture not found\n")
  }
}

# Example 4: Custom Prompt Analysis
example_custom_prompt <- function() {
  cat("\n--- Example 4: Custom Prompt Analysis ---\n")
  
  # Use code fixture for custom prompt
  submission_path <- "../tests/fixtures/code_example/fail_submission/fail_submission.R"
  solution_path <- "../tests/fixtures/code_example/solution.R"
  
  if (file.exists(submission_path)) {
    cat("Analyzing with custom prompt:", submission_path, "\n")
    
    # Define custom prompt
    custom_prompt <- paste(
      "Evaluate this R code submission focusing on:",
      "1. Syntax errors and bugs",
      "2. Logic and algorithm correctness", 
      "3. Code style and readability",
      "4. Efficiency and best practices",
      "",
      "Provide specific line-by-line feedback where appropriate.",
      "{file_contents}",
      sep = "\n"
    )
    
    # Generate feedback
    feedback <- run_llm_r(
      prompt_text = custom_prompt,
      scope = "code",
      model = "claude",
      submission_file = submission_path,
      solution_file = solution_path
    )
    
    # Output Markus format
    add_markus_message(feedback)
    add_markus_overall_comments(feedback)
    
    cat("Custom prompt analysis completed\n")
  } else {
    cat("Code fixture not found\n")
  }
}

# Main execution
main <- function() {
  cat("Running Markus tester usage examples...\n")  
  # Run examples
  example_code_analysis()
  example_pdf_analysis() 
  example_qmd_image_analysis()
  example_custom_prompt()
  
  cat("\n=== Usage Examples Complete ===\n")
  cat("To use these testers in Markus:\n")
  cat("1. Copy the appropriate tester script to your assignment directory\n")
  cat("2. Update the SUBMISSION_FILE path to match your student files\n")
  cat("3. Modify prompts and models as needed\n")
  cat("4. Run with: Rscript -e \"library(devtools); load_all(); source('tester_script.R')\"\n")
}

# Execute if run directly
if (!interactive()) {
  main()
}
