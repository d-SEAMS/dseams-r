# Copyright (c) d-SEAMS developers

# The package root during R CMD check is the 00_pkg_src copy. A direct
# test_file() run walks up from tests/testthat.
hardening_root <- function() {
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
    for (i in seq_len(8L)) {
      if (file.exists(file.path(dir, "DESCRIPTION")) &&
          file.exists(file.path(dir, "configure"))) {
        return(normalizePath(dir))
      }
      src <- file.path(dir, "00_pkg_src", "dseams")
      if (file.exists(file.path(src, "DESCRIPTION")) &&
          file.exists(file.path(src, "configure"))) {
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

capture_sh <- function(dir, script, env = NULL) {
  log <- tempfile("dseams-harden-")
  old <- getwd()
  on.exit(
    {
      setwd(old)
      unlink(log)
    },
    add = TRUE
  )
  setwd(dir)
  status <- system2("sh", script, stdout = log, stderr = log, env = env)
  out <- if (file.exists(log)) readLines(log, warn = FALSE) else character()
  list(status = as.integer(status), out = out)
}

# system2(env=) adds NAME=value strings to the child. It does not take a
# named vector, and copying this process's environment into that form
# feeds shell text in some values back to sh. Pass only the names the
# test sets. Dropping a variable is done by the command, with unset.
child_env <- function(set = character()) {
  if (!length(set)) {
    return(NULL)
  }
  paste0(names(set), "=", as.character(set), recycle0 = TRUE)
}

test_that("configure.win refuses a linked engine", {
  root <- hardening_root()
  expect_false(is.null(root))
  base <- tempfile("dseams-win-link-")
  dir.create(base)
  on.exit(unlink(base, recursive = TRUE), add = TRUE)
  expect_true(file.copy(
    file.path(root, "configure.win"),
    file.path(base, "configure.win")
  ))
  cases <- list(
    list(
      set = c(SEAMS_LIBDIR = "/nonexistent/seams-lib"),
      message = paste0(
        "configure.win: SEAMS_LIBDIR is set, but Windows supports only ",
        "the bundled build. Unset SEAMS_LIBDIR."
      )
    ),
    list(
      set = c(DSEAMS_SYSTEM_ENGINE = "1"),
      message = paste0(
        "configure.win: DSEAMS_SYSTEM_ENGINE is set, but Windows supports ",
        "only the bundled build. Unset DSEAMS_SYSTEM_ENGINE."
      )
    ),
    list(
      set = c(DSEAMS_SYSTEM_ENGINE = "yes"),
      message = paste0(
        "configure.win: DSEAMS_SYSTEM_ENGINE is set, but Windows supports ",
        "only the bundled build. Unset DSEAMS_SYSTEM_ENGINE."
      )
    ),
    list(
      set = c(DSEAMS_SYSTEM_ENGINE = "TRUE"),
      message = paste0(
        "configure.win: DSEAMS_SYSTEM_ENGINE is set, but Windows supports ",
        "only the bundled build. Unset DSEAMS_SYSTEM_ENGINE."
      )
    )
  )
  for (case in cases) {
    got <- capture_sh(base, "configure.win", env = child_env(set = case$set))
    expect_identical(got$status, 1L, info = paste(got$out, collapse = "\n"))
    expect_true(
      any(grepl(case$message, got$out, fixed = TRUE)),
      info = paste(got$out, collapse = "\n")
    )
    expect_false(file.exists(file.path(base, "src", "rust-target.mk")))
  }
})

test_that("cleanup.win removes the files a Windows build writes", {
  root <- hardening_root()
  expect_false(is.null(root))
  base <- tempfile("dseams-cleanup-win-")
  dir.create(file.path(base, "src", "seams"), recursive = TRUE)
  dir.create(file.path(base, "src", "readcon-core", "target"), recursive = TRUE)
  dir.create(file.path(base, "src", "readcon-core", "cargo-home"), recursive = TRUE)
  dir.create(file.path(base, "src", "chemfiles-build"), recursive = TRUE)
  dir.create(file.path(base, "src", "chemfiles-build.abc123"), recursive = TRUE)
  dir.create(file.path(base, "src", "chemfiles-install"), recursive = TRUE)
  on.exit(unlink(base, recursive = TRUE), add = TRUE)
  generated <- c(
    "src/Makevars",
    "src/reader-stamp",
    "src/rust-target.mk",
    "src/x.o",
    "src/x.so",
    "src/x.dll",
    "src/seams/engine.o"
  )
  for (rel in generated) {
    writeLines("generated", file.path(base, rel))
  }
  writeLines("keep", file.path(base, "src", "Makevars.win"))
  writeLines("keep", file.path(base, "DESCRIPTION"))
  expect_true(file.copy(
    file.path(root, "cleanup.win"),
    file.path(base, "cleanup.win")
  ))
  got <- capture_sh(base, "cleanup.win")
  expect_identical(got$status, 0L, info = paste(got$out, collapse = "\n"))
  for (rel in generated) {
    expect_false(file.exists(file.path(base, rel)), info = rel)
  }
  expect_false(dir.exists(file.path(base, "src", "readcon-core", "target")))
  expect_false(dir.exists(file.path(base, "src", "readcon-core", "cargo-home")))
  expect_false(dir.exists(file.path(base, "src", "chemfiles-build")))
  expect_false(dir.exists(file.path(base, "src", "chemfiles-build.abc123")))
  expect_false(dir.exists(file.path(base, "src", "chemfiles-install")))
  expect_identical(readLines(file.path(base, "src", "Makevars.win")), "keep")
  expect_identical(readLines(file.path(base, "DESCRIPTION")), "keep")
})

test_that("configure requires R_HOME before it uses R", {
  root <- hardening_root()
  expect_false(is.null(root))
  base <- tempfile("dseams-rhome-")
  dir.create(base)
  on.exit(unlink(base, recursive = TRUE), add = TRUE)
  expect_true(file.copy(file.path(root, "configure"), file.path(base, "configure")))
  # A script file, not sh -c. The -c text is expanded by the caller
  # before unset runs, so R_HOME would still be set.
  writeLines(
    c("unset R_HOME", "exec sh ./configure"),
    file.path(base, "run-unset-r-home.sh")
  )

  missing <- capture_sh(base, "run-unset-r-home.sh")
  expect_identical(
    missing$status,
    1L,
    info = paste(missing$out, collapse = "\n")
  )
  expect_true(any(grepl(
    "configure: R_HOME is not set. Run R CMD INSTALL, which sets it, or export R_HOME.",
    missing$out,
    fixed = TRUE
  )), info = paste(missing$out, collapse = "\n"))
  expect_false(file.exists(file.path(base, "src", "Makevars")))

  bogus <- tempfile("dseams-no-r-")
  dir.create(bogus)
  on.exit(unlink(bogus, recursive = TRUE), add = TRUE)
  bad <- capture_sh(base, "configure", env = child_env(set = c(R_HOME = bogus)))
  expect_identical(bad$status, 1L, info = paste(bad$out, collapse = "\n"))
  expect_true(any(grepl(
    paste0("configure: R_HOME=", bogus, " does not contain an executable R at bin/R"),
    bad$out,
    fixed = TRUE
  )), info = paste(bad$out, collapse = "\n"))
  expect_false(file.exists(file.path(base, "src", "Makevars")))
})

test_that("chemfiles builds in a directory private to that install", {
  root <- hardening_root()
  expect_false(is.null(root))
  needle <- 'mktemp -d "chemfiles-build.XXXXXX"'
  for (rel in c("src/Makevars.in", "src/Makevars.win")) {
    lines <- readLines(file.path(root, rel), warn = FALSE)
    expect_true(any(grepl(needle, lines, fixed = TRUE)), info = rel)
    expect_false(any(grepl("CHEMFILES_BUILD =", lines, fixed = TRUE)), info = rel)
    expect_false(any(grepl(
      "-B \"$(CHEMFILES_BUILD)\"",
      lines,
      fixed = TRUE
    )), info = rel)
  }
  configure <- readLines(file.path(root, "configure"), warn = FALSE)
  expect_false(any(grepl("dseams-chemfiles", configure, fixed = TRUE)))
  expect_false(any(grepl("@CHEMFILES_BUILD@", configure, fixed = TRUE)))

  # The recipe's mktemp line, run twice in one directory, yields two
  # directories. A fixed name would make the second call the same path.
  base <- tempfile("dseams-cf-build-")
  dir.create(base)
  on.exit(unlink(base, recursive = TRUE), add = TRUE)
  script <- c(
    "set -e",
    "one=$(mktemp -d \"chemfiles-build.XXXXXX\")",
    "two=$(mktemp -d \"chemfiles-build.XXXXXX\")",
    "test \"$one\" != \"$two\"",
    "test -d \"$one\"",
    "test -d \"$two\"",
    "case \"$one\" in",
    "  chemfiles-build.*) ;;",
    "  *) echo \"fixed build directory: $one\"; exit 1 ;;",
    "esac",
    "case \"$two\" in",
    "  chemfiles-build.*) ;;",
    "  *) echo \"fixed build directory: $two\"; exit 1 ;;",
    "esac",
    "rm -rf \"$one\" \"$two\""
  )
  writeLines(script, file.path(base, "alloc.sh"))
  got <- capture_sh(base, "alloc.sh")
  expect_identical(got$status, 0L, info = paste(got$out, collapse = "\n"))
  expect_false(length(list.files(base, pattern = "^chemfiles-build")) > 0L)
})
