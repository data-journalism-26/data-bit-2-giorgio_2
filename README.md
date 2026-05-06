# When did "remigrazione" enter the Italian parliament — and who used it?

**Author:** Giorgio Coppola · **Date:** May 2026 · GRAD-E1493 Data Journalism, Hertie School

For two years "remigrazione" — the euphemism for mass forced removal coined by French Identitarians around 2014 and pushed across Europe by Austrian activist Martin Sellner — sat outside Italian plenary debate, except as an insult thrown at the right. Then, on 1 April 2026, an FdI senator embraced it.

## 📄 View

**[Open on raw.githack.com](https://raw.githack.com/data-journalism-26/data-bit-2-giorgio_2/main/article.html)** · or open `article.html` directly in any browser — the page is self-contained, no local server needed.

## Layout

```
.
├── article.html              # HTML shell + article copy + methodology dropdown + figure
├── assets/
│   └── style.css             # all visual styling
├── code/
│   ├── 00-setup.R            # paths, packages, search regex
│   ├── 01-scrape-camera.sh   # curl + xargs, stream-grep, only matches kept
│   ├── 02-extract-camera.R   # HTML → tidy CSV of speech-level hits
│   ├── 03-extract-senato.R   # Akoma Ntoso XML → tidy CSV of speech / allegato hits
│   ├── 04-party-lookup.R     # pulls scheda pages, attaches party at time of speech
│   ├── 05-figure.R           # prints summary stats; figure itself lives in article.html
│   └── run_all.R             # orchestrator (idempotent)
├── data/
│   ├── raw/                  # cached Camera HTML, Senato repo (sparse), deputy schede
│   └── processed/            # camera_hits.csv, senato_hits.csv, all_hits.csv
└── README.md
```

### Where to edit what

- **Article copy, figure markup, methodology dropdown** → `article.html`
- **Visual styling** → `assets/style.css`
- **Search regex and paths** → `code/00-setup.R`
- **Camera scraping** → `code/01-scrape-camera.sh`
- **Camera / Senato parsing** → `code/02-extract-camera.R`, `code/03-extract-senato.R`
- **Party attribution at time of speech** → `code/04-party-lookup.R`

## Rebuilding the data

The processed CSVs in `data/processed/` ship with the repo, so the article opens out of the box. To regenerate them from scratch:

```bash
Rscript code/run_all.R
```

Each step is idempotent — re-running re-uses cached Camera HTML, the Senato sparse clone, and the deputy scheda pages.

The pipeline uses `httr2`, `rvest`, `xml2`, `stringr`, `dplyr`, `tidyr`, `purrr`, `lubridate`, `here`.

## Sources

- **Camera dei Deputati** — plenary resoconti stenografici from the official portal <https://www.camera.it/> (one HTML page per session at `documenti.camera.it/leg{LL}/resoconti/assemblea/html/sed{NNNN}/stenografico.htm`).
- **Senato della Repubblica** — official Akoma Ntoso bulk repository <https://github.com/SenatoDellaRepubblica/AkomaNtosoBulkData> (one `resaula/*-ra.akn.xml` file per resoconto d'aula).
- **Camera deputy schede** — biographical and group-history pages on `documenti.camera.it`, used to attribute each speech to the speaker's parliamentary group at the date of the speech.

## Methodology

- **Search pattern.** Case-insensitive regex `remigra[a-z]*` on every paragraph — matches `remigrazione`, `remigrare`, `remigrato`, etc.
- **Scope.** Plenary records only — Camera resoconti stenografici and Senato resoconti d'aula — for legislatures XVIII (2018–2022) and XIX (full to the most recent session, May 2026).
- **Camera attribution.** Each `<p class="intervento">` / `<p class="interventoVirtuale">` carries an `idPersona` for its speaker; group history is fetched from the deputy's scheda and the group active on the date of the speech is selected (relevant e.g. for Sasso, who left Lega for Misto on 6 February 2026).
- **Senato attribution.** Matches inside `<an:speech>` are attributed to the speaker named in `<an:from>`; matches in Allegato B (written questions) carry no paragraph-level signer and are tagged `allegato_b`.
- **Curation.** The figure shows eight moments selected from the 68 paragraph-level hits, picked for the trajectory they trace (firsts, breakthroughs, and the peak session) rather than for raw frequency.
- For the full walkthrough, see the *Data and methods* dropdown at the bottom of the article.

## AI disclosure

Claude Code (Anthropic) was used to support the design of the page, the troubleshooting and refinement of the scraping/parsing pipeline, and the article styling. Editorial decisions, data wrangling, analysis, interpretation, and writing are the author's.
