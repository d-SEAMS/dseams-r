# Copyright (c) d-SEAMS developers

# R CMD check runs with the working directory set to tests/, and copies
# that directory away from the rest of the source tree. Walk up from both
# places, and from 00_pkg_src, until the symbol script is found. The same
# walk is in test-submission.R.
portability_root <- function() {
  starts <- unique(c(
    normalizePath(testthat::test_path("."), mustWork = FALSE),
    normalizePath(getwd(), mustWork = FALSE),
    normalizePath(testthat::test_path(".."), mustWork = FALSE),
    normalizePath(testthat::test_path("../.."), mustWork = FALSE)
  ))
  for (start in starts) {
    if (!nzchar(start) || !dir.exists(start)) {
      next
    }
    dir <- start
    for (i in seq_len(6L)) {
      helper <- file.path(dir, "tools", "reader-symbols.sh")
      if (file.exists(file.path(dir, "DESCRIPTION")) && file.exists(helper)) {
        return(normalizePath(dir))
      }
      src <- file.path(dir, "00_pkg_src", "dseams")
      src_helper <- file.path(src, "tools", "reader-symbols.sh")
      src_desc <- file.path(src, "DESCRIPTION")
      if (file.exists(src_desc) && file.exists(src_helper)) {
        return(normalizePath(src))
      }
      parent <- dirname(dir)
      if (identical(parent, dir)) {
        break
      }
      dir <- parent
    }
  }
  NULL
}

run_capture <- function(cmd, args) {
  out <- system2(cmd, args, stdout = TRUE, stderr = TRUE)
  status <- attr(out, "status")
  if (is.null(status)) {
    status <- 0L
  }
  list(status = as.integer(status), out = out)
}

read_map <- function(root, system_name) {
  script <- file.path(root, "tools", "reader-symbols.sh")
  got <- run_capture("sh", c(script, "--print-map", system_name))
  expect_identical(got$status, 0L, info = paste(got$out, collapse = "\n"))
  lines <- got$out[nzchar(got$out)]
  parts <- strsplit(lines, " ", fixed = TRUE)
  list(
    lines = lines,
    from = vapply(parts, `[[`, "", 1L),
    to = vapply(parts, `[[`, "", 2L)
  )
}

wrapper_symbols <- function(root) {
  lines <- readLines(file.path(root, "src", "dseams_r_io.cpp"), warn = FALSE)
  asm <- character()
  funs <- character()
  vars <- character()
  for (line in lines) {
    m <- regexec("__asm__\\(\"([^\"]+)\"\\)", line)
    g <- regmatches(line, m)[[1L]]
    if (length(g) == 2L) {
      asm <- c(asm, g[[2L]])
    }
    m <- regexec("\\b(dseams_r_[A-Za-z0-9_]+)\\s*\\(", line)
    g <- regmatches(line, m)[[1L]]
    if (length(g) == 2L) {
      funs <- c(funs, g[[2L]])
    }
    m <- regexec("\\b(dseams_r_[A-Za-z0-9_]+)\\s*;", line)
    g <- regmatches(line, m)[[1L]]
    if (length(g) == 2L) {
      vars <- c(vars, g[[2L]])
    }
    m <- regexec("\\(\\*(dseams_r_[A-Za-z0-9_]+)\\)", line)
    g <- regmatches(line, m)[[1L]]
    if (length(g) == 2L) {
      vars <- c(vars, g[[2L]])
    }
  }
  # A use such as `= dseams_r___acrt_iob_func;` matches the semicolon
  # pattern too. A name that is called is a function.
  funs <- unique(funs)
  vars <- setdiff(unique(vars), funs)
  list(asm = unique(asm), funs = funs, vars = vars, lines = lines)
}

defined_wrappers <- function(found) {
  unique(c(found$asm, found$funs, found$vars))
}

test_that("each platform map names every source once", {
  root <- portability_root()
  expect_false(is.null(root))
  for (system_name in c("Linux", "Darwin", "Windows_NT")) {
    map <- read_map(root, system_name)
    expect_gt(length(map$lines), 0L)
    expect_identical(
      anyDuplicated(sub(" .*", "", map$lines)),
      0L,
      info = system_name
    )
  }
})

test_that("Darwin targets are the Mach-O names of the wrappers", {
  root <- portability_root()
  expect_false(is.null(root))
  darwin <- read_map(root, "Darwin")
  linux <- read_map(root, "Linux")
  windows <- read_map(root, "Windows_NT")
  found <- wrapper_symbols(root)
  defined <- defined_wrappers(found)

  # Mach-O does not prefix an asm label, so the iostream targets are the
  # labels themselves. Every other target carries the underscore.
  is_asm <- darwin$to %in% found$asm
  expect_setequal(darwin$to[is_asm], found$asm)
  expect_true(all(startsWith(darwin$to[!is_asm], "_")))
  darwin_names <- ifelse(is_asm, darwin$to, sub("^_", "", darwin$to))
  expect_true(all(darwin_names %in% defined))
  expect_true(all(linux$to %in% defined))
  expect_true(all(windows$to %in% defined))
  expect_setequal(darwin_names, linux$to)

  stdout_target <- sub("^_", "", darwin$to[darwin$from == "___stdoutp"])
  stderr_target <- sub("^_", "", darwin$to[darwin$from == "___stderrp"])
  expect_identical(stdout_target, "dseams_r_stdout")
  expect_identical(stderr_target, "dseams_r_stderr")
  expect_true(stdout_target %in% found$vars)
  expect_true(stderr_target %in% found$vars)
  expect_false(stdout_target %in% found$funs)
  expect_false(stderr_target %in% found$funs)
  expect_false(any(grepl("dseams_r___stdoutp", found$lines, fixed = TRUE)))
  expect_false(any(grepl("dseams_r___stderrp", found$lines, fixed = TRUE)))

  expect_false("printf" %in% darwin$from)
  expect_true("_printf" %in% darwin$from)
  expect_true("printf" %in% linux$from)
  expect_false("__acrt_iob_func" %in% linux$from)
  expect_false("__acrt_iob_func" %in% darwin$from)
  expect_true("__acrt_iob_func" %in% windows$from)
  expect_true("__imp___acrt_iob_func" %in% windows$from)
  expect_identical(
    windows$to[windows$from == "__imp___acrt_iob_func"],
    "dseams_r___imp___acrt_iob_func"
  )
  expect_true("dseams_r___imp___acrt_iob_func" %in% found$vars)
  expect_true("dseams_r___acrt_iob_func" %in% found$funs)
})
