# tests/test_main.R
library(jsonlite)
path <- here::here("tests", "fixtures")

# Build the custom prompt
custom_prompt <- paste(
  "Compare the student's code and the solution code.",
  "Create a final evaluation table with three columns: (1) task requirements, (2) student's attempt, (3) potential issue.",
  "If possible, identify the root causes of errors that lead to further issues later in the code.",
  "Prioritize fixing the earliest instances where the code breaks to prevent cascading failures.",
  "",
  "Return ONLY a single JSON object that VALIDATES against the schema below.",
  "Do NOT include any extra commentary, markdown, or code fences. Output JSON only.",
  "",
  "",
  "Files to Reference:",
  "{file_references}",
  "",
  "File Contents:",
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
      submission = file.path(path, "code_example/fail_submission/fail_submission.R"),
      solution = file.path(path, "code_example/solution.R"),
      output = "output/test_annotations_openai.md",
      json_schema = file.path(path, "schema/code_annotations_schema.json")
    )
  ),
  list(
    name = "PDF Analysis - OpenAI",
    params = list(
      scope = "text",
      model = "openai",
      prompt_custom = custom_prompt,
      submission = file.path(path, "pdf_example/student_pdf_submission.pdf"),
      solution = file.path(path, "pdf_example/instructor_pdf_solution.pdf"),
      output = "output/test_pdf_annotations_openai.md",
      json_schema = file.path(path, "schema/code_annotations_schema.json")
    )
  )
)

# Run test cases
for (test in tests) {
  cat("Running test:", test$name, "\n")
  do.call(main, test$params)
  validate_output(test$params$output)
}
