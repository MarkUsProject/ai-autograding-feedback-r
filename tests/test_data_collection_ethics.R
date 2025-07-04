# tests/test_main.R

source("ai-feedback/main.R")

# Utility to read generated output and validate
validate_output <- function(output_path) {
  if (!file.exists(output_path)) {
    stop(paste("❌ Missing output:", output_path))
  }
  content <- readLines(output_path, warn = FALSE)
  text <- paste(content, collapse = "\n")

  #implement basic validation checks
  cat("✅ Output validated:", output_path, "\n")
}

# Define test cases
tests <- list(
  list(
    name = "Text Scope - OpenAI",
    params = list(
      scope = "text",
      model = "openai",
      prompt = "text_pdf_analyze",
      submission = "test_submissions/data_collection_ethics_module/average_submission/average_submission_scoring.md",
      solution = "test_submissions/data_collection_ethics_module/solution.txt",
      output = "output/test_ethics_openai.md"
    )
  ),
  list(
    name = "Text Scope - Claude",
    params = list(
      scope = "text",
      model = "claude",
      prompt = "text_pdf_analyze",
      submission = "test_submissions/data_collection_ethics_module/average_submission/average_submission_scoring.md",
      solution = "test_submissions/data_collection_ethics_module/solution.txt",
      output = "output/test_ethics_claude.md"
    )
  ),
  list(
    name = "Text Scope - Remote",
    params = list(
      scope = "text",
      model = "remote",
      prompt = "text_pdf_analyze",
      submission = "test_submissions/data_collection_ethics_module/average_submission/average_submission_scoring.md",
      solution = "test_submissions/data_collection_ethics_module/solution.txt",
      output = "output/test_ethics_remote.md"
    )
  )
)

# Run test cases
for (test in tests) {
  cat("Running test:", test$name, "\n")
  do.call(main, test$params)
  validate_output(test$params$output)
}
