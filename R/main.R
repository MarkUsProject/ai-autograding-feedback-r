# main.R
# Load required libraries
suppressWarnings(suppressMessages({
  library(optparse)
  library(jsonlite)
}))

# Load markdown output template
load_file <- function(file_path) {
  if (!file.exists(file_path)) {
    stop(paste("Error: Template file not found:", file_path))
  }
  paste(readLines(file_path), collapse = "\n")
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
  output_template = NULL,
  system_prompt = NULL,
  question = NULL,
  marking_instructions = NULL
) {
  prompt_content <- ""
  system_instructions <- ""
  marking_instructions_content <- NULL
  
  if (!is.null(system_prompt) && system_prompt != ""){
    system_instructions <- paste(readLines(system_prompt), collapse = "\n")
  }

  # Load marking instructions if provided
  if (!is.null(marking_instructions) && marking_instructions != "") {
    tryCatch({
      marking_instructions_content <- paste(readLines(marking_instructions), collapse = "\n")
    }, error = function(e) {
      stop("Error reading marking instructions file")
    })
  }

  if (!is.null(prompt_custom)) {
    prompt_content <- prompt_custom
  } else {
    if (!is.null(prompt)) {
      prompt_data <- load_file(prompt)
      prompt_content <- paste0(prompt_content, prompt_data)
    } else {
      stop("No prompt provided. Please specify a prompt file or text.")
    }
    if (!is.null(prompt_text)) {
      prompt_content <- paste0(prompt_content, prompt_text)
    }
  }

  if (prompt_content == "") {
    stop("No prompt content provided. Please specify a prompt.")
  }

  if (scope == "image") {
    response <- process_image(environment(), prompt_content, system_instructions, marking_instructions_content)
  } else if (scope == "text") {
    response <- process_text(environment(), prompt_content, system_instructions, marking_instructions_content)
  } else {
    response <- process_code(environment(), prompt_content, system_instructions, marking_instructions_content)
  }

  if (!is.null(output_template) && file.exists(output_template)) {
    markdown_template <- load_file(output_template)
  } else {
    markdown_template <- "{response}"
  }
  output_text <- markdown_template
  output_text <- gsub("\\{model\\}", model, output_text)
  output_text <- gsub("\\{request\\}", prompt_content, output_text)
  output_text <- gsub("\\{response\\}", paste(response[[2]], collapse = "\n"), output_text)
  output_text <- gsub("\\{timestamp\\}", format(Sys.time(), "%Y%m%d_%H%M%S"), output_text)
  output_text <- gsub("\\{submission\\}", submission, output_text)

  if (output != "") {
    dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
    writeLines(output_text, output)
  } else {
    cat(output_text)
  }
}
