# 05-figure.R — print summary stats AND generate the cumulative-area
# SVG used in article.html (the second figure). The first figure
# (vertical quote-timeline) lives directly in article.html as HTML/CSS:
# the cards ARE the data and lose meaning at low resolution.
#
# Output: assets/figure-cumulative.svg — referenced from article.html
# via <img>. Re-running this script reproduces the chart from
# data/processed/all_hits.csv.

source(here::here("code", "00-setup.R"))

hits <- readr::read_csv(file.path(PROCESSED, "all_hits.csv"),
                        show_col_types = FALSE)

# ── Headline stats (kept from previous version) ─────────────────────
cat("\n=== Headline numbers ===\n")
cat(sprintf("  Total paragraphs containing remigra*: %d\n", nrow(hits)))
cat(sprintf("    Camera dei Deputati: %d\n",  sum(hits$chamber == "Camera")))
cat(sprintf("    Senato della Repubblica: %d (%d speeches, %d Allegato B)\n",
            sum(hits$chamber == "Senato"),
            sum(hits$chamber == "Senato" & hits$para_class == "speech"),
            sum(hits$chamber == "Senato" & hits$para_class == "allegato_b")))

cat("\n=== Coalition split ===\n")
print(hits |> dplyr::count(coalition, sort = TRUE))

cat("\n=== Sessions with most mentions ===\n")
print(hits |> dplyr::count(chamber, date, sed_num, sort = TRUE) |> head(5))

# ── Aggregate to monthly cumulatives by coalition ────────────────────
# Collapse "Other" (Allegato B written questions) and "Misto" into one
# band labelled "Allegato B / Misto", matching the published figure.
hits$coalition_band <- dplyr::case_when(
  hits$coalition == "Opposition"           ~ "Opposition",
  hits$coalition == "Government coalition" ~ "Government coalition",
  TRUE                                     ~ "Allegato B / Misto"
)

months <- seq(as.Date("2024-04-01"), as.Date("2026-05-01"), by = "month")
bands  <- c("Allegato B / Misto", "Government coalition", "Opposition")

monthly <- hits |>
  dplyr::mutate(month = as.Date(format(date, "%Y-%m-01"))) |>
  dplyr::count(month, coalition_band, name = "n")

cum <- tidyr::expand_grid(month = months, coalition_band = bands) |>
  dplyr::left_join(monthly, by = c("month", "coalition_band")) |>
  dplyr::mutate(n = dplyr::coalesce(n, 0L)) |>
  dplyr::arrange(coalition_band, month) |>
  dplyr::group_by(coalition_band) |>
  dplyr::mutate(cum = cumsum(n)) |>
  dplyr::ungroup() |>
  dplyr::mutate(coalition_band = factor(coalition_band, levels = bands))

# ── Plot ─────────────────────────────────────────────────────────────
band_colours <- c(
  "Allegato B / Misto"   = "#bcbcbc",
  "Government coalition" = "#0f3b5a",
  "Opposition"           = "#c8102e"
)

n_total      <- nrow(hits)
lisei_date   <- as.Date("2026-04-01")
band_counts  <- as.list(table(hits$coalition_band)[bands])
legend_label <- function(b) {
  n <- band_counts[[b]]
  sprintf("%s · %d (%d%%)", b, n, round(100 * n / n_total))
}

p <- ggplot2::ggplot(cum,
                     ggplot2::aes(month, cum, fill = coalition_band)) +
  ggplot2::geom_area(position = "stack", alpha = 0.92) +
  ggplot2::geom_vline(xintercept = lisei_date,
                      linetype = "dashed",
                      colour = "#444", linewidth = 0.3) +
  ggplot2::annotate("text",
                    x = lisei_date - 30, y = n_total * 0.78,
                    label = "1 April 2026\nLisei breakthrough →\n+42 paragraphs in April",
                    hjust = 1, size = 3.2, colour = "#444",
                    family = "Helvetica") +
  ggplot2::annotate("text",
                    x = max(months), y = n_total,
                    label = sprintf(" %d total", n_total),
                    hjust = 0, vjust = 0.5, size = 3.1, fontface = "bold",
                    colour = "#7a1b1b", family = "Helvetica") +
  ggplot2::coord_cartesian(clip = "off") +
  ggplot2::scale_fill_manual(values = band_colours,
                             labels = vapply(bands, legend_label, character(1)),
                             breaks = bands) +
  ggplot2::scale_x_date(breaks = as.Date(c("2024-04-01", "2025-01-01", "2026-01-01")),
                        labels = c("2024", "2025", "2026"),
                        expand = ggplot2::expansion(mult = c(0.01, 0.02))) +
  ggplot2::scale_y_continuous(breaks = seq(0, 70, 10),
                              expand = ggplot2::expansion(mult = c(0, 0.05))) +
  ggplot2::labs(x = NULL, y = "Cumulative paragraphs containing 'remigra*'",
                fill = NULL) +
  ggplot2::theme_minimal(base_family = "Helvetica", base_size = 11) +
  ggplot2::theme(
    legend.position    = "bottom",
    legend.key.size    = ggplot2::unit(10, "pt"),
    panel.grid.minor   = ggplot2::element_blank(),
    panel.grid.major.x = ggplot2::element_line(colour = "#cfcfcf",
                                               linetype = "dotted"),
    panel.grid.major.y = ggplot2::element_line(colour = "#eee"),
    axis.title.y       = ggplot2::element_text(colour = "#444", size = 10),
    plot.margin        = ggplot2::margin(8, 56, 8, 8)
  )

ASSETS  <- file.path(PROJECT_ROOT, "assets")
out_svg <- file.path(ASSETS, "figure-cumulative.svg")
ggplot2::ggsave(out_svg, p, width = 7.2, height = 3.6,
                device = svglite::svglite, bg = "white")
cat(sprintf("\n[fig] wrote %s\n", out_svg))
