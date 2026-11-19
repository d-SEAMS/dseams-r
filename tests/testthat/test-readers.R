# Copyright (c) d-SEAMS developers
# Readers compiled into this build. LAMMPS and XYZ are always on.
# chemfiles and readcon tests run only when configure found those libraries.

fixture <- function(name) {
  path <- system.file("extdata", name, package = "dseams")
  expect_true(nzchar(path))
  path
}

test_that("dseams_features names the compiled readers", {
  feat <- dseams_features()
  expect_named(feat, c("lammps", "xyz", "chemfiles", "readcon"))
  expect_type(feat, "logical")
  expect_length(feat, 4L)
  expect_false(anyNA(feat))
  expect_true(isTRUE(feat[["lammps"]]))
  expect_true(isTRUE(feat[["xyz"]]))
  expect_true(feat[["chemfiles"]] %in% c(TRUE, FALSE))
  expect_true(feat[["readcon"]] %in% c(TRUE, FALSE))
})

test_that("the XYZ fixture and the LAMMPS dump hold the same three atoms", {
  xyz <- positions(read_frame(fixture("water3.xyz"), type = -1L))
  dump <- positions(read_frame(fixture("water3.lammpstrj"), type = -1L))
  expect_equal(nrow(xyz), 3L)
  expect_equal(dump, xyz, tolerance = 1e-6)
  expect_equal(nframes(fixture("water3.xyz")), 1L)
  expect_equal(nframes(fixture("water3.lammpstrj")), 1L)
})

test_that("PDB and GRO need chemfiles", {
  skip_if(isTRUE(dseams_features()[["chemfiles"]]))
  expect_error(read_frame(fixture("water3.pdb"), type = -1L), "chemfiles")
  expect_error(read_frame(fixture("water3.gro"), type = -1L), "chemfiles")
  expect_error(
    seams_system_read(seams_system_new(), fixture("water3.pdb"), 1L, -1L),
    "chemfiles"
  )
})

test_that("a CON file needs readcon", {
  skip_if(isTRUE(dseams_features()[["readcon"]]))
  expect_error(read_frame(fixture("water3.con"), type = -1L), "readcon")
  expect_error(
    seams_system_read(seams_system_new(), fixture("water3.con"), 1L, -1L),
    "readcon"
  )
  expect_error(nframes(fixture("water3.con")), "readcon")
})

test_that("chemfiles PDB and GRO match the XYZ and LAMMPS fixtures", {
  skip_if_not(
    isTRUE(dseams_features()[["chemfiles"]]),
    "chemfiles is not compiled in"
  )
  xyz <- positions(read_frame(fixture("water3.xyz"), type = -1L))
  dump <- positions(read_frame(fixture("water3.lammpstrj"), type = -1L))
  expect_equal(dump, xyz, tolerance = 1e-6)
  for (name in c("water3.pdb", "water3.gro")) {
    path <- fixture(name)
    frame <- read_frame(path, type = -1L)
    got <- positions(frame)
    expect_equal(nrow(got), 3L)
    expect_equal(got, xyz, tolerance = 1e-3)
    expect_equal(got, dump, tolerance = 1e-3)
    expect_equal(nframes(path), 1L)
    sys <- seams_system_new()
    expect_identical(seams_system_read(sys, path, 1L, -1L), 3L)
  }
})

test_that("readcon CON matches the XYZ and LAMMPS fixtures", {
  skip_if_not(
    isTRUE(dseams_features()[["readcon"]]),
    "readcon is not compiled in"
  )
  xyz <- positions(read_frame(fixture("water3.xyz"), type = -1L))
  dump <- positions(read_frame(fixture("water3.lammpstrj"), type = -1L))
  path <- fixture("water3.con")
  frame <- read_frame(path, type = -1L)
  got <- positions(frame)
  expect_equal(nrow(got), 3L)
  expect_equal(got, xyz, tolerance = 1e-4)
  expect_equal(got, dump, tolerance = 1e-4)
  expect_equal(nframes(path), 1L)
  sys <- seams_system_new()
  expect_identical(seams_system_read(sys, path, 1L, -1L), 3L)
})
