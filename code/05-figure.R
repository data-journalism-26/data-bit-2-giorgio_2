# 05-figure.R — print summary stats. The figure itself is a vertical
# quote-timeline embedded directly in article.html (HTML/CSS, not a
# raster — quotes lose meaning at low resolution and "context" is the
# whole point). The eight moments shown there are an editorial selection
# from data/processed/all_hits.csv; reasoning is documented in README.md.

source(here::here("code", "00-setup.R"))

hits <- readr::read_csv(file.path(PROCESSED, "all_hits.csv"),
                        show_col_types = FALSE)

cat("\n=== Headline numbers ===\n")
cat(sprintf("  Total paragraphs containing remigra*: %d\n", nrow(hits)))
cat(sprintf("    Camera dei Deputati: %d\n",  sum(hits$chamber == "Camera")))
cat(sprintf("    Senato della Repubblica: %d (%d speeches, %d Allegato B)\n",
            sum(hits$chamber == "Senato"),
            sum(hits$chamber == "Senato" & hits$para_class == "speech"),
            sum(hits$chamber == "Senato" & hits$para_class == "allegato_b")))

cat("\n=== First mentions ===\n")
first_camera <- hits |>
  dplyr::filter(chamber == "Camera") |>
  dplyr::arrange(date) |> dplyr::slice(1)
first_senato <- hits |>
  dplyr::filter(chamber == "Senato") |>
  dplyr::arrange(date) |> dplyr::slice(1)
cat(sprintf("  Camera: %s — %s (%s) [seduta %d]\n",
            first_camera$date, first_camera$speaker,
            first_camera$party, first_camera$sed_num))
cat(sprintf("  Senato: %s — %s [seduta %d, %s]\n",
            first_senato$date,
            ifelse(is.na(first_senato$speaker), "Allegato B written question",
                   paste0(first_senato$speaker, " (", first_senato$party, ")")),
            first_senato$sed_num, first_senato$para_class))

cat("\n=== Coalition split ===\n")
print(hits |> dplyr::count(coalition, sort = TRUE))

cat("\n=== Sessions with most mentions ===\n")
print(hits |> dplyr::count(chamber, date, sed_num, sort = TRUE) |> head(5))

cat("\n=== Government-coalition speakers (the wedge) ===\n")
print(hits |>
  dplyr::filter(coalition == "Government coalition") |>
  dplyr::count(chamber, speaker, party, sort = TRUE))

cat("\n[fig] no raster figure produced — the figure lives in article.html\n")
