# required_packages.R

source("ai-feedback/helpers/install_dependencies.R")
# List of required packages
required_packages <- c(
  "optparse",
  "jsonlite",
  "magick",
  "base64enc",
  "jsonlite",
  "stringr",
  "tools",
  "httr",
  "dotenv",
  "R6",
)

install_dependencies(required_packages)