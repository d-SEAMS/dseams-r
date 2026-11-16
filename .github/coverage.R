# Copyright (c) d-SEAMS developers
# covr for the test-coverage workflow. COVR_INSTALL keeps the instrumented
# install, the coverage object and any failing test output for the
# artifact; GITHUB_STEP_SUMMARY receives the per-file table.
install_path <- Sys.getenv("COVR_INSTALL")
cov <- covr::package_coverage(quiet = FALSE, clean = FALSE,
                              install_path = install_path)
print(cov)
saveRDS(cov, file.path(install_path, "coverage.rds"))
df <- as.data.frame(cov)
per <- tapply(df$value > 0, df$filename, mean)
writeLines(c(
  "## R coverage", "",
  sprintf("%.2f%% of R lines", covr::percent_coverage(cov)), "",
  "| file | percent |", "|---|---|",
  sprintf("| %s | %.1f |", names(per), 100 * per)
), Sys.getenv("GITHUB_STEP_SUMMARY"))
