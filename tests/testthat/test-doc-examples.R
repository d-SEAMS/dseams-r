# Copyright (c) d-SEAMS developers
# The scripts in inst/examples are the R pages of the d-SEAMS site. Each
# asserts its own numbers with stopifnot; these tests run them and check
# what they print. They read dumps from a seams-core checkout (DSEAMS_ROOT)
# that the package does not ship.

run_example <- function(name) {
  script <- system.file("examples", name, package = "dseams")
  expect_true(nzchar(script))
  capture.output(source(script, local = new.env()))
}

seams_root <- function() {
  root <- Sys.getenv("DSEAMS_ROOT", unset = "")
  skip_if(root == "" || !dir.exists(file.path(root, "input", "traj")),
          "DSEAMS_ROOT is not set")
  root
}

test_that("core_counts.R counts Ice Ih and sII", {
  seams_root()
  out <- run_example("core_counts.R")
  expect_identical(out, "r hexagonal 128 rings6 256 clathrate 136 rings5 144")
})

test_that("minimal_r.R classifies the sI cell", {
  seams_root()
  expect_identical(run_example("minimal_r.R"), "r example ok")
})

test_that("r_api.R labels exampleTraj", {
  seams_root()
  expect_identical(run_example("r_api.R"), "r api ok")
})

test_that("lang_tasks.R prints four bonds per water and the Ih rings", {
  root <- seams_root()
  out <- run_example("lang_tasks.R")
  expect_length(out, 1L)
  fields <- strsplit(trimws(out), " +")[[1]]
  expect_identical(fields[c(1L, 3L, 11L)], c("pairs", "rings", "chill"))
  n <- nrow(positions(read_frame(
    file.path(root, "input", "traj", "ice1h.lammpstrj"),
    type = -1L
  )))
  # Every water in ice Ih has four neighbours inside 3.5 angstrom.
  expect_equal(as.integer(fields[[2]]), 4L * n)
  # rings histogram: sizes 0 through 6.
  expect_equal(as.integer(fields[[10]]), 256L)
  expect_equal(sum(as.integer(fields[12:20])), n)
})

test_that("science_tutorials.R reproduces the tutorial counts", {
  seams_root()
  out <- run_example("science_tutorials.R")
  expect_true(all(c(
    "interface hexagonal 352 water 434 interfacial 49 cubic 1",
    "nucleus cubic 47 hexagonal 62 water 3589 interfacial 240",
    "cages sII 512 16", "cages sII 51264 8", "cages sH 512 12",
    "cages sH sh 8", "cages sH 51268 4"
  ) %in% out))
})

# binding_oracle reports what the seams-core build it belongs to computes,
# so SEAMS_CPP_ORACLE is set only when the package links that build
# (SEAMS_LIBDIR or DSEAMS_SYSTEM_ENGINE). The bundled copy is compiled
# without the optional readers, CON among them.
test_that("r_capi.R matches the C++ oracle", {
  seams_root()
  oracle <- Sys.getenv("SEAMS_CPP_ORACLE", unset = "")
  skip_if(oracle == "" || !file.exists(oracle), "SEAMS_CPP_ORACLE is not set")
  expect_identical(run_example("r_capi.R"), "r capi ok")
})
