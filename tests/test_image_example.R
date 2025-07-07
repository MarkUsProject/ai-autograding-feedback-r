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
      scope = "image",
      model = "openai",
      prompt = "data/prompts/user/image_analyze.md",
      submission = "test_submissions/image_example/correctness_submission/correctness_submission.ipynb",
      submission_image = "test_submissions/image_example/correctness_submission/correctness_submission.png",
      solution = "test_submissions/image_example/solution.ipynb",
      output = "output/test_image_example_openai.md"
    )
  ),
  list(
    name = "Text Scope - Claude",
    params = list(
      scope = "image",
      model = "claude",
      prompt = "data/prompts/user/image_analyze.md",
      submission = "test_submissions/image_example/correctness_submission/correctness_submission.ipynb",
      submission_image = "test_submissions/image_example/correctness_submission/correctness_submission.png",
      solution = "test_submissions/image_example/solution.ipynb",
      output = "output/test_image_example_claude.md"
    )
  )
)

# Run test cases
for (test in tests) {
  cat("Running test:", test$name, "\n")
  do.call(main, test$params)
  validate_output(test$params$output)
}
