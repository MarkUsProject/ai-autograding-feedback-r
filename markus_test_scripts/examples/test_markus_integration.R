#!/usr/bin/env Rscript

# Test if we can load the package and helpers
tryCatch({
  source("../r_helpers.R")
  cat("Successfully loaded r_helpers.R\n")
}, error = function(e) {
  cat("Error loading r_helpers.R:", e$message, "\n")
  quit(status = 1)
})

# Test basic LLM function with a simple example
test_basic_functionality <- function() {
  test_code <- 'x <- 1 + 1\nprint(x)'
  writeLines(test_code, "test_submission.R")
  
  tryCatch({
    # Test code analysis
    result <- run_llm_r(
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
      submission_file = "test_submission.R"
    )
    
    if (is.character(result) && nchar(result) > 0) {
      cat("Code analysis test passed\n")
      cat("Response length:", nchar(result), "characters\n")
    } else {
      cat("Code analysis test failed - empty response\n")
    }
    
    unlink("test_submission.R")
    
  }, error = function(e) {
    cat("Code analysis test failed:", e$message, "\n")
    unlink("test_submission.R")
  })
}

# Test fixture integration
test_fixture_integration <- function() {
  
  # Test with existing fixtures
  fixture_path <- "../../tests/fixtures/code_example/fail_submission/fail_submission.R"
  
  if (file.exists(fixture_path)) {
    cat("✓ Found test fixture:", fixture_path, "\n")
    
    tryCatch({
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
        submission_file = fixture_path
      )
      
      if (is.character(feedback) && nchar(feedback) > 0) {
        cat("Fixture integration test passed\n")
      } else {
        cat("Fixture integration test failed - empty response\n")
      }
      
    }, error = function(e) {
      cat("Fixture integration test failed:", e$message, "\n")
    })
  } else {
    cat("Test fixture not found, skipping fixture integration test\n")
  }
}

# Test QMD image generation fixture
test_qmd_fixture <- function() {  
  qmd_fixture_path <- "../../tests/fixtures/sta130_example/submission.qmd"
  
  if (file.exists(qmd_fixture_path)) {
    cat("Found QMD fixture:", qmd_fixture_path, "\n")
    
    tryCatch({
      result <- run_llm_r(
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
        model = "openai",
        output = "direct",
        submission_file = qmd_fixture_path
      )
      
      if (is.character(result) && nchar(result) > 0) {
        cat("QMD image generation test passed\n")
      } else {
        cat("QMD image generation test failed - empty response\n")
      }
      
    }, error = function(e) {
      cat("QMD image generation test failed:", e$message, "\n")
    })
  } else {
    cat("QMD fixture not found, skipping QMD test\n")
  }
}

# Test Markus output formatting
test_markus_formatting <- function() {  
  # Test message formatting
  add_markus_message("Test message")
  add_markus_overall_comments("Test comments")
  
  add_markus_annotation(
    filename = "test.R",
    content = "Test annotation",
    line_start = 1,
    line_end = 1, 
    column_start = 0,
    column_end = 10
  )
  
  cat("Markus formatting functions executed successfully\n")
}

main <- function() {
  cat("Starting Markus integration tests...\n")
  
  test_basic_functionality()
  test_fixture_integration()
  test_qmd_fixture()
  test_markus_formatting()
}

if (!interactive()) {
  main()
}
