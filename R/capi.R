# Copyright (c) d-SEAMS developers
# .Call wrappers over include/seams.h. The libseams_lang frame API stays
# in dseams.R.

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
  ext <- .Call(`_dseams_seams_r_system`)
  class(ext) <- "dseams_system"
  ext
}

#' Read one frame into a system.
#'
#' @param sys A `dseams_system`.
#' @param path Trajectory path.
#' @param frame 1-based frame index.
#' @param type Species filter. Negative keeps every atom.
#' @return The atom count. `sys` is updated in place. On failure the
#'   previous frame is kept and the call stops with the engine's message.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' @export
seams_system_read <- function(sys, path, frame = 1L, type = -1L) {
  .Call(
    `_dseams_seams_r_read`, sys, normalizePath(path, mustWork = TRUE),
    as.integer(frame), as.integer(type)
  )
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
  .Call(`_dseams_seams_r_count`, sys)
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
  .Call(`_dseams_seams_r_threads`, as.integer(n))
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
  out <- .Call(
    `_dseams_seams_r_chill`, sys, cutoff, as.integer(type),
    as.integer(graph), as.integer(rule)
  )
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
  out <- .Call(
    `_dseams_seams_r_steinhardt`, sys, cutoff, as.integer(order),
    as.integer(average)
  )
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
#' @return An integer vector `c(n_hex, n_cubic, n_water, n_both)`, class
#'   `dseams_cage_counts`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_cages(sys)
#' @export
seams_cages <- function(sys, cutoff = 3.5, graph = 2L, k = 4L,
                        complete = FALSE) {
  out <- .Call(
    `_dseams_seams_r_cages`, sys, cutoff, as.integer(graph),
    as.integer(k), as.integer(complete)
  )
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
  out <- .Call(
    `_dseams_seams_r_signature`, sys, cutoff, as.integer(graph), spec
  )
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
  .tag(
    .Call(
      `_dseams_seams_r_knn`, sys, as.integer(k), cutoff, as.integer(mutual)
    ),
    "dseams_nnz"
  )
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
  out <- .Call(`_dseams_seams_r_rdf`, sys, rmax, as.integer(bins))
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
  .tag(
    .Call(`_dseams_seams_r_running_cn`, sys, rmax, as.integer(bins)),
    "dseams_running_cn"
  )
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
  .Call(`_dseams_seams_r_coordination`, sys, rmax, as.integer(bins))
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
seams_hbonds <- function(sys, cutoff = 3.5, oxygen_type = 1L,
                         hydrogen_type = 2L, dist = 2.42, angle = 30) {
  .Call(`_dseams_seams_r_hbonds`, sys, cutoff, as.integer(oxygen_type),
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
  .tag(
    .Call(
      `_dseams_seams_r_density`, sys, as.integer(type), as.integer(bins),
      as.integer(axis)
    ),
    "dseams_density"
  )
}

#' Topological fingerprint summary.
#'
#' @param sys A `dseams_system`.
#' @param cutoff Neighbour cutoff in angstrom.
#' @param hops Neighbourhood depth.
#' @return An integer vector `c(key_length, ring_sum)`, class
#'   `dseams_fingerprint`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_fingerprint(sys)
#' @export
seams_fingerprint <- function(sys, cutoff = 3.5, hops = 2L) {
  out <- .Call(`_dseams_seams_r_fingerprint`, sys, cutoff, as.integer(hops))
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
#' @return An integer vector `c(n_pairs, n_cation, n_anion)`, class
#'   `dseams_contacts`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_contact_pairs(sys, "1=cationHead")
#' @export
seams_contact_pairs <- function(sys, spec) {
  out <- .Call(`_dseams_seams_r_pairs`, sys, spec)
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
#' @return A numeric vector `c(n_subset, largest, percolation)`, class
#'   `dseams_domains`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_domains(sys, "1=waterO")
#' @export
seams_domains <- function(sys, spec, cutoff = 3.5, subset = 0L) {
  out <- .Call(`_dseams_seams_r_domains`, sys, cutoff, spec, as.integer(subset))
  names(out) <- c("n_subset", "largest", "percolation")
  .tag(out, "dseams_domains")
}

#' Perfect prism counts by ring size.
#'
#' @param sys A `dseams_system`.
#' @param cutoff Neighbour cutoff in angstrom.
#' @return An integer vector of length 7, class `dseams_prisms`. Index 7
#'   is size 6.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_prisms(sys)
#' @export
seams_prisms <- function(sys, cutoff = 3.5) {
  .tag(.Call(`_dseams_seams_r_prisms`, sys, cutoff), "dseams_prisms")
}

#' Primitive-ring histogram of a monolayer.
#'
#' @param sys A `dseams_system`.
#' @param cutoff Neighbour cutoff in angstrom.
#' @param max_depth Largest ring size.
#' @param sheet_area Sheet area in square angstrom.
#' @return An integer vector, class `dseams_monolayer`. `counts[k + 1]` is
#'   size `k`.
#' @examples
#' sys <- seams_system_new()
#' seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
#' seams_monolayer(sys)
#' @export
seams_monolayer <- function(sys, cutoff = 3.5, max_depth = 6L,
                            sheet_area = 100) {
  .tag(
    .Call(
      `_dseams_seams_r_monolayer`, sys, cutoff, as.integer(max_depth),
      sheet_area
    ),
    "dseams_monolayer"
  )
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
seams_rings_vertices <- function(sys, cutoff = 3.5, max_depth = 6L,
                                 index = 0L) {
  .tag(
    .Call(
      `_dseams_seams_r_vertices`, sys, cutoff, as.integer(max_depth),
      as.integer(index)
    ),
    "dseams_vertices"
  )
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
  .tag(.Call(`_dseams_seams_r_site`, sys, spec), "dseams_sites")
}
