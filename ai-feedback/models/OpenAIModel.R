source("ai-feedback/helpers/install_dependencies.R")
install_if_missing(c("httr", "jsonlite", "dotenv", "R6"))

library(httr)
library(jsonlite)
library(dotenv)
library(R6)

load_dot_env()  # Load .env variables like OPENAI_API_KEY

OpenAIModel <- R6Class("OpenAIModel",
  public = list(
    api_key = NULL,

    initialize = function() {
      #' Initialize the OpenAIModel instance by loading the API key.
      self$api_key <- Sys.getenv("OPENAI_API_KEY")
      if (self$api_key == "") {
        stop("OPENAI_API_KEY is not set in environment.")
      }
    },

    generate_response = function(
      prompt,
      submission_file,
      system_instructions,
      question_num = NULL,
      solution_file = NULL,
      test_output = NULL,
      scope = NULL,
      llama_mode = NULL
    ) {
      #' Generate a model response using the OpenAI API
      #'
      #' @param prompt User prompt
      #' @param submission_file Path to submission file (unused here)
      #' @param system_instructions System instructions
      #' @return A list with the original prompt and the model's response

      response_text <- self$private$call_openai(prompt, system_instructions)
      return(list(prompt = prompt, response = response_text))
    }
  ),

  private = list(
    call_openai = function(prompt, system_instructions) {
      #' Call OpenAI's chat completion API
      #' @return Response string

      url <- "https://api.openai.com/v1/chat/completions"

      headers <- add_headers(
        Authorization = paste("Bearer", self$api_key),
        `Content-Type` = "application/json"
      )

      body <- toJSON(list(
        model = "gpt-4-turbo",
        messages = list(
          list(role = "system", content = system_instructions),
          list(role = "user", content = prompt)
        ),
        max_tokens = 1000,
        temperature = 0.5
      ), auto_unbox = TRUE)

      res <- POST(url, headers, body = body)
      if (res$status_code != 200) {
        stop("OpenAI API call failed: ", content(res, "text"))
      }

      parsed <- content(res, as = "parsed", type = "application/json")
      return(parsed$choices[[1]]$message$content)
    }
  )
)
