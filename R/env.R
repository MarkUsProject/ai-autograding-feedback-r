.load_env_safely <- function(override = TRUE) {
  candidates <- c(
    Sys.getenv("AIFEEDBACKR_DOTENV"),
    ".env",
    "/home/docker/.env"
  )
  candidates <- candidates[nzchar(candidates)]
  for (p in candidates) {
    if (file.exists(p)) {
      if (requireNamespace("dotenv", quietly = TRUE)) {
        try(dotenv::load_dot_env(file = p, override = override), silent = TRUE)
      }
      # Fallback: ensure keys from file are present in environment
      lines <- tryCatch(readLines(p, warn = FALSE), error = function(e) character())
      if (length(lines) > 0) {
        for (ln in lines) {
          ln <- trimws(ln)
          if (ln == "" || startsWith(ln, "#")) next
          ln <- sub("^export\\s+", "", ln)
          parts <- strsplit(ln, "=", fixed = TRUE)[[1]]
          if (length(parts) >= 2) {
            key <- trimws(parts[1])
            value <- paste(parts[-1], collapse = "=")
            value <- trimws(value)
            if ((startsWith(value, '"') && endsWith(value, '"')) ||
                (startsWith(value, "'") && endsWith(value, "'"))) {
              value <- substring(value, 2, nchar(value) - 1)
            }
            if (nzchar(key) && (override || Sys.getenv(key, unset = "") == "")) {
              kv <- list()
              kv[[key]] <- value
              do.call(Sys.setenv, kv)
            }
          }
        }
      }
      break
    }
  }
  invisible(TRUE)
}
