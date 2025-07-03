# text_processing.R
source("ai-feedback/helpers/constants.R")

#' Process text-based submissions and generate model feedback.
#'
#' This function loads submission and solution files, constructs a prompt,
#' and uses the selected model to generate a response.
#'
#' @param args A list of arguments (typically from command-line parsing).
#' @param prompt A string containing the prompt template.
#' @param system_instructions A string of system-level instructions for the model.
#'
#' @return A list of two elements: request and response from the model.
#' @examples
#' # Assuming valid args and prompt setup
#' result <- process_text(args, prompt, system_instructions)
process_text <- function(args, prompt, system_instructions) {
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

  # prompt <- render_prompt_template(
  #   prompt,
  #   submission = submission_file,
  #   solution = solution_file,
  #   test_output = test_output_file,
  #   question_num = args$question
  # )

  model_class <- model_mapping[[args$model]]
  if (is.null(model_class)) {
    stop("Invalid model selected for text scope.")
  }

  if (model_class$name == "RemoteModel" && !is.null(args$remote_model)) {
    model <- model_class$new(model_name = args$remote_model)
  } else {
    model <- model_class$new()
  }

  if (!is.null(args$question)) {
    result <- model$generate_response(
      prompt = prompt,
      submission_file = submission_file,
      solution_file = solution_file,
      scope = args$scope,
      question_num = args$question,
      system_instructions = system_instructions,
      llama_mode = args$llama_mode
    )
  } else {
    result <- model$generate_response(
      prompt = prompt,
      submission_file = submission_file,
      solution_file = solution_file,
      scope = args$scope,
      system_instructions = system_instructions,
      llama_mode = args$llama_mode
    )
  }

  return(result)
}
