# Copyright (c) d-SEAMS developers

test_that("the submission draft pastes DESCRIPTION and names Ruhila Goswami", {
  root <- normalizePath(testthat::test_path("../.."))
  helper <- file.path(root, "tools", "check-submission.R")
  expect_true(file.exists(helper))
  source(helper, local = TRUE)

  desc_path <- file.path(root, "DESCRIPTION")
  readme_path <- file.path(root, "README.md")
  expect_true(file.exists(desc_path))
  expect_true(file.exists(readme_path))
  desc <- read_text(desc_path)
  readme <- read_text(readme_path)
  expect_true(grepl(ruhila_description, desc, fixed = TRUE))
  expect_true(grepl(ruhila_readme, readme, fixed = TRUE))

  # docs/ and codemeta.json are in .Rbuildignore, so the built tree used
  # by R CMD check does not contain them. A git checkout does, and then
  # the same check the script runs has to pass.
  draft <- file.path(root, "docs", "ropensci-submission.md")
  meta <- file.path(root, "codemeta.json")
  if (file.exists(draft) && file.exists(meta)) {
    problems <- check_submission(root)
    expect_length(problems, 0L)
  }
})
