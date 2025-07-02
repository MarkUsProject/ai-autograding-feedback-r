# helpers/process_code.R

library(base64enc)
library(magick)

encode_image <- function(image_path) {
  base64encode(image_path)
}

openai_call <- function(message, model) {
  api_key <- Sys.getenv("OPENAI_API_KEY")
  if (api_key == "") stop("OPENAI_API_KEY not set in environment")
  
  images <- lapply(message$images, function(img_path) {
    list(
      type = "image_url",
      image_url = list(url = paste0("data:image/png;base64,", encode_image(img_path)))
    )
  })
  
  body <- list(
    model = model,
    messages = list(
      list(
        role = "user",
        content = append(
          list(list(type = "text", text = message$content)),
          images
        )
      )
    ),
    temperature = 0.33
  )
  
  response <- httr::POST(
    url = "https://api.openai.com/v1/chat/completions",
    httr::add_headers(Authorization = paste("Bearer", api_key), `Content-Type` = "application/json"),
    body = jsonlite::toJSON(body, auto_unbox = TRUE),
    encode = "json"
  )

  content <- httr::content(response)
  return(content$choices[[1]]$message$content)
}

process_image <- function(args, prompt, system_instructions) {
  OUTPUT_DIRECTORY <- "output_images"
  submission_file <- args$submission
  solution_file <- if (!is.null(args$solution)) args$solution else NULL
  
  if (!file.exists(submission_file)) stop("Submission file not found")
  if (!is.null(solution_file) && !file.exists(solution_file)) stop("Solution file not found")
  
  questions <- if (!is.null(args$question)) list(args$question) else list("Q1")  # Stub for testing
  requests <- c()
  responses <- c()

  for (question in questions) {
    prompt_content <- prompt$prompt_content

    if (grepl("\\{context\\}", prompt_content)) {
      context <- "(Context placeholder)"
      prompt_content <- gsub("\\{context\\}", paste0("```\n", context, "\n```"), prompt_content)
    }

    if (grepl("\\{image_size\\}", prompt_content)) {
      img <- image_read(args$submission_image)
      size <- image_info(img)
      prompt_content <- gsub("\\{image_size\\}", paste(size$width, "by", size$height), prompt_content)
    }

    rendered_prompt <- render_prompt_template(
      prompt_content,
      submission = submission_file,
      solution = solution_file,
      has_submission_image = grepl("\\{submission_image\\}", prompt_content),
      has_solution_image = grepl("\\{solution_image\\}", prompt_content)
    )

    message <- list(role = "user", content = rendered_prompt, images = c())
    if (grepl("\\{submission_image\\}", prompt_content)) {
      message$images <- c(message$images, args$submission_image)
    }
    if (grepl("\\{solution_image\\}", prompt_content)) {
      message$images <- c(message$images, args$solution_image)
    }

    request_text <- paste0(rendered_prompt, "\n\n", paste(message$images, collapse = ", "))
    requests <- c(requests, request_text)

    if (args$model == "openai") {
      responses <- c(responses, openai_call(message, model = "gpt-4o"))
    } else if (args$model == "remote") {
      model <- if (!is.null(args$remote_model)) RemoteModel$new(args$remote_model) else RemoteModel$new()
      result <- model$generate_response(
        rendered_prompt,
        submission_file,
        system_instructions = system_instructions,
        question_num = question,
        submission_image = args$submission_image
      )
      responses <- c(responses, result[[2]])
    } else {
      responses <- c(responses, paste("Stub call for model:", args$model))
    }
  }

  return(list(paste(requests, collapse = "\n\n---\n\n"), paste(responses, collapse = "\n\n---\n\n")))
}
