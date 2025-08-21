library(httr)
library(jsonlite)
library(dotenv)
library(R6)
library(base64enc)

ClaudeModel <- R6Class("ClaudeModel",
  public = list(
    api_key = NULL,
    model_name = "claude-3-7-sonnet-20250219",
    initialize = function() {
      dotenv::load_dot_env()

      self$api_key <- Sys.getenv("CLAUDE_API_KEY")
      if (self$api_key == "") {
        stop("CLAUDE_API_KEY not set in environment variables.")
      }
    },

    generate_response = function(
      prompt,
      system_instructions,
      submission_images = NULL,
      solution_image = NULL
    ) {
      #' Generate a Claude response, optionally including submission and solution images.

      # Build the content blocks (text + image if present)
      content_blocks <- list(
        list(type = "text", text = prompt)
      )

      # Helper: wrap base64-encoded image as Claude image block
      encode_image_block <- function(image_path) {
        encoded <- base64encode(image_path)
        list(
          type = "image",
          source = list(
            type = "base64",
            media_type = "image/png",  # Change if not PNG
            data = encoded
          )
        )
      }

      # Handle multiple submission images from QMD/RMD processing
      if (!is.null(submission_images)) {
        for (i in seq_along(submission_images)) {
          submission_img <- submission_images[i]
          content_blocks <- append(content_blocks, list(encode_image_block(submission_img)))
        }
      }
      
      # Handle solution image
      if (!is.null(solution_image)) {
        content_blocks <- append(content_blocks, list(encode_image_block(solution_image)))
      }

      body <- toJSON(list(
        model = self$model_name,
        max_tokens = 1000,
        temperature = 0.5,
        system = system_instructions,
        messages = list(
          list(role = "user", content = content_blocks)
        )
      ), auto_unbox = TRUE)

      headers <- add_headers(
        `x-api-key` = self$api_key,
        `content-type` = "application/json",
        `anthropic-version` = "2023-06-01"
      )

      res <- POST(
        url = "https://api.anthropic.com/v1/messages",
        body = body,
        encode = "raw",
        config = headers
      )

      if (res$status_code != 200) {
        stop(sprintf("Claude API call failed [HTTP %s]: %s",
                     res$status_code, content(res, "text")))
      }

      parsed <- content(res, as = "parsed", type = "application/json")
      response_text <- parsed$content[[1]]$text

      return(list(prompt = prompt, response = response_text))
    }
  )
)
