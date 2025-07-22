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

  # Check if submission is QMD file and generate PNGs
  submission_images <- NULL
  if (grepl("\\.(qmd|rmd)$", submission_file, ignore.case = TRUE)) {
    cat("Detected QMD file, generating PNG plots...\n")
    png_files <- run_qmd_collect_png(submission_file, timeout = 60, output_dir = NULL)

      # filter by question tag
  if (!is.null(args$question)) {
    pat <- args$question
    if (grepl("^\\([a-z]\\)$", pat)) {
      pat <- paste0("__", gsub("[^a-z]", "", pat), "__")   # "(b)" → "__b__"
    } else if (grepl("^[Qq]uestion\\s*\\d+", pat)) {
      num <- sub(".*?(\\d+).*", "\\1", pat)                # "Question 1" → "1"
      pat <- paste0("Q", num, "__")                        # → "Q1__"
    }
    png_files <- png_files[grepl(pat, basename(png_files))]
  }
    
    if (length(png_files) > 0) {
      cat("Generated", length(png_files), "PNG files from QMD\n")
      submission_images <- png_files
    } else {
      cat("No PNG files generated from QMD\n")
    }
  } else if (!is.null(args$submission_image)) {
    # Use provided submission image
    submission_images <- args$submission_image
  }

  prompt_content <- prompt

  # Replace {context} placeholder
  if (grepl("\\{context\\}", prompt_content)) {
    context <- "(Context placeholder)"
    prompt_content <- gsub("\\{context\\}", paste0("```\n", context, "\n```"), prompt_content)
  }

  # Replace {image_size} placeholder
  if (grepl("\\{image_size\\}", prompt_content)) {
    if (!is.null(submission_images)) {
      img <- image_read(submission_images[1])  # Use first image for size
      size <- image_info(img)
      prompt_content <- gsub("\\{image_size\\}", paste(size$width, "by", size$height), prompt_content)
    }
  }

  rendered_prompt <- render_prompt_template(
    prompt_content = prompt_content,
    submission = submission_file,
    solution = solution_file,
    has_submission_image = !is.null(submission_images),
    has_solution_image = grepl("\\{solution_image\\}", prompt_content),
    question = args$question,
  )

  # Build prompt image list for OpenAI
  solution_image <- NULL
  if (grepl("\\{solution_image\\}", prompt_content)) {
    solution_image <- args$solution_image
  }

  model_class <- model_mapping[[args$model]]
  if (is.null(model_class)) {
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
    submission_images = submission_images,
    solution_image = solution_image
  )

  return(list(rendered_prompt, response))
}
