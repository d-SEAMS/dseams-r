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

test_that("VMD molfile readers enabled in chemfiles read their files", {
  water <- rbind(c(0, 0, 0), c(0.957, 0, 0), c(-0.24, 0.927, 0))
  for (name in c("tiny.pqr", "tiny.cube", "tiny.rst7")) {
    path <- dseams_example(name)
    expect_identical(nframes(path), 1L, label = name)
    xyz <- unname(positions(read_frame(path, type = -1L)))
    expect_equal(xyz, water, tolerance = 1e-5, label = name)
  }
  # The 10 A cell is read: the third atom wraps to x = 9.76.
  xsf <- dseams_example("tiny.xsf")
  expect_identical(nframes(xsf), 1L)
  expect_equal(unname(positions(read_frame(xsf, type = -1L))[3, ]),
    c(9.76, 0.927, 0),
    tolerance = 1e-5
  )
})

test_that("every extension of an enabled molfile reader reaches it", {
  # seams-core's chemfiles molfiles patch registers these. Only the
  # molfile wrapper says "is empty", so an empty file proves the extension
  # selects a molfile reader without running a plugin on it. The Gaussian
  # log reader has no extension of its own.
  enabled <- c(
    "bgf", "binpos", "car", "cor", "cpmd", "cube", "dlpolyconfig",
    "dlpolyhist", "dtr", "js", "log", "mae", "mdf", "coor", "parm",
    "parm7", "pqr", "rst7", "OUTCAR", "POSCAR", "XDATCAR",
    "VASP_XDATCAR5", "xml", "vsf", "vtf", "xbgf", "xsf",
    "dms", "g96", "out"
  )
  dir <- tempfile("molfile-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  for (ext in enabled) {
    path <- file.path(dir, paste0("empty.", ext))
    file.create(path)
    expect_error(read_frame(path, type = -1L), "is empty", label = ext)
  }
  unknown <- file.path(dir, "empty.zzz")
  file.create(unknown)
  expect_error(read_frame(unknown, type = -1L), "can not find a format")
})
