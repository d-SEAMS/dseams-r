# Copyright (c) d-SEAMS developers
# Fails unless a test run read every pinned input and skipped none of the
# tests that need one. Run after R CMD check (or covr) with
# DSEAMS_REQUIRE_DATA=1 and DSEAMS_INPUTS_LOG set:
#
#   Rscript tools/check-test-inputs.R <testthat.Rout> <inputs log>
#
# The pins and the skip wording come from tests/testthat/helper-inputs.R.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) {
  stop("usage: Rscript tools/check-test-inputs.R <testthat.Rout> <inputs log>")
}
rout <- args[[1L]]
log <- args[[2L]]

helper <- new.env()
sys.source(file.path("tests", "testthat", "helper-inputs.R"), envir = helper)
pins <- get("seams_inputs_sha256", envir = helper)

fail <- function(...) {
  message(...)
  quit(status = 1L)
}

if (!file.exists(rout)) {
  fail(rout, " does not exist; the tests did not finish")
}
out <- readLines(rout, warn = FALSE)
totals <- grep("^\\[ FAIL [0-9]+ \\| WARN [0-9]+ \\| SKIP [0-9]+ \\| PASS [0-9]+ \\]",
               out, value = TRUE)
if (length(totals) == 0L) {
  fail(rout, " has no testthat totals line")
}
final <- totals[[length(totals)]]
message(final)
if (!startsWith(final, "[ FAIL 0 ")) {
  fail("testthat reports failures: ", final)
}

if (!file.exists(log)) {
  fail(log, " does not exist; no test resolved a pinned input")
}
seen <- strsplit(readLines(log, warn = FALSE), " ", fixed = TRUE)
for (name in names(pins)) {
  hits <- Filter(function(f) length(f) >= 3L && identical(f[[1L]], name), seen)
  if (length(hits) == 0L) {
    fail(name, " is not in ", log, "; its test did not read it")
  }
  digests <- unique(vapply(hits, `[[`, "", 2L))
  if (!identical(digests, unname(pins[[name]]))) {
    fail(name, " was read with sha256 ", paste(digests, collapse = ", "),
         ", expected ", pins[[name]])
  }
  skipped <- grep(name, out, fixed = TRUE, value = TRUE)
  skipped <- grep("is not in DSEAMS_ROOT/input/traj", skipped,
                  fixed = TRUE, value = TRUE)
  if (length(skipped)) {
    fail("a test that needs ", name, " skipped:\n",
         paste(skipped, collapse = "\n"))
  }
  message(name, " read ", length(hits), " time(s) with sha256 ", pins[[name]])
}
