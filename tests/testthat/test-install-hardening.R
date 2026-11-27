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

copyright_lines <- function(root) {
  raw <- readLines(file.path(root, "inst", "COPYRIGHTS"), warn = FALSE)
  raw <- trimws(sub("\r$", "", raw))
  raw[nzchar(raw) & !startsWith(raw, "#")]
}

cph_display_names <- function(authors) {
  out <- character()
  for (p in authors) {
    if (!("cph" %in% p$role)) {
      next
    }
    name <- if (is.null(p$family) || !nzchar(p$family)) {
      p$given
    } else {
      paste(p$given, p$family)
    }
    out <- c(out, name)
  }
  out
}

test_that("Authors@R cph names are the vendored copyright holders", {
  root <- hardening_root()
  expect_false(is.null(root))
  listed <- copyright_lines(root)
  expect_gt(length(listed), 0L)
  desc <- read.dcf(file.path(root, "DESCRIPTION"))
  authors <- utils:::.read_authors_at_R_field(desc[, "Authors@R"])
  cph <- cph_display_names(authors)
  expect_length(setdiff(listed, cph), 0L)
  expect_length(setdiff(cph, listed), 0L)
  expect_identical(sort(cph), sort(listed))
  python <- Sys.which("python3")
  expect_true(nzchar(python))
  log <- tempfile("dseams-cph-")
  on.exit(unlink(log), add = TRUE)
  status <- system2(
    python,
    c(file.path(root, "tools", "check-copyright-holders.py"), root),
    stdout = log,
    stderr = log
  )
  out <- if (file.exists(log)) readLines(log, warn = FALSE) else character()
  expect_identical(as.integer(status), 0L, info = paste(out, collapse = "\n"))
  expect_true(any(grepl(
    "vendored copyright holders match inst/COPYRIGHTS and LICENSE.note",
    out,
    fixed = TRUE
  )), info = paste(out, collapse = "\n"))
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

  expect_true(file.copy(
    file.path(root, "configure.win"),
    file.path(base, "configure.win"),
    overwrite = TRUE
  ))
  # configure.win exits on SEAMS_LIBDIR or DSEAMS_SYSTEM_ENGINE before
  # it reads R_HOME. A linked check exports SEAMS_LIBDIR. The script
  # clears those names, then sets R_HOME. system2(env=) would leave the
  # parent values set, and on Windows that assignment is an argument
  # of sh, which exits 127.
  writeLines(
    c(
      "unset SEAMS_LIBDIR",
      "unset DSEAMS_SYSTEM_ENGINE",
      "unset R_HOME",
      "exec sh ./configure.win"
    ),
    file.path(base, "run-unset-r-home-win.sh")
  )
  missing_win <- capture_sh(base, "run-unset-r-home-win.sh")
  expect_identical(
    missing_win$status,
    1L,
    info = paste(missing_win$out, collapse = "\n")
  )
  expect_true(any(grepl(
    paste0(
      "configure.win: R_HOME is not set. Run R CMD INSTALL, which sets it, ",
      "or export R_HOME."
    ),
    missing_win$out,
    fixed = TRUE
  )), info = paste(missing_win$out, collapse = "\n"))
  bogus_quoted <- paste0("'", gsub("'", "'\\''", bogus, fixed = TRUE), "'")
  writeLines(
    c(
      "unset SEAMS_LIBDIR",
      "unset DSEAMS_SYSTEM_ENGINE",
      paste0("export R_HOME=", bogus_quoted),
      "exec sh ./configure.win"
    ),
    file.path(base, "run-bogus-r-home-win.sh")
  )
  bad_win <- capture_sh(base, "run-bogus-r-home-win.sh")
  expect_identical(
    bad_win$status,
    1L,
    info = paste(bad_win$out, collapse = "\n")
  )
  expect_true(any(grepl(
    paste0(
      "configure.win: R_HOME=",
      bogus,
      " does not contain an executable R at bin/R"
    ),
    bad_win$out,
    fixed = TRUE
  )), info = paste(bad_win$out, collapse = "\n"))
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

sentinel_lines <- function(root) {
  raw <- readLines(file.path(root, "tools", "vendored-sentinels"), warn = FALSE)
  raw <- trimws(sub("\r$", "", raw))
  raw[nzchar(raw) & !startsWith(raw, "#")]
}

# A tree configure can finish: every sentinel, the readcon checksum, and
# a Makevars.in. tools/vendor.sh exits 0 and restores nothing, which is
# what a refused download does.
plant_configure_tree <- function(root, base, listed) {
  dir.create(file.path(base, "tools"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(base, "src"), recursive = TRUE, showWarnings = FALSE)
  rels <- c(
    "configure",
    "configure.win",
    "tools/ensure-vendored.sh",
    "tools/vendored-tree.sh",
    "tools/vendored-sentinels",
    "tools/bundled-tools.sh"
  )
  for (rel in rels) {
    ok <- file.copy(file.path(root, rel), file.path(base, rel), overwrite = TRUE)
    expect_true(ok, info = rel)
  }
  writeLines(
    c("Package: dseams", "Version: 0.0.0"),
    file.path(base, "DESCRIPTION")
  )
  writeLines("kept", file.path(base, "src", "Makevars.in"))
  writeLines(
    "SEAMS_LANG_VERSION='\"0.0.0\"'",
    file.path(base, "src", "Makevars.win")
  )
  for (path in listed) {
    rel <- sub("/$", "", path)
    dest <- file.path(base, rel)
    unlink(dest, recursive = TRUE)
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    if (endsWith(path, "/")) {
      dir.create(dest, recursive = TRUE, showWarnings = FALSE)
    } else {
      writeLines("x", dest)
    }
  }
  checksum <- file.path(base, "src", "readcon-core", "vendor", "dlpk")
  dir.create(checksum, recursive = TRUE, showWarnings = FALSE)
  writeLines("{}", file.path(checksum, "cargo-checksum.json"))
  writeLines(c("#!/bin/sh", "exit 0"), file.path(base, "tools", "vendor.sh"))
}

test_that("a missing vendored sentinel stops configure before Makevars", {
  root <- hardening_root()
  expect_false(is.null(root))
  r_home <- Sys.getenv("R_HOME")
  expect_true(nzchar(r_home))
  expect_true(file.exists(file.path(r_home, "bin", "R")))
  listed <- sentinel_lines(root)
  expect_gt(length(listed), 0L)
  base <- tempfile("dseams-sentinel-")
  dir.create(base)
  on.exit(unlink(base, recursive = TRUE), add = TRUE)
  plant_configure_tree(root, base, listed)

  complete <- capture_sh(base, "configure")
  expect_identical(
    complete$status,
    0L,
    info = paste(complete$out, collapse = "\n")
  )
  expect_false(any(grepl("still incomplete", complete$out, fixed = TRUE)))
  expect_identical(readLines(file.path(base, "src", "Makevars")), "kept")
  unlink(file.path(base, "src", "Makevars"))

  refusal <- "refusing to configure a package with a missing vendored file"
  for (path in listed) {
    plant_configure_tree(root, base, listed)
    unlink(file.path(base, sub("/$", "", path)), recursive = TRUE)
    expect_false(file.exists(file.path(base, sub("/$", "", path))), info = path)
    for (script in c("configure", "configure.win")) {
      got <- capture_sh(base, script)
      info <- paste(script, path, paste(got$out, collapse = "\n"))
      expect_identical(got$status, 1L, info = info)
      expect_true(path %in% got$out, info = info)
      expect_true(any(grepl(
        paste0(script, ": the vendored tree is still incomplete after tools/vendor.sh:"),
        got$out,
        fixed = TRUE
      )), info = info)
      expect_true(any(grepl(
        paste0(script, ": ", refusal),
        got$out,
        fixed = TRUE
      )), info = info)
      expect_false(file.exists(file.path(base, "src", "Makevars")), info = info)
      expect_false(file.exists(file.path(base, "src", "rust-target.mk")), info = info)
    }
  }
})

# jsonlite is not a Depends, Imports, or Suggests package. Read the
# document with base R so the comparison does not need another package
# or python. Objects and arrays keep a class because a JSON null has to
# stay in the list, and `[[<-` would drop it.
parse_json_text <- function(text) {
  chars <- strsplit(text, "", fixed = TRUE)[[1L]]
  n <- length(chars)
  pos <- 1L

  peek <- function() {
    if (pos > n) "" else chars[[pos]]
  }
  advance <- function() {
    ch <- peek()
    pos <<- pos + 1L
    ch
  }
  skip_ws <- function() {
    while (pos <= n && chars[[pos]] %in% c(" ", "\t", "\r", "\n")) {
      pos <<- pos + 1L
    }
  }
  put <- function(box, key, value) {
    kind <- class(box)
    box[key] <- list(value)
    class(box) <- kind
    box
  }
  parse_string <- function() {
    if (advance() != "\"") {
      stop("codemeta JSON string does not open", call. = FALSE)
    }
    out <- character()
    repeat {
      ch <- advance()
      if (ch == "\"") {
        return(paste0(out, collapse = ""))
      }
      if (!nzchar(ch)) {
        stop("codemeta JSON string does not close", call. = FALSE)
      }
      if (ch == "\\") {
        esc <- advance()
        ch <- if (esc == "\"" || esc == "\\" || esc == "/") {
          esc
        } else if (esc == "b") {
          "\b"
        } else if (esc == "f") {
          "\f"
        } else if (esc == "n") {
          "\n"
        } else if (esc == "r") {
          "\r"
        } else if (esc == "t") {
          "\t"
        } else if (esc == "u") {
          hex <- paste0(advance(), advance(), advance(), advance())
          if (!grepl("^[0-9A-Fa-f]{4}$", hex)) {
            stop("codemeta JSON has a bad unicode escape", call. = FALSE)
          }
          intToUtf8(strtoi(hex, 16L))
        } else {
          stop("codemeta JSON has a bad escape", call. = FALSE)
        }
      }
      out <- c(out, ch)
    }
  }
  parse_number <- function() {
    start <- pos
    if (peek() == "-") {
      advance()
    }
    if (peek() == "0") {
      advance()
    } else if (grepl("^[1-9]$", peek())) {
      while (grepl("^[0-9]$", peek())) {
        advance()
      }
    } else {
      stop("codemeta JSON has a bad number", call. = FALSE)
    }
    if (peek() == ".") {
      advance()
      if (!grepl("^[0-9]$", peek())) {
        stop("codemeta JSON has a bad number", call. = FALSE)
      }
      while (grepl("^[0-9]$", peek())) {
        advance()
      }
    }
    if (peek() %in% c("e", "E")) {
      advance()
      if (peek() %in% c("+", "-")) {
        advance()
      }
      if (!grepl("^[0-9]$", peek())) {
        stop("codemeta JSON has a bad number", call. = FALSE)
      }
      while (grepl("^[0-9]$", peek())) {
        advance()
      }
    }
    as.numeric(paste0(chars[start:(pos - 1L)], collapse = ""))
  }
  parse_literal <- function(word, value) {
    end <- pos + nchar(word) - 1L
    if (end > n) {
      stop("codemeta JSON has a bad literal", call. = FALSE)
    }
    got <- paste0(chars[pos:end], collapse = "")
    if (!identical(got, word)) {
      stop("codemeta JSON has a bad literal", call. = FALSE)
    }
    pos <<- end + 1L
    value
  }
  parse_value <- function() {
    skip_ws()
    ch <- peek()
    if (ch == "{") {
      return(parse_object())
    }
    if (ch == "[") {
      return(parse_array())
    }
    if (ch == "\"") {
      return(parse_string())
    }
    if (ch == "t") {
      return(parse_literal("true", TRUE))
    }
    if (ch == "f") {
      return(parse_literal("false", FALSE))
    }
    if (ch == "n") {
      return(parse_literal("null", NULL))
    }
    if (ch == "-" || grepl("^[0-9]$", ch)) {
      return(parse_number())
    }
    stop("codemeta JSON has an unexpected character", call. = FALSE)
  }
  parse_object <- function() {
    if (advance() != "{") {
      stop("codemeta JSON object does not open", call. = FALSE)
    }
    box <- structure(list(), class = "json_object")
    skip_ws()
    if (peek() == "}") {
      advance()
      return(box)
    }
    repeat {
      skip_ws()
      if (peek() != "\"") {
        stop("codemeta JSON object key is not a string", call. = FALSE)
      }
      key <- parse_string()
      skip_ws()
      if (advance() != ":") {
        stop("codemeta JSON object is missing a colon", call. = FALSE)
      }
      box <- put(box, key, parse_value())
      skip_ws()
      ch <- advance()
      if (ch == "}") {
        return(box)
      }
      if (ch != ",") {
        stop("codemeta JSON object does not continue", call. = FALSE)
      }
    }
  }
  parse_array <- function() {
    if (advance() != "[") {
      stop("codemeta JSON array does not open", call. = FALSE)
    }
    box <- structure(list(), class = "json_array")
    skip_ws()
    if (peek() == "]") {
      advance()
      return(box)
    }
    i <- 0L
    repeat {
      i <- i + 1L
      box <- put(box, i, parse_value())
      skip_ws()
      ch <- advance()
      if (ch == "]") {
        return(box)
      }
      if (ch != ",") {
        stop("codemeta JSON array does not continue", call. = FALSE)
      }
    }
  }

  if (!n) {
    stop("codemeta JSON is empty", call. = FALSE)
  }
  value <- parse_value()
  skip_ws()
  if (pos <= n) {
    stop("codemeta JSON has trailing text", call. = FALSE)
  }
  value
}

parse_json_file <- function(path) {
  size <- file.info(path)$size
  if (is.na(size)) {
    stop("missing file: ", path, call. = FALSE)
  }
  raw <- if (size == 0L) raw(0L) else readBin(path, "raw", n = size)
  if (length(raw) >= 3L && identical(as.integer(raw[1:3]), c(0xef, 0xbb, 0xbf))) {
    raw <- raw[-c(1L, 2L, 3L)]
  }
  text <- rawToChar(raw)
  Encoding(text) <- "UTF-8"
  parse_json_text(text)
}

json_field <- function(object, key) {
  if (!inherits(object, "json_object") || !key %in% names(object)) {
    return(NULL)
  }
  object[[key]]
}

json_string <- function(value) {
  if (is.null(value)) {
    return("")
  }
  if (!is.character(value) || length(value) != 1L || anyNA(value)) {
    stop("codemeta field is not a string", call. = FALSE)
  }
  value
}

# A holder with no family name is an Organization. Everyone else is a
# Person, and aut/ctb/cph/cre map onto the four codemeta arrays.
codemeta_rows <- function(path) {
  data <- parse_json_file(path)
  if (!inherits(data, "json_object")) {
    stop("codemeta.json is not a JSON object", call. = FALSE)
  }
  rows <- character()
  for (key in c("author", "contributor", "copyrightHolder", "maintainer")) {
    items <- json_field(data, key)
    if (!inherits(items, "json_array")) {
      stop("codemeta.json has no ", key, " array", call. = FALSE)
    }
    for (item in items) {
      kind <- json_string(json_field(item, "@type"))
      if (identical(kind, "Organization")) {
        name <- json_string(json_field(item, "name"))
        email <- ""
        orcid <- ""
      } else if (identical(kind, "Person")) {
        given <- json_string(json_field(item, "givenName"))
        family <- json_string(json_field(item, "familyName"))
        name <- if (!nzchar(family)) given else paste(given, family)
        email <- json_string(json_field(item, "email"))
        orcid <- json_string(json_field(item, "@id"))
      } else {
        stop("codemeta ", key, " has @type ", kind, call. = FALSE)
      }
      rows <- c(rows, paste(key, kind, name, email, orcid, sep = "\t"))
    }
  }
  list(
    version = json_string(json_field(data, "version")),
    license = json_string(json_field(data, "license")),
    rows = rows
  )
}

file_bytes <- function(path) {
  size <- file.info(path)$size
  if (is.na(size)) {
    stop("missing file: ", path, call. = FALSE)
  }
  if (size == 0L) {
    return(raw(0L))
  }
  readBin(path, "raw", n = size)
}

# .Rbuildignore omits the top-level file from the built tree. A check
# started inside a checkout still has that file above 00_pkg_src.
checkout_codemeta <- function(root) {
  dir <- root
  for (i in seq_len(8L)) {
    meta <- file.path(dir, "codemeta.json")
    if (file.exists(meta) &&
        file.exists(file.path(dir, "DESCRIPTION")) &&
        file.exists(file.path(dir, "configure"))) {
      return(normalizePath(meta, mustWork = TRUE))
    }
    parent <- dirname(dir)
    if (identical(parent, dir)) {
      break
    }
    dir <- parent
  }
  NULL
}

description_codemeta_rows <- function(path) {
  desc <- read.dcf(path)
  authors <- utils:::.read_authors_at_R_field(desc[, "Authors@R"])
  orcid_of <- function(p) {
    if (is.null(p$comment) || is.null(names(p$comment))) {
      return("")
    }
    hit <- unname(p$comment["ORCID"])
    if (length(hit) != 1L || is.na(hit) || !nzchar(hit)) {
      return("")
    }
    paste0("https://orcid.org/", hit)
  }
  email_of <- function(p) {
    if (is.null(p$email) || is.na(p$email) || !nzchar(p$email)) {
      return("")
    }
    p$email
  }
  family_of <- function(p) {
    if (is.null(p$family) || is.na(p$family)) {
      return("")
    }
    p$family
  }
  role_key <- c(
    aut = "author",
    ctb = "contributor",
    cph = "copyrightHolder",
    cre = "maintainer"
  )
  rows <- character()
  for (key in role_key) {
    role <- names(role_key)[role_key == key]
    for (p in authors) {
      if (!(role %in% p$role)) {
        next
      }
      family <- family_of(p)
      kind <- if (nzchar(family)) "Person" else "Organization"
      name <- if (nzchar(family)) paste(p$given, family) else p$given
      email <- if (kind == "Person") email_of(p) else ""
      orcid <- if (kind == "Person") orcid_of(p) else ""
      rows <- c(rows, paste(key, kind, name, email, orcid, sep = "\t"))
    }
  }
  list(
    version = unname(desc[, "Version"]),
    license = unname(desc[, "License"]),
    rows = rows
  )
}

test_that("codemeta.json agrees with DESCRIPTION", {
  root <- hardening_root()
  expect_false(is.null(root))
  shipped <- testthat::test_path("codemeta.json")
  expect_true(file.exists(shipped))
  found <- checkout_codemeta(root)
  if (!is.null(found)) {
    expect_identical(file_bytes(found), file_bytes(shipped))
  }
  got <- codemeta_rows(shipped)
  expected <- description_codemeta_rows(file.path(root, "DESCRIPTION"))
  expect_identical(got$version, expected$version)
  expect_identical(got$license, expected$license)
  expect_identical(got$rows, expected$rows)
})
