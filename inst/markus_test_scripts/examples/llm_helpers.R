# llm_helpers.R

.extract_codefence_json <- function(txt) {
  if (is.null(txt) || !nzchar(txt)) return(character())
  m <- gregexpr("```(?:json)?\\s*([\\s\\S]*?)\\s*```", txt, perl = TRUE)
  hits <- regmatches(txt, m)[[1]]
  if (!length(hits)) return(character())
  sub("^```(?:json)?\\s*|\\s*```$", "", hits, perl = TRUE)
}

.extract_brace_json <- function(txt) {
  if (is.null(txt) || !nzchar(txt)) return(character())
  m <- gregexpr("\\{(?:[^{}]|\\{[^{}]*\\})*\\}", txt, perl = TRUE)
  regmatches(txt, m)[[1]]
}

.parse_json_list <- function(chunks) {
  out <- list()
  for (s in chunks) {
    s <- trimws(s)
    j <- try(jsonlite::fromJSON(s, simplifyVector = FALSE), silent = TRUE)
    if (!inherits(j, "try-error") && is.list(j)) {
      out[[length(out) + 1]] <- j
    }
  }
  out
}

extract_json <- function(response) {
  cands <- c(.extract_codefence_json(response), .extract_brace_json(response))
  objs <- .parse_json_list(cands)
  return(objs)
}

find_annotations_object <- function(txt) {
  objs <- extract_json(txt)
  
  for (o in objs) {
    if (!is.null(o$annotations) && is.list(o$annotations) && length(o$annotations) > 0) {
      return(o$annotations)
    }
  }
  
  for (o in objs) {
    if (is.list(o) && length(o) > 0 && is.list(o[[1]]) &&
        all(c("filename","content","line_start","line_end") %in% names(o[[1]]))) {
      return(o)
    }
  }
  
  for (o in objs) {
    if (is.list(o) && all(c("filename","content","line_start","line_end") %in% names(o))) {
      return(list(o))
    }
  }
  
  return(list())
}

`%||%` <- function(a, b) if (is.null(a)) b else a

compute_columns <- function(file_lines, line_start, line_end) {
  n <- length(file_lines)
  ls <- max(1L, min(as.integer(line_start), n))
  le <- max(ls, min(as.integer(line_end), n))
  starts <- integer(); ends <- integer()
  
  for (i in ls:le) {
    if (i > length(file_lines)) break
    ln <- file_lines[[i]]
    if (!nzchar(trimws(ln))) { 
      starts <- c(starts, 1L); ends <- c(ends, 1L) 
    } else {
      start_col <- nchar(ln, type = "bytes") - nchar(sub("^\\s*", "", ln), type = "bytes")
      end_col <- nchar(sub("\\s*$", "", ln), type = "bytes")
      starts <- c(starts, start_col + 1L); ends <- c(ends, end_col)
    }
  }
  
  list(
    line_start = ls, 
    line_end = le,
    column_start = ifelse(length(starts), min(starts), 1L),
    column_end = ifelse(length(ends), max(ends), 1L)
  )
}

add_annotation_columns <- function(annotations, submission_path) {
  tryCatch({
    file_lines <- readLines(submission_path, warn = FALSE)
  }, error = function(e) {
    return(list())
  })
  
  annotations_with_columns <- list()
  
  for (annotation in annotations) {
    filename <- annotation$filename
    line_start <- annotation$line_start
    line_end <- annotation$line_end
    
    if (is.null(file_lines) || line_start > length(file_lines) || line_end > length(file_lines)) {
      next
    }
    
    column_starts <- c()
    column_ends <- c()
    
    for (i in line_start:line_end) {
      if (i > length(file_lines)) next
      
      line <- file_lines[i]
      stripped_line <- trimws(line, "right")
      
      if (nzchar(stripped_line)) {
        start_col <- nchar(line) - nchar(trimws(line, "left"))
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

add_code_annotations <- function(submission_path, llm_output, max_annotations = 100) {
  file_lines <- try(readLines(submission_path, warn = FALSE), silent = TRUE)
  if (inherits(file_lines, "try-error")) file_lines <- character()

  anns <- find_annotations_object(llm_output)
  if (!length(anns)) return(invisible(NULL))

  key <- function(a) paste(
    a$filename %||% basename(submission_path),
    a$content %||% "",
    a$line_start %||% 1L,
    a$line_end %||% (a$line_start %||% 1L),
    sep = "|"
  )
  seen <- new.env(parent = emptyenv())

  count <- 0L
  for (a in anns) {
    if (count >= max_annotations) break

    fn <- a$filename %||% basename(submission_path)
    txt <- a$content %||% a$description %||% ""
    ls <- as.integer(a$line_start %||% 1L)
    le <- as.integer(a$line_end %||% ls)

    if (!nzchar(txt)) next
    
    k <- key(a)
    if (isTRUE(seen[[k]])) next
    seen[[k]] <- TRUE

    cols <- compute_columns(file_lines, ls, le)

    exp_signal(new_expectation(
      type = "success",
      message = "",
      markus_annotation = list(
        filename = fn,
        content = txt,
        line_start = cols$line_start,
        line_end = cols$line_end,
        column_start = cols$column_start,
        column_end = cols$column_end
      )
    ))
    count <- count + 1L
  }
  
  invisible(NULL)
}

add_image_annotations <- function(target_filename, llm_output, max_annotations = 50) {
  annotations <- extract_json(llm_output)
  
  count <- 0L
  for (annotation in annotations) {
    if (count >= max_annotations) break
    
    if (!is.null(annotation$location) && !is.null(annotation$description)) {
      coords <- convert_coordinates(annotation$location)
      
      exp_signal(new_expectation(
        type = "success",
        message = "",
        markus_annotation = list(
          type = "ImageAnnotation",
          filename = basename(target_filename),
          content = annotation$description,
          x1 = coords[1],
          y1 = coords[2], 
          x2 = coords[3],
          y2 = coords[4]
        )
      ))
      count <- count + 1L
    }
  }
  
  invisible(NULL)
}