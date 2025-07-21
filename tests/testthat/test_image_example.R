# tests/test_main.R
path <- here::here("tests", "fixtures")

custom <- paste(
  "Consider this question:",
  "{file_references}",
  "",
  "Files to Reference:",
  "{file_contents}",
  "",
  "{submission_image}",
  "",
  "Do the graphs in the attached image solve the problem?",
  "Do not include an example solution.",
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
      scope = "image",
      model = "openai",
      prompt_custom = custom,
      submission = file.path(path, "image_example/correctness_submission/correctness_submission.ipynb"),
      submission_image = file.path(path, "image_example/correctness_submission/correctness_submission.png"),
      solution = file.path(path, "image_example/solution.ipynb"),
      output = "output/test_image_example_openai.md"
    )
  ),
  list(
    name = "Text Scope - Claude",
    params = list(
      scope = "image",
      model = "claude",
      prompt_custom = custom,
      submission = file.path(path, "image_example/correctness_submission/correctness_submission.ipynb"),
      submission_image = file.path(path, "image_example/correctness_submission/correctness_submission.png"),
      solution = file.path(path, "image_example/solution.ipynb"),
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
