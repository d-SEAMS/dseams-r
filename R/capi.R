# Copyright (c) d-SEAMS developers
# .Call wrappers over include/seams.h. The libseams_lang frame API stays in dseams.R.

.tag <- function(x, cls) {
  structure(x, class = c(cls, class(x)))
}

.chill_names <- c(
  "cubic", "hexagonal", "water", "interfacial", "clathrate",
  "interClathrate", "unclassified", "reCubic", "reHex"
)

#' Empty system handle
#'
#' [seams_system_read()] loads one frame into the handle. Later `seams_*`
#' calls analyse that frame. R frees the handle when the object is
#' collected.
#'
#' `print()` reports the atom count. `summary()` reports the same count.
#' Both return the handle, invisibly.
#'
#' @return A `dseams_system`. `print()` and `summary()` return the handle,
#'   invisibly.
#' @examples
#' sys <- seams_system_new()
#' sys
#' @export
seams_system_new <- function() {
  ext <- .capi_call("_dseams_seams_r_system")
  class(ext) <- "dseams_system"
  ext
}

#' Read one frame into a system.
#'
#' The path is a LAMMPS dump or an XYZ file on every build. When
#' [dseams_features()] reports `chemfiles`, it may be any format
#' chemfiles 0.10 reads (PDB, GRO, DCD, and the rest of that set). When
#' it reports `readcon`, a readcon `.con` file is read, and a `.convel`
#' file is read when the engine routes that extension.
#'
#' @param sys A `dseams_system`.
#' @param path Trajectory path. See the description for which formats
#'   this build reads.
#' @param frame 1-based frame index.
#' @param type Species filter. Negative keeps every atom. A positive
#'   value keeps that species number (a LAMMPS type, or an atomic number
#'   on a chemfiles or readcon frame).
#' @return The atom count. `sys` is updated in place. On failure the
#'   previous frame is kept and the call stops with the engine's message.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' @export
seams_system_read <- function(sys, path, frame = 1L, type = -1L) {
  .capi_call("_dseams_seams_r_read", sys, normalizePath(path, mustWork = TRUE), as.integer(frame), as.integer(type))
}

#' Atom count stored on a system.
#'
#' @param sys A `dseams_system`.
#' @return An integer. Zero when the handle has no frame.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_system_count(sys)
#' @export
seams_system_count <- function(sys) {
  .capi_call("_dseams_seams_r_count", sys)
}

#' Set the OpenMP width used by the next analysis.
#'
#' @param n Thread count. Zero restores the library default.
#' @return The width the next analysis requests, as an integer. A
#'   negative `n` stops with the library's error text.
#' @examples
#' seams_set_num_threads(1L)
#' @export
seams_set_num_threads <- function(n) {
  .capi_call("_dseams_seams_r_threads", as.integer(n))
}

#' Original CHILL population counts
#'
#' Nine counts, in the same label order as [chill_plus()]: cubic,
#' hexagonal, water, interfacial, clathrate, interClathrate, unclassified,
#' reCubic, reHex. `graph = 0` is the cutoff neighbour list and
#' `graph = 1` is the mutual four-neighbour list. `rule = 0` is the
#' published CHILL+ rule and `rule = 1` is the OVITO variant.
#'
#' `print()` and `summary()` show the nine counts and return `x`,
#' invisibly.
#'
#' @param sys A `dseams_system`.
#' @param cutoff Neighbour cutoff in angstrom.
#' @param type Species filter. Zero keeps every atom.
#' @param graph `0` cutoff, `1` mutual.
#' @param rule `0` published, `1` OVITO.
#' @return An integer vector of length 9, class `dseams_chill`.
#'   Position `i` is the population of label `i - 1`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_chill(sys)
#' @export
seams_chill <- function(sys, cutoff = 3.5, type = 0L, graph = 0L, rule = 0L) {
  out <- .capi_call("_dseams_seams_r_chill", sys, cutoff, as.integer(type), as.integer(graph), as.integer(rule))
  names(out) <- .chill_names
  .tag(out, "dseams_chill")
}

#' Local Steinhardt parameter on the cutoff shell.
#'
#' @param sys A `dseams_system`.
#' @param order Spherical-harmonic degree. 3, 4, 6, 8, or 12.
#' @param cutoff Neighbour cutoff in angstrom.
#' @param average When true, the second element is the Lechner-Dellago average.
#' @return A list of class `dseams_order` with elements `ql` and `qlbar`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_steinhardt(sys, order = 6L)
#' @export
seams_steinhardt <- function(sys, order, cutoff = 3.5, average = FALSE) {
  out <- .capi_call("_dseams_seams_r_steinhardt", sys, cutoff, as.integer(order), as.integer(average))
  names(out) <- c("ql", "qlbar")
  .tag(out, "dseams_order")
}

#' Disjoint cage population counts.
#'
#' @param sys A `dseams_system`.
#' @param cutoff Neighbour cutoff in angstrom.
#' @param graph `2` seeded, `1` mutual, `0` cutoff. These are the same
#'   graphs as `"seeded"`, `"mutual"`, and `"cutoff"` in [cages()].
#' @param k Neighbour count for the seeded graph.
#' @param complete When true, run ring-adjacent completion.
#' @return An integer vector `c(n_hex, n_cubic, n_water, n_both)`, class `dseams_cage_counts`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_cages(sys)
#' @export
seams_cages <- function(sys, cutoff = 3.5, graph = 2L, k = 4L, complete = FALSE) {
  out <- .capi_call("_dseams_seams_r_cages", sys, cutoff, as.integer(graph), as.integer(k), as.integer(complete))
  names(out) <- c("n_hex", "n_cubic", "n_water", "n_both")
  .tag(out, "dseams_cage_counts")
}

#' Closed cages of one ring census.
#'
#' @param sys A `dseams_system`.
#' @param spec Census text such as `"512"`.
#' @param cutoff Neighbour cutoff in angstrom.
#' @param graph `0` cutoff or `1` mutual.
#' @return An integer vector `c(n_cages, n_atoms)`, class `dseams_signature`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_signature_cages(sys, "512")
#' @export
seams_signature_cages <- function(sys, spec, cutoff = 3.5, graph = 0L) {
  out <- .capi_call("_dseams_seams_r_signature", sys, cutoff, as.integer(graph), spec)
  names(out) <- c("n_cages", "n_atoms")
  .tag(out, "dseams_signature")
}

#' Column count of a k-nearest neighbour list.
#'
#' @param sys A `dseams_system`.
#' @param k Neighbour count.
#' @param cutoff Nominal cutoff in angstrom.
#' @param mutual When true, keep the mutual graph.
#' @return An integer, class `dseams_nnz`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_neighbours_knn(sys)
#' @export
seams_neighbours_knn <- function(sys, k = 4L, cutoff = 3.5, mutual = TRUE) {
  .tag(.capi_call("_dseams_seams_r_knn", sys, as.integer(k), cutoff, as.integer(mutual)), "dseams_nnz")
}

#' Partial radial distribution.
#'
#' @param sys A `dseams_system`.
#' @param rmax Maximum radius in angstrom.
#' @param bins Bin count.
#' @return A list of class `dseams_rdf` with `r`, `g`, and `volume`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_rdf(sys)
#' @export
seams_rdf <- function(sys, rmax = 6, bins = 8L) {
  out <- .capi_call("_dseams_seams_r_rdf", sys, rmax, as.integer(bins))
  names(out) <- c("r", "g", "volume")
  .tag(out, "dseams_rdf")
}

#' Running coordination number.
#'
#' @param sys A `dseams_system`.
#' @param rmax Maximum radius in angstrom.
#' @param bins Bin count.
#' @return A numeric vector, class `dseams_running_cn`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_running_cn(sys)
#' @export
seams_running_cn <- function(sys, rmax = 6, bins = 8L) {
  .tag(.capi_call("_dseams_seams_r_running_cn", sys, rmax, as.integer(bins)), "dseams_running_cn")
}

#' Coordination number integrated to `rmax`.
#'
#' @param sys A `dseams_system`.
#' @param rmax Cutoff in angstrom.
#' @param bins Bin count used by the integral.
#' @return A numeric scalar.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_coordination(sys)
#' @export
seams_coordination <- function(sys, rmax = 3.5, bins = 8L) {
  .capi_call("_dseams_seams_r_coordination", sys, rmax, as.integer(bins))
}

#' Hydrogen-bond count.
#'
#' Counts bonds between `oxygen_type` and `hydrogen_type`. In
#' `exampleTraj.lammpstrj` oxygen is type 2 and hydrogen is type 1.
#' The ice Ih cell has no hydrogen.
#'
#' @param sys A `dseams_system`.
#' @param cutoff Heavy-atom cutoff in angstrom.
#' @param oxygen_type,hydrogen_type Species numbers.
#' @param dist Acceptor-H distance in angstrom.
#' @param angle O-O-H angle in degrees.
#' @return An integer.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("exampleTraj.lammpstrj"), type = -1L)
#' seams_hbonds(sys, oxygen_type = 2L, hydrogen_type = 1L)
#' @export
seams_hbonds <- function(sys, cutoff = 3.5, oxygen_type = 1L, hydrogen_type = 2L,
                         dist = 2.42, angle = 30) {
  .capi_call("_dseams_seams_r_hbonds", sys, cutoff, as.integer(oxygen_type),
             as.integer(hydrogen_type), dist, angle)
}

#' Number density along one cell axis.
#'
#' @param sys A `dseams_system`.
#' @param type Species filter.
#' @param bins Bin count.
#' @param axis 0, 1, or 2.
#' @return A numeric vector, class `dseams_density`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_density_axis(sys)
#' @export
seams_density_axis <- function(sys, type = 0L, bins = 4L, axis = 2L) {
  .tag(.capi_call("_dseams_seams_r_density", sys, as.integer(type), as.integer(bins), as.integer(axis)), "dseams_density")
}

#' Topological fingerprint summary.
#'
#' @param sys A `dseams_system`.
#' @param cutoff Neighbour cutoff in angstrom.
#' @param hops Neighbourhood depth.
#' @return An integer vector `c(key_length, ring_sum)`, class `dseams_fingerprint`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_fingerprint(sys)
#' @export
seams_fingerprint <- function(sys, cutoff = 3.5, hops = 2L) {
  out <- .capi_call("_dseams_seams_r_fingerprint", sys, cutoff, as.integer(hops))
  names(out) <- c("key_length", "ring_sum")
  .tag(out, "dseams_fingerprint")
}

#' Mutual nearest unlike contacts.
#'
#' `spec` names each LAMMPS type. The ice Ih cell is one species, so the
#' pair count is zero.
#'
#' @param sys A `dseams_system`.
#' @param spec Site-table text such as `"1=cationHead"`.
#' @return An integer vector `c(n_pairs, n_cation, n_anion)`, class `dseams_contacts`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_contact_pairs(sys, "1=cationHead")
#' @export
seams_contact_pairs <- function(sys, spec) {
  out <- .capi_call("_dseams_seams_r_pairs", sys, spec)
  names(out) <- c("n_pairs", "n_cation", "n_anion")
  .tag(out, "dseams_contacts")
}

#' Largest polar or apolar domain.
#'
#' `subset = 0` is apolar and `subset = 1` is polar. On the ice Ih cell
#' the three numbers are zero.
#'
#' @param sys A `dseams_system`.
#' @param spec Site-table text.
#' @param cutoff Neighbour cutoff in angstrom.
#' @param subset `0` apolar, `1` polar.
#' @return A numeric vector `c(n_subset, largest, percolation)`, class `dseams_domains`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_domains(sys, "1=waterO")
#' @export
seams_domains <- function(sys, spec, cutoff = 3.5, subset = 0L) {
  out <- .capi_call("_dseams_seams_r_domains", sys, cutoff, spec, as.integer(subset))
  names(out) <- c("n_subset", "largest", "percolation")
  .tag(out, "dseams_domains")
}

#' Perfect prism counts by ring size.
#'
#' @param sys A `dseams_system`.
#' @param cutoff Neighbour cutoff in angstrom.
#' @return An integer vector of length 7, class `dseams_prisms`. Index 7 is size 6.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_prisms(sys)
#' @export
seams_prisms <- function(sys, cutoff = 3.5) {
  .tag(.capi_call("_dseams_seams_r_prisms", sys, cutoff), "dseams_prisms")
}

#' Primitive-ring histogram of a monolayer.
#'
#' @param sys A `dseams_system`.
#' @param cutoff Neighbour cutoff in angstrom.
#' @param max_depth Largest ring size.
#' @param sheet_area Sheet area in square angstrom.
#' @return An integer vector, class `dseams_monolayer`. `counts[k + 1]` is size `k`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_monolayer(sys)
#' @export
seams_monolayer <- function(sys, cutoff = 3.5, max_depth = 6L, sheet_area = 100) {
  .tag(.capi_call("_dseams_seams_r_monolayer", sys, cutoff, as.integer(max_depth), sheet_area), "dseams_monolayer")
}

#' Atom indices of one primitive ring.
#'
#' @param sys A `dseams_system`.
#' @param cutoff Neighbour cutoff in angstrom.
#' @param max_depth Largest ring size.
#' @param index Ring index, from 0.
#' @return An integer vector, class `dseams_vertices`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_rings_vertices(sys)
#' @export
seams_rings_vertices <- function(sys, cutoff = 3.5, max_depth = 6L, index = 0L) {
  .tag(.capi_call("_dseams_seams_r_vertices", sys, cutoff, as.integer(max_depth), as.integer(index)), "dseams_vertices")
}

#' Per-atom site kind.
#'
#' @param sys A `dseams_system`.
#' @param spec Site-table text such as `"1=waterO"`.
#' @return An integer vector, class `dseams_sites`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_site_table(sys, "1=waterO")
#' @export
seams_site_table <- function(sys, spec) {
  .tag(.capi_call("_dseams_seams_r_site", sys, spec), "dseams_sites")
}

#' C API ABI and version metadata.
#'
#' @return A list with `abi`, `version`, `major`, `minor`, `patch`, and
#'   `version_string`.
#' @examples
#' seams_capi_info()
#' @export
seams_capi_info <- function() {
  out <- .capi_call("_dseams_seams_r_capi_info")
  names(out) <- c("abi", "version", "major", "minor", "patch", "version_string")
  out
}

#' Human-readable CHILL/CHILL+ label name.
#'
#' @param label Integer label code (0 to 8).
#' @return A character string.
#' @examples
#' seams_label_name(1L)
#' @export
seams_label_name <- function(label) {
  .capi_call("_dseams_seams_r_label_name", as.integer(label))
}

#' Human-readable ring symmetry name.
#'
#' @param symmetry Integer ring symmetry code (0 to 11).
#' @return A character string.
#' @examples
#' seams_ring_symmetry_name(2L)
#' @export
seams_ring_symmetry_name <- function(symmetry) {
  .capi_call("_dseams_seams_r_ring_symmetry_name", as.integer(symmetry))
}

#' Populate a system handle from R arrays.
#'
#' @param sys A `dseams_system`.
#' @param xyz Numeric matrix with `n` rows and 3 columns (`x`, `y`, `z`)
#'   in angstrom.
#' @param box Numeric vector of length 9: `c(ox, oy, oz, lx, ly, lz, xy, xz, yz)`.
#' @param types Optional integer vector of atom types of length `n`.
#' @param ids Optional integer vector of atom IDs of length `n`.
#' @return The atom count `n`, invisibly.
#' @examples
#' sys <- seams_system_new()
#' xyz <- matrix(c(1, 2, 3, 1.5, 2, 3, 1, 2.8, 3), ncol = 3, byrow = TRUE)
#' box <- c(0, 0, 0, 20, 20, 20, 0, 0, 0)
#' seams_system_set_atoms(sys, xyz, box)
#' seams_system_count(sys)
#' @export
seams_system_set_atoms <- function(sys, xyz, box, types = NULL, ids = NULL) {
  xyz <- as.matrix(xyz)
  storage.mode(xyz) <- "double"
  box <- as.numeric(box)
  types_arg <- if (is.null(types)) NULL else as.integer(types)
  ids_arg <- if (is.null(ids)) NULL else as.integer(ids)
  invisible(.capi_call("_dseams_seams_r_set_atoms", sys, xyz, box, types_arg, ids_arg))
}

#' Simulation box stored on a system.
#'
#' @param sys A `dseams_system`.
#' @return Named numeric vector of length 9 (`ox`, `oy`, `oz`, `lx`, `ly`,
#'   `lz`, `xy`, `xz`, `yz`).
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_system_box(sys)
#' @export
seams_system_box <- function(sys) {
  out <- .capi_call("_dseams_seams_r_box", sys)
  names(out) <- c("ox", "oy", "oz", "lx", "ly", "lz", "xy", "xz", "yz")
  out
}

#' Atom positions stored on a system.
#'
#' @param sys A `dseams_system`.
#' @return Numeric matrix with `n` rows and columns `x`, `y`, `z`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' head(seams_system_positions(sys))
#' @export
seams_system_positions <- function(sys) {
  out <- .capi_call("_dseams_seams_r_positions", sys)
  colnames(out) <- c("x", "y", "z")
  out
}

#' Atom types stored on a system.
#'
#' @param sys A `dseams_system`.
#' @return An integer vector of atom types.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' head(seams_system_types(sys))
#' @export
seams_system_types <- function(sys) {
  .capi_call("_dseams_seams_r_types", sys)
}

#' Atom IDs stored on a system.
#'
#' @param sys A `dseams_system`.
#' @return An integer vector of atom IDs.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' head(seams_system_ids(sys))
#' @export
seams_system_ids <- function(sys) {
  .capi_call("_dseams_seams_r_ids", sys)
}

#' Shell symmetry labels on a system.
#'
#' @param sys A `dseams_system`.
#' @param shell_rmsd Largest RMSD threshold for matching the ice template.
#' @return An integer vector: `0` ice Ih, `1` ice Ic, `2` stacking-disordered,
#'   `-1` otherwise.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' table(seams_system_symmetry(sys))
#' @export
seams_system_symmetry <- function(sys, shell_rmsd = 0.12) {
  .capi_call("_dseams_seams_r_system_symmetry", sys, shell_rmsd)
}

#' Local q4 and q6 on the cutoff shell of a system.
#'
#' @param sys A `dseams_system`.
#' @param cutoff Neighbour cutoff in angstrom.
#' @param type Species filter.
#' @return A data.frame with columns `q4` and `q6`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' head(seams_q4q6(sys))
#' @export
seams_q4q6 <- function(sys, cutoff = 3.5, type = 0L) {
  out <- .capi_call("_dseams_seams_r_q4q6", sys, cutoff, as.integer(type))
  data.frame(q4 = out[[1L]], q6 = out[[2L]])
}

#' Lechner-Dellago q6bar summary on a system.
#'
#' @param sys A `dseams_system`.
#' @param cutoff Neighbour cutoff in angstrom.
#' @param type Species filter.
#' @param ice_cut Threshold on `q6bar` for counting ice-like atoms.
#' @return A list with `q6bar`, `mean`, `median`, and `n_ice`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_q6bar(sys)[c("mean", "median", "n_ice")]
#' @export
seams_q6bar <- function(sys, cutoff = 3.5, type = 0L, ice_cut = 0.36) {
  out <- .capi_call("_dseams_seams_r_q6bar", sys, cutoff, as.integer(type), ice_cut)
  names(out) <- c("q6bar", "mean", "median", "n_ice")
  out
}

#' Steinhardt q_l and Lechner-Dellago average on any neighbour graph.
#'
#' @param sys A `dseams_system`.
#' @param order Spherical-harmonic degree (3, 4, 6, 8, or 12).
#' @param cutoff Neighbour cutoff in angstrom.
#' @param type Species filter.
#' @param graph `0` cutoff, `1` mutual.
#' @return A list of class `dseams_order` with elements `ql` and `qlbar`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_ql(sys, order = 6L, graph = 0L)
#' @export
seams_ql <- function(sys, order = 6L, cutoff = 3.5, type = 0L, graph = 0L) {
  out <- .capi_call("_dseams_seams_r_ql", sys, cutoff, as.integer(type),
                    as.integer(order), as.integer(graph))
  names(out) <- c("ql", "qlbar")
  .tag(out, "dseams_order")
}

#' Per-atom cage membership labels on a system.
#'
#' @param sys A `dseams_system`.
#' @param cutoff Neighbour cutoff in angstrom.
#' @param type Species filter.
#' @param graph `2` seeded, `1` mutual, `0` cutoff.
#' @param k Neighbour count for the seeded graph.
#' @param complete When true, run ring-adjacent completion.
#' @return An integer vector (`0` water, `1` hexagonal, `2` cubic, `3` both)
#'   with `counts` attribute `c(n_hex, n_cubic, n_water, n_both)`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' table(seams_cages_labels(sys))
#' @export
seams_cages_labels <- function(sys, cutoff = 3.5, type = 0L, graph = 2L,
                               k = 4L, complete = FALSE) {
  out <- .capi_call("_dseams_seams_r_cages_labels", sys, cutoff, as.integer(type),
                    as.integer(graph), as.integer(k), as.integer(complete))
  labels <- out[[1L]]
  counts <- out[[2L]]
  names(counts) <- c("n_hex", "n_cubic", "n_water", "n_both")
  attr(labels, "counts") <- counts
  labels
}

#' Closed cages of one ring census with an edge filter.
#'
#' @param sys A `dseams_system`.
#' @param spec Census text such as `"512"`.
#' @param edge Edge-count filter specification, or `""` for the default window.
#' @param cutoff Neighbour cutoff in angstrom.
#' @param type Species filter.
#' @param graph `0` cutoff or `1` mutual.
#' @return An integer vector `c(n_cages, n_atoms)`, class `dseams_signature`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_signature_cages_edge(sys, "512")
#' @export
seams_signature_cages_edge <- function(sys, spec, edge = "", cutoff = 3.5,
                                       type = 0L, graph = 0L) {
  out <- .capi_call("_dseams_seams_r_signature_edge", sys, cutoff,
                    as.integer(type), as.integer(graph), spec, edge)
  names(out) <- c("n_cages", "n_atoms")
  .tag(out, "dseams_signature")
}

#' CSR neighbour list on a system.
#'
#' @param sys A `dseams_system`.
#' @param cutoff Neighbour cutoff in angstrom.
#' @param type Species filter.
#' @param graph `0` cutoff, `1` mutual, `2` seeded.
#' @return A list with `offsets`, `cols` (0-based indices), and `n_rows`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' nb <- seams_neighbours(sys)
#' length(nb$cols)
#' @export
seams_neighbours <- function(sys, cutoff = 3.5, type = 0L, graph = 0L) {
  out <- .capi_call("_dseams_seams_r_neighbours", sys, cutoff,
                    as.integer(type), as.integer(graph))
  names(out) <- c("offsets", "cols", "n_rows")
  out
}

#' Primitive ring census, labels, and ring fraction on a system.
#'
#' @param sys A `dseams_system`.
#' @param cutoff Neighbour cutoff in angstrom.
#' @param type Species filter.
#' @param graph `0` cutoff or `1` mutual.
#' @param max_depth Largest ring size.
#' @return A list with `n_rings`, `histogram` (sizes `0..max_depth`),
#'   `sizes`, `symmetry`, and `fraction`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_rings(sys)$n_rings
#' @export
seams_rings <- function(sys, cutoff = 3.5, type = 0L, graph = 0L, max_depth = 6L) {
  out <- .capi_call("_dseams_seams_r_rings", sys, cutoff, as.integer(type),
                    as.integer(graph), as.integer(max_depth))
  names(out) <- c("n_rings", "histogram", "sizes", "symmetry", "fraction")
  out
}

#' Chordless rings of a given size on a system.
#'
#' @param sys A `dseams_system`.
#' @param size Ring size (3 to 12).
#' @param cutoff Neighbour cutoff in angstrom.
#' @param type Species filter.
#' @param graph `0` cutoff or `1` mutual.
#' @return A list with `n_rings`, `rings` (matrix of 0-based atom indices),
#'   and `per_atom` counts.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_rings_chordless(sys, size = 6L)$n_rings
#' @export
seams_rings_chordless <- function(sys, size = 6L, cutoff = 3.5, type = 0L,
                                  graph = 0L) {
  out <- .capi_call("_dseams_seams_r_rings_chordless", sys, cutoff,
                    as.integer(type), as.integer(graph), as.integer(size))
  names(out) <- c("n_rings", "rings", "per_atom")
  out
}

#' Frame and per-atom topological fingerprints on a system.
#'
#' @param sys A `dseams_system`.
#' @param cutoff Neighbour cutoff in angstrom.
#' @param hops Neighbourhood depth.
#' @param type Species filter.
#' @param k Neighbour count.
#' @param graph `0` cutoff or `1` mutual.
#' @param color_types Whether to include species colors in the fingerprint.
#' @return A list with `key`, `atom_keys`, and `rings`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' fp <- seams_fingerprint_atoms(sys)
#' length(fp$atom_keys)
#' @export
seams_fingerprint_atoms <- function(sys, cutoff = 3.5, hops = 2L, type = 0L,
                                    k = 4L, graph = 0L, color_types = FALSE) {
  out <- .capi_call("_dseams_seams_r_fingerprint_atoms", sys, cutoff,
                    as.integer(type), as.integer(k), as.integer(graph),
                    as.integer(hops), as.integer(color_types))
  names(out) <- c("key", "atom_keys", "rings")
  out
}

#' Planar ice/brine front analysis on a system.
#'
#' @param sys A `dseams_system`.
#' @param ice Integer vector of length equal to atom count (`1` ice, `0` non-ice).
#' @param water_type Water species filter (`0` for all).
#' @param ion_type Ion species filter (`0` for none).
#' @param n_bins Number of profile bins along `axis`.
#' @param axis Axis index (`0`, `1`, or `2`).
#' @return A list with `fronts`, `rejection`, `profile` data.frame, and `pockets`.
#' @examples
#' sys <- seams_system_new()
#' n <- seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_brine(sys, rep(1L, n), n_bins = 4L)
#' @export
seams_brine <- function(sys, ice, water_type = 0L, ion_type = 0L,
                        n_bins = 8L, axis = 2L) {
  out <- .capi_call("_dseams_seams_r_brine", sys, as.integer(ice),
                    as.integer(water_type), as.integer(ion_type),
                    as.integer(n_bins), as.integer(axis))
  fronts <- out[[1L]]
  names(fronts) <- c("z_enter", "z_exit", "thickness", "found")
  rejection <- out[[2L]]
  names(rejection) <- c("c_ice", "c_liquid", "k", "defined")
  profile <- data.frame(
    z_mid = out[[3L]],
    molality = out[[4L]],
    ice_fraction = out[[5L]]
  )
  pockets <- out[[6L]]
  names(pockets) <- c("n_pockets", "reservoir_waters")
  list(fronts = fronts, rejection = rejection, profile = profile, pockets = pockets)
}
