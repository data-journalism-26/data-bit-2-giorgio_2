#!/usr/bin/env bash
# Scrape Italian Chamber of Deputies plenary stenographic records and keep
# only sessions whose text matches /remigra/i. Streams to grep, writes
# matched HTML to data/raw/camera/, discards the rest.
#
# Coverage: legislatures XVIII (2018-03-23 → 2022-10-12) and XIX (2022-10-13 → today)
# — the window during which the term entered European far-right discourse.
# A few XVII (2013-2018) sessions are also probed at coarse intervals as a
# sanity check that the term was absent from earlier proceedings.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT/data/raw/camera"
TMP_DIR="$(mktemp -d)"
mkdir -p "$OUT_DIR"

UA="data-journalism research scrape - Hertie School"
MIN_BYTES=5000

scrape_session() {
  local leg=$1
  local sed_num=$2
  local sed_padded
  sed_padded=$(printf "%04d" "$sed_num")
  local out="${OUT_DIR}/leg${leg}_sed${sed_padded}.html"

  # Skip if already cached as a hit
  [[ -f "$out" ]] && return 0

  local url="https://documenti.camera.it/leg${leg}/resoconti/assemblea/html/sed${sed_padded}/stenografico.htm"
  local tmp="${TMP_DIR}/leg${leg}_sed${sed_padded}.html"

  if ! curl -sS -m 60 -A "$UA" "$url" -o "$tmp"; then
    rm -f "$tmp"
    return 0
  fi

  if [[ ! -s "$tmp" ]] || [[ $(stat -f %z "$tmp") -lt $MIN_BYTES ]]; then
    rm -f "$tmp"
    return 0
  fi

  if grep -qiE 'remigra' "$tmp"; then
    mv "$tmp" "$out"
    echo "  HIT  leg${leg} sed${sed_padded}" >&2
  else
    rm -f "$tmp"
  fi
}

export -f scrape_session
export OUT_DIR TMP_DIR UA MIN_BYTES

{
  # Coarse XVII probe: every 50th session as a sanity check
  for s in $(seq 1 50 950); do echo "17 $s"; done
  # Full XVIII and XIX coverage
  for s in $(seq 1 750); do echo "18 $s"; done
  for s in $(seq 1 700); do echo "19 $s"; done
} | xargs -P 12 -n 2 bash -c 'scrape_session "$@"' _

echo
echo "[scrape-camera] hits saved:"
ls -1 "$OUT_DIR" | wc -l | tr -d ' '

rm -rf "$TMP_DIR"
