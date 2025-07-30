# tests/test_marking_instructions.R
path <- here::here("tests", "fixtures")

test_marking_instructions <- paste(
  "# Test Marking Instructions",
  "",
  "## Grading Criteria",
  "",
  "### 1. Correctness (40%)",
  "- The code/visualization/text accurately represents the requirements",
  "- All required elements are present and functional",
  "",
  "### 2. Clarity (30%)",
  "- The output is easy to understand and interpret",
  "- Documentation and comments are clear",
  "",
  "### 3. Style (20%)",
  "- Code follows good programming practices",
  "- Visualizations are aesthetically pleasing",
  "",
  "### 4. Efficiency (10%)",
  "- Code is efficient and well-structured",
  "- No unnecessary complexity",
  "",
  "## Specific Requirements",
  "- Use appropriate variable names",
  "- Include proper error handling",
  "- Follow the assignment guidelines",
  "",
  "## Common Issues to Check",
  "- Missing required functions or methods",
  "- Incorrect data types or structures",
  "- Poor formatting or readability",
  "- Inefficient algorithms or approaches",
  sep = "\n"
)

test_marking_file <- file.path(path, "test_marking_instructions.md")
writeLines(test_marking_instructions, test_marking_file)

custom_prompt_with_marking <- paste(
  "Evaluate the student's submission based on the provided criteria.",
  "",
  "{marking_instructions}",
  "",
  "Create a detailed evaluation table with the following columns:",
  "- Criterion: The specific requirement being evaluated",
  "- Student Performance: How well the student met the criterion",
  "- Comments: Detailed feedback and suggestions",
  "",
  "{file_references}",
  "",
  "Files to Reference:",
  "{file_contents}",
  sep = "\n"
)

validate_output <- function(output_path) {
  if (!file.exists(output_path)) {
    stop(paste("Missing output:", output_path))
  }
  content <- readLines(output_path, warn = FALSE)
  text <- paste(content, collapse = "\n")

  cat("Output validated:", output_path, "\n")
}

# Define test cases
tests <- list(
  list(
    name = "Code Scope with Marking Instructions - OpenAI",
    params = list(
      scope = "code",
      model = "openai",
      prompt_custom = custom_prompt_with_marking,
      submission = file.path(path, "code_example/fail_submission/fail_submission.R"),
      solution = file.path(path, "code_example/solution.R"),
      marking_instructions = test_marking_file,
      output = "output/test_marking_instructions_code_openai.md"
    )
  ),
  list(
    name = "Text Scope with Marking Instructions - Claude",
    params = list(
      scope = "text",
      model = "claude",
      prompt_custom = custom_prompt_with_marking,
      submission = file.path(path, "pdf_example/student_pdf_submission.pdf"),
      solution = file.path(path, "pdf_example/instructor_pdf_solution.pdf"),
      marking_instructions = test_marking_file,
      output = "output/test_marking_instructions_text_claude.md"
    )
  ),
  list(
    name = "Image Scope with Marking Instructions - OpenAi",
    params = list(
      scope = "image",
      model = "openai",
      prompt_custom = custom_prompt_with_marking,
      submission = file.path(path, "sta130_example/submission.qmd"),
      solution = NULL,
      marking_instructions = test_marking_file,
      output = "output/test_marking_instructions_image_remote.md"
    )
  )
)

# Run test cases
for (test in tests) {
  cat("Running test:", test$name, "\n")
  tryCatch({
    do.call(main, test$params)
    validate_output(test$params$output)
    cat("Test passed:", test$name, "\n")
  }, error = function(e) {
    cat("Test failed:", test$name, "-", e$message, "\n")
  })
}
unlink(test_marking_file)
