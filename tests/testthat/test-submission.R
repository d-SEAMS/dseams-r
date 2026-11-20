# Copyright (c) d-SEAMS developers

# R CMD check runs with the working directory set to tests/, and copies
# that directory away from the rest of the source tree. Walk up from both
# places, and from 00_pkg_src, until the checker script is found.
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
  NULL
}

test_that("the submission draft pastes DESCRIPTION and names Ruhila Goswami", {
  root <- submission_root()
  if (is.null(root)) {
    desc <- readLines(file.path(find.package("dseams"), "DESCRIPTION"))
    expect_true(any(grepl("0000-0002-5443-9356", desc, fixed = TRUE)))
    skip("tools/check-submission.R is not beside this test run")
  }
  source(file.path(root, "tools", "check-submission.R"), local = TRUE)
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
