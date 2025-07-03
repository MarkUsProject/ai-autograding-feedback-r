# helpers/install_dependencies.R

if (!dir.exists(Sys.getenv("R_LIBS_USER"))) {
  dir.create(Sys.getenv("R_LIBS_USER"), recursive = TRUE)
}
.libPaths(Sys.getenv("R_LIBS_USER"))

install_dependencies <- function(packages) {
  for (pkg in packages) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      install.packages(pkg, repos = "https://cloud.r-project.org", lib = Sys.getenv("R_LIBS_USER"))
    }
  }
}
