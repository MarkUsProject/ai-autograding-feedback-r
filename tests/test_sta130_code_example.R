# tests/test_main.R

source("ai-feedback/main.R")

custom_prompt <- paste(
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
      prompt_custom = custom_prompt,
      submission = "fixtures/test_submissions/sta130_code_example/fail_submission/fail_submission.R",
      solution = "fixtures/test_submissions/sta130_code_example/solution.R",
      output = "output/test_sta_130_code_openai.md"
    )
  ),
  list(
    name = "Code Scope - Claude",
    params = list(
      scope = "code",
      model = "claude",
      prompt_custom = custom_prompt,
      submission = "fixtures/test_submissions/sta130_code_example/fail_submission/fail_submission.R",
      solution = "fixtures/test_submissions/sta130_code_example/solution.R",
      output = "output/test_sta_130_code_claude.md"
    )
  ),
  list(
    name = "Code Scope - Remote",
    params = list(
      scope = "code",
      model = "remote",
      prompt_custom = custom_prompt,
      submission = "fixtures/test_submissions/sta130_code_example/fail_submission/fail_submission.R",
      solution = "fixtures/test_submissions/sta130_code_example/solution.R",
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
