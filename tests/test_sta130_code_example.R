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
      scope = "code",
      model = "openai",
      prompt = "data/prompts/user/code_table.md",
      submission = "test_submissions/sta130_code_example/fail_submission/fail_submission.R",
      solution = "test_submissions/sta130_code_example/solution.R",
      output = "output/test_sta_130_code_openai.md"
    )
  ),
  list(
    name = "Code Scope - Claude",
    params = list(
      scope = "code",
      model = "claude",
      prompt = "data/prompts/user/code_table.md",
      submission = "test_submissions/sta130_code_example/fail_submission/fail_submission.R",
      solution = "test_submissions/sta130_code_example/solution.R",
      output = "output/test_sta_130_code_claude.md"
    )
  ),
  list(
    name = "Code Scope - Remote",
    params = list(
      scope = "code",
      model = "remote",
      prompt = "data/prompts/user/code_table.md",
      submission = "test_submissions/sta130_code_example/fail_submission/fail_submission.R",
      solution = "test_submissions/sta130_code_example/solution.R",
      output = "output/test_sta_130_code_remote.md"
    )
  )
)

# Run test cases
for (test in tests) {
  cat("Running test:", test$name, "\n")
  do.call(main, test$params)
  validate_output(test$params$output)
}
