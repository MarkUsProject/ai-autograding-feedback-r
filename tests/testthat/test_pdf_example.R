# tests/test_pdf_example.R
path <- here::here("tests", "fixtures")

custom_prompt <- paste(
  "Does the student correctly respond to the question,",
  "and meet all the criteria that's stated in the rubric?",
  "Output a table of all the criteria that the instructor has in the solution,",
  "whether the student's response follows the criteria,",
  "and an explanation on how they improve their answer.",
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

  if (grepl("\\[Error.*PDF", text)) {
    stop(paste("PDF processing error detected in:", output_path))
  }

  cat("Output validated:", output_path, "\n")
}

tests <- list(
  list(
    name = "PDF Analysis - OpenAI",
    params = list(
      scope = "text",
      model = "openai",
      prompt_custom = custom_prompt,
      submission = file.path(path, "pdf_example/student_pdf_submission.pdf"),
      solution = file.path(path, "pdf_example/instructor_pdf_solution.pdf"),
      output = "output/test_pdf_analyze_openai.md"
    )
  ),
  list(
    name = "PDF Analysis - Claude",
    params = list(
      scope = "text",
      model = "claude",
      prompt_custom = custom_prompt,
      submission = file.path(path, "pdf_example/student_pdf_submission.pdf"),
      solution = file.path(path, "pdf_example/instructor_pdf_solution.pdf"),
      output = "output/test_pdf_analyze_claude.md"
    )
  ),
  list(
    name = "PDF Analysis - Remote",
    params = list(
      scope = "text",
      model = "remote",
      prompt_custom = custom_prompt,
      submission = file.path(path, "pdf_example/student_pdf_submission.pdf"),
      solution = file.path(path, "pdf_example/instructor_pdf_solution.pdf"),
      output = "output/test_pdf_analyze_remote.md"
    )
  )
)

# Run test cases
for (test in tests) {

  tryCatch({
    do.call(main, test$params)
    validate_output(test$params$output)
  }, error = function(e) {
    cat("Test failed:", e$message, "\n")
  })
}
