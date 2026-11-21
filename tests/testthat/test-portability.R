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

host_system <- function() {
  got <- run_capture("uname", "-s")
  if (identical(got$status, 0L) && length(got$out) == 1L && nzchar(got$out)) {
    return(got$out)
  }
  Sys.info()[["sysname"]]
}

tool_path <- function(name) {
  found <- Sys.which(name)
  if (nzchar(found)) found else NULL
}

config_tool <- function(key) {
  bin <- file.path(R.home("bin"), "R")
  if (!file.exists(bin)) {
    return(NULL)
  }
  got <- run_capture(bin, c("CMD", "config", key))
  if (!identical(got$status, 0L) || !length(got$out)) {
    return(NULL)
  }
  parts <- strsplit(trimws(got$out[[1L]]), "[[:space:]]+")[[1L]]
  if (!length(parts) || !nzchar(parts[[1L]])) {
    return(NULL)
  }
  if (!nzchar(Sys.which(parts[[1L]])) && !file.exists(parts[[1L]])) {
    return(NULL)
  }
  parts
}

# Darwin needs llvm-objcopy. GNU objcopy does not rewrite Mach-O.
find_objcopy <- function() {
  sys <- Sys.info()[["sysname"]]
  llvm <- tool_path("llvm-objcopy")
  gnu <- tool_path("objcopy")
  if (identical(sys, "Darwin")) {
    if (!is.null(llvm)) {
      ver <- run_capture(llvm, "--version")
      if (identical(ver$status, 0L) && any(grepl("llvm", ver$out, ignore.case = TRUE))) {
        return(llvm)
      }
    }
    brew <- tool_path("brew")
    if (!is.null(brew)) {
      prefix <- run_capture(brew, c("--prefix", "llvm"))
      if (identical(prefix$status, 0L) && length(prefix$out) == 1L) {
        candidate <- file.path(prefix$out, "bin", "llvm-objcopy")
        if (file.exists(candidate)) {
          return(candidate)
        }
      }
    }
    return(NULL)
  }
  if (!is.null(gnu)) {
    return(gnu)
  }
  llvm
}

nm_undefined <- function(nm, archive) {
  got <- run_capture(nm, c("-u", archive))
  expect_identical(got$status, 0L, info = paste(got$out, collapse = "\n"))
  syms <- character()
  for (line in got$out) {
    if (!grepl("(^|[[:space:]])U([[:space:]]|$)", line)) {
      next
    }
    parts <- strsplit(trimws(line), "[[:space:]]+")[[1L]]
    syms <- c(syms, parts[[length(parts)]])
  }
  syms
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

test_that("objcopy rewrites a real archive onto the wrapper names", {
  root <- portability_root()
  expect_false(is.null(root))
  objcopy <- find_objcopy()
  nm <- tool_path("nm")
  if (is.null(nm)) {
    nm <- tool_path("llvm-nm")
  }
  cc <- config_tool("CC")
  ar <- config_tool("AR")
  if (is.null(objcopy) || is.null(nm) || is.null(cc) || is.null(ar)) {
    skip("objcopy, nm, ar, or the C compiler is absent")
  }

  sys <- host_system()
  map <- read_map(root, sys)
  dir <- tempfile("dseams-symbols")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  src <- file.path(dir, "fixture.c")
  obj <- file.path(dir, "fixture.o")
  archive <- file.path(dir, "libfixture.a")
  decls <- vapply(seq_along(map$from), function(i) {
    sprintf("extern char dseams_fix_%d __asm__(\"%s\");", i, map$from[[i]])
  }, "")
  uses <- vapply(seq_along(map$from), function(i) {
    sprintf("  n ^= (unsigned long)&dseams_fix_%d;", i)
  }, "")
  writeLines(c(
    decls,
    "",
    "unsigned long dseams_r_touch(void) {",
    "  unsigned long n = 0;",
    uses,
    "  return n;",
    "}",
    ""
  ), src)
  compiled <- run_capture(cc[[1L]], c(cc[-1L], "-c", src, "-o", obj))
  expect_identical(compiled$status, 0L, info = paste(compiled$out, collapse = "\n"))
  archived <- run_capture(ar[[1L]], c(ar[-1L], "crs", archive, obj))
  expect_identical(archived$status, 0L, info = paste(archived$out, collapse = "\n"))

  before <- nm_undefined(nm, archive)
  expect_true(all(map$from %in% before))

  script <- file.path(root, "tools", "reader-symbols.sh")
  rewritten <- run_capture("sh", c(script, objcopy, archive, sys))
  expect_identical(rewritten$status, 0L, info = paste(rewritten$out, collapse = "\n"))

  after <- nm_undefined(nm, archive)
  expect_true(all(map$to %in% after))
  expect_false(any(map$from %in% after))
})
