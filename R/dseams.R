#' Path of a trajectory shipped with the package
#'
#' `"ice1h.lammpstrj"` is a 2x2x2 ice Ih cell from GenIce (128 oxygens).
#' `"exampleTraj.lammpstrj"` is one frame of a mixed TIP4P/ice system (250
#' waters, type 2 is oxygen). `"nucleation_f1.lammpstrj"` is the first frame
#' of the d-SEAMS mW nucleation trajectory (4096 waters). Each dump has a
#' `.source.txt` file or a header that names its origin.
#'
#' @param name File name. `NULL` lists the files.
#' @return A path, or a character vector of file names when `name` is `NULL`.
#' @examples
#' dseams_example()
#' dseams_example("ice1h.lammpstrj")
#' @export
dseams_example <- function(name = NULL) {
  dir <- system.file("extdata", package = "dseams", mustWork = TRUE)
  if (is.null(name)) {
    return(list.files(dir, pattern = "\\.lammpstrj$"))
  }
  path <- file.path(dir, name)
  if (!file.exists(path)) {
    stop("no example named ", sQuote(name), call. = FALSE)
  }
  path
}

#' Read one trajectory frame
#'
#' `type = 0` guesses oxygen (LAMMPS type 2, otherwise type 1). A positive
#' type keeps that species. A negative type keeps every atom.
#'
#' `print()` reports the frame index and the atom count. `summary()` also
#' reports the file and the type filter. Both return the frame, invisibly.
#'
#' @param path Path to a LAMMPS dump, or an XYZ file.
#' @param frame 1-based frame index.
#' @param type LAMMPS type filter.
#' @param x A `dseams_frame`, for `print()`.
#' @param object A `dseams_frame`, for `summary()`.
#' @param ... Ignored.
#' @return `read_frame()` returns an object of class `dseams_frame`.
#'   `nframes()` returns the number of LAMMPS timesteps; an XYZ file counts
#'   as one. `print()` and `summary()` return the frame, invisibly.
#' @examples
#' path <- dseams_example("ice1h.lammpstrj")
#' nframes(path)
#' frame <- read_frame(path, type = -1L)
#' frame
#' @export
read_frame <- function(path, frame = 1L, type = 0L) {
  path <- normalizePath(path, mustWork = TRUE)
  ptr <- read_frame_(path, as.integer(frame), as.integer(type))
  structure(
    list(
      ptr = ptr,
      path = path,
      frame = as.integer(frame),
      type = as.integer(type)
    ),
    class = "dseams_frame"
  )
}

#' @rdname read_frame
#' @export
nframes <- function(path) {
  nframes_(normalizePath(path, mustWork = TRUE))
}

#' Atom positions
#'
#' @param frame A `dseams_frame`.
#' @return `positions()` returns a numeric matrix with one row per atom and
#'   columns `x`, `y`, `z` in the units of the file.
#' @examples
#' frame <- read_frame(dseams_example("ice1h.lammpstrj"), type = -1L)
#' head(positions(frame))
#' @export
positions <- function(frame) {
  UseMethod("positions")
}

#' @rdname positions
#' @export
positions.dseams_frame <- function(frame) {
  n <- nop_(frame$ptr)
  matrix(positions_(frame$ptr), nrow = n, ncol = 3, byrow = TRUE,
         dimnames = list(NULL, c("x", "y", "z")))
}

#' @rdname read_frame
#' @export
print.dseams_frame <- function(x, ...) {
  cat("dseams frame", x$frame, "atoms", nop_(x$ptr), "\n", sep = " ")
  invisible(x)
}

#' CHILL+ ice labels
#'
#' `graph = "cutoff"` (the default) bonds every pair closer than `cutoff`,
#' as `seams chill-plus`, pydseamslib, and the Julia package do by default.
#' `graph = "mutual"` keeps the mutual four nearest neighbours inside
#' `cutoff + 1.5`.
#'
#' `rule = "chill+"` is the published rule: the cutoff shell must hold
#' exactly four neighbours, q3 is averaged over the four nearest, and the
#' Table 1 interfacial-neighbour test is on. `rule = "ovito-chill+"`
#' averages q3 over the whole shell and skips that test.
#'
#' `name` is one of nine labels. `cubic` is cubic ice and `hexagonal` is
#' hexagonal ice. `interfacial` is ice-like but not cubic or hexagonal.
#' `clathrate` is clathrate and `interClathrate` is interfacial clathrate.
#' `water` is liquid or amorphous. `unclassified` matched none of those.
#' `reCubic` and `reHex` are cubic and hexagonal ice reclassified with the
#' q6 order parameter.
#'
#' `print()` counts the names. It does not print the rows. `summary()`
#' prints the same counts. Both return the data frame, invisibly.
#'
#' Ice Ih (`dseams_example("ice1h.lammpstrj")`, every atom) is 128
#' hexagonal waters and 256 primitive six-rings.
#'
#' @param frame A `dseams_frame`.
#' @param cutoff Neighbour cutoff in angstrom. For the mutual graph this is
#'   only the cell-size hint (`cutoff + 1.5`).
#' @param type LAMMPS type. 0 uses the first atom's type.
#' @param graph `"cutoff"` or `"mutual"`.
#' @param rule `"chill+"` or `"ovito-chill+"`. A YAML or Lua snippet with
#'   a `rule` field is accepted.
#' @return A data.frame with columns `atom`, `type`, `label`, `name`.
#'   The `counts` attribute is the nine-label histogram. `print()` and
#'   `summary()` return that data frame, invisibly.
#' @references Nguyen, A. H. and Molinero, V. (2015). Identification of
#'   clathrate hydrates, hexagonal ice, cubic ice, and liquid water in
#'   simulations: the CHILL+ algorithm.
#'   *The Journal of Physical Chemistry B* 119, 9369-9376.
#'   \doi{10.1021/jp510289t}
#' @examples
#' frame <- read_frame(dseams_example("ice1h.lammpstrj"), type = -1L)
#' ice <- chill_plus(frame)
#' table(ice$name)
#' ice
#' @export
chill_plus <- function(frame, cutoff = 3.5, type = 0L, graph = "cutoff",
                       rule = "chill+") {
  UseMethod("chill_plus")
}

#' @rdname chill_plus
#' @export
chill_plus.dseams_frame <- function(frame, cutoff = 3.5, type = 0L,
                                    graph = "cutoff", rule = "chill+") {
  out <- chill_plus_(frame$ptr, cutoff, as.integer(type), graph, rule)
  class(out) <- c("dseams_ice", "data.frame")
  out
}

#' Hexagonal-cage and double-diamond membership
#'
#' @param frame A `dseams_frame`.
#' @param cutoff Neighbour cutoff in angstrom.
#' @param type LAMMPS type. 0 uses the first atom's type.
#' @param k Neighbours kept by the k-nearest graphs.
#' @param graph `"seeded"`, `"mutual"`, `"cutoff"`, or `"knn-union"`.
#' @return A data.frame with columns `atom`, `cage`, `name`.
#'   `print()` reports `n_ih`, `n_ic`, `n_both`, and `n_water`.
#'   `summary()` counts `name`. Both return the data frame, invisibly.
#'   Attributes `n_ih`, `n_ic`, `n_both`, `n_water` are disjoint and match
#'   `seams cages` (hexagonal only, cubic only, both, water). Per-atom
#'   `cage` is 0 water, 1 hexagonal, 2 cubic, 3 both.
#' @examples
#' frame <- read_frame(dseams_example("ice1h.lammpstrj"), type = -1L)
#' found <- cages(frame)
#' attr(found, "n_ih")
#' @export
cages <- function(frame, cutoff = 3.5, type = 0L, k = 4L, graph = "seeded") {
  UseMethod("cages")
}

#' @rdname cages
#' @export
cages.dseams_frame <- function(frame, cutoff = 3.5, type = 0L, k = 4L,
                               graph = "seeded") {
  out <- cages_(frame$ptr, cutoff, as.integer(type), as.integer(k), graph)
  class(out) <- c("dseams_cages", "data.frame")
  out
}

#' Primitive ring census
#'
#' Counts the primitive rings of the hydrogen-bond network (Franzblau's
#' shortest-path rings).
#'
#' @param frame A `dseams_frame`.
#' @param cutoff Neighbour cutoff in angstrom.
#' @param type LAMMPS type. 0 uses the first atom's type.
#' @param graph `"mutual"` or `"cutoff"`.
#' @param max_depth Largest ring retained.
#' @return A data.frame with columns `size` and `n`, one row per ring size
#'   that occurs. `print()` and `summary()` print that table and return the
#'   data frame, invisibly.
#' @references Franzblau, D. S. (1991). Computation of ring statistics for
#'   network models of solids. *Physical Review B* 44, 4925.
#'   \doi{10.1103/PhysRevB.44.4925}
#' @examples
#' frame <- read_frame(dseams_example("ice1h.lammpstrj"), type = -1L)
#' primitive_rings(frame, graph = "cutoff", max_depth = 6L)
#' @export
primitive_rings <- function(frame, cutoff = 3.5, type = 0L, graph = "mutual",
                            max_depth = 6L) {
  UseMethod("primitive_rings")
}

#' @rdname primitive_rings
#' @export
primitive_rings.dseams_frame <- function(frame, cutoff = 3.5, type = 0L,
                                         graph = "mutual", max_depth = 6L) {
  out <- rings_(
    frame$ptr, cutoff, as.integer(type), graph, as.integer(max_depth)
  )
  class(out) <- c("dseams_rings", "data.frame")
  out
}

#' Closed cages for one ring census
#'
#' @param frame A `dseams_frame`.
#' @param spec Ring census such as `"512"` (twelve pentagons, the sI small
#'   cage) or `"5:12,6:2"`.
#' @param cutoff Neighbour cutoff in angstrom.
#' @param type LAMMPS type. 0 uses the first atom's type.
#' @param graph `"cutoff"` or `"mutual"`.
#' @return An integer vector `c(n_cages, n_atoms)`.
#' @examples
#' frame <- read_frame(dseams_example("exampleTraj.lammpstrj"), type = 2L)
#' signature_cages(frame, "512")
#' @export
signature_cages <- function(frame, spec = "512", cutoff = 3.5, type = 0L,
                            graph = "cutoff") {
  UseMethod("signature_cages")
}

#' @rdname signature_cages
#' @export
signature_cages.dseams_frame <- function(frame, spec = "512", cutoff = 3.5,
                                         type = 0L, graph = "cutoff") {
  signature_cages_(frame$ptr, cutoff, as.integer(type), graph, spec)
}

#' Jump-rotor tau_90 between two frames
#'
#' Returns `dt` when any water's H-H vector rotates by at least 90 degrees
#' between the two frames, and `NaN` otherwise. Both frames must contain
#' oxygen and hydrogen. In `exampleTraj.lammpstrj` those species are types
#' 2 and 1. `ice1h.lammpstrj` is oxygen only, so it has no H-H vector.
#' Comparing a frame with itself returns `NaN`.
#'
#' @param first,second `dseams_frame` objects read with every atom
#'   (`type = -1`), so that both oxygens and hydrogens are present.
#' @param dt Time between the two frames.
#' @param oxygen_type,hydrogen_type LAMMPS types of the oxygen and hydrogen
#'   atoms.
#' @return A number: `dt`, or `NaN`.
#' @examples
#' frame <- read_frame(dseams_example("exampleTraj.lammpstrj"), type = -1L)
#' jump_tau90(frame, frame, dt = 1, oxygen_type = 2L, hydrogen_type = 1L)
#' @export
jump_tau90 <- function(first, second, dt = 1, oxygen_type = 1L,
                       hydrogen_type = 2L) {
  stopifnot(inherits(first, "dseams_frame"), inherits(second, "dseams_frame"))
  jump_tau90_(first$ptr, second$ptr, dt, as.integer(oxygen_type),
              as.integer(hydrogen_type))
}

#' Shell symmetry label for every atom
#'
#' @param frame A `dseams_frame`.
#' @param shell_rmsd Largest RMSD, in the units of the file, at which a
#'   neighbour shell still matches the ideal ice template.
#' @return An integer vector, one code per atom: 0 ice Ih, 1 ice Ic,
#'   2 stacking-disordered, -1 otherwise.
#' @examples
#' frame <- read_frame(dseams_example("ice1h.lammpstrj"), type = -1L)
#' table(symmetry(frame))
#' @export
symmetry <- function(frame, shell_rmsd = 0.12) {
  UseMethod("symmetry")
}

#' @rdname symmetry
#' @export
symmetry.dseams_frame <- function(frame, shell_rmsd = 0.12) {
  symmetry_(frame$ptr, shell_rmsd)
}

#' Steinhardt order parameters
#'
#' `ql` is the local parameter. `qlbar` is the Lechner-Dellago neighbour
#' average.
#'
#' @param frame A `dseams_frame`.
#' @param order_l Spherical-harmonic degree. 3, 4, 6, 8, and 12 are computed.
#'   Degrees 4 and 6 on an orthorhombic or restricted-triclinic cell use the
#'   solid-harmonic kernel.
#' @param cutoff Neighbour cutoff in angstrom.
#' @param type LAMMPS type. 0 uses the first atom's type.
#' @param graph Neighbour graph. `NULL` is the cutoff shell. `"mutual"` is
#'   the four nearest neighbours inside `cutoff + 1.5`. `"cutoff"` asks for
#'   the cutoff shell by name.
#' @return A data.frame with columns `atom`, `ql`, `qlbar`.
#'   `print()` reports the atom count and the mean of `ql`. `summary()`
#'   reports the mean of `ql` and of `qlbar`. Both return the data frame,
#'   invisibly.
#' @references Steinhardt, P. J., Nelson, D. R. and Ronchetti, M. (1983).
#'   Bond-orientational order in liquids and glasses. *Physical Review B*
#'   28, 784. \doi{10.1103/PhysRevB.28.784}
#' @examples
#' frame <- read_frame(dseams_example("ice1h.lammpstrj"), type = -1L)
#' summary(steinhardt(frame, order_l = 6L)$ql)
#' @export
steinhardt <- function(frame, order_l = 6L, cutoff = 3.5, type = 0L,
                       graph = NULL) {
  UseMethod("steinhardt")
}

#' @rdname steinhardt
#' @export
steinhardt.dseams_frame <- function(
    frame, order_l = 6L, cutoff = 3.5, type = 0L, graph = NULL) {
  graph_arg <- if (is.null(graph)) "" else as.character(graph)
  out <- steinhardt_(
    frame$ptr, cutoff, as.integer(type), as.integer(order_l), graph_arg
  )
  class(out) <- c("dseams_steinhardt", "data.frame")
  out
}

#' Local q4 and q6 on the cutoff shell
#'
#' Both degrees use the solid-harmonic kernel. `q4bar` and `q6bar` are the
#' Lechner-Dellago averages.
#'
#' @param frame A `dseams_frame`.
#' @param cutoff Neighbour cutoff in angstrom.
#' @param type LAMMPS type. 0 uses the first atom's type.
#' @return A data.frame with columns `atom`, `q4`, `q6`, `q4bar`, `q6bar`.
#'   `print()` reports the atom count and the mean of `q6`. `summary()`
#'   reports the mean of `q4` and of `q6`. Both return the data frame,
#'   invisibly.
#' @examples
#' frame <- read_frame(dseams_example("ice1h.lammpstrj"), type = -1L)
#' head(q4_q6(frame))
#' @export
q4_q6 <- function(frame, cutoff = 3.5, type = 0L) {
  UseMethod("q4_q6")
}

#' @rdname q4_q6
#' @export
q4_q6.dseams_frame <- function(frame, cutoff = 3.5, type = 0L) {
  out <- q4_q6_(frame$ptr, cutoff, as.integer(type))
  class(out) <- c("dseams_q4_q6", "data.frame")
  out
}

#' Engine threads
#'
#' The engine parallelises with OpenMP when the package was compiled with
#' it. `dseams_threads()` reports the thread count, and
#' `dseams_threads(n)` sets it for later calls from this R session. Frames
#' below about 2000 atoms run on one thread regardless.
#'
#' The option `dseams.threads` sets the starting count, before the package
#' is loaded. When R has been asked to limit the number of cores, the
#' package starts with at most two threads.
#'
#' @param n Number of threads, or `NULL` to only query.
#' @return The thread count in effect after the call. Without OpenMP this
#'   is always 1.
#' @examples
#' dseams_threads()
#' @export
dseams_threads <- function(n = NULL) {
  if (!is.null(n)) {
    n <- as.integer(n)
    if (length(n) != 1L || is.na(n) || n < 1L) {
      stop("`n` must be one positive integer", call. = FALSE)
    }
    set_threads_(n)
  }
  get_threads_()
}

#' Engine version
#'
#' @return The version string of the bundled seams-core engine.
#' @examples
#' dseams_version()
#' @export
dseams_version <- function() {
  lang_version_()
}
