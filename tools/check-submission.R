# Copyright (c) d-SEAMS developers
# Command line for the submission checks. The checks themselves are in
# inst/check-submission.R, which the package install keeps, so a test can
# source them when this file is not beside the test run.
#
#   Rscript tools/check-submission.R
#   Rscript tools/check-submission.R --write
#   Rscript tools/check-submission.R --test-log PATH

script_root <- function() {
  cmd <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", cmd, value = TRUE)
  if (length(file_arg) != 1L) {
    return(normalizePath("."))
  }
  normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1L])), ".."))
}

parse_cli_args <- function(args) {
  write_mode <- FALSE
  test_log <- NULL
  i <- 1L
  while (i <= length(args)) {
    arg <- args[[i]]
    if (identical(arg, "--write")) {
      write_mode <- TRUE
    } else if (identical(arg, "--test-log")) {
      if (i == length(args)) {
        stop("--test-log requires a file path", call. = FALSE)
      }
      i <- i + 1L
      test_log <- args[[i]]
    } else if (startsWith(arg, "--test-log=")) {
      test_log <- sub("^--test-log=", "", arg)
    } else {
      stop(
        "usage: Rscript tools/check-submission.R [--write] [--test-log PATH]",
        call. = FALSE
      )
    }
    i <- i + 1L
  }
  list(write = write_mode, test_log = test_log)
}

# Rscript sets --file= to this script. A test that sources it does not, so
# the source() frame's ofile is used first. Either way the checks are the
# installed file's source, one directory up, in inst/.
checker_file <- function() {
  found <- NULL
  for (i in seq_along(sys.frames())) {
    f <- sys.frame(i)$ofile
    if (is.character(f) && length(f) == 1L &&
        grepl("tools/check-submission\\.R$", f)) {
      found <- f
    }
  }
  if (is.null(found)) {
    cmd <- commandArgs(trailingOnly = FALSE)
    file_arg <- grep("^--file=", cmd, value = TRUE)
    if (length(file_arg) == 1L) {
      candidate <- sub("^--file=", "", file_arg[1L])
      if (grepl("tools/check-submission\\.R$", candidate)) {
        found <- candidate
      }
    }
  }
  if (is.null(found)) {
    stop("tools/check-submission.R could not find its own path", call. = FALSE)
  }
  normalizePath(
    file.path(dirname(found), "..", "inst", "check-submission.R"),
    mustWork = TRUE
  )
}

source(checker_file(), local = TRUE)

if (sys.nframe() == 0L) {
  root <- script_root()
  opts <- parse_cli_args(commandArgs(trailingOnly = TRUE))
  if (opts$write) {
    write_submission_description(root)
    cat("rewrote the DESCRIPTION fence in docs/ropensci-submission.md\n")
  }
  problems <- check_submission(root, test_log = opts$test_log)
  if (length(problems)) {
    stop(paste(problems, collapse = "\n"), call. = FALSE)
  }
  cat(
    "submission DESCRIPTION matches the file; Ruhila Goswami's record matches",
    if (!is.null(opts$test_log)) "; bundled-check summary matches the test log",
    "\n",
    sep = ""
  )
}
