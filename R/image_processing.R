library(base64enc)
library(magick)

process_image <- function(args, prompt, system_instructions) {
  submission_file <- args$submission
  if (!is.null(args$solution)) {
    solution_file <- args$solution
  } else {
    solution_file <- NULL
  }

  if (!file.exists(submission_file)) {
    stop("Submission file not found")
  }

  if (!is.null(solution_file) && !file.exists(solution_file)) {
    stop("Solution file not found")
  }

  prompt_content <- prompt

  # Replace {context} placeholder
  if (grepl("\\{context\\}", prompt_content)) {
    context <- "(Context placeholder)"
    prompt_content <- gsub("\\{context\\}", paste0("```\n", context, "\n```"), prompt_content)
  }

  # Replace {image_size} placeholder
  if (grepl("\\{image_size\\}", prompt_content)) {
    img <- image_read(args$submission_image)
    size <- image_info(img)
    prompt_content <- gsub("\\{image_size\\}", paste(size$width, "by", size$height), prompt_content)
  }

  rendered_prompt <- render_prompt_template(
    prompt_content = prompt_content,
    submission = submission_file,
    solution = solution_file,
    has_submission_image = grepl("\\{submission_image\\}", prompt_content),
    has_solution_image = grepl("\\{solution_image\\}", prompt_content)
  )

  # Build prompt image list for OpenAI
  if (grepl("\\{submission_image\\}", prompt_content)) {
    submission_image <- args$submission_image
  } else {
    submission_image <- NULL
  }
  if (grepl("\\{solution_image\\}", prompt_content)) {
    solution_image <- args$solution_image
  } else {
    solution_image <- NULL
  }
  request_text <- paste0(rendered_prompt, "\n\n",
                         paste(stats::na.omit(c(submission_image, solution_image)), collapse = ", "))

  model_class <- model_mapping[[args$model]]
  if (is.null(model_class)) {
    stop("Invalid model selected for image scope.")
    stop("Invalid model selected for image scope.")
  }

  if (identical(model_class, RemoteModel) && !is.null(args$remote_model) && args$remote_model != "") {
    model <- model_class$new(model_name = args$remote_model)
  } else {
    model <- model_class$new()
  }

  response <- model$generate_response(
    prompt = rendered_prompt,
    system_instructions = system_instructions,
    submission_image = submission_image,
    solution_image = solution_image
  )

  return(list(request_text, response))
}
