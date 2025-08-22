# code_processing.R

#' Process code-based assignment files and generate model feedback.
#'
#' This function loads the submission, solution, and test output files,
#' constructs a prompt using the template system, and dispatches to the
#' appropriate model to generate a feedback response.
#'
#' @param args A list of input arguments including submission path, model name,
#'        scope, solution path, optional question, and test output file.
#' @param prompt The user-defined prompt string, possibly with placeholders.
#' @param system_instructions A string passed to the model with system-level instructions.
#' @param marking_instructions Optional marking instructions
#' @param json_schema Optional JSON schema for structured response
#' @return A list of two elements: the full request string and the model's response.
#
#' @examples
#' result <- process_code(args, prompt, system_instructions)
process_code <- function(args, prompt, system_instructions, marking_instructions = NULL, json_schema = NULL) {
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

  prompt <- render_prompt_template(
    prompt_content = prompt,
    submission = submission_file,
    solution = solution_file,
    test_output = test_output_file,
    question = args$question,
    marking_instructions = marking_instructions
  )

  model_class <- model_mapping[[args$model]]
  if (is.null(model_class)) {
    stop("Invalid model selected for code scope.")
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
