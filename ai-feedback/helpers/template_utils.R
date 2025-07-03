# helpers/template_utils.r

# Load required libraries (matching Python imports)
library(pdftools)

#' Render a prompt template by replacing placeholders with actual values
#'
#' @param prompt_content Character string with placeholders like {file_contents}
#' @param submission Path to student's submission file
#' @param solution Path to instructor's solution file (optional)
#' @param test_output Path to test output file (optional)
#' @param has_submission_image Whether submission image is present
#' @param has_solution_image Whether solution image is present
#' @param ... Additional key-value pairs for placeholder replacement
#'
#' @return Character string with placeholders replaced
render_prompt_template <- function(
  prompt_content,
  submission = NULL,
  solution = NULL,
  test_output = NULL,
  has_submission_image = FALSE,
  has_solution_image = FALSE,
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
    template_data$file_contents <- gather_file_contents(files_to_process)
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
#' 
#' @return Character string with file contents and line numbers
gather_file_contents <- function(file_paths) {
  file_contents <- ""
  
  for (file_path in file_paths) {
    if (is.null(file_path) || !file.exists(file_path)) {
      next
    }
    
    filename <- basename(file_path)
    
    tryCatch({
      if (grepl("\\.pdf$", filename, ignore.case = TRUE)) {
        # Handle PDF files
        text_content <- extract_pdf_text(file_path)
        file_contents <- paste0(file_contents, "=== ", filename, " ===\n")
        lines <- strsplit(text_content, "\n")[[1]]
        
        for (i in seq_along(lines)) {
          stripped_line <- trimws(lines[i], which = "right")
          if (nzchar(stripped_line)) {
            file_contents <- paste0(file_contents, "(Line ", i, ") ", stripped_line, "\n")
          } else {
            file_contents <- paste0(file_contents, "(Line ", i, ") \n")
          }
        }
        file_contents <- paste0(file_contents, "\n")
        
      } else {
        # Handle regular text files
        lines <- readLines(file_path, warn = FALSE)
        file_contents <- paste0(file_contents, "=== ", filename, " ===\n")
        
        for (i in seq_along(lines)) {
          stripped_line <- trimws(lines[i], which = "right")
          if (nzchar(stripped_line)) {
            file_contents <- paste0(file_contents, "(Line ", i, ") ", stripped_line, "\n")
          } else {
            file_contents <- paste0(file_contents, "(Line ", i, ") ", lines[i], "\n")
          }
        }
        file_contents <- paste0(file_contents, "\n")
      }
      
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

#' Gather image context for image-based prompts
#'
#' @param output_directory Directory containing extracted images
#' @param question Question identifier
#' 
#' @return Character string with question context
gather_image_context <- function(output_directory, question) {
  tryCatch({
    context_file <- file.path(output_directory, question, "context.txt")
    if (file.exists(context_file)) {
      return(paste(readLines(context_file), collapse = "\n"))
    } else {
      return(paste("Context for question", question))
    }
  }, error = function(e) {
    cat("Error reading question context:", e$message, "\n")
    return("")
  })
}
