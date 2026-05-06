# 03-extract-senato.R — find every Senato resoconto d'aula speech / annex
# paragraph containing /remigra/i. Senato bulk data is published as Akoma
# Ntoso XML in SenatoDellaRepubblica/AkomaNtosoBulkData (cloned to
# data/raw/senato_repo). Speeches sit inside <an:speech>; written questions
# (interrogazioni a risposta scritta) live under Allegato B with no <an:speech>
# wrapper, so we walk the XML tree and attribute each match accordingly.

source(here::here("code", "00-setup.R"))

senato_root <- file.path(RAW_SENATO, c("Leg17", "Leg18", "Leg19"))
xml_files <- list.files(senato_root, pattern = "-ra\\.akn\\.xml$",
                        recursive = TRUE, full.names = TRUE)
xml_files <- xml_files[stringr::str_detect(xml_files, "/resaula/")]
xml_files <- xml_files[!duplicated(basename(xml_files))]
cat(sprintf("[extract-senato] %d unique resoconti to scan\n", length(xml_files)))

ns <- c(an = "http://docs.oasis-open.org/legaldocml/ns/akn/3.0/CSD03")

`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1 && is.na(a))) b else a

extract_one <- function(path) {
  doc <- tryCatch(xml2::read_xml(path), error = function(e) NULL)
  if (is.null(doc)) return(NULL)

  date_node <- xml2::xml_find_first(doc, "//an:FRBRdate", ns)
  date_     <- xml2::xml_attr(date_node, "date")
  num_node  <- xml2::xml_find_first(doc, "//an:FRBRnumber", ns)
  sed_num   <- as.integer(xml2::xml_attr(num_node, "value"))
  leg       <- as.integer(stringr::str_match(path, "/Leg(\\d+)/")[, 2])

  # All paragraphs (an:p) anywhere in the document
  paras <- xml2::xml_find_all(doc, "//an:p", ns)
  if (length(paras) == 0) return(NULL)

  out <- list()
  for (p in paras) {
    txt <- xml2::xml_text(p, trim = TRUE)
    if (!stringr::str_detect(txt, stringr::regex("remigra", ignore_case = TRUE))) next

    # Walk up to find a containing speech (for plenary debate) or component
    # (for Allegato B written questions).
    speech <- xml2::xml_find_first(p, "ancestor::an:speech", ns)
    speaker_party_raw <- NA_character_
    if (!inherits(speech, "xml_missing")) {
      from_node <- xml2::xml_find_first(speech, "./an:from", ns)
      speaker   <- xml2::xml_text(from_node, trim = TRUE) |>
        stringr::str_remove("^\\.\\s*") |> stringr::str_trim()
      persona   <- sub("^#", "", xml2::xml_attr(from_node, "refersTo") %||% NA_character_)
      para_class <- "speech"
      # Capture the speech's full leading text — the speaker's group tag like
      # "(FdI)" or "(Misto-AVS)" only appears at the start of the speech and
      # is missed when the matching paragraph is not the first.
      speaker_party_raw <- xml2::xml_text(speech, trim = TRUE) |> stringr::str_squish()
    } else {
      # Allegato B: extract any signing senator from the enclosing item heading.
      item <- xml2::xml_find_first(p, "ancestor::an:item", ns)
      sig_node <- if (!inherits(item, "xml_missing")) {
        xml2::xml_find_first(item, ".//an:signature", ns)
      } else NULL
      speaker <- if (!is.null(sig_node) && !inherits(sig_node, "xml_missing")) {
        xml2::xml_text(sig_node, trim = TRUE)
      } else NA_character_
      persona <- NA_character_
      para_class <- "allegato_b"
    }

    out[[length(out) + 1L]] <- tibble(
      chamber  = "Senato",
      leg      = leg,
      sed_num  = sed_num,
      date     = as.Date(date_),
      speaker  = speaker,
      id_persona = persona,
      para_class = para_class,
      speech_lead = speaker_party_raw,
      text     = stringr::str_squish(txt),
      snippet  = stringr::str_trunc(stringr::str_squish(txt), 280, ellipsis = "…")
    )
  }
  if (length(out) == 0) return(NULL)
  bind_rows(out)
}

senato_hits <- map_dfr(xml_files, function(f) {
  tryCatch(extract_one(f), error = function(e) {
    warning("Failed: ", basename(f), " :: ", conditionMessage(e)); NULL
  })
})

if (nrow(senato_hits) == 0) {
  cat("[extract-senato] no hits found\n")
} else {
  senato_hits <- senato_hits |> arrange(date, sed_num)
  out <- file.path(PROCESSED, "senato_hits.csv")
  readr::write_csv(senato_hits, out)
  cat(sprintf("[extract-senato] wrote %d hits → %s\n", nrow(senato_hits), out))
  cat(sprintf("[extract-senato] distinct sessions: %d\n",
              dplyr::n_distinct(senato_hits$sed_num)))
  cat(sprintf("[extract-senato] by para_class:\n"))
  print(senato_hits |> dplyr::count(para_class))
  cat(sprintf("[extract-senato] date range: %s → %s\n",
              min(senato_hits$date, na.rm = TRUE),
              max(senato_hits$date, na.rm = TRUE)))
}
