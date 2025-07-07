# tests/test_pdf_example.R

source("ai-feedback/main.R")

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
      prompt = "data/prompts/user/text_pdf_analyze.md",
      submission = "test_submissions/pdf_example/student_pdf_submission.pdf",
      solution = "test_submissions/pdf_example/instructor_pdf_solution.pdf",
      output = "output/test_pdf_analyze_openai.md"
    )
  ),
  list(
    name = "PDF Analysis - Claude",
    params = list(
      scope = "text",
      model = "claude",
      prompt = "data/prompts/user/text_pdf_analyze.md",
      submission = "test_submissions/pdf_example/student_pdf_submission.pdf",
      solution = "test_submissions/pdf_example/instructor_pdf_solution.pdf",
      output = "output/test_pdf_analyze_claude.md"
    )
  ),
  list(
    name = "PDF Analysis - Remote",
    params = list(
      scope = "text",
      model = "remote",
      prompt = "data/prompts/user/text_pdf_analyze.md",
      submission = "test_submissions/pdf_example/student_pdf_submission.pdf",
      solution = "test_submissions/pdf_example/instructor_pdf_solution.pdf",
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
 