# Required Libraries
library(stringr)
library(tools)
library(glue)

#' Render a prompt template with placeholder substitutions
#'
#' @param prompt_content The template string with placeholders (e.g., {file_contents})
#' @param submission Path to the student's submission file
#' @param has_submission_image Boolean indicating if submission image is available
#' @param has_solution_image Boolean indicating if solution image is available
#' @param solution Optional path to instructor's solution file
#' @param test_output Optional path to test output or traceback file
#' @param question_num Optional question number (used to extract specific task content)
#' @param ... Additional named values for placeholder substitution
#' @return A string with all placeholders filled in using provided content
render_prompt_template <- function(prompt_content,
                                   submission,
                                   has_submission_image = FALSE,
                                   has_solution_image = FALSE,
                                   solution = NULL,
                                   test_output = NULL,
                                   question_num = NULL,
                                   ...) {
  args <- list(...)
  args$file_references <- gather_file_references(submission, solution, test_output)

  if (!is.null(question_num)) {
    args$file_contents <- get_question_contents(list(submission, solution), question_num)
  } else {
    args$file_contents <- gather_file_contents(list(submission, solution, test_output))
  }

  if (str_detect(prompt_content, "\\{submission_image\\}") && is.null(args$submission_image)) {
    args$submission_image <- if (has_submission_image && has_solution_image) {
      "The first attached image is the student's submission."
    } else if (has_submission_image) {
      "The attached image is the student's submission."
    } else {
      "[Submission Image Attached]"
    }
  }

  if (str_detect(prompt_content, "\\{solution_image\\}") && is.null(args$solution_image)) {
    args$solution_image <- if (has_submission_image && has_solution_image) {
      "The second attached image is the expected solution."
    } else if (has_solution_image) {
      "The attached image is the expected solution."
    } else {
      "[Solution Image Attached]"
    }
  }

  glue::glue_data(args, prompt_content)
}

#' Generate human-readable references for file names
#'
#' @param submission Path to student's submission file
#' @param solution Optional path to solution file
#' @param test_output Optional path to test output or error trace file
#' @return A string listing all referenced files
gather_file_references <- function(submission, solution = NULL, test_output = NULL) {
  refs <- c(paste0("The student's submission file is ", basename(submission), "."))
  if (!is.null(solution)) {
    refs <- c(refs, paste0("The instructor's solution file is ", basename(solution), "."))
  }
  if (!is.null(test_output)) {
    refs <- c(refs, paste0("The student's test output file is ", basename(test_output), "."))
  }
  paste(refs, collapse = "\n")
}

#' Collect contents of submission/solution files with line numbers
#'
#' @param paths List of file paths
#' @return String representing file contents with line numbers
gather_file_contents <- function(paths) {
  contents <- ""

  for (path in paths) {
    if (is.null(path)) next
    filename <- basename(path)

    tryCatch({
      if (tolower(file_ext(filename)) == "pdf") {
        text <- extract_pdf_text(path)
        lines <- strsplit(text, "\n")[[1]]
      } else {
        lines <- readLines(path, warn = FALSE)
      }

      contents <- paste0(contents, "=== ", filename, " ===\n")
      for (i in seq_along(lines)) {
        line <- lines[[i]]
        if (nzchar(trimws(line))) {
          contents <- paste0(contents, sprintf("(Line %d) %s\n", i, line))
        } else {
          contents <- paste0(contents, sprintf("(Line %d) \n", i))
        }
      }

      contents <- paste0(contents, "\n")
    }, error = function(e) {
      message(sprintf("Error reading file %s: %s", filename, e$message))
    })
  }

  contents
}

#' Extract plain text from a PDF
#'
#' @param pdf_path Path to the PDF file
#' @return Extracted text as a string
extract_pdf_text <- function(pdf_path) {
  if (!requireNamespace("pdftools", quietly = TRUE)) {
    stop("Please install 'pdftools' package.")
  }

  tryCatch({
    pdftools::pdf_text(pdf_path) %>% paste(collapse = "\n")
  }, error = function(e) {
    message(sprintf("Error extracting text from PDF %s: %s", basename(pdf_path), e$message))
    return(sprintf("[Error: Could not extract text from PDF %s]", basename(pdf_path)))
  })
}

#' Extract content from a specific task number within submission/solution files
#'
#' Assumes the files follow a Markdown-like structure with '## Introduction' and '## Task {n}' sections.
#'
#' @param paths List of file paths
#' @param question_num Question number to extract
#' @return String with introduction and target task section contents
get_question_contents <- function(paths, question_num) {
  contents <- ""
  task_found <- FALSE

  for (path in paths) {
    if (is.null(path) || file_ext(path) != "txt" || grepl("error_output|.DS_Store", basename(path))) next

    text <- readLines(path, warn = FALSE) %>% paste(collapse = "\n")

    intro <- str_match(text, "(## Introduction\\b.*?)(?=\\n##|$)")[, 2]
    task_pattern <- sprintf("(## Task %d\\b.*?)(?=\\n##|$)", question_num)
    task <- str_match(text, task_pattern)[, 2]

    if (!is.na(task)) task_found <- TRUE

    contents <- paste0(contents, "\n\n---\n### ", path, "\n\n",
                       if (!is.na(intro)) paste0(intro, "\n\n") else "",
                       if (!is.na(task)) paste0(task, "\n\n") else "")
  }

  if (!task_found) {
    stop(sprintf("Task %d not found in any assignment file.", question_num))
  }

  trimws(contents)
}
