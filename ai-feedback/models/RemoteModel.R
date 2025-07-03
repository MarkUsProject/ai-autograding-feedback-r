# RemoteModel.R

library(httr)
library(jsonlite)
library(dotenv)
library(R6)

# Load environment variables from .env
load_dot_env()

# Define RemoteModel class
RemoteModel <- R6Class("RemoteModel",
  public = list(
    remote_url = NULL,
    model_name = NULL,

    initialize = function(
      remote_url = "http://polymouth.teach.cs.toronto.edu:5000/chat",
      model_name = "deepseek-coder-v2:latest"
    ) {
      #' Initialize RemoteModel with a remote URL and model name
      self$remote_url <- remote_url
      self$model_name <- model_name
    },

    generate_response = function(
      prompt,
      submission_file,
      system_instructions,
      solution_file = NULL,
      question_num = NULL,
      test_output = NULL,
      scope = NULL,
      llama_mode = NULL,
      submission_image = NULL
    ) {
      #' Generate a model response using the prompt and optional file paths.
      #'
      #' @param prompt A character string prompt for the model
      #' @param submission_file Path to the student's submission
      #' @param system_instructions System-level model instructions
      #' @param solution_file Optional path to solution file
      #' @param question_num Optional question number
      #' @param test_output Optional path to test output
      #' @param scope Optional string to define task scope
      #' @param llama_mode Optional llama-specific mode
      #' @param submission_image Optional path to image to include
      #' @return A list with prompt and model response text, or NULL if failed

      api_key <- Sys.getenv("REMOTE_API_KEY")
      if (api_key == "") {
        stop("REMOTE_API_KEY not found in environment.")
      }

      headers <- add_headers(`X-API-KEY` = api_key)
      body <- list(
        content = prompt,
        model = self$model_name,
        system_instructions = system_instructions
      )
      if (!is.null(llama_mode)) {
        body$llama_mode <- llama_mode
      }

      files <- NULL
      if (!is.null(submission_image)) {
        file_name <- basename(submission_image)
        files <- upload_file(submission_image)
        body[[file_name]] <- files
      }

      response <- POST(url = self$remote_url, body = body, encode = "multipart", headers)
      if (response$status_code != 200) {
        warning("Failed to get a valid response from server")
        return(NULL)
      }

      parsed <- content(response, as = "parsed", type = "application/json")
      return(list(prompt = prompt, response = parsed))
    }
  )
)
