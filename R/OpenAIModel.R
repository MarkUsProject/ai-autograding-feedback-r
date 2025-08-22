library(httr)
library(jsonlite)
library(dotenv)
library(R6)
library(base64enc)

OpenAIModel <- R6Class("OpenAIModel",
  public = list(
    api_key = NULL,

    initialize = function() {
      dotenv::load_dot_env(".env")

      #' Initialize the OpenAIModel instance by loading the API key.
      self$api_key <- Sys.getenv("OPENAI_API_KEY")
      if (self$api_key == "") {
        stop("OPENAI_API_KEY is not set in environment.")
      }
    },

    generate_response = function(prompt, system_instructions, submission_images = NULL, solution_image = NULL, json_schema = NULL) {
      #' Generate a model response using the OpenAI API, including optional images.
      #' @param prompt User prompt
      #' @param system_instructions System-level instructions for the model
      #' @param submission_images Optional file path to submission images
      #' @param solution_image Optional file path to solution image
      #' @param schema Optional JSON schema for structured response
      #' @return A list with the original prompt and the model's response or error message
      response_text <- tryCatch({
        url <- "https://api.openai.com/v1/chat/completions"

        headers <- httr::add_headers(
          'Authorization' = paste('Bearer', self$api_key),
          'Content-Type' = 'application/json'
        )

        image_blocks <- list()
        
        # Handle multiple submission images from QMD/RMD processing
        if (!is.null(submission_images)) {
          for (i in seq_along(submission_images)) {
            submission_img <- submission_images[i]
            image_blocks <- append(image_blocks, list(list(
              type = "image_url",
              image_url = list(url = paste0("data:image/png;base64,", base64enc::base64encode(submission_img)))
            )))
          }
        }
        
        # Handle solution image
        if (!is.null(solution_image)) {
          image_blocks <- append(image_blocks, list(list(
            type = "image_url",
            image_url = list(url = paste0("data:image/png;base64,", base64enc::base64encode(solution_image)))
          )))
        }

        # Message structure with text and optional images
        messages <- list(
          list(role = "system", content = system_instructions),
          list(
            role = "user",
            content = append(
              list(list(type = "text", text = prompt)),
              image_blocks
            )
          )
        )

        body_list <- list(
          model = "gpt-4o",
          messages = messages,
          max_tokens = 1000,
          temperature = 0.5
        )

        if (!is.null(json_schema)) {
          if (!file.exists(json_schema)) stop("Schema file not found: ", json_schema)

          raw <- jsonlite::fromJSON(json_schema, simplifyVector = FALSE)

          # Wrapper support: { name, description, schema }  OR  bare schema
          has_wrapper  <- !is.null(raw$schema)
          inner_schema <- if (has_wrapper) raw$schema else raw

          # Use wrapper name if present; otherwise default to filename
          schema_name <- if (has_wrapper && !is.null(raw$name) && nzchar(raw$name)) {
            raw$name
          } else {
            tools::file_path_sans_ext(basename(json_schema))
          }

          # Validate required shape for OpenAI structured outputs
          if (is.null(inner_schema$type) || inner_schema$type != "object") {
            stop('json_schema must have root {"type":"object"}.')
          }

          body_list$response_format <- list(
            type = "json_schema",
            json_schema = list(
              name   = schema_name,
              strict = TRUE,
              schema = inner_schema
            )
          )
        }

        body <- jsonlite::toJSON(body_list, auto_unbox = TRUE)
        res <- httr::POST(url, body = body, encode = "raw", config = headers)

        if (res$status_code != 200) {
          stop("OpenAI API call failed: ", httr::content(res, "text"))
        }

        parsed <- httr::content(res, as = "parsed", type = "application/json")
        parsed$choices[[1]]$message$content

      }, error = function(e) {
        message("Error in OpenAI API call: ", conditionMessage(e))
        return(paste("ERROR: Failed to call OpenAI API —", conditionMessage(e)))
      })
      
      return(list(prompt = prompt, response = response_text))
    }
  )
)
