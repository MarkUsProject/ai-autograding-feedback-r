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
      system_instructions,
      submission_image = NULL,
      solution_image = NULL
    ) {
      #' Generate a model response using the prompt and optional file paths.
      #'
      #' @param prompt A character string prompt for the model
      #' @param system_instructions System-level model instructions
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

      response <- POST(url = self$remote_url, body = body, encode = "multipart", headers)
      if (response$status_code != 200) {
        stop(sprintf("Remote API call failed [HTTP %s]: %s",
                     response$status_code, content(response, "text")))
      }

      parsed <- content(response, as = "parsed", type = "application/json")
      return(list(prompt = prompt, response = parsed))
    }
  )
)
