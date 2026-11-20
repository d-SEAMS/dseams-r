# Copyright (c) d-SEAMS developers

test_that("seams_capi_info and label/symmetry names work", {
  info <- seams_capi_info()
  expect_identical(info$abi, 1L)
  expect_identical(info$version_string, as.character(utils::packageVersion("dseams")))
  expect_identical(seams_label_name(0L), "cubic")
  expect_identical(seams_label_name(1L), "hexagonal")
  expect_type(seams_ring_symmetry_name(1L), "character")
})

test_that("system set_atoms and read-back accessors round-trip", {
  sys <- seams_system_new()
  xyz <- matrix(c(
    1, 2, 3,
    4, 5, 6,
    7, 8, 9
  ), ncol = 3L, byrow = TRUE)
  box <- c(0, 0, 0, 20, 20, 20, 0, 0, 0)
  types <- c(1L, 2L, 2L)
  ids <- c(10L, 20L, 30L)
  expect_identical(seams_system_set_atoms(sys, xyz, box, types = types, ids = ids), 3L)
  expect_identical(seams_system_count(sys), 3L)
  expect_equal(unname(seams_system_box(sys)), box)
  got_xyz <- seams_system_positions(sys)
  expect_identical(colnames(got_xyz), c("x", "y", "z"))
  expect_equal(unname(got_xyz), xyz)
  expect_identical(seams_system_types(sys), types)
  expect_identical(seams_system_ids(sys), ids)
})

test_that("system order, cage, ring, neighbour, fingerprint, symmetry, and brine wrappers work", {
  sys <- seams_system_new()
  n <- seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
  expect_identical(n, 128L)

  sym <- seams_system_symmetry(sys)
  expect_length(sym, 128L)
  expect_true(all(sym >= -1L & sym <= 2L))

  qq <- seams_q4q6(sys)
  expect_s3_class(qq, "data.frame")
  expect_identical(names(qq), c("q4", "q6"))
  expect_equal(nrow(qq), 128L)

  qb <- seams_q6bar(sys)
  expect_length(qb$q6bar, 128L)
  expect_true(is.finite(qb$mean))
  expect_true(is.finite(qb$median))
  expect_gte(qb$n_ice, 0L)

  ql <- seams_ql(sys, order = 6L, graph = 0L)
  expect_s3_class(ql, "dseams_order")
  expect_equal(ql$ql, qq$q6)

  cl <- seams_cages_labels(sys)
  expect_length(cl, 128L)
  expect_identical(attr(cl, "counts")[["n_hex"]], 128L)

  sig_e <- seams_signature_cages_edge(sys, "512")
  expect_s3_class(sig_e, "dseams_signature")
  expect_identical(names(sig_e), c("n_cages", "n_atoms"))

  nb <- seams_neighbours(sys)
  expect_identical(nb$n_rows, 128L)
  expect_length(nb$offsets, 129L)
  expect_identical(
    length(nb$cols),
    as.integer(seams_neighbours_knn(sys, k = 4L, mutual = TRUE))
  )

  rg <- seams_rings(sys, graph = 0L, max_depth = 6L)
  expect_identical(rg$n_rings, 256L)
  expect_identical(rg$histogram[[7L]], 256L)
  expect_length(rg$sizes, 256L)
  expect_length(rg$symmetry, 256L)
  expect_equal(rg$fraction, 1.0)

  ch <- seams_rings_chordless(sys, size = 6L, graph = 0L)
  expect_identical(ch$n_rings, 256L)
  expect_identical(dim(ch$rings), c(256L, 6L))
  expect_length(ch$per_atom, 128L)

  fp <- seams_fingerprint_atoms(sys)
  expect_true(nzchar(fp$key))
  expect_length(fp$atom_keys, 128L)
  expect_true(all(nzchar(fp$atom_keys)))
  expect_identical(sum(fp$rings), seams_fingerprint(sys)[["ring_sum"]])

  br <- seams_brine(sys, rep(1L, 128L), n_bins = 4L, axis = 2L)
  expect_named(br, c("fronts", "rejection", "profile", "pockets"))
  expect_s3_class(br$profile, "data.frame")
  expect_equal(nrow(br$profile), 4L)
})
