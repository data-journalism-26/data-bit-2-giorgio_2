# Reproducibility entry points for the remigrazione data bit.
# Steps are idempotent — cached Camera HTML, the Senato sparse clone, and
# deputy schede are all reused. `Rscript code/run_all.R` is the single-shot
# equivalent.
#
# Targets:
#   make                 full pipeline -> data/processed/all_hits.csv
#   make figure          print headline stats AND build assets/figure-cumulative.svg
#   make camera          Camera scrape only
#   make senato          Senato sparse clone only
#   make refresh-camera  re-probe Camera for new sessions
#   make clean           remove data/processed/*.csv (keeps raw caches)
#   make clean-cache     also remove data/raw/{camera,senato_repo,schede_camera}

R         := Rscript
CODE      := code
RAW       := data/raw
PROCESSED := data/processed

CAMERA_RAW := $(RAW)/camera
SENATO_RAW := $(RAW)/senato_repo
SCHEDE_RAW := $(RAW)/schede_camera

CAMERA_CSV := $(PROCESSED)/camera_hits.csv
SENATO_CSV := $(PROCESSED)/senato_hits.csv
ALL_CSV    := $(PROCESSED)/all_hits.csv
FIGURE_SVG := assets/figure-cumulative.svg

# Marker for "senato sparse clone is in place" — Leg19 exists after the
# sparse-checkout and not before, matching the heuristic in code/run_all.R.
SENATO_MARKER := $(SENATO_RAW)/Leg19

.PHONY: all setup camera senato hits parties figure clean clean-cache refresh-camera

all: $(ALL_CSV)

setup:
	$(R) -e 'source("$(CODE)/00-setup.R")'

# Camera publishes no bulk download or session index — the shell script
# probes session URLs sequentially and keeps only HTML matching /remigra/i.
camera: $(CAMERA_RAW)
$(CAMERA_RAW):
	bash $(CODE)/01-scrape-camera.sh

refresh-camera:
	bash $(CODE)/01-scrape-camera.sh

senato: $(SENATO_MARKER)
$(SENATO_MARKER):
	git clone --depth 1 --filter=blob:none --sparse \
		https://github.com/SenatoDellaRepubblica/AkomaNtosoBulkData.git \
		$(SENATO_RAW)
	cd $(SENATO_RAW) && git sparse-checkout set Leg18 Leg19

$(CAMERA_CSV): $(CODE)/02-extract-camera.R $(CODE)/00-setup.R | $(CAMERA_RAW)
	$(R) $<

$(SENATO_CSV): $(CODE)/03-extract-senato.R $(CODE)/00-setup.R | $(SENATO_MARKER)
	$(R) $<

hits: $(CAMERA_CSV) $(SENATO_CSV)

$(ALL_CSV): $(CODE)/04-party-lookup.R $(CODE)/00-setup.R $(CAMERA_CSV) $(SENATO_CSV)
	$(R) $<

parties: $(ALL_CSV)

# 05-figure.R prints summary stats and writes assets/figure-cumulative.svg
# from data/processed/all_hits.csv. Re-renders whenever the CSV changes.
$(FIGURE_SVG): $(CODE)/05-figure.R $(CODE)/00-setup.R $(ALL_CSV)
	$(R) $(CODE)/05-figure.R

figure: $(FIGURE_SVG)

clean:
	rm -f $(CAMERA_CSV) $(SENATO_CSV) $(ALL_CSV) $(FIGURE_SVG)

clean-cache: clean
	rm -rf $(CAMERA_RAW) $(SENATO_RAW) $(SCHEDE_RAW)
