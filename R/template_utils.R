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
#' @param question Question identifier for {question_images} placeholder (optional)
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
        lines <- strsplit(text_content, "\n")[[1]]
      } else {
        # Handle regular text files
        lines <- readLines(file_path, warn = FALSE)
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
        library(knitr)
        library(evaluate)  
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
  
  for (i in seq_along(content)) {
    line <- trimws(content[i])
    
    if (grepl("^# ", line)) {
      # Main question: # Question 1
      if (grepl("^# Question [0-9]+", line, ignore.case = TRUE)) {
        match <- regmatches(line, regexpr("[0-9]+", line))
        if (length(match) > 0) {
          current_main <- paste0("Q", match[1])
          current_sub <- NULL
        }
      }
    } else if (grepl("^## ", line)) {
      # Sub-question: ## (a)
      if (grepl("^## \\([a-z]\\)", line)) {
        match <- regmatches(line, regexpr("\\([a-z]\\)", line))
        if (length(match) > 0) {
          sub_letter <- gsub("[^a-z]", "", match[1])
          current_sub <- sub_letter
        }
      }
    }
    
    # Handle R code chunks
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
    }
  }
  
  return(chunk_list)
}

#' Legacy wrapper for backward compatibility
#' @param qmd_path Path to QMD file
#' @param target_question Question section
#' @param output_dir Output directory
#' @return Character vector of PNG file paths
execute_student_code_for_images <- function(qmd_path, target_question = NULL, output_dir = NULL) {
  all_png_files <- run_qmd_collect_png(qmd_path, timeout = 60, output_dir = output_dir)
  
  # If target_question specified, filter results
  if (!is.null(target_question)) {
    question_pattern <- if (grepl("^\\([a-z]\\)$", target_question)) {
      # Sub-question like "(a)"
      paste0("__", gsub("[^a-z]", "", target_question), "__")
    } else if (grepl("^[Qq]uestion\\s*\\d+", target_question)) {
      # Main question like "Question 1"  
      paste0("Q", gsub(".*([0-9]+).*", "\\1", target_question), "__")
    } else {
      target_question
    }
    
    all_png_files <- all_png_files[grepl(question_pattern, basename(all_png_files))]
  }
  
  return(all_png_files)
}
