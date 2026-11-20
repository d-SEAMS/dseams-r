# Copyright (c) d-SEAMS developers
# Readers compiled into this build. LAMMPS and XYZ are always on.
# chemfiles and readcon tests run only when configure found those libraries.

ext_fixture <- function(name) {
  path <- system.file("extdata", name, package = "dseams")
  expect_true(nzchar(path))
  path
}

local_fixture <- function(name) {
  path <- testthat::test_path("fixtures", name)
  expect_true(file.exists(path))
  path
}

expect_water3_reader <- function(path, feature = NULL, tol = 1e-3) {
  if (!is.null(feature)) {
    skip_if_not(
      isTRUE(dseams_features()[[feature]]),
      paste(feature, "is not compiled in")
    )
  }
  xyz <- positions(read_frame(ext_fixture("water3.xyz"), type = -1L))
  frame <- read_frame(path, type = -1L)
  got <- positions(frame)
  expect_equal(nrow(got), 3L)
  expect_equal(got, xyz, tolerance = tol)
  expect_equal(nframes(path), 1L)
  sys <- seams_system_new()
  expect_identical(seams_system_read(sys, path, 1L, -1L), 3L)
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

test_that("PDB and GRO need chemfiles", {
  skip_if(isTRUE(dseams_features()[["chemfiles"]]))
  expect_error(read_frame(ext_fixture("water3.pdb"), type = -1L), "chemfiles")
  expect_error(read_frame(ext_fixture("water3.gro"), type = -1L), "chemfiles")
  expect_error(
    seams_system_read(seams_system_new(), ext_fixture("water3.pdb"), 1L, -1L),
    "chemfiles"
  )
})

test_that("a CON file needs readcon", {
  skip_if(isTRUE(dseams_features()[["readcon"]]))
  expect_error(read_frame(ext_fixture("water3.con"), type = -1L), "readcon")
  expect_error(
    seams_system_read(seams_system_new(), ext_fixture("water3.con"), 1L, -1L),
    "readcon"
  )
  expect_error(nframes(ext_fixture("water3.con")), "readcon")
})

test_that("native reader reads lammps", {
  expect_water3_reader(ext_fixture("water3.lammpstrj"), tol = 1e-6)
})

test_that("native reader reads xyz", {
  expect_water3_reader(ext_fixture("water3.xyz"), tol = 1e-6)
})

test_that("chemfiles reader reads mol2", {
  expect_water3_reader(local_fixture("water3.mol2"), feature = "chemfiles")
})

test_that("chemfiles reader reads mmcif", {
  expect_water3_reader(local_fixture("water3.mmcif"), feature = "chemfiles")
})

test_that("chemfiles reader reads cif", {
  expect_water3_reader(local_fixture("water3.cif"), feature = "chemfiles")
})

test_that("chemfiles reader reads pdb", {
  expect_water3_reader(ext_fixture("water3.pdb"), feature = "chemfiles")
})

test_that("chemfiles reader reads gro", {
  expect_water3_reader(ext_fixture("water3.gro"), feature = "chemfiles")
})

test_that("chemfiles reader reads dcd", {
  expect_water3_reader(local_fixture("water3.dcd"), feature = "chemfiles")
})

test_that("chemfiles reader reads xtc", {
  expect_water3_reader(local_fixture("water3.xtc"), feature = "chemfiles")
})

test_that("chemfiles reader reads trr", {
  expect_water3_reader(local_fixture("water3.trr"), feature = "chemfiles")
})

test_that("chemfiles reader reads tng", {
  expect_water3_reader(local_fixture("water3.tng"), feature = "chemfiles")
})

test_that("chemfiles reader reads netcdf", {
  expect_water3_reader(local_fixture("water3.nc"), feature = "chemfiles")
})

test_that("chemfiles reader reads sdf", {
  expect_water3_reader(local_fixture("water3.sdf"), feature = "chemfiles")
})

test_that("chemfiles reader reads cml", {
  expect_water3_reader(local_fixture("water3.cml"), feature = "chemfiles")
})

test_that("chemfiles reader reads cssr", {
  expect_water3_reader(local_fixture("water3.cssr"), feature = "chemfiles")
})

test_that("chemfiles reader reads arc", {
  expect_water3_reader(local_fixture("water3.arc"), feature = "chemfiles")
})

test_that("chemfiles reader reads mmtf", {
  expect_water3_reader(local_fixture("water3.mmtf"), feature = "chemfiles")
})

test_that("readcon reader reads con", {
  expect_water3_reader(ext_fixture("water3.con"), feature = "readcon", tol = 1e-4)
})

test_that("nframes counts a CON file through libseams", {
  skip_if_not(
    isTRUE(dseams_features()[["readcon"]]),
    "readcon is not compiled in"
  )
  # libseams_lang's seams_path_nframes(path) returns 0 for a .con file.
  # libseams's seams_path_nframes(path, size_t *) writes the real count.
  # A linked build that binds the language symbol from the C API reports
  # 0 here. water3.con holds one frame. Bundled builds rename the
  # language symbol, so they do not hit this.
  expect_equal(nframes(ext_fixture("water3.con")), 1L)
})
