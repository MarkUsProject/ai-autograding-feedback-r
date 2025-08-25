# text_processing.R

#' Process text-based submissions and generate model feedback.
#'
#' This function loads submission and solution files, constructs a prompt,
#' and uses the selected model to generate a response.
#'
#' @param args A list of arguments
#' @param prompt A string containing the prompt template.
#' @param system_instructions A string of system-level instructions for the model.
#' @param marking_instructions Optional marking instructions.
#' @param json_schema Optional JSON schema for structured response.
#' @return A list of two elements: request and response from the model.
#' @examples
#' # Assuming valid args and prompt setup
#' result <- process_text(args, prompt, system_instructions)
process_text <- function(args, prompt, system_instructions, marking_instructions = NULL, json_schema = NULL) {
  if (!file.exists(args$submission)) {
    stop(paste("Submission file not found:", args$submission))
  }
  submission_file <- args$submission

  solution_file <- NULL
  if (!is.null(args$solution) && args$solution != "") {
    if (!file.exists(args$solution)) {
      stop(paste("Solution file not found:", args$solution))
    }
    solution_file <- args$solution
  }

  test_output_file <- NULL
  if (!is.null(args$test_output) && args$test_output != "") {
    if (!file.exists(args$test_output)) {
      stop(paste("Test output file not found:", args$test_output))
    }
    test_output_file <- args$test_output
  }

  # Pass file paths to template renderer
  prompt <- render_prompt_template(
    prompt_content = prompt,
    submission = submission_file,
    solution = solution_file,
    test_output = test_output_file,
    system_instructions = system_instructions,
    question = args$question,
    marking_instructions = marking_instructions
  )

  model_class <- model_mapping[[args$model]]
  if (is.null(model_class)) {
    stop("Invalid model selected for text scope.")
  }

  if (identical(model_class, RemoteModel) && !is.null(args$remote_model) && args$remote_model != "") {
    model <- model_class$new(model_name = args$remote_model)
  } else {
    model <- model_class$new()
  }

  combined_prompt <- paste0(
    "System Instructions:\n", system_instructions, "\n\n",
    "User Prompt:\n", prompt
  )

  result <- model$generate_response(prompt = prompt, system_instructions = system_instructions, json_schema = json_schema)

  return(list(combined_prompt, result$response))
}
