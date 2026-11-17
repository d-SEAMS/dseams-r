# Copyright (c) d-SEAMS developers
library(dseams)

test_that("a missing path is an R error", {
  expect_error(read_frame("no-such-dump.lammpstrj"), regexp = ".")
})

test_that("an empty system stops with the handle text", {
  sys <- seams_system_new()
  expect_s3_class(sys, "dseams_system")
  expect_output(print(sys), "dseams system")
  expect_error(seams_chill(sys), regexp = ".")
})

test_that("summary methods print the frame", {
  root <- Sys.getenv("DSEAMS_ROOT", unset = "")
  tip <- file.path(root, "input", "traj", "exampleTraj.lammpstrj")
  skip_if(root == "" || !file.exists(tip), "DSEAMS_ROOT is not set")
  frame <- read_frame(tip, type = 2L)
  expect_output(summary(frame), "dseams frame")
  ice <- chill_plus(frame)
  expect_s3_class(ice, "dseams_ice")
  expect_output(print(ice), "CHILL\\+")
  expect_output(summary(ice), "water")
})

test_that("a ring census prints and summarises", {
  rings <- primitive_rings(read_frame(dseams_example("ice1h.lammpstrj"), type = -1L),
                           graph = "cutoff", max_depth = 6L)
  expect_s3_class(rings, "dseams_rings")
  expect_output(print(rings), "size")
  expect_output(summary(rings), "size")
})

test_that("cages, steinhardt and q4_q6 results print their counts", {
  frame <- read_frame(dseams_example("ice1h.lammpstrj"), type = -1L)
  cg <- cages(frame)
  expect_s3_class(cg, "dseams_cages")
  expect_output(print(cg), "cages hexagonal 128 cubic 0 both 0 water 0")
  expect_output(summary(cg), "hexagonal.*128")

  st <- steinhardt(frame)
  expect_s3_class(st, "dseams_steinhardt")
  expect_output(print(st), "Steinhardt parameters, 128 atoms, mean ql")
  expect_output(summary(st), "mean ql .* mean qlbar")

  qq <- q4_q6(frame)
  expect_s3_class(qq, "dseams_q4_q6")
  expect_output(print(qq), "q4 q6, 128 atoms, mean q6")
  expect_output(summary(qq), "mean q4 .* mean q6")
  # q6 of q4_q6 is the l = 6 parameter that steinhardt() reports.
  expect_equal(mean(qq$q6), mean(st$ql))
})

test_that("a read system and its CHILL counts print", {
  sys <- seams_system_new()
  expect_identical(seams_system_read(sys, dseams_example("ice1h.lammpstrj")), 128L)
  expect_output(print(sys), "dseams system 128 atoms")
  expect_output(summary(sys), "external pointer.*dseams system 128 atoms")
  chill <- seams_chill(sys)
  expect_s3_class(chill, "dseams_chill")
  expect_identical(chill[["hexagonal"]], 128L)
  expect_output(print(chill), "CHILL counts")
  expect_output(summary(chill), "hexagonal")
})

test_that("seams_set_num_threads returns the width in effect", {
  # seams_set_num_threads also sets the OpenMP width dseams_threads()
  # reads, so record that width now. An on.exit expression that called
  # dseams_threads() would see the width this test had just set.
  # Zero puts the C API back on its saved default; dseams_threads(old)
  # then puts back the OpenMP width .onLoad chose, which may differ from
  # the default the C API captured on its first use.
  old <- dseams_threads()
  on.exit({
    seams_set_num_threads(0L)
    dseams_threads(old)
  }, add = TRUE)
  expect_identical(seams_set_num_threads(1L), 1L)
  expect_error(seams_set_num_threads(-1L), "negative")
})
