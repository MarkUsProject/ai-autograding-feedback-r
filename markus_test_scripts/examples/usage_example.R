#!/usr/bin/env Rscript

# Example usage of the Markus RScript testers

# Example 1: Code Analysis with Fixture
example_code_analysis <- function() {
  cat("\n--- Example 1: Code Analysis ---\n")
  
  # Load helpers
  source("../r_helpers.R")
  
  # Use the failing submission fixture
  submission_path <- "../../tests/fixtures/code_example/fail_submission/fail_submission.R"
  solution_path <- "../../tests/fixtures/code_example/solution.R"
  
  if (file.exists(submission_path)) {
    cat("Analyzing code submission:", submission_path, "\n")
    
    # Generate feedback
    feedback <- run_llm_r(
      prompt_text = paste(
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
      ),
      scope = "code",
      model = "claude",
      output = "direct",
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
  
  source("../r_helpers.R")
  
  # Use the PDF fixtures
  submission_path <- "../../tests/fixtures/pdf_example/student_pdf_submission.pdf"
  solution_path <- "../../tests/fixtures/pdf_example/instructor_pdf_solution.pdf"
  
  if (file.exists(submission_path)) {
    cat("Analyzing PDF submission:", submission_path, "\n")
    
    # Generate feedback
    feedback <- run_llm_r(
      prompt_text = paste(
        "Analyze the student's document and provide detailed feedback on:",
        "1. Content accuracy and completeness",
        "2. Structure and organization",
        "3. Writing quality and clarity",
        "4. Use of appropriate terminology",
        "5. Adherence to requirements",
        "",
        "Compare with solution if provided and suggest specific improvements.",
        "",
        "{file_contents}",
        sep = "\n"
      ),
      scope = "text",
      model = "claude",
      output = "direct",
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
  
  source("../r_helpers.R")
  
  # Use the QMD fixture that generates images
  submission_path <- "../../tests/fixtures/sta130_example/submission.qmd"
  
  if (file.exists(submission_path)) {
    cat("Analyzing QMD submission (generates images):", submission_path, "\n")
    
    # Generate feedback
    feedback <- run_llm_r(
      prompt_text = paste(
        "Analyze the student's plot/figure and provide detailed feedback on:",
        "1. Data visualization best practices",
        "2. Chart type appropriateness", 
        "3. Axis labels and titles",
        "4. Color choices and readability",
        "5. Overall clarity and effectiveness",
        "",
        "Compare with solution if provided and suggest specific improvements.",
        sep = "\n"
      ),
      scope = "image",
      model = "openai",  # OpenAI better for images
      output = "direct",
      submission_file = submission_path,
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
  
  source("../r_helpers.R")
  
  # Use code fixture with custom prompt
  submission_path <- "../../tests/fixtures/code_example/fail_submission/fail_submission.R"
  
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
      output = "direct",
      submission_file = submission_path
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
  cat("Note: Make sure the ai-autograding-feedback-r package is loaded\n\n")
  
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
