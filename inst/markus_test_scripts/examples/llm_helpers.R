# llm_helpers.R

library(httr)
library(jsonlite)

if (file.exists(".env")) {
  try({
    if (requireNamespace("dotenv", quietly = TRUE)) dotenv::load_dot_env(".env")
  }, silent = TRUE)
}

ANNOTATION_PROMPT <- "These are the student mistakes you previously identified in the last message. For each of the mistakes you identified, return a JSON object containing an array of annotations, referencing the student's submission file for line and column #s. Each annotation should include: filename: The name of the student's file. content: A short description of the mistake. line_start and line_end: The line number(s) where the mistake occurs. Ensure the JSON is valid and properly formatted. Here is a sample format of the json array to return: { \"annotations\": [{\"filename\": \"submission.R\", \"content\": \"Variable 'x' is unused.\", \"line_start\": 5, \"line_end\": 5}]}. ONLY return the json object and nothing else. Make sure the line #s don't exceed the number of lines in the file. You can use markdown syntax in the annotation's content, especially when denoting code."

add_annotation_columns <- function(annotations, submission_file_path) {
  tryCatch({
    file_lines <- readLines(submission_file_path, warn = FALSE)
  }, error = function(e) {
    cat("Error reading submission file:", e$message, "\n")
    return(list())
  })
  
  annotations_with_columns <- list()
  
  for (annotation in annotations) {
    filename <- annotation$filename
    line_start <- annotation$line_start
    line_end <- annotation$line_end
    
    if (is.null(file_lines) || line_start > length(file_lines) || line_end > length(file_lines)) {
      cat("Skipping invalid line numbers for", filename, ":", line_start, "-", line_end, "\n")
      next
    }
    
    column_starts <- c()
    column_ends <- c()
    
    for (i in line_start:line_end) {
      if (i > length(file_lines)) next
      
      line <- file_lines[i]
      stripped_line <- sub("\n$", "", line)
      
      if (nzchar(trimws(stripped_line))) {
        start_col <- nchar(line) - nchar(sub("^\\s*", "", line))
        end_col <- nchar(stripped_line)
      } else {
        start_col <- 0
        end_col <- 1
      }
      
      column_starts <- c(column_starts, start_col)
      column_ends <- c(column_ends, end_col)
    }
    
    if (length(column_starts) > 0 && length(column_ends) > 0) {
      column_start <- min(column_starts)
      column_end <- max(column_ends)
    } else {
      column_start <- 0
      column_end <- 1
    }
    
    annotation$column_start <- column_start
    annotation$column_end <- column_end
    annotations_with_columns[[length(annotations_with_columns) + 1]] <- annotation
  }
  
  return(annotations_with_columns)
}

run_llm <- function(
  submission,
  model,
  scope,
  output,
  prompt_custom = NULL,
  question = NULL,
  prompt_text = NULL,
  prompt = NULL
) {
  # Get Claude API key
  api_key <- Sys.getenv("CLAUDE_API_KEY")
  if (api_key == "") {
    stop("CLAUDE_API_KEY not set in environment variables")
  }
  
  # Build prompt content
  prompt_content <- ""
  if (!is.null(prompt)) {
    prompt_content <- paste(readLines(prompt), collapse = "\n")
  }
  if (!is.null(prompt_text)) {
    prompt_content <- paste0(prompt_content, prompt_text)
  }
  if (prompt_content == "") {
    stop("No prompt provided. Please specify a prompt file or text.")
  }
  
  # Read submission file
  submission_content <- paste(readLines(submission), collapse = "\n")
  
  # Combine prompt with submission
  full_prompt <- paste0(
    prompt_content, "\n\n",
    "File: ", basename(submission), "\n",
    submission_content
  )
  
  # Prepare API request
  body <- list(
    model = "claude-3-5-sonnet-20241022",
    max_tokens = 2000,
    temperature = 0.3,
    system = "You are an instructor evaluating student code.",
    messages = list(
      list(
        role = "user",
        content = full_prompt
      )
    )
  )
  
  # Make API call
  response <- POST(
    url = "https://api.anthropic.com/v1/messages",
    body = toJSON(body, auto_unbox = TRUE),
    add_headers(
      `x-api-key` = api_key,
      `content-type` = "application/json",
      `anthropic-version` = "2023-06-01"
    )
  )
  
  if (status_code(response) != 200) {
    error_content <- content(response, "text")
    stop(paste("Claude API call failed [HTTP", status_code(response), "]:", error_content))
  }
  
  # Parse response
  parsed <- content(response, "parsed")
  response_text <- parsed$content[[1]]$text
  
  return(response_text)
}

extract_json <- function(response) {
  matches <- regmatches(response, gregexpr("\\{(?:[^{}]|(?:\\{(?:[^{}]|(?:\\{[^{}]*\\}))*\\}))*\\}", response, perl = TRUE))[[1]]
  
  json_objects <- list()
  for (match in matches) {
    parsed <- try(fromJSON(match, simplifyVector = FALSE), silent = TRUE)
    if (!inherits(parsed, "try-error")) {
      json_objects[[length(json_objects) + 1]] <- parsed
    }
  }
  
  return(json_objects)
}

MINIMUM_ANNOTATION_WIDTH <- 8

convert_coordinates <- function(box) {
  x_extension <- max(0, (MINIMUM_ANNOTATION_WIDTH - abs(box[3] - box[1])) %/% 2)
  y_extension <- max(0, (MINIMUM_ANNOTATION_WIDTH - abs(box[4] - box[2])) %/% 2)
  
  return(c(
    box[1] - x_extension,
    box[2] - y_extension,
    box[3] + x_extension,
    box[4] + y_extension
  ))
}

add_image_annotations <- function(request, llm_feedback, file_name) {
  annotations <- extract_json(llm_feedback)
  for (annotation in annotations) {
    if (!is.null(annotation$location) && !is.null(annotation$description)) {
      coords <- convert_coordinates(annotation$location)
      
      # R equivalent of pytest.mark.markus_annotation
      expectation <- new_expectation(
        type = "success",
        message = ""
      )
      attr(expectation, "markus_annotation") <- list(
        type = "ImageAnnotation",
        filename = basename(file_name),
        content = annotation$description,
        x1 = coords[1],
        y1 = coords[2],
        x2 = coords[3],
        y2 = coords[4]
      )
      exp_signal(expectation)
    }
  }
}
