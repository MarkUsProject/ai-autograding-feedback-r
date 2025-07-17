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

      # Format the extracted lines
      file_contents <- paste0(file_contents, "=== ", filename, " ===\n")
      for (i in seq_along(lines)) {
        stripped <- trimws(lines[i], which = "right")
        file_contents <- paste0(file_contents, "(Line ", i, ") ", stripped, "\n")
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

#' Extract question content using PDF bookmarks (outline headings) using PyMuPDF
#'
#' @param pdf_path Path to the PDF file
#' @param heading Title of the heading to extract (e.g., "Question 1")
#' @return Text block under that heading, up to the next heading
extract_question_from_pdf <- function(pdf_path, heading) {
  if (!file.exists(pdf_path)) {
    stop("Error: File ", basename(pdf_path), " not found")
  }

  fitz <- reticulate::import("fitz", delay_load = TRUE)
  doc <- fitz$open(pdf_path)
  toc <- doc$get_toc()

  # Find heading in ToC
  cat(heading, "\n")
  matches <- which(sapply(toc, function(entry) {
    tolower(entry[[2]]) == tolower(heading)
  }))

  if (length(matches) == 0) {
    stop("Heading '", heading, "' not found in PDF bookmarks")
  }

  match_index <- matches[1] - 1
  start_page <- toc[[match_index]][[3]]
  start_level <- toc[[match_index]][[1]]

  next_index <- NA
  for (i in (match_index + 2):length(toc)) {
    next_level <- toc[[i]][[1]]
    if (next_level <= start_level) {
      next_index <- i
      break
    }
  }
  next_heading_title <- if (!is.na(next_index)) toc[[next_index]][[2]] else NULL

  end_page <- if (!is.na(next_index)) {
    toc[[next_index]][[3]] - 1
  } else {
    doc$page_count - 1  # include till end
  }

  if (end_page == start_page) {
    end_page <- end_page + 1
  }

  text <- ""
  found_end_heading <- FALSE

  for (i in start_page:end_page) {
    if (found_end_heading) break

    page <- doc$load_page(i)
    page_dict <- page$get_text("dict")

    for (block in page_dict$blocks) {
      if (!is.null(block$lines)) {
        for (line in block$lines) {
          line_text <- paste(sapply(line$spans, function(span) span$text), collapse = "")

          # Early stop if we hit the next heading
          if (!is.null(next_heading_title) &&
                i == end_page &&
                tolower(trimws(line_text)) == tolower(trimws(next_heading_title))) {
            found_end_heading <- TRUE
            break
          }

          text <- paste0(text, line_text, "\n")
        }
      }
      if (found_end_heading) break
    }
  }

  doc$close()
  return(text)
}

#' Extract a specific question block from a submission file
#' @param submission Path to the submission file
#' @param question The exact heading string to look for
#' @return Text block belonging to the specified question
extract_question_from_txt <- function(submission, question) {
  if (!file.exists(submission)) {
    return(paste0("[Error: Submission file ", basename(submission), " not found]"))
  }

  # Read and split file
  lines <- readLines(submission, warn = FALSE)

  # Find the exact heading that matches the question identifier
  start_idx <- grep(paste0("^\\s*", question, "\\b"), lines, ignore.case = TRUE)
  if (length(start_idx) == 0) {
    stop("Could not find '", question, "' in submission")
  }

  # Generalize: get prefix of the question (e.g., "Question", "Q", "Task", etc.)
  question_prefix <- regmatches(question, regexpr("^[^0-9a-zA-Z]*", question))

  # Pattern to detect next heading that starts similarly
  # E.g., if question is "Question 2a", we look for "Question ..." later on
  heading_pattern <- paste0("^\\s*", question_prefix, "\\s*[0-9]+[a-zA-Z\\.\\(\\)]*\\b")

  # Find the next matching heading line after current
  next_heading <- grep(heading_pattern, lines, ignore.case = TRUE)
  next_heading <- next_heading[next_heading > start_idx[1]]

  # Determine end of block
  end_idx <- if (length(next_heading) > 0) next_heading[1] - 1 else length(lines)

  extracted <- paste(lines[start_idx[1]:end_idx], collapse = "\n")
  return(extracted)
}

