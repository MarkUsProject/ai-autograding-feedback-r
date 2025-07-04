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
  prompt_file <- file.path(script_dir, "data", "prompts", "user", paste0(prompt_name, ".md"))
  if (!file.exists(prompt_file)) stop(paste("Error: Prompt file not found:", prompt_file))
  list(prompt_content = paste(readLines(prompt_file), collapse = "\n"))
}

# Load markdown output template
load_markdown_template <- function(template, script_dir) {
  template_file <- file.path(script_dir, "data", "output", paste0(template, ".md"))
  if (!file.exists(template_file)) stop(paste("Error: Template file not found:", template_file))
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

main <- function() {
  option_list <- list(
    make_option("--prompt", type = "character"),
    make_option("--prompt_text", type = "character"),
    make_option("--prompt_custom", type = "character"),
    make_option("--scope", type = "character"),
    make_option("--submission", type = "character"),
    make_option("--solution", type = "character", default = ""),
    make_option("--model", type = "character"),
    make_option("--remote_model", type = "character"),
    make_option("--output", type = "character", default = ""),
    make_option("--submission_image", type = "character"),
    make_option("--solution_image", type = "character"),
    make_option("--output_template", type = "character", default = "response_only"),
    make_option("--system_prompt", type = "character", default = "student_test_feedback")
  )

  parser <- OptionParser(option_list = option_list)
  args <- parse_args(parser)

  script_dir <- get_script_dir()
  prompt_content <- ""
  system_prompt_path <- file.path(script_dir, "data", "prompts", "system", paste0(args$system_prompt, ".md"))
  system_instructions <- paste(readLines(system_prompt_path), collapse = "\n")
  
  if (!is.null(args$prompt_custom)) {
    prompt_content <- paste(readLines(args$prompt_custom), collapse = "\n")
  } else {
    if (!is.null(args$prompt)) {
      if (!startsWith(args$prompt, args$scope)) stop("Prompt prefix does not match scope.")
      prompt <- load_markdown_prompt(args$prompt, script_dir)
      prompt_content <- paste0(prompt_content, prompt$prompt_content)
    }
    if (!is.null(args$prompt_text)) {
      prompt_content <- paste0(prompt_content, args$prompt_text)
    }
  }

  if (args$scope == "image") {
    response <- process_image(args, prompt_content, system_instructions)
  } else if (args$scope == "text") {
    response <- process_text(args, prompt_content, system_instructions)
  } else {
    response <- process_code(args, prompt_content, system_instructions)
  }

  markdown_template <- load_markdown_template(args$output_template, script_dir)
  output_text <- markdown_template
  output_text <- gsub("\\{model\\}", args$model, output_text)
  output_text <- gsub("\\{request\\}", prompt_content, output_text)
  output_text <- gsub("\\{response\\}", paste(response, collapse = "\n"), output_text)
  output_text <- gsub("\\{timestamp\\}", format(Sys.time(), "%Y%m%d_%H%M%S"), output_text)
  output_text <- gsub("\\{submission\\}", args$submission, output_text)

  if (args$output != "") {
    dir.create(dirname(args$output), recursive = TRUE, showWarnings = FALSE)
    writeLines(output_text, args$output)
  } else {
    cat(output_text)
  }
}

main()
