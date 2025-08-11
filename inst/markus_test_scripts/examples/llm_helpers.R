# llm_helpers.R

.extract_codefence_json <- function(txt) {
  if (is.null(txt) || !nzchar(txt)) return(character())
  # ```json ... ``` or ``` ... ```
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
    j <- try(jsonlite::fromJSON(s, simplifyVector = FALSE), silent = TRUE)
    if (!inherits(j, "try-error") && is.list(j)) out[[length(out) + 1]] <- j
  }
  out
}

find_annotations_object <- function(txt) {
  cands <- c(.extract_codefence_json(txt), .extract_brace_json(txt))
  objs <- .parse_json_list(cands)
  for (o in objs) {
    if (!is.null(o$annotations) && is.list(o$annotations) && length(o$annotations) > 0) {
      return(o$annotations)
    }
  }
  # fallback: if object itself looks like an annotation list
  for (o in objs) {
    if (is.list(o) && length(o) && is.list(o[[1]]) &&
        all(c("filename","content","line_start","line_end") %in% names(o[[1]]))) {
      return(o)
    }
  }
  list()
}

`%||%` <- function(a, b) if (is.null(a)) b else a

compute_columns <- function(file_lines, line_start, line_end) {
  n <- length(file_lines)
  ls <- max(1L, min(as.integer(line_start), n))
  le <- max(ls,  min(as.integer(line_end),   n))
  starts <- integer(); ends <- integer()
  for (i in ls:le) {
    ln <- file_lines[[i]]
    if (!nzchar(trimws(ln))) { starts <- c(starts, 1L); ends <- c(ends, 1L) }
    else {
      start_col <- nchar(ln, type = "bytes") - nchar(sub("^\\s*", "", ln), type = "bytes")
      end_col   <- nchar(sub("\\s*$", "", ln), type = "bytes")
      starts <- c(starts, start_col + 1L); ends <- c(ends, end_col)
    }
  }
  list(line_start = ls, line_end = le,
       column_start = ifelse(length(starts), min(starts), 1L),
       column_end   = ifelse(length(ends),   max(ends),   1L))
}

add_code_annotations <- function(submission_path, llm_output, max_annotations = 100) {
  file_lines <- try(readLines(submission_path, warn = FALSE), silent = TRUE)
  if (inherits(file_lines, "try-error")) file_lines <- character()

  anns <- find_annotations_object(llm_output)
  if (!length(anns)) return(invisible(NULL))

  # dedupe
  key <- function(a) paste(
    a$filename %||% basename(submission_path),
    a$content   %||% "",
    a$line_start %||% 1L,
    a$line_end   %||% (a$line_start %||% 1L),
    sep = "|"
  )
  seen <- new.env(parent = emptyenv())

  count <- 0L
  for (a in anns) {
    if (count >= max_annotations) break

    fn  <- a$filename %||% basename(submission_path)
    txt <- a$content  %||% a$description %||% ""
    ls  <- as.integer(a$line_start %||% 1L)
    le  <- as.integer(a$line_end   %||% ls)

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
  anns <- find_annotations_object(llm_output)
  if (!length(anns)) return(invisible(NULL))

  count <- 0L
  for (a in anns) {
    if (count >= max_annotations) break
    desc <- a$description %||% a$content %||% ""
    exp_signal(new_expectation(
      type = "success",
      message = "",
      markus_annotation = list(
        filename = target_filename,
        content = desc,
        line_start = 1, line_end = 1, column_start = 1, column_end = 1
      )
    ))
    count <- count + 1L
  }
  invisible(NULL)
}
