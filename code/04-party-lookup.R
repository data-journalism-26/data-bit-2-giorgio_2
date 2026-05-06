# 04-party-lookup.R — attach party affiliations to each hit.
# Camera: fetch each speaker's scheda once, parse the gruppo parlamentare.
# Senato: speaker name in resoconti embeds the group, e.g.
#   "DE CRISTOFARO(Misto-AVS) ." or "LISEI(FdI) ." — extract via regex.
# Allegato B written questions have no single signer (we leave NA and tag
# the para_class).

source(here::here("code", "00-setup.R"))

camera_hits <- readr::read_csv(file.path(PROCESSED, "camera_hits.csv"),
                               show_col_types = FALSE)
senato_hits <- readr::read_csv(file.path(PROCESSED, "senato_hits.csv"),
                               show_col_types = FALSE)

# ---- Camera: fetch scheda per id_persona ----------------------------------

scheda_url <- function(id_persona, leg = 19) {
  sprintf("https://documenti.camera.it/apps/commonServices/getDocumento.ashx?sezione=deputati&tipoDoc=schedaDeputato&idLegislatura=%d&idPersona=%d",
          leg, as.integer(id_persona))
}

# Parse group history from a scheda HTML. Each group entry looks like:
#   <span class="stesso-stile">Lega - Salvini Premier</span>
#   <span>dal 18 Ottobre 2022 al 06 Febbraio 2026</span>
# We pull all (group_name, from_date, to_date) tuples; "to_date" may say
# "ad oggi" for the current group.
parse_groups <- function(html_text) {
  # Restrict to the GRUPPO PARLAMENTARE section only — the scheda also has
  # sections for committees and government roles using the same span class.
  section <- stringr::str_match(html_text,
    stringr::regex('<h3>GRUPPO PARLAMENTARE</h3>(.*?)<h3>', dotall = TRUE))
  if (is.na(section[1])) return(NULL)

  # Each <li> entry in the section. Group name can be either bare text inside
  # the span, or wrapped in <a>..</a>. Date span is either:
  #   "dal D Month Y al D Month Y" (past assignment), or
  #   "dal D Month Y" / "dal D Month Y ad oggi" (still active).
  block <- section[, 2]
  m <- stringr::str_match_all(block, stringr::regex(
    '<span class="stesso-stile">(?:<a[^>]*>)?([^<]+?)(?:</a>)?</span>\\s*<span>dal\\s+([^<]+?)(?:\\s+al\\s+([^<]+?))?(?:\\s+ad oggi)?</span>',
    dotall = TRUE))[[1]]
  if (nrow(m) == 0) return(NULL)
  tibble(
    group  = stringr::str_trim(m[, 2]),
    from_d = stringr::str_trim(m[, 3]),
    to_d   = ifelse(is.na(m[, 4]) | m[, 4] == "", "ad oggi", stringr::str_trim(m[, 4]))
  )
}

ITALIAN_MONTHS_FULL <- c(
  Gennaio = 1L, Febbraio = 2L, Marzo = 3L, Aprile = 4L, Maggio = 5L, Giugno = 6L,
  Luglio = 7L, Agosto = 8L, Settembre = 9L, Ottobre = 10L, Novembre = 11L, Dicembre = 12L
)

parse_it_date <- function(s) {
  if (is.na(s) || s == "ad oggi") return(NA_Date_)
  m <- stringr::str_match(s, "^\\s*(\\d{1,2})\\s+([A-Za-z]+)\\s+(\\d{4})\\s*$")
  if (is.na(m[1])) return(NA_Date_)
  mn <- ITALIAN_MONTHS_FULL[stringr::str_to_title(m[, 3])]
  if (is.na(mn)) return(NA_Date_)
  as.Date(sprintf("%s-%02d-%02d", m[, 4], mn, as.integer(m[, 2])))
}

NA_Date_ <- as.Date(NA)

# Map a long group name to a short label used on the figure.
short_label <- function(group) {
  case_when(
    stringr::str_detect(group, "Lega")            ~ "Lega",
    stringr::str_detect(group, "Fratelli d.Italia") ~ "FdI",
    stringr::str_detect(group, "Forza Italia")    ~ "FI",
    stringr::str_detect(group, "Noi Moderati")    ~ "Noi Moderati",
    stringr::str_detect(group, "Partito Democratico") ~ "PD",
    stringr::str_detect(group, "MoVimento 5 Stelle|Movimento 5 Stelle") ~ "M5S",
    stringr::str_detect(group, "Alleanza Verdi|Verdi e Sinistra|AVS")   ~ "AVS",
    stringr::str_detect(group, "Italia Viva|Italiaviva")  ~ "IV",
    stringr::str_detect(group, "Azione")          ~ "Azione",
    stringr::str_detect(group, "Pi.+Europa|\\+Europa") ~ "+Europa",
    stringr::str_detect(group, "MISTO|Misto")     ~ "Misto",
    TRUE ~ group
  )
}

# Coalition tag for color coding
coalition_of <- function(party) {
  case_when(
    party %in% c("Lega", "FdI", "FI", "Noi Moderati") ~ "Government coalition",
    party %in% c("PD", "M5S", "AVS", "IV", "Azione", "+Europa") ~ "Opposition",
    party == "Misto" ~ "Misto",
    TRUE ~ "Other"
  )
}

# Cache schede on disk
sched_dir <- file.path(PROJECT_ROOT, "data", "raw", "schede_camera")
dir.create(sched_dir, showWarnings = FALSE, recursive = TRUE)

ids <- unique(na.omit(camera_hits$id_persona))
cat(sprintf("[party] %d unique Camera speakers to look up\n", length(ids)))

fetch_scheda <- function(id) {
  out <- file.path(sched_dir, sprintf("scheda_%d.html", as.integer(id)))
  if (!file.exists(out)) {
    resp <- tryCatch(
      httr2::request(scheda_url(id)) |>
        httr2::req_user_agent("data-journalism research") |>
        httr2::req_timeout(30) |>
        httr2::req_perform(),
      error = function(e) NULL
    )
    if (is.null(resp)) return(NULL)
    body <- httr2::resp_body_string(resp)
    writeLines(body, out, useBytes = TRUE)
  }
  readLines(out, warn = FALSE) |> paste(collapse = "\n")
}

# Pull each speaker's group at the date of the speech
attach_party <- function(id, date) {
  if (is.na(id)) return(NA_character_)
  html <- fetch_scheda(id)
  if (is.null(html)) return(NA_character_)
  groups <- parse_groups(html)
  if (is.null(groups) || nrow(groups) == 0) return(NA_character_)
  groups$from_d_p <- as.Date(vapply(groups$from_d, parse_it_date, FUN.VALUE = as.Date(NA)))
  groups$to_d_p   <- vapply(groups$to_d, function(s) {
    if (s == "ad oggi") Sys.Date() else parse_it_date(s)
  }, FUN.VALUE = as.Date(NA))
  match_row <- which(groups$from_d_p <= date & groups$to_d_p >= date)
  if (length(match_row) == 0) {
    # Fallback: pick the latest group <= date, or the first one
    match_row <- which.max(groups$from_d_p[groups$from_d_p <= date])
    if (length(match_row) == 0) match_row <- 1L
  }
  short_label(groups$group[match_row[1]])
}

camera_hits <- camera_hits |>
  mutate(party = purrr::map2_chr(id_persona, date, attach_party))

# ---- Senato: parse "(GROUP)" prefix in snippet ----------------------------
parse_senato_party <- function(speech_lead, para_class) {
  if (is.na(speech_lead) || para_class == "allegato_b") return(NA_character_)
  m <- stringr::str_match(speech_lead, "\\(([A-Z][^\\(\\)]+(?:\\([^\\)]+\\)[^\\(\\)]*)?)\\)\\s*\\.")
  if (is.na(m[1])) return(NA_character_)
  short_label(m[, 2])
}

senato_hits <- senato_hits |>
  mutate(party = purrr::map2_chr(speech_lead, para_class, parse_senato_party))

camera_hits$id_persona <- as.character(camera_hits$id_persona)
senato_hits$id_persona <- as.character(senato_hits$id_persona)
all_hits <- bind_rows(camera_hits, senato_hits) |>
  mutate(coalition = coalition_of(party))

readr::write_csv(all_hits, file.path(PROCESSED, "all_hits.csv"))
cat(sprintf("[party] wrote %d rows → all_hits.csv\n", nrow(all_hits)))
print(all_hits |> dplyr::count(chamber, party, coalition, sort = TRUE))
