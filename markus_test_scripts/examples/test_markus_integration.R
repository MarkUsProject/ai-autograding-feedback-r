#!/usr/bin/env Rscript

# Load helper functions
source("r_helpers.R")

# Test basic LLM function with a simple example
test_basic_functionality <- function() {
  test_code <- 'x <- 1 + 1\nprint(x)'
  writeLines(test_code, "test_submission.R")
  
  tryCatch({
    # Test code analysis
    result <- run_llm_r(
      prompt = "code_prompt",
      scope = "code",
      model = "claude",
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
  fixture_path <- "../tests/fixtures/code_example/fail_submission/fail_submission.R"
  
  if (file.exists(fixture_path)) {
    cat("Found test fixture:", fixture_path, "\n")
    
    tryCatch({
      feedback <- run_llm_r(
        prompt = "code_prompt",
        scope = "code",
        model = "claude",
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
  qmd_fixture_path <- "../tests/fixtures/sta130_example/submission.qmd"
  
  if (file.exists(qmd_fixture_path)) {
    cat("Found QMD fixture:", qmd_fixture_path, "\n")
    
    tryCatch({
      result <- run_llm_r(
        prompt = "image_prompt",
        scope = "image",
        model = "claude", 
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

# Test that illustrates MarkUs metadata attributes
test_markus_metadata_attributes <- function() {
  cat("Testing MarkUs metadata attributes integration\n")
  
  tryCatch({
    test_result <- list(
      type = "success",
      message = "",
      markus_overall_comments = "This is an overall comment for R testing. Great job!",
      markus_tag = "good",
      markus_annotation = list(
        filename = "student_submission.R",
        content = "This function demonstrates good R practices",
        line_start = 3,
        line_end = 3,
        column_start = 1,
        column_end = 25
      )
    )
    
    cat("MARKUS_METADATA:", toJSON(test_result, auto_unbox = TRUE), "\n")
    cat("MarkUs metadata attributes test completed successfully\n")
    
  }, error = function(e) {
    cat("Error in MarkUs metadata test:", e$message, "\n")
  })
}

main <- function() {
  
  test_basic_functionality()
  test_fixture_integration()
  test_qmd_fixture()
  test_markus_formatting()
  test_markus_metadata_attributes()
}

if (!interactive()) {
  main()
}
