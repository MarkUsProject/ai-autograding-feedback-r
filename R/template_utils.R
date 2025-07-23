# helpers/template_utils.R

library(pdftools)

#' Render a prompt template by replacing placeholders with actual values
#'
#' @param prompt_content Character string with placeholders like {file_contents}
#' @param submission Path to student's submission file
#' @param solution Path to instructor's solution file (optional)
#' @param test_output Path to test output file (optional)
#' @param has_submission_image Whether submission image is present
#' @param has_solution_image Whether solution image is present
#' @param question Question identifier
#' @param ... Additional key-value pairs for placeholder replacement
#'
#' @return Character string with placeholders replaced
#' 
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
    template_data$file_contents <- gather_file_contents(files_to_process)
  }
  
  # Handle image placeholders
  if (grepl("\\{submission_image\\}", prompt_content) && !("submission_image" %in% names(template_data))) {
    if (has_submission_image && has_solution_image) {
      template_data$submission_image <- "The attached images include the student's submission plots and the expected solution."
    } else if (has_submission_image) {
      template_data$submission_image <- "The attached images are the student's submission plots."
    } else {
      template_data$submission_image <- "[Submission Images Attached]"
    }
  }
  
  if (grepl("\\{solution_image\\}", prompt_content) && !("solution_image" %in% names(template_data))) {
    if (has_submission_image && has_solution_image) {
      template_data$solution_image <- "The final attached image is the expected solution."
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
  
  remaining_placeholders <- regmatches(result, gregexpr("\\{[a-zA-Z_][a-zA-Z0-9_]+\\}", result))[[1]]
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
    if (is.null(file_path) || !file.exists(file_path)){
      next
    }
    
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
          lines <- readLines(file_path)
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

#' Converts a nested list of TOC entries (as returned by \code{pdf_toc()}) into a flat list,
#' preserving heading titles, page numbers, and their respective hierarchy levels.
#'
#' @param toc A list of TOC entries
#' @param level The current heading level (defaults to 1). Used internally during recursion.
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
  matches <- which(tolower(sapply(toc, `[[`, "title")) == tolower(heading))
  if (length(matches) == 0){
    return(NULL)
  }

  match_index <- matches[length(matches)]
  start_level <- toc[[match_index]]$level

  if (match_index >= length(toc)) {
    return(NULL)  # No next heading available
  }
  for (i in (match_index + 1):length(toc)) {
    if (toc[[i]]$level <= start_level) {
      return(toc[[i]]$title)
    }
  }

  return(NULL)
}

# Safe null-coalescing operator
`%||%` <- function(a, b){
  if (is.null(a)) {
    return(b)
  } else {
    return(a)
  }
}

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

#' Extract question content using PDF bookmarks (outline headings) using pdftools
#'
#' @param pdf_path Path to the PDF file
#' @param heading Title of the heading to extract (e.g., "Question 1")
#' @return Text block under that heading, up to the next heading
extract_question_from_pdf <- function(pdf_path, heading) {

  if (!file.exists(pdf_path)) {
    stop(paste0("[Error: Submission file ", basename(pdf_path), " not found]"))
  }

  # Load and flatten TOC
  toc_full <- pdf_toc(pdf_path)
  toc <- flatten_toc(toc_full$children)

  norm_titles <- normalize_text(sapply(toc, `[[`, "title"))
  norm_heading <- normalize_text(heading)

  matches <- which(norm_titles == norm_heading)
  if (length(matches) == 0) {
    stop("Question heading '", heading, "' not found in TOC")
  }

  next_heading_title <- get_next_heading_title(toc, heading)
  # Read full text
  full_text <- pdf_text(pdf_path)
  lines <- unlist(strsplit(paste(full_text, collapse = "\n"), "\n"))
  norm_lines <- normalize_text(trimws(lines))

  # Locate start of heading
  start_idx <- which(norm_lines == norm_heading)
  if (length(start_idx) == 0) {
    stop("Question heading '", heading, "' not found in text")
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

  lines <- readLines(submission)

  normalize_text <- function(x) {
    tolower(trimws(gsub("\\s+", " ", x)))
  }

  # Identify all Markdown headers and their levels
  header_lines <- grep("^#{1,6}\\s+.*", lines)
  header_levels <- nchar(gsub("\\s.*", "", lines[header_lines]))
  header_texts <- normalize_text(sub("^#{1,6}\\s+", "", lines[header_lines]))

  # Find the starting heading
  norm_question <- normalize_text(question)
  match_idx <- which(header_texts == norm_question)

  if (length(match_idx) == 0) {
    stop("Could not find question heading '", question, "' in submission")
  }

  start_line <- header_lines[match_idx[1]]
  current_level <- header_levels[match_idx[1]]

  # Find the next heading of the same or higher level
  next_idx <- which(header_lines > start_line & header_levels <= current_level)
  if (length(next_idx) > 0) {
    end_line <- header_lines[next_idx[1]] - 1
  } else {
    end_line <- length(lines)
  }
  # Extract the block
  extracted <- paste(lines[start_line:end_line], collapse = "\n")
  return(extracted)
}

#' Extract R code and context from QMD/RMD file using simple parsing
#' @param qmd_path Path to QMD/RMD file
#' @param timeout Timeout in seconds for code execution  
#' @param output_dir Output directory (default: tempdir())
#' @return Character vector of PNG file paths
run_qmd_collect_png <- function(qmd_path, timeout = 60, output_dir = NULL) {
  if (!file.exists(qmd_path)) {
    stop("QMD file not found: ", qmd_path)
  }
  
  if (is.null(output_dir)) {
    output_dir <- tempdir()
  }
  
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  tryCatch({
    code_chunks <- extract_qmd_chunks_with_context(qmd_path)
    
    if (length(code_chunks) == 0) {
      warning("No R chunks with question context found")
      return(character(0))
    }
    
    abs_output_dir <- normalizePath(output_dir, mustWork = TRUE)
    
    # Execute in child process with plot capture
    png_files <- callr::r_safe(
      function(qmd_path, code_chunks, output_dir_path) { 
        library(withr)
        library(tidyverse)
        
        png_files <- character(0)
        plot_counters <- new.env()
        
        temp_dir <- dirname(qmd_path)
        
        withr::with_dir(temp_dir, {
          # Disable default PDF device to prevent Rplots.pdf
          options(device = function() pdf(NULL))
          
          for (chunk_info in code_chunks) {
            context_tag <- chunk_info$context
            code_lines <- chunk_info$code
            
            if (length(code_lines) > 0) {
              tryCatch({
                
                # Initialize counter for this context
                if (!exists(context_tag, envir = plot_counters)) {
                  assign(context_tag, 0, envir = plot_counters)
                }
                
                # Track ggplot objects before execution
                env_before <- ls(envir = globalenv())
                ggplots_before <- character(0)
                for (obj_name in env_before) {
                  obj <- get(obj_name, envir = globalenv())
                  if (inherits(obj, "ggplot")) {
                    ggplots_before <- c(ggplots_before, obj_name)
                  }
                }
                
                code_text <- paste(code_lines, collapse = "\n")
                eval(parse(text = code_text), envir = globalenv())
                
                env_after <- ls(envir = globalenv())
                context_pattern <- gsub("__", "", tolower(context_tag))
                
                new_ggplot_objects <- character(0)
                for (obj_name in env_after) {
                  obj <- get(obj_name, envir = globalenv())
                  if (inherits(obj, "ggplot") && 
                      grepl(paste0("^", context_pattern), tolower(obj_name)) &&
                      !obj_name %in% ggplots_before) {
                    new_ggplot_objects <- c(new_ggplot_objects, obj_name)
                  }
                }
                
                code_lines_clean <- code_lines[!grepl("^#", trimws(code_lines))]
                assignment_order <- character(0)
                
                for (line in code_lines_clean) {
                  for (plot_name in new_ggplot_objects) {
                    if (grepl(paste0("^\\s*", plot_name, "\\s*<-"), line)) {
                      if (!plot_name %in% assignment_order) {
                        assignment_order <- c(assignment_order, plot_name)
                      }
                    }
                  }
                }
                
                for (plot_name in assignment_order) {
                  plot_obj <- get(plot_name, envir = globalenv())
                  
                  counter <- get(context_tag, envir = plot_counters) + 1
                  assign(context_tag, counter, envir = plot_counters)
                  
                  png_filename <- file.path(
                    output_dir_path,
                    sprintf("plot__%s__%03d.png", context_tag, counter)
                  )
                  
                  tryCatch({
                    ggsave(png_filename, plot_obj, width = 8, height = 6, dpi = 120, device = "png")
                    png_files <- c(png_files, png_filename)
                    cat("Saved plot:", basename(png_filename), "\n")
                  }, error = function(e) {
                    cat("Error saving plot", plot_name, ":", e$message, "\n")
                  })
                }
                
              }, error = function(e) {
                cat("Error in chunk with context", context_tag, ":", e$message, "\n")
              })
            }
          }
          
          while (dev.cur() > 1) {
            dev.off()
          }
        })
        
        return(png_files)
      },
      args = list(qmd_path = qmd_path, code_chunks = code_chunks, output_dir_path = abs_output_dir),
      timeout = timeout
    )
    
    return(png_files)
    
  }, error = function(e) {
    warning("Error in child process execution: ", e$message)
    return(character(0))
  })
}

#' Extract R code chunks with question context using manual parsing
#' @param qmd_path Path to QMD file
#' @return List of chunk info with context and code
extract_qmd_chunks_with_context <- function(qmd_path) {
  content <- readLines(qmd_path, warn = FALSE)
  
  current_main <- NULL
  current_sub <- NULL
  chunk_list <- list()
  in_r_chunk <- FALSE
  current_chunk_code <- character(0)
  chunk_start_line <- 0
  
  # Helper function to clean heading text into context tag
  clean_heading_text <- function(text) {
    text <- trimws(text)
    
    # Extract common patterns first
    if (grepl("^\\([a-z]\\)", text)) {
      return(gsub("[^a-z]", "", regmatches(text, regexpr("\\([a-z]\\)", text))))
    }
    
    if (grepl("^(Question|Problem|Exercise)\\s*[0-9]+", text, ignore.case = TRUE)) {
      number_match <- regmatches(text, regexpr("[0-9]+", text))
      prefix <- if (grepl("^Question", text, ignore.case = TRUE)) "Q" else 
                if (grepl("^Problem", text, ignore.case = TRUE)) "P" else "E"
      return(paste0(prefix, number_match))
    }
    
    # For other cases, clean and truncate
    text <- gsub("[^a-zA-Z0-9]", "_", text)
    text <- gsub("_+", "_", text)
    text <- substr(text, 1, 20)
    text <- gsub("^_|_$", "", text)
    
    if (text == "") text <- "unknown"
    return(text)
  }
  
  for (i in seq_along(content)) {
    line <- trimws(content[i])
    
    # Handle R code chunks first
    if (grepl("^```\\{r", line)) {
      in_r_chunk <- TRUE
      current_chunk_code <- character(0)
      chunk_start_line <- i
    } else if (grepl("^```\\s*$", line) && in_r_chunk) {
      in_r_chunk <- FALSE
      
      if (!is.null(current_main)) {
        if (!is.null(current_sub)) {
          context_tag <- paste0(current_main, "__", current_sub)
        } else {
          context_tag <- current_main
        }
        
        if (length(current_chunk_code) > 0) {
          chunk_list[[length(chunk_list) + 1]] <- list(
            context = context_tag,
            code = current_chunk_code,
            start_line = chunk_start_line
          )
        }
      }
      
    } else if (in_r_chunk) {
      current_chunk_code <- c(current_chunk_code, content[i])
    } else if (!in_r_chunk && grepl("^# ", line)) {
      # extract everything after "# " when not in R chunk
      heading_text <- sub("^# ", "", line)
      current_main <- clean_heading_text(heading_text)
      current_sub <- NULL
    } else if (!in_r_chunk && grepl("^## ", line)) {
      # extract everything after "## " when not in R chunk
      heading_text <- sub("^## ", "", line)
      current_sub <- clean_heading_text(heading_text)
    }
  }
  
  return(chunk_list)
}
