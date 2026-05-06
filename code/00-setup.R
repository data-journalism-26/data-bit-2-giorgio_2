# 00-setup.R — paths, packages, constants for the remigrazione data bit

suppressPackageStartupMessages({
  required <- c("httr2", "rvest", "xml2", "stringr", "dplyr", "tidyr",
                "purrr", "lubridate", "ggplot2", "ggrepel", "scales", "here")
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    message("Installing missing packages: ", paste(missing, collapse = ", "))
    install.packages(missing, repos = "https://cloud.r-project.org")
  }
  library(stringr); library(dplyr); library(tidyr); library(purrr)
  library(lubridate); library(ggplot2); library(rvest); library(xml2)
})

PROJECT_ROOT  <- here::here()
RAW_CAMERA    <- file.path(PROJECT_ROOT, "data", "raw", "camera")
RAW_SENATO    <- file.path(PROJECT_ROOT, "data", "raw", "senato_repo")
PROCESSED     <- file.path(PROJECT_ROOT, "data", "processed")
FIGURES       <- file.path(PROJECT_ROOT, "output", "figures")

for (d in c(RAW_CAMERA, PROCESSED, FIGURES)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

# Match all morphological forms: remigrazione, remigrare, remigrato, remigrazioni, ...
PATTERN <- regex("remigra[a-z]*", ignore_case = TRUE)
