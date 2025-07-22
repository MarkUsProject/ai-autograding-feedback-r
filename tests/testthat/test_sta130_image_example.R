# tests/test_sta130_image_example.R

custom_prompt <- paste(
  "Analyze the student's submission plots generated from their QMD file.",
  "Compare the visualizations with best practices and evaluate:",
  "1. Correctness of plot types and structure", 
  "2. Appropriate use of data variables and aesthetics",
  "3. Quality of titles, labels, and formatting",
  "4. Statistical accuracy of the visual representations",
  "",
  "{file_references}",
  "",
  "Files to Reference:",
  "{file_contents}",
  sep = "\n"
)

# Utility to read generated output and validate
validate_output <- function(output_path) {
  if (!file.exists(output_path)) {
    stop(paste("Missing output:", output_path))
  }
  content <- readLines(output_path, warn = FALSE)
  text <- paste(content, collapse = "\n")
}

# Define test cases for image processing
tests <- list(
  list(
    name = "Image Scope - OpenAI (QMD Plots)",
    params = list(
      scope = "image",
      model = "openai", 
      prompt_custom = custom_prompt,
      submission = "tests/fixtures/sta130-example/submission.qmd",
      solution = NULL,
      question = "Question 1",
      output = "tests/output/test_sta130_image_openai.md"
    )
  ),
  # list(
  #   name = "Image Scope - Claude (QMD Plots)", 
  #   params = list(
  #     scope = "image",
  #     model = "claude",
  #     prompt_custom = custom_prompt,
  #     submission = "tests/fixtures/sta130-example/submission.qmd",
  #     solution = NULL,
  #     question = "Question 1",
  #     output = "tests/output/test_sta130_image_claude.md"
  #   )
  # ),
  list(
    name = "Image Scope - Openai Subquestion (QMD Plots)", 
    params = list(
      scope = "image",
      model = "openai",
      prompt_custom = custom_prompt,
      submission = "tests/fixtures/sta130-example/submission.qmd",
      solution = NULL,
      question = "Q1__c",
      output = "tests/output/test_sta130_image_openai_question.md"
    )
  )
)

# Test the QMD PNG generation workflow
qmd_path <- "tests/fixtures/sta130-example/submission.qmd"
if (file.exists(qmd_path)) {
  
  # Test PNG generation directly
  png_files <- run_qmd_collect_png(qmd_path, timeout = 30, output_dir = tempdir())
  
  if (length(png_files) > 0) {
    for (i in seq_along(png_files)) {
      cat("  ", i, ". ", basename(png_files[i]), "\n")
    }
  }
} else {
  cat("QMD test file not found:", qmd_path, "\n")
}

# Create output directory if it doesn't exist
if (!dir.exists("tests/output")) {
  dir.create("tests/output", recursive = TRUE)
}

# Run test cases
for (test in tests) {
  cat("\nRunning test:", test$name, "\n")
  
  tryCatch({
    do.call(main, test$params)
    validate_output(test$params$output)
    cat(test$name, "completed successfully\n")
  }, error = function(e) {
    cat(test$name, "failed:", e$message, "\n")
  })
}
