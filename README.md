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
│   ├── raw/
│   │   ├── camera/           # Camera resoconti HTML, only sessions that mention remigra*
│   │   ├── senato_repo/      # sparse clone of SenatoDellaRepubblica/AkomaNtosoBulkData (Leg17–19)
│   │   └── schede_camera/    # one HTML per deputy whose speech matched (party history)
│   └── processed/            # camera_hits.csv, senato_hits.csv, all_hits.csv
├── Makefile                  # incremental entry points: make, make figure, make clean
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
make            # full pipeline → data/processed/all_hits.csv
make figure     # print headline numbers
make clean      # delete the CSVs, keep scraped files
```

…or, equivalently, `Rscript code/run_all.R` for a single-shot rebuild. Both paths are idempotent — re-running re-uses cached Camera HTML, the Senato sparse clone, and the deputy scheda pages.

The pipeline uses `httr2`, `rvest`, `xml2`, `stringr`, `dplyr`, `tidyr`, `purrr`, `lubridate`, `here`.

## Sources

- **Camera dei Deputati — plenary resoconti stenografici.** One HTML page per session at `documenti.camera.it/leg{LL}/resoconti/assemblea/html/sed{NNNN}/stenografico.htm`. Camera publishes no bulk download or session index, so `01-scrape-camera.sh` probes session numbers sequentially — XVII at every 50th session (sanity check), XVIII fully (1–750), XIX fully (1–700) — and keeps only HTML matching `/remigra/i`. Coverage window: legislatures XVIII (2018-03-23 → 2022-10-12) and XIX (2022-10-13 → most recent session, May 2026), the period during which the term entered European far-right discourse.
- **Senato della Repubblica — Akoma Ntoso bulk repository.** Cloned (sparse, blob-filtered) from <https://github.com/SenatoDellaRepubblica/AkomaNtosoBulkData>. One `Leg{17,18,19}/.../resaula/*-ra.akn.xml` file per resoconto d'aula; speeches sit inside `<an:speech>`, written questions live under Allegato B without a single signer.
- **Camera deputy schede.** Per-deputy biographical and group-history pages fetched on demand from `documenti.camera.it/apps/commonServices/getDocumento.ashx?sezione=deputati&tipoDoc=schedaDeputato&idLegislatura={L}&idPersona={N}`, where `idPersona` comes from the speech's anchor tag. Used to attribute each speech to the speaker's parliamentary group on the date of the speech.

## Methodology

- **Acquisition.** Camera publishes no bulk export, API, or session index, so `01-scrape-camera.sh` probes the empirically-observed URL template `documenti.camera.it/leg{LL}/resoconti/assemblea/html/sed{NNNN}/stenografico.htm` for every plausible `(leg, sed_num)` pair (XVIII fully 1–750, XIX fully 1–700), drops 404s and sub-5 KB stubs, and keeps only HTML matching `/remigra/i`. Senato is sparse-cloned from `SenatoDellaRepubblica/AkomaNtosoBulkData`. Deputy schede are fetched on demand from `getDocumento.ashx?...idPersona={N}` and cached. **Claude Code (Anthropic) was used to identify the Camera URL template and to scaffold the probe-and-filter pipeline; URLs were spot-checked against the live portal before the full scrape ran.**
- **Search pattern.** Case-insensitive regex `remigra[a-z]*` on every paragraph — matches `remigrazione`, `remigrare`, `remigrato`, etc.
- **Scope.** Plenary records only — Camera resoconti stenografici and Senato resoconti d'aula — for legislatures XVIII (2018–2022) and XIX (full to the most recent session, May 2026). All matched paragraphs end up in legislature XIX; XVIII appears in scope but yields zero hits. Earlier legislatures (XVII and before) are out of scope.
- **Camera attribution.** Each `<p class="intervento">` / `<p class="interventoVirtuale">` carries an `idPersona` for its speaker; group history is fetched from the deputy's scheda and the group active on the date of the speech is selected (relevant e.g. for Sasso, who left Lega for Misto on 6 February 2026).
- **Senato attribution.** Matches inside `<an:speech>` are attributed to the speaker named in `<an:from>`; matches in Allegato B (written questions) carry no paragraph-level signer and are tagged `allegato_b`.
- **Curation.** The figure shows eight moments selected from the 68 paragraph-level hits, picked for the trajectory they trace (firsts, breakthroughs, and the peak session) rather than for raw frequency.
- For the full walkthrough, see the *Data and methods* dropdown at the bottom of the article.

## AI disclosure

Claude Code (Anthropic) was used to identify the Camera URL template (Camera publishes no public index of session URLs), scaffold and refine the scraping/parsing pipeline, and support the page design and styling. Editorial decisions, data wrangling, analysis, interpretation, and writing are the author's.
