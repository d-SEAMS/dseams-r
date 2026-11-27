# Copyright (c) d-SEAMS developers

# R CMD check runs with the working directory set to tests/, and copies
# that directory away from the rest of the source tree. Walk up from both
# places, and from 00_pkg_src, until the checker script is found. covr has
# no 00_pkg_src; kept_source_dir() is used only when that walk finds nothing.
submission_root <- function() {
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
      helper <- file.path(dir, "tools", "check-submission.R")
      if (file.exists(file.path(dir, "DESCRIPTION")) && file.exists(helper)) {
        return(normalizePath(dir))
      }
      src <- file.path(dir, "00_pkg_src", "dseams")
      src_helper <- file.path(src, "tools", "check-submission.R")
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
  kept <- kept_source_dir()
  if (length(kept) == 1L && nzchar(kept)) {
    helper <- file.path(kept, "tools", "check-submission.R")
    if (file.exists(file.path(kept, "DESCRIPTION")) && file.exists(helper)) {
      return(normalizePath(kept))
    }
  }
  NULL
}

test_that("the submission draft pastes DESCRIPTION and names Ruhila Goswami", {
  root <- submission_root()
  if (is.null(root)) {
    desc <- readLines(file.path(find.package("dseams"), "DESCRIPTION"))
    expect_true(any(grepl("0000-0002-5443-9356", desc, fixed = TRUE)))
    skip("tools/check-submission.R is not beside this test run")
  }
  source(file.path(root, "inst", "check-submission.R"), local = TRUE)
  desc <- read_text(file.path(root, "DESCRIPTION"))
  readme <- read_text(file.path(root, "README.md"))
  expect_true(grepl(ruhila_description, desc, fixed = TRUE))
  expect_true(grepl(ruhila_readme, readme, fixed = TRUE))

  # docs/ and codemeta.json are in .Rbuildignore, so the built source
  # tree does not contain them. A git checkout does.
  draft <- file.path(root, "docs", "ropensci-submission.md")
  meta <- file.path(root, "codemeta.json")
  if (file.exists(draft) && file.exists(meta)) {
    problems <- check_submission(root)
    expect_length(problems, 0L)
  }
})

test_that("recorded testthat summaries must pass and match a bundled test log", {
  # inst/check-submission.R is installed. system.file finds it when the
  # source walk cannot, including under covr's testInstalledPackage().
  checker <- system.file("check-submission.R", package = "dseams")
  expect_true(nzchar(checker) && file.exists(checker))
  source(checker, local = TRUE)
  saved <- Sys.getenv("DSEAMS_TEST_LOG", unset = NA_character_)
  Sys.unsetenv("DSEAMS_TEST_LOG")
  on.exit(
    {
      if (is.na(saved)) {
        Sys.unsetenv("DSEAMS_TEST_LOG")
      } else {
        Sys.setenv(DSEAMS_TEST_LOG = saved)
      }
    },
    add = TRUE
  )

  put <- function(text, path) writeBin(charToRaw(enc2utf8(text)), path)
  has <- function(probs, text) any(grepl(text, probs, fixed = TRUE))
  clean <- "[ FAIL 0 | WARN 0 | SKIP 1 | PASS 455 ]"
  other <- "[ FAIL 0 | WARN 0 | SKIP 1 | PASS 454 ]"

  tmp <- tempfile("dseams-submission-")
  dir.create(file.path(tmp, "docs"), recursive = TRUE)
  # The installed DESCRIPTION carries the Ruhila record. README.md is not
  # installed, so the fixture writes the one line the checker requires.
  file.copy(file.path(find.package("dseams"), "DESCRIPTION"), tmp)
  put(paste0(ruhila_readme, "\n"), file.path(tmp, "README.md"))
  put(
    paste0("{\n  \"contributor\": [{\n", ruhila_codemeta, "\n  }]\n}\n"),
    file.path(tmp, "codemeta.json")
  )
  desc <- read_text(file.path(tmp, "DESCRIPTION"))
  body <- substring(desc, 1L, nchar(desc) - 1L)
  draft_path <- file.path(tmp, "docs", "ropensci-submission.md")
  cran_path <- file.path(tmp, "cran-comments.md")
  write_draft <- function(summary = NULL, marker = TRUE) {
    tail <- if (is.null(summary)) {
      ""
    } else if (marker) {
      paste0(bundled_marker, ":\n", summary, "\n")
    } else {
      paste0(summary, "\n")
    }
    put(
      paste0(
        "Paste the full DESCRIPTION file inside a code block below:\n",
        "```\n", body, "\n```\n",
        ruhila_draft, "\n",
        "0000-0002-5443-9356\n",
        tail
      ),
      draft_path
    )
  }
  write_draft(clean)
  put("cran comments\n", cran_path)
  test_log <- file.path(tmp, "testthat.Rout")
  put(paste0("[ FAIL 0 | WARN 0 | SKIP 0 | PASS 1 ]\n", clean, "\n"), test_log)
  expect_length(check_submission(tmp, test_log = test_log), 0L)

  bare <- file.path(tmp, "bare.Rout")
  put("no totals here\n", bare)
  probs <- check_submission(tmp, test_log = bare)
  expect_true(has(probs, "test log has no testthat summary line"))

  write_draft(other)
  probs <- check_submission(tmp, test_log = test_log)
  expect_true(has(probs, "records the bundled check as"))

  failing <- "[ FAIL 20 | WARN 8 | SKIP 9 | PASS 454 ]"
  write_draft(failing)
  put(paste0(failing, "\n"), test_log)
  probs <- check_submission(tmp, test_log = test_log)
  expect_true(has(probs, paste0(
    "test log ends with failures or warnings: ", failing
  )))
  expect_true(has(
    check_submission(tmp),
    paste0(
      "docs/ropensci-submission.md records a test run with failures or warnings: ",
      failing
    )
  ))

  write_draft(clean, marker = FALSE)
  put(paste0(clean, "\n"), test_log)
  probs <- check_submission(tmp, test_log = test_log)
  expect_true(has(probs, "has no bundled-check test_check() summary"))

  warned <- "[ FAIL 0 | WARN 2 | SKIP 0 | PASS 9 ]"
  write_draft(clean)
  put(paste0("note\n", warned, "\n"), cran_path)
  expect_true(has(
    check_submission(tmp),
    "cran-comments.md records a test run with failures or warnings"
  ))
})

test_that("the bundled-check summary is the latest totals line after the last marker", {
  checker <- system.file("check-submission.R", package = "dseams")
  expect_true(nzchar(checker) && file.exists(checker))
  source(checker, local = TRUE)
  saved <- Sys.getenv("DSEAMS_TEST_LOG", unset = NA_character_)
  Sys.unsetenv("DSEAMS_TEST_LOG")
  on.exit(
    {
      if (is.na(saved)) {
        Sys.unsetenv("DSEAMS_TEST_LOG")
      } else {
        Sys.setenv(DSEAMS_TEST_LOG = saved)
      }
    },
    add = TRUE
  )

  put <- function(text, path) writeBin(charToRaw(enc2utf8(text)), path)
  has <- function(probs, text) any(grepl(text, probs, fixed = TRUE))
  historical <- "[ FAIL 0 | WARN 0 | SKIP 2 | PASS 625 ]"
  linked <- "[ FAIL 0 | WARN 0 | SKIP 0 | PASS 629 ]"
  latest <- "[ FAIL 0 | WARN 0 | SKIP 7 | PASS 871 ]"
  before <- "[ FAIL 0 | WARN 0 | SKIP 1 | PASS 100 ]"

  tmp <- tempfile("dseams-submission-latest-")
  dir.create(file.path(tmp, "docs"), recursive = TRUE)
  file.copy(file.path(find.package("dseams"), "DESCRIPTION"), tmp)
  put(paste0(ruhila_readme, "\n"), file.path(tmp, "README.md"))
  put(
    paste0("{\n  \"contributor\": [{\n", ruhila_codemeta, "\n  }]\n}\n"),
    file.path(tmp, "codemeta.json")
  )
  desc <- read_text(file.path(tmp, "DESCRIPTION"))
  body <- substring(desc, 1L, nchar(desc) - 1L)
  # The fixture matches the draft: one marker, the historical bundled
  # run, another run, then the latest bundled run. The latest record
  # does not repeat the marker. A totals line before the marker is not
  # a bundled-check record.
  draft <- paste0(
    "Paste the full DESCRIPTION file inside a code block below:\n",
    "```\n", body, "\n```\n",
    ruhila_draft, "\n",
    "0000-0002-5443-9356\n",
    "An earlier run printed:\n", before, "\n",
    bundled_marker, ":\n", historical, "\n",
    "The linked check printed:\n", linked, "\n",
    "A later bundled check of this tree finished. testthat printed:\n",
    latest, "\n"
  )
  draft_path <- file.path(tmp, "docs", "ropensci-submission.md")
  put(draft, draft_path)
  put("cran comments\n", file.path(tmp, "cran-comments.md"))
  expect_identical(extract_bundled_summary(draft), latest)

  # The fixture log holds both the historical result and the latest.
  log_path <- file.path(tmp, "both.Rout")
  put(paste0(historical, "\n", latest, "\n"), log_path)
  expect_length(check_submission(tmp, test_log = log_path), 0L)

  hist_log <- file.path(tmp, "historical.Rout")
  put(paste0(latest, "\n", historical, "\n"), hist_log)
  probs <- check_submission(tmp, test_log = hist_log)
  expect_true(has(probs, paste0(
    "docs/ropensci-submission.md records the bundled check as ",
    latest, "; the test log ends with ", historical
  )))

  # A second marker opens a new record. The latest summary is the last
  # totals line after that marker, not the first line of the new record
  # and not a totals line that sits between the two markers.
  remarked <- paste0(
    bundled_marker, ":\n", historical, "\n", linked, "\n",
    bundled_marker, ":\n", linked, "\n", latest, "\n"
  )
  expect_identical(extract_bundled_summary(remarked), latest)
})
