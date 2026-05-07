# 02-extract-camera.R — parse Camera resoconti hits
# For each saved HTML in data/raw/camera/, find every paragraph containing
# /remigra/i, attribute it to a speaker, and emit a tidy table.

source(here::here("code", "00-setup.R"))

ITALIAN_MONTHS <- c(
  gennaio = 1L, febbraio = 2L, marzo = 3L, aprile = 4L, maggio = 5L, giugno = 6L,
  luglio = 7L, agosto = 8L, settembre = 9L, ottobre = 10L, novembre = 11L, dicembre = 12L
)

parse_seduta_date <- function(html) {
  # <p class="centerBold">Seduta n. 1 di giovedì 13 ottobre 2022</p>
  hdr <- html |>
    rvest::html_elements("p.centerBold") |>
    rvest::html_text2()
  hit <- hdr[stringr::str_detect(hdr, "Seduta")]
  if (length(hit) == 0) return(as.Date(NA))
  m <- stringr::str_match(hit[1],
    "(\\d{1,2})\\s+(gennaio|febbraio|marzo|aprile|maggio|giugno|luglio|agosto|settembre|ottobre|novembre|dicembre)\\s+(\\d{4})")
  if (is.na(m[1])) return(as.Date(NA))
  as.Date(sprintf("%s-%02d-%02d", m[, 4], ITALIAN_MONTHS[m[, 3]], as.integer(m[, 2])))
}

parse_seduta_num <- function(html) {
  hdr <- html |>
    rvest::html_elements("p.centerBold") |>
    rvest::html_text2()
  hit <- hdr[stringr::str_detect(hdr, "Seduta n\\.")]
  if (length(hit) == 0) return(NA_integer_)
  as.integer(stringr::str_match(hit[1], "Seduta n\\.\\s*(\\d+)")[, 2])
}

# Walk paragraphs in order. Each <p class="intervento"> opens a new speaker
# turn (speaker name from inner <a title="Vai alla scheda personale: ...">).
# Subsequent <p class="interventoVirtuale"> belong to that speaker until the
# next <p class="intervento">.
parse_hits_from_file <- function(path) {
  html <- rvest::read_html(path)
  date_   <- parse_seduta_date(html)
  sed_num <- parse_seduta_num(html)
  fname   <- basename(path)
  leg     <- as.integer(stringr::str_match(fname, "leg(\\d+)")[, 2])

  ps <- html |> rvest::html_elements("p")
  classes <- ps |> rvest::html_attr("class")

  current_speaker  <- NA_character_
  current_idperson <- NA_character_

  hits <- list()
  for (i in seq_along(ps)) {
    cls <- classes[i] %||% ""
    if (cls == "intervento") {
      a <- ps[[i]] |> rvest::html_element("a")
      if (!is.na(a) && length(a) > 0) {
        title  <- rvest::html_attr(a, "title")
        href   <- rvest::html_attr(a, "href")
        nm <- if (!is.na(title)) sub("Vai alla scheda personale:\\s*", "", title) else NA_character_
        idp <- if (!is.na(href)) sub(".*idPersona=(\\d+).*", "\\1", href) else NA_character_
        current_speaker  <- nm
        current_idperson <- idp
      } else {
        current_speaker  <- NA_character_
        current_idperson <- NA_character_
      }
    }

    txt <- rvest::html_text2(ps[[i]])
    if (stringr::str_detect(txt, stringr::regex("remigra", ignore_case = TRUE))) {
      hits[[length(hits) + 1L]] <- tibble(
        chamber  = "Camera",
        leg      = leg,
        sed_num  = sed_num,
        date     = date_,
        speaker  = current_speaker,
        id_persona = current_idperson,
        para_class = cls,
        text     = txt
      )
    }
  }
  if (length(hits) == 0) return(NULL)
  bind_rows(hits)
}

`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1 && is.na(a))) b else a

files <- list.files(RAW_CAMERA, pattern = "^leg\\d+_sed\\d+\\.html$", full.names = TRUE)
cat(sprintf("[extract-camera] %d hit files to parse\n", length(files)))

camera_hits <- map_dfr(files, function(f) {
  tryCatch(parse_hits_from_file(f), error = function(e) {
    warning("Failed: ", f, " :: ", conditionMessage(e)); NULL
  })
})

if (nrow(camera_hits) == 0) {
  cat("[extract-camera] no hits found.\n")
} else {
  camera_hits <- camera_hits |>
    arrange(date, leg, sed_num) |>
    mutate(
      speaker = stringr::str_trim(speaker),
      text    = stringr::str_squish(text),
      # Truncate long text for the snippet column
      snippet = stringr::str_trunc(text, 280, ellipsis = "…")
    )
  out <- file.path(PROCESSED, "camera_hits.csv")
  readr::write_csv(camera_hits, out)
  cat(sprintf("[extract-camera] wrote %d hits → %s\n", nrow(camera_hits), out))
  cat(sprintf("[extract-camera] sessions with at least 1 hit: %d\n",
              dplyr::n_distinct(paste(camera_hits$leg, camera_hits$sed_num))))
  cat(sprintf("[extract-camera] date range: %s → %s\n",
              min(camera_hits$date, na.rm = TRUE),
              max(camera_hits$date, na.rm = TRUE)))
}
