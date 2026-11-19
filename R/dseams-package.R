# Copyright (c) d-SEAMS developers

#' @description
#' Structural analysis of water and ice in one molecular-dynamics frame.
#' LAMMPS dumps and XYZ files are always read. Chemfiles formats are
#' read when chemfiles is compiled in, and readcon `.con` files are read
#' when readcon-core is. readcon-core also defines `.convel`; this engine
#' routes `.con` ([dseams_features()]). The analyses are CHILL+ ice labels,
#' primitive rings, cages, Steinhardt q4 and q6, hydrogen bonds, radial
#' distribution functions, prisms, domains, monolayers, topological
#' fingerprints, coordination, density profiles, and jump_tau90.
#'
#' @details
#' [dseams_example()] names the dumps shipped with the package.
#' [read_frame()] loads one frame. [dseams_features()] reports which
#' readers this build compiled. [chill_plus()], [primitive_rings()],
#' [cages()], [signature_cages()], [symmetry()], [steinhardt()],
#' [q4_q6()], and [jump_tau90()] analyse that frame. The `seams_*`
#' functions are the same analyses on a system handle, plus hydrogen
#' bonds, radial distribution, coordination, density, prisms, domains,
#' monolayers, and fingerprints.
#'
#' Cite Goswami, Goswami and Singh (2020), Journal of Chemical Information
#' and Modeling. `citation("dseams")` prints the record.
#'
#' @references
#' Goswami, R., Goswami, A. and Singh, J. K. (2020).
#' d-SEAMS: Deferred Structural Elucidation Analysis for Molecular
#' Simulations.
#' *Journal of Chemical Information and Modeling* 60, 2169-2177.
#' \doi{10.1021/acs.jcim.0c00031}
#'
#' Nguyen, A. H. and Molinero, V. (2015). Identification of clathrate
#' hydrates, hexagonal ice, cubic ice, and liquid water in simulations:
#' the CHILL+ algorithm.
#' *The Journal of Physical Chemistry B* 119, 9369-9376.
#' \doi{10.1021/jp510289t}
#'
#' Franzblau, D. S. (1991). Computation of ring statistics for network
#' models of solids. *Physical Review B* 44, 4925.
#' \doi{10.1103/PhysRevB.44.4925}
#'
#' Steinhardt, P. J., Nelson, D. R. and Ronchetti, M. (1983).
#' Bond-orientational order in liquids and glasses.
#' *Physical Review B* 28, 784.
#' \doi{10.1103/PhysRevB.28.784}
#'
#' @examples
#' frame <- read_frame(dseams_example("ice1h.lammpstrj"), type = -1L)
#' table(chill_plus(frame)$name)
#'
#' @useDynLib dseams, .registration = TRUE
"_PACKAGE"

.onLoad <- function(libname, pkgname) {
  n <- getOption("dseams.threads")
  if (is.null(n)) {
    limit <- Sys.getenv("_R_CHECK_LIMIT_CORES_", "")
    if (nzchar(limit) && !identical(toupper(limit), "FALSE")) {
      n <- min(2L, get_threads_())
    }
  }
  if (!is.null(n)) {
    set_threads_(as.integer(n))
  }
}
