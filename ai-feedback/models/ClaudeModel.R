source("ai-feedback/helpers/install_dependencies.R")
install_if_missing(c("httr", "jsonlite", "dotenv", "R6"))

library(httr)
library(jsonlite)
library(dotenv)
library(R6)

load_dot_env()

ClaudeModel <- R6Class("ClaudeModel",
  public = list(
    api_key = NULL,
    model_name = "claude-3-7-sonnet-20250219",

    initialize = function() {
      #' Initializes ClaudeModel with the Anthropic API key.
      self$api_key <- Sys.getenv("CLAUDE_API_KEY")
      if (self$api_key == "") {
        stop("CLAUDE_API_KEY not set in environment variables.")
      }
    },

    generate_response = function(
      prompt,
      submission_file,
      system_instructions,
      solution_file = NULL,
      scope = NULL,
      question_num = NULL,
      test_output = NULL,
      llama_mode = NULL
    ) {
      #' Generates a Claude response for the provided prompt and context.
      #'
      #' @param prompt Prompt string from user
      #' @param system_instructions Model's system prompt
      #' @param question_num Optional question/task number to focus on
      #' @return List with prompt and response text, or NULL if failed

      request <- ""
      if (!is.null(question_num)) {
        request <- paste0(
          "Identify and generate a response for the mistakes **only** in question/task ",
          question_num,
          ". "
        )
      }
      request <- paste0(request, prompt)

      body <- toJSON(list(
        model = self$model_name,
        max_tokens = 1000,
        temperature = 0.5,
        system = system_instructions,
        messages = list(
          list(role = "user", content = request)
        )
      ), auto_unbox = TRUE)

      headers <- add_headers(
        Authorization = paste("Bearer", self$api_key),
        `Content-Type` = "application/json",
        `anthropic-version` = "2023-06-01"
      )

      res <- POST(
        url = "https://api.anthropic.com/v1/messages",
        body = body,
        encode = "raw",
        headers
      )

      if (res$status_code != 200) {
        warning("Claude API call failed: ", content(res, "text"))
        return(NULL)
      }

      parsed <- content(res, as = "parsed", type = "application/json")
      response_text <- parsed$content[[1]]$text

      return(list(prompt = prompt, response = response_text))
    }
  )
)
