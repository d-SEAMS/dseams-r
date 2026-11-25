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
  expect_identical(as.integer(fields[[2]]), 4L * n)
  # rings histogram: sizes 0 through 6.
  expect_identical(as.integer(fields[[10]]), 256L)
  expect_identical(sum(as.integer(fields[12:20])), n)
})

test_that("science_tutorials.R reproduces the tutorial counts", {
  seams_root()
  out <- run_example("science_tutorials.R")
  # DSEAMS_BRINE_T0 and DSEAMS_BRINE_TEND are not set by CI. The example
  # then prints a fixed skip line; the test requires that line so the
  # brine counts are not dropped without a failure.
  brine <- c(Sys.getenv("DSEAMS_BRINE_T0"), Sys.getenv("DSEAMS_BRINE_TEND"))
  if (all(nzchar(brine)) && all(file.exists(brine))) {
    brine_lines <- c(
      "brine t0 hexagonal 733",
      "brine tend hexagonal 741"
    )
  } else {
    brine_lines <- paste(
      "brine tutorial skipped: cannot fetch d-SEAMS/brine-front-230K at",
      "4828e33ecf419c70643b2d466bfa4f283b4138dc"
    )
  }
  expect_true(all(c(
    "interface hexagonal 352 water 434 interfacial 49 cubic 1",
    "nucleus cubic 47 hexagonal 62 water 3589 interfacial 240",
    "cages sII 512 16", "cages sII 51264 8", "cages sH 512 12",
    "cages sH sh 8", "cages sH 51268 4",
    brine_lines
  ) %in% out))
})

test_that("readers.R reads the shipped CON, PDB, GRO, and XYZ files", {
  expect_identical(run_example("readers.R"), "r readers ok")
})

# binding_oracle reports what the seams-core build it belongs to computes,
# so SEAMS_CPP_ORACLE is set only when the package links that build
# (SEAMS_LIBDIR or DSEAMS_SYSTEM_ENGINE). The bundled copy includes
# readcon-core and chemfiles, so this comparison covers CON as well.
test_that("r_capi.R matches the C++ oracle", {
  root <- Sys.getenv("DSEAMS_ROOT", unset = "")
  oracle <- Sys.getenv("SEAMS_CPP_ORACLE", unset = "")
  missing <- character()
  if (root == "" || !dir.exists(file.path(root, "input", "traj"))) {
    missing <- c(missing, "DSEAMS_ROOT is not set")
  }
  if (oracle == "" || !file.exists(oracle)) {
    missing <- c(missing, "SEAMS_CPP_ORACLE is not set")
  }
  if (length(missing)) {
    skip(paste(missing, collapse = "; "))
  }
  expect_identical(run_example("r_capi.R"), "r capi ok")
})
