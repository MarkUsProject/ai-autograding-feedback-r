# RemoteModel.R

library(httr)
library(jsonlite)
library(dotenv)
library(R6)

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
      submission_images = NULL,
      solution_image = NULL,
      json_schema = NULL
    ) {
      #' Generate a model response using the prompt and optional file paths.
      #'
      #' @param prompt A character string prompt for the model
      #' @param system_instructions System-level model instructions
      #' @param submission_images Optional file paths to submission images
      #' @param solution_image Optional file path to solution image
      #' @param json_schema Optional JSON schema for structured response
      #' @return A list with prompt and model response text, or NULL if failed

      # Load environment variables from .env
      dotenv::load_dot_env()

      api_key <- Sys.getenv("REMOTE_API_KEY")
      if (api_key == "") {
        stop("REMOTE_API_KEY not found in environment.")
      }

      headers <- httr::add_headers(`X-API-KEY` = api_key)
      schema <- NULL
      if (!is.null(json_schema)) {
        schema <- jsonlite::fromJSON(json_schema)$schema
      }

      body <- list(
        content = prompt,
        model = self$model_name,
        system_instructions = system_instructions,
        json_schema = schema
      )

      response <- httr::POST(url = self$remote_url, body = body, encode = "multipart", headers)
      if (response$status_code != 200) {
        stop(sprintf("Remote API call failed [HTTP %s]: %s",
                     response$status_code, httr::content(response, "text")))
      }

      parsed <- httr::content(response, as = "parsed", type = "application/json")
      return(list(prompt = prompt, response = parsed))
    }
  )
)
