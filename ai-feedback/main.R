# main.R
source("ai-feedback/image_processing.R")
source("ai-feedback/code_processing.R")
source("ai-feedback/text_processing.R")

# Load required libraries
suppressWarnings(suppressMessages({
  library(optparse)
  library(jsonlite)
}))

# Load markdown prompt file
load_markdown_prompt <- function(prompt_name, script_dir) {
  prompt_file <- file.path("ai-feedback", "data", "prompts", "user", paste0(prompt_name, ".md"))
  if (!file.exists(prompt_file)) {
    stop(paste("Error: Prompt file not found:", prompt_file))
  }
  list(prompt_content = paste(readLines(prompt_file), collapse = "\n"))
}

# Load markdown output template
load_markdown_template <- function(template, script_dir) {
  template_file <- file.path('ai-feedback', "data", "output", paste0(template, ".md"))
  if (!file.exists(template_file)) {
    stop(paste("Error: Template file not found:", template_file))
  }
  paste(readLines(template_file), collapse = "\n")
}

get_script_dir <- function() {
  # Detect script path whether using Rscript or source()
  cmdArgs <- commandArgs(trailingOnly = FALSE)
  match <- grep("--file=", cmdArgs)
  if (length(match) > 0) {
    return(dirname(normalizePath(sub("--file=", "", cmdArgs[match]))))
  } else {
    return(dirname(normalizePath(sys.frames()[[1]]$ofile)))
  }
}

main <- function(
  prompt = NULL,
  prompt_text = NULL,
  prompt_custom = NULL,
  scope,
  submission,
  solution = "",
  model,
  remote_model,
  output = "",
  submission_image = NULL,
  solution_image = NULL,
  output_template = "response_only",
  system_prompt = "student_test_feedback"
) {
  script_dir <- get_script_dir()
  prompt_content <- ""
  system_prompt_path <- file.path('ai-feedback', "data", "prompts", "system", paste0(system_prompt, ".md"))
  system_instructions <- paste(readLines(system_prompt_path), collapse = "\n")

  if (!is.null(prompt_custom)) {
    prompt_content <- paste(readLines(prompt_custom), collapse = "\n")
  } else {
    if (!is.null(prompt)) {
      if (!startsWith(prompt, scope)) {
        stop("Prompt prefix does not match scope.")
      }
      prompt_data <- load_markdown_prompt(prompt, script_dir)
      prompt_content <- paste0(prompt_content, prompt_data$prompt_content)
    }
    if (!is.null(prompt_text)) {
      prompt_content <- paste0(prompt_content, prompt_text)
    }
  }

  if (scope == "image") {
    response <- process_image(environment(), prompt_content, system_instructions)
  } else if (scope == "text") {
    response <- process_text(environment(), prompt_content, system_instructions)
  } else {
    response <- process_code(environment(), prompt_content, system_instructions)
  }

  markdown_template <- load_markdown_template(output_template, script_dir)
  output_text <- markdown_template
  output_text <- gsub("\\{model\\}", model, output_text)
  output_text <- gsub("\\{request\\}", prompt_content, output_text)
  output_text <- gsub("\\{response\\}", paste(response, collapse = "\n"), output_text)
  output_text <- gsub("\\{timestamp\\}", format(Sys.time(), "%Y%m%d_%H%M%S"), output_text)
  output_text <- gsub("\\{submission\\}", submission, output_text)

  if (output != "") {
    dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
    writeLines(output_text, output)
  } else {
    cat(output_text)
  }
}
