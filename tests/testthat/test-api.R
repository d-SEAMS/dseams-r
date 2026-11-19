# Copyright (c) d-SEAMS developers
test_that("examples are listed and resolved", {
  files <- dseams_example()
  expect_true(all(c("ice1h.lammpstrj", "exampleTraj.lammpstrj") %in% files))
  expect_true(file.exists(dseams_example("ice1h.lammpstrj")))
  expect_error(dseams_example("missing.lammpstrj"), "no example")
})

test_that("bad input is an R error, not a crash", {
  expect_error(read_frame(tempfile(fileext = ".lammpstrj")))
  bad <- tempfile(fileext = ".lammpstrj")
  writeLines("not a dump", bad)
  on.exit(unlink(bad), add = TRUE)
  expect_error(nframes(bad))
  expect_identical(nrow(positions(read_frame(bad))), 0L)
})

test_that("print and positions agree on the atom count", {
  frame <- read_frame(dseams_example("ice1h.lammpstrj"), type = -1L)
  expect_output(print(frame), "atoms 128")
  expect_identical(nrow(positions(frame)), 128L)
  expect_identical(colnames(positions(frame)), c("x", "y", "z"))
})

test_that("Steinhardt graphs and degrees return one row per atom", {
  frame <- read_frame(dseams_example("ice1h.lammpstrj"), type = -1L)
  for (l in c(3L, 4L, 6L)) {
    s <- steinhardt(frame, order_l = l)
    expect_s3_class(s, "data.frame")
    expect_identical(nrow(s), 128L)
    expect_identical(attr(s, "order_l"), l)
  }
  mutual <- steinhardt(frame, order_l = 6L, graph = "mutual")
  expect_identical(nrow(mutual), 128L)
})

test_that("the OVITO rule is selectable", {
  frame <- read_frame(dseams_example("exampleTraj.lammpstrj"), type = 2L)
  ovito <- chill_plus(frame, rule = "ovito-chill+")
  expect_identical(nrow(ovito), 250L)
  expect_error(chill_plus(frame, rule = "no-such-rule"))
})

test_that("C API wrapper outputs are shaped as documented", {
  sys <- seams_system_new()
  expect_identical(
    seams_system_read(sys, dseams_example("ice1h.lammpstrj"), frame = 1L, type = -1L),
    128L
  )

  order <- seams_steinhardt(sys, order = 6L, average = TRUE)
  expect_s3_class(order, "dseams_order")
  expect_named(order, c("ql", "qlbar"))
  expect_length(order$ql, 128L)
  expect_length(order$qlbar, 128L)

  cages <- seams_cages(sys)
  expect_s3_class(cages, "dseams_cage_counts")
  expect_named(cages, c("n_hex", "n_cubic", "n_water", "n_both"))

  sig <- seams_signature_cages(sys, "512")
  expect_s3_class(sig, "dseams_signature")
  expect_named(sig, c("n_cages", "n_atoms"))

  expect_s3_class(seams_neighbours_knn(sys), "dseams_nnz")
  rdf <- seams_rdf(sys)
  expect_s3_class(rdf, "dseams_rdf")
  expect_named(rdf, c("r", "g", "volume"))
  expect_s3_class(seams_running_cn(sys), "dseams_running_cn")
  expect_type(seams_coordination(sys), "double")
  expect_type(seams_hbonds(sys), "integer")
  expect_s3_class(seams_density_axis(sys), "dseams_density")

  fp <- seams_fingerprint(sys)
  expect_s3_class(fp, "dseams_fingerprint")
  expect_named(fp, c("key_length", "ring_sum"))

  contacts <- seams_contact_pairs(sys, "1=cationHead")
  expect_s3_class(contacts, "dseams_contacts")
  expect_named(contacts, c("n_pairs", "n_cation", "n_anion"))

  domains <- seams_domains(sys, "1=waterO")
  expect_s3_class(domains, "dseams_domains")
  expect_named(domains, c("n_subset", "largest", "percolation"))

  expect_s3_class(seams_prisms(sys), "dseams_prisms")
  expect_s3_class(seams_monolayer(sys), "dseams_monolayer")
  expect_s3_class(seams_rings_vertices(sys), "dseams_vertices")
  expect_s3_class(seams_site_table(sys, "1=waterO"), "dseams_sites")
})

test_that("threads can be set and read back", {
  old <- dseams_threads()
  on.exit(dseams_threads(old), add = TRUE)
  expect_gte(old, 1L)
  expect_identical(dseams_threads(1L), 1L)
  expect_error(dseams_threads(0L))
})

test_that("the engine version is the package version", {
  expect_identical(
    dseams_version(),
    as.character(utils::packageVersion("dseams"))
  )
})

test_that(".onLoad honours the thread option and the core limit", {
  ns <- asNamespace("dseams")
  lib <- find.package("dseams")
  old_opt <- getOption("dseams.threads")
  old_env <- Sys.getenv("_R_CHECK_LIMIT_CORES_", unset = NA)
  on.exit({
    options(dseams.threads = old_opt)
    if (is.na(old_env)) {
      Sys.unsetenv("_R_CHECK_LIMIT_CORES_")
    } else {
      Sys.setenv("_R_CHECK_LIMIT_CORES_" = old_env)
    }
    ns$.onLoad(lib, "dseams")
  }, add = TRUE)

  options(dseams.threads = 1L)
  ns$.onLoad(lib, "dseams")
  expect_identical(dseams_threads(), 1L)

  options(dseams.threads = NULL)
  Sys.setenv("_R_CHECK_LIMIT_CORES_" = "TRUE")
  ns$.onLoad(lib, "dseams")
  expect_lte(dseams_threads(), 2L)

  Sys.setenv("_R_CHECK_LIMIT_CORES_" = "FALSE")
  ns$.onLoad(lib, "dseams")

  Sys.unsetenv("_R_CHECK_LIMIT_CORES_")
  ns$.onLoad(lib, "dseams")
  expect_gte(dseams_threads(), 1L)
})
