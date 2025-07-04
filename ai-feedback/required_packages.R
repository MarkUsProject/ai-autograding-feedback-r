# required_packages.R

source("ai-feedback/helpers/install_dependencies.R")
# List of required packages
required_packages <- c(
  "magick",
  "base64enc",
  "jsonlite",
  "stringr",
  "tools",
  "httr",
  "dotenv",
  "pdftools",
  "R6"
)

install_dependencies(required_packages)