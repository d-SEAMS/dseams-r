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
  writeLines(
    c("unset R_HOME", "exec sh ./configure.win"),
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
  bad_win <- capture_sh(
    base,
    "configure.win",
    env = child_env(set = c(R_HOME = bogus))
  )
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

# A holder with no family name is an Organization. Everyone else is a
# Person, and aut/ctb/cph/cre map onto the four codemeta arrays.
codemeta_rows <- function(path) {
  script <- tempfile("dseams-codemeta-", fileext = ".py")
  writeLines(
    c(
      "import json, sys",
      "data = json.load(open(sys.argv[1], encoding='utf-8'))",
      "print('version\\t' + str(data.get('version', '')))",
      "print('license\\t' + str(data.get('license', '')))",
      "for key in ('author', 'contributor', 'copyrightHolder', 'maintainer'):",
      "    for item in data[key]:",
      "        kind = item.get('@type', '')",
      "        if kind == 'Organization':",
      "            name = item.get('name', '')",
      "            email = ''",
      "            orcid = ''",
      "        elif kind == 'Person':",
      "            given = item.get('givenName', '')",
      "            family = item.get('familyName') or ''",
      "            name = given if family == '' else given + ' ' + family",
      "            email = item.get('email') or ''",
      "            orcid = item.get('@id') or ''",
      "        else:",
      "            sys.exit('codemeta ' + key + ' has @type ' + kind)",
      "        sys.stdout.write(key + '\\t' + kind + '\\t' + name + '\\t' + email + '\\t' + orcid + '\\n')"
    ),
    script
  )
  log <- tempfile("dseams-codemeta-out-")
  status <- system2("python3", c(script, path), stdout = log, stderr = log)
  out <- if (file.exists(log)) readLines(log, warn = FALSE) else character()
  unlink(c(script, log))
  list(status = as.integer(status), out = out)
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
  meta <- file.path(root, "codemeta.json")
  expect_true(file.exists(meta))
  got <- codemeta_rows(meta)
  expect_identical(got$status, 0L, info = paste(got$out, collapse = "\n"))
  version <- got$out[startsWith(got$out, "version\t")]
  license <- got$out[startsWith(got$out, "license\t")]
  expect_length(version, 1L)
  expect_length(license, 1L)
  listed <- got$out[startsWith(got$out, "author\t") |
    startsWith(got$out, "contributor\t") |
    startsWith(got$out, "copyrightHolder\t") |
    startsWith(got$out, "maintainer\t")]
  expected <- description_codemeta_rows(file.path(root, "DESCRIPTION"))
  expect_identical(sub("^version\t", "", version), expected$version)
  expect_identical(sub("^license\t", "", license), expected$license)
  expect_identical(listed, expected$rows)
})
