# helpers/template_utils.R

# Load required libraries (matching Python imports)
library(pdftools)

#' Render a prompt template by replacing placeholders with actual values
#' @param prompt_content Character string with placeholders like {file_contents}
#' @param submission Path to student's submission file
#' @param solution Path to instructor's solution file (optional)
#' @param test_output Path to test output file (optional)
#' @param has_submission_image Whether submission image is present
#' @param has_solution_image Whether solution image is present
#' @param ... Additional key-value pairs for placeholder replacement
#'
#' @return Character string with placeholders replaced
#'
#' @export
render_prompt_template <- function(
  prompt_content,
  submission = NULL,
  solution = NULL,
  test_output = NULL,
  has_submission_image = FALSE,
  has_solution_image = FALSE,
  question = NULL,
  ...
) {
  # Start with additional arguments
  template_data <- list(...)

  # Generate file references if needed
  if (grepl("\\{file_references\\}", prompt_content)) {
    template_data$file_references <- gather_file_references(submission, solution, test_output)
  }

  # Generate file contents if needed
  if (grepl("\\{file_contents\\}", prompt_content)) {
    files_to_process <- list(submission, solution, test_output)
    files_to_process <- files_to_process[!sapply(files_to_process, is.null)]
    template_data$file_contents <- gather_file_contents(files_to_process, question)
  }
  
  # Handle image placeholders
  if (grepl("\\{submission_image\\}", prompt_content) && !("submission_image" %in% names(template_data))) {
    if (has_submission_image && has_solution_image) {
      template_data$submission_image <- "The first attached image is the student's submission."
    } else if (has_submission_image) {
      template_data$submission_image <- "The attached image is the student's submission."
    } else {
      template_data$submission_image <- "[Submission Image Attached]"
    }
  }

  if (grepl("\\{solution_image\\}", prompt_content) && !("solution_image" %in% names(template_data))) {
    if (has_submission_image && has_solution_image) {
      template_data$solution_image <- "The second attached image is the expected solution."
    } else if (has_solution_image) {
      template_data$solution_image <- "The attached image is the expected solution."
    } else {
      template_data$solution_image <- "[Solution Image Attached]"
    }
  }

  # Replace placeholders
  result <- prompt_content
  for (key in names(template_data)) {
    placeholder <- paste0("{", key, "}")
    if (grepl(placeholder, result, fixed = TRUE)) {
      result <- gsub(placeholder, template_data[[key]], result, fixed = TRUE)
    }
  }

  remaining_placeholders <- regmatches(result, gregexpr("\\{[a-zA-Z_][a-zA-Z0-9_]*\\}", result))[[1]]
  if (length(remaining_placeholders) > 0) {
    stop("Missing placeholders in template: ", paste(remaining_placeholders, collapse = ", "))
  }

  return(result)
}

#' Generate file reference descriptions
#' 
#' @param submission Path to student's submission file
#' @param solution Path to instructor's solution file (optional)
#' @param test_output Path to test output file (optional)
#' 
#' @return Character string with file descriptions
gather_file_references <- function(submission, solution = NULL, test_output = NULL) {
  references <- c()
  
  if (!is.null(submission)) {
    references <- c(references, paste("The student's submission file is", basename(submission), "."))
  }
  
  if (!is.null(solution)) {
    references <- c(references, paste("The instructor's solution file is", basename(solution), "."))
  }
  
  if (!is.null(test_output)) {
    references <- c(references, paste("The student's test output file is", basename(test_output), "."))
  }
  
  return(paste(references, collapse = "\n"))
}

#' Generate file contents with line numbers
#'
#' @param file_paths List of file paths to process
#' @param question Optional question heading to extract from files
#' @return Character string with file contents and line numbers
gather_file_contents <- function(file_paths, question = NULL) {
  file_contents <- ""

  for (file_path in file_paths) {
    if (is.null(file_path) || !file.exists(file_path)) next

    filename <- basename(file_path)
    lines <- NULL

    tryCatch({
      # Only extract the question block if question is set
      if (!is.null(question)) {
        if (grepl("\\.pdf$", filename, ignore.case = TRUE)) {
          text_block <- extract_question_from_pdf(file_path, question)
        } else {
          text_block <- extract_question_from_txt(file_path, question)
        }
        lines <- strsplit(text_block, "\n")[[1]]
      } else {
        if (grepl("\\.pdf$", filename, ignore.case = TRUE)) {
          text_content <- extract_pdf_text(file_path)
          lines <- strsplit(text_content, "\n")[[1]]
        } else {
          lines <- readLines(file_path, warn = FALSE)
        }
      }

      # Common processing for all file types
      file_contents <- paste0(file_contents, "=== ", filename, " ===\n")
      for (i in seq_along(lines)) {
        stripped_line <- trimws(lines[i], which = "right")
        file_contents <- paste0(file_contents, "(Line ", i, ") ", stripped_line, "\n")
      }
      file_contents <- paste0(file_contents, "\n")

    }, error = function(e) {
      cat("Error reading file", filename, ":", e$message, "\n")
    })
  }

  return(file_contents)
}


#' Extract text from PDF files
#'
#' @param pdf_path Path to PDF file
#' 
#' @return Character string with extracted text
extract_pdf_text <- function(pdf_path) {
  tryCatch({
    # Try to use pdftools (R equivalent of PyPDF2)
    text <- pdftools::pdf_text(pdf_path)
    return(paste(text, collapse = "\n"))
  }, error = function(e) {
    cat("Error extracting text from PDF", basename(pdf_path), ":", e$message, "\n")
    return(paste0("[Error: Could not extract text from PDF ", basename(pdf_path), "]"))
  })
}

flatten_toc <- function(toc, level = 1) {
  flat_list <- list()
  for (item in toc) {
    flat_list <- append(flat_list, list(list(
      title = item$title,
      page = item$page %||% NA_integer_,
      level = level
    )))
    if (!is.null(item$children) && length(item$children) > 0) {
      flat_list <- append(flat_list, flatten_toc(item$children, level + 1))
    }
  }
  return(flat_list)
}

#' Given a flattened TOC (table of contents) list and a specific heading title,
#' this function returns the title of the next heading that is at the same or higher
#' level in the hierarchy (i.e., not a child/subheading).
#'
#' @param toc A flattened list of TOC entries, as returned by \code{flatten_toc()}.
#'            Each TOC entry should have at least \code{title} and \code{level} fields.
#' @param heading A character string representing the heading title to search for.
#'
#' @return The title (character string) of the next heading at the same or higher level,
#'         or \code{NULL} if there is no such heading.
get_next_heading_title <- function(toc, heading) {
  cat("Finding next heading after:", heading, "\n")
  matches <- which(tolower(sapply(toc, `[[`, "title")) == tolower(heading))
  if (length(matches) == 0) return(NULL)

  match_index <- matches[length(matches)]
  start_level <- toc[[match_index]]$level
  print(match_index)
  print(start_level)
  print(length(toc))
  if (match_index >= length(toc)) {
    return(NULL)  # No next heading available
  }
  for (i in (match_index + 1):length(toc)) {
    print(toc[[i]])
    if (toc[[i]]$level <= start_level) {
      return(toc[[i]]$title)
    }
  }

  return(NULL)
}

# Safe null-coalescing operator
`%||%` <- function(a, b) if (!is.null(a)) a else b

#' Normalize Text for Consistent Matching
#'
#' @param x A character vector or string to normalize.
#'
#' @return A character vector with normalized text.
normalize_text <- function(x) {
  x <- gsub("[\r\n\t]", " ", x)
  x <- gsub("[‘’´`]", "'", x)
  x <- gsub("[“”]", "\"", x)
  x <- gsub("–|—", "-", x)
  x <- gsub("\\s+", " ", x)
  tolower(trimws(x))
}

#' Extract question content using PDF bookmarks (outline headings) using PyMuPDF
#'
#' @param pdf_path Path to the PDF file
#' @param heading Title of the heading to extract (e.g., "Question 1")
#' @return Text block under that heading, up to the next heading
extract_question_from_pdf <- function(pdf_path, heading) {

  if (!file.exists(pdf_path)) {
    stop("File not found:", pdf_path)
  }

  # Load and flatten TOC
  toc_full <- pdf_toc(pdf_path)
  toc <- flatten_toc(toc_full$children)

  norm_titles <- normalize_text(sapply(toc, `[[`, "title"))
  norm_heading <- normalize_text(heading)

  matches <- which(norm_titles == norm_heading)
  if (length(matches) == 0) {
    stop("Heading '", heading, "' not found in TOC")
  }

  next_heading_title <- get_next_heading_title(toc, heading)
  # Read full text
  full_text <- pdf_text(pdf_path)
  lines <- unlist(strsplit(paste(full_text, collapse = "\n"), "\n"))
  norm_lines <- normalize_text(trimws(lines))

  # Locate start of heading
  start_idx <- which(norm_lines == norm_heading)
  if (length(start_idx) == 0) {
    stop("Heading '", heading, "' not found in text")
  }

  start_line <- start_idx[1]
  end_line <- length(lines)

  # Locate next heading line
  if (!is.null(next_heading_title)) {
    norm_next <- normalize_text(next_heading_title)
    next_idx <- which(norm_lines == norm_next)
    if (length(next_idx) > 0 && next_idx[1] > start_line) {
      end_line <- next_idx[1] - 1
    }
  }

  # Defensive bounds check
  if (start_line > end_line || start_line < 1 || end_line < 1) {
    stop("Invalid line bounds: start =", start_line, ", end =", end_line)
  }

  extracted <- lines[start_line:end_line]
  return(paste(trimws(extracted), collapse = "\n"))
}


#' Extract a specific question block from a submission file
#' @param submission Path to the submission file
#' @param question The exact heading string to look for
#' @return Text block belonging to the specified question
extract_question_from_txt <- function(submission, question) {
  if (!file.exists(submission)) {
    return(paste0("[Error: Submission file ", basename(submission), " not found]"))
  }

  lines <- readLines(submission, warn = FALSE)

  # Find the exact heading that matches the question identifier
  start_idx <- grep(paste0("^\\s*", question, "\\b"), lines, ignore.case = TRUE)
  if (length(start_idx) == 0) {
    stop("Could not find '", question, "' in submission")
  }

  question_prefix <- regmatches(question, regexpr("^[^0-9a-zA-Z]*", question))

  # Pattern to detect next heading that starts similarly
  heading_pattern <- paste0("^\\s*", question_prefix, "\\s*[0-9]+[a-zA-Z\\.\\(\\)]*\\b")

  # Find the next matching heading line after current
  next_heading <- grep(heading_pattern, lines, ignore.case = TRUE)
  next_heading <- next_heading[next_heading > start_idx[1]]

  # Determine end of block
  end_idx <- if (length(next_heading) > 0) next_heading[1] - 1 else length(lines)

  extracted <- paste(lines[start_idx[1]:end_idx], collapse = "\n")
  return(extracted)
}
