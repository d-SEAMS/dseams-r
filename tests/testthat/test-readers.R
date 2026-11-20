# Copyright (c) d-SEAMS developers
# These files ship in the package. They must be read by the build under
# test. There is no skip when readcon-core or chemfiles was left out.

test_that("the shipped CON file is two frames of four atoms", {
  path <- dseams_example("tiny_multi_cuh2.con")
  expect_identical(nframes(path), 2L)
  first <- read_frame(path, type = -1L)
  second <- read_frame(path, frame = 2L, type = -1L)
  expect_identical(nrow(positions(first)), 4L)
  expect_identical(nrow(positions(second)), 4L)
  expect_false(isTRUE(all.equal(
    positions(first)[1, ],
    positions(second)[1, ]
  )))
})

test_that("shipped PDB, GRO, and XYZ frames have their atoms", {
  pdb <- dseams_example("tiny.pdb")
  gro <- dseams_example("tiny.gro")
  xyz <- dseams_example("tiny.xyz")
  expect_identical(nframes(pdb), 1L)
  expect_identical(nrow(positions(read_frame(pdb, type = -1L))), 3L)
  expect_identical(nframes(gro), 1L)
  expect_identical(nrow(positions(read_frame(gro, type = -1L))), 3L)
  expect_identical(nframes(xyz), 1L)
  expect_identical(nrow(positions(read_frame(xyz, type = -1L))), 2L)
})
