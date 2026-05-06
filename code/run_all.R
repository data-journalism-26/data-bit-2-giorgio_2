# run_all.R — orchestrator
# 1. scrape Camera resoconti for /remigra/i (shell)
# 2. clone Senato Akoma Ntoso bulk repo (shell, sparse-checkout Leg18–19)
# 3. extract Camera hits (R)
# 4. extract Senato hits (R)
# 5. attach party affiliation to each hit (R)
# 6. build the figure (R)
#
# Steps 1 and 2 are idempotent and skip files already present.

source(here::here("code", "00-setup.R"))

run_step <- function(label, expr) {
  cat(sprintf("\n=== %s ===\n", label))
  t0 <- Sys.time()
  expr()
  cat(sprintf("  done in %.1fs\n", as.numeric(Sys.time() - t0, units = "secs")))
}

# 1. Camera scrape (shell)
run_step("01 scrape Camera (shell)", function() {
  system2("bash", c(file.path(PROJECT_ROOT, "code", "01-scrape-camera.sh")))
})

# 2. Senato bulk repo (git clone, sparse-checkout)
run_step("02 fetch Senato bulk repo", function() {
  if (!dir.exists(file.path(RAW_SENATO, "Leg19"))) {
    system2("git", c("clone", "--depth", "1", "--filter=blob:none", "--sparse",
                     "https://github.com/SenatoDellaRepubblica/AkomaNtosoBulkData.git",
                     RAW_SENATO))
    old_wd <- setwd(RAW_SENATO); on.exit(setwd(old_wd))
    system2("git", c("sparse-checkout", "set", "Leg18", "Leg19"))
  } else {
    cat("  Senato repo already cloned — skipping\n")
  }
})

run_step("03 extract Camera",  function() source(file.path(PROJECT_ROOT, "code", "02-extract-camera.R")))
run_step("04 extract Senato",  function() source(file.path(PROJECT_ROOT, "code", "03-extract-senato.R")))
run_step("05 attach parties",  function() source(file.path(PROJECT_ROOT, "code", "04-party-lookup.R")))
run_step("06 build figure",    function() source(file.path(PROJECT_ROOT, "code", "05-figure.R")))

cat("\n=== done. piece at article.html (figure embedded; no separate raster).\n")
