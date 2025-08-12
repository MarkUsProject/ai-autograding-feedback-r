# R/env.R
.load_env_safely <- function(override = TRUE) {
  # If keys are already present (e.g., via Renviron.site), skip file scanning.
  known_keys <- c("OPENAI_API_KEY", "CLAUDE_API_KEY", "REMOTE_API_KEY")
  if (any(nzchar(Sys.getenv(known_keys, unset = "")))) {
    return(invisible(TRUE))
  }

  # Only consider an explicit AIFEEDBACKR_DOTENV or a local .env
  candidates <- unique(c(
    Sys.getenv("AIFEEDBACKR_DOTENV", unset = ""),
    ".env"
  ))
  candidates <- candidates[nzchar(candidates)]

  for (p in candidates) {
    # Must exist and be readable by this process
    ok <- tryCatch(file.exists(p) && file.access(p, 4L) == 0L, error = function(e) FALSE)
    if (!isTRUE(ok)) next

    # Prefer dotenv if available
    if (requireNamespace("dotenv", quietly = TRUE)) {
      try(dotenv::load_dot_env(file = p, override = override), silent = TRUE)
    } else {
      # Fallback: manual parse without throwing on errors/permissions
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
              kv <- list(); kv[[key]] <- value; do.call(Sys.setenv, kv)
            }
          }
        }
      }
    }
    break
  }
  invisible(TRUE)
}
