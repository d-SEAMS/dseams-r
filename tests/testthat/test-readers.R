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

# inst/extdata/water3.xyz lines 3-5, in angstrom. Written here so a
# reader that shifts every format the same way cannot be its own oracle.
water3_positions <- matrix(
  c(
    1.000, 2.000, 3.000,
    1.500, 2.000, 3.000,
    1.000, 2.800, 3.000
  ),
  ncol = 3L,
  byrow = TRUE
)

water3_ids <- c(1L, 2L, 3L)

# ox, oy, oz, lx, ly, lz, xy, xz, yz.
water3_cell20 <- c(0, 0, 0, 20, 20, 20, 0, 0, 0)
water3_cell0 <- c(0, 0, 0, 0, 0, 0, 0, 0, 0)
# water3.gro writes the cell in nanometres: 20 nm is 200 angstrom.
water3_cell_gro <- c(0, 0, 0, 200, 200, 200, 0, 0, 0)
# A native XYZ read has no lattice. The cell is the coordinate span.
water3_cell_xyz_native <- c(1, 2, 3, 0.5, 0.8, 0, 0, 0, 0)

expect_water3_reader <- function(path, feature = NULL, tol = 1e-3,
                                 types, ids = water3_ids,
                                 box = water3_cell20) {
  if (!is.null(feature)) {
    skip_if_not(
      isTRUE(dseams_features()[[feature]]),
      paste(feature, "is not compiled in")
    )
  }
  frame <- read_frame(path, type = -1L)
  got <- positions(frame)
  expect_equal(nrow(got), 3L)
  expect_equal(unname(got), water3_positions, tolerance = tol)
  expect_equal(nframes(path), 1L)
  sys <- seams_system_new()
  expect_identical(seams_system_read(sys, path, 1L, -1L), 3L)
  capi_pos <- seams_system_positions(sys)
  expect_equal(unname(capi_pos), water3_positions, tolerance = tol)
  expect_identical(seams_system_types(sys), types)
  expect_identical(seams_system_ids(sys), ids)
  expect_equal(unname(seams_system_box(sys)), box, tolerance = 1e-6)
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
  # The dump column is `id type x y z`: types 1, 2, 2 and ids 1, 2, 3.
  # BOX BOUNDS is 0 to 20 on each axis.
  expect_water3_reader(
    ext_fixture("water3.lammpstrj"),
    tol = 1e-6,
    types = c(1L, 2L, 2L)
  )
})

test_that("native reader reads xyz", {
  path <- ext_fixture("water3.xyz")
  if (isTRUE(dseams_features()[["chemfiles"]])) {
    # O and H are atomic numbers. The comment line has no lattice.
    expect_water3_reader(path, tol = 1e-6, types = c(8L, 1L, 1L), box = water3_cell0)
  } else {
    # O is the first element name and H the second, so the types are 1, 2, 2.
    expect_water3_reader(
      path,
      tol = 1e-6,
      types = c(1L, 2L, 2L),
      box = water3_cell_xyz_native
    )
  }
})

test_that("chemfiles reader reads mol2", {
  expect_water3_reader(local_fixture("water3.mol2"), feature = "chemfiles", types = c(8L, 1L, 1L))
})

test_that("chemfiles reader reads mmcif", {
  expect_water3_reader(local_fixture("water3.mmcif"), feature = "chemfiles", types = c(8L, 1L, 1L))
})

test_that("chemfiles reader reads cif", {
  expect_water3_reader(local_fixture("water3.cif"), feature = "chemfiles", types = c(8L, 1L, 1L))
})

test_that("chemfiles reader reads pdb", {
  expect_water3_reader(ext_fixture("water3.pdb"), feature = "chemfiles", types = c(8L, 1L, 1L))
})

test_that("chemfiles reader reads gro", {
  # Names are O, H1, H2. H1 and H2 are not the element token H.
  expect_water3_reader(
    ext_fixture("water3.gro"),
    feature = "chemfiles",
    types = c(8L, 0L, 0L),
    box = water3_cell_gro
  )
})

test_that("chemfiles reader reads dcd", {
  # DCD stores coordinates and the cell, not element names.
  expect_water3_reader(local_fixture("water3.dcd"), feature = "chemfiles", types = c(1L, 1L, 1L))
})

test_that("chemfiles reader reads xtc", {
  expect_water3_reader(local_fixture("water3.xtc"), feature = "chemfiles", types = c(1L, 1L, 1L))
})

test_that("chemfiles reader reads trr", {
  expect_water3_reader(local_fixture("water3.trr"), feature = "chemfiles", types = c(1L, 1L, 1L))
})

test_that("chemfiles reader reads tng", {
  expect_water3_reader(local_fixture("water3.tng"), feature = "chemfiles", types = c(8L, 1L, 1L))
})

test_that("chemfiles reader reads netcdf", {
  expect_water3_reader(local_fixture("water3.nc"), feature = "chemfiles", types = c(1L, 1L, 1L))
})

test_that("chemfiles reader reads sdf", {
  # The V2000 block has elements and no crystal.
  expect_water3_reader(
    local_fixture("water3.sdf"),
    feature = "chemfiles",
    types = c(8L, 1L, 1L),
    box = water3_cell0
  )
})

test_that("chemfiles reader reads cml", {
  expect_water3_reader(local_fixture("water3.cml"), feature = "chemfiles", types = c(8L, 1L, 1L))
})

test_that("chemfiles reader reads cssr", {
  expect_water3_reader(local_fixture("water3.cssr"), feature = "chemfiles", types = c(8L, 1L, 1L))
})

test_that("chemfiles reader reads arc", {
  # Atom names are O, H1, H2. H1 and H2 are not the element token H.
  expect_water3_reader(local_fixture("water3.arc"), feature = "chemfiles", types = c(8L, 0L, 0L))
})

test_that("chemfiles reader reads mmtf", {
  expect_water3_reader(local_fixture("water3.mmtf"), feature = "chemfiles", types = c(8L, 1L, 1L))
})

test_that("readcon reader reads con", {
  expect_water3_reader(
    ext_fixture("water3.con"),
    feature = "readcon",
    tol = 1e-4,
    types = c(8L, 1L, 1L)
  )
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
