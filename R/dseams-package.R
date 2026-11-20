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

.capi <- new.env(parent = emptyenv())

.capi_syms <- c(
  "_dseams_seams_r_system",
  "_dseams_seams_r_read",
  "_dseams_seams_r_count",
  "_dseams_seams_r_nframes",
  "_dseams_seams_r_threads",
  "_dseams_seams_r_chill",
  "_dseams_seams_r_steinhardt",
  "_dseams_seams_r_cages",
  "_dseams_seams_r_signature",
  "_dseams_seams_r_knn",
  "_dseams_seams_r_rdf",
  "_dseams_seams_r_running_cn",
  "_dseams_seams_r_coordination",
  "_dseams_seams_r_hbonds",
  "_dseams_seams_r_density",
  "_dseams_seams_r_fingerprint",
  "_dseams_seams_r_pairs",
  "_dseams_seams_r_domains",
  "_dseams_seams_r_prisms",
  "_dseams_seams_r_monolayer",
  "_dseams_seams_r_vertices",
  "_dseams_seams_r_site"
)

.capi_call <- function(sym, ...) {
  fn <- .capi[[sym]]
  if (is.null(fn)) {
    stop("C API symbol ", sym, " is not loaded", call. = FALSE)
  }
  .Call(fn, ...)
}

.onLoad <- function(libname, pkgname) {
  capi_pkg <- pkgname
  if ("dseams_capi" %in% names(getLoadedDLLs())) {
    capi_pkg <- "dseams_capi"
  } else {
    pkg_dir <- if (identical(basename(libname), pkgname) &&
                   file.exists(file.path(libname, "DESCRIPTION"))) {
      libname
    } else {
      file.path(libname, pkgname)
    }
    arch <- .Platform$r_arch
    capi_so <- paste0("dseams_capi", .Platform$dynlib.ext)
    capi_path <- if (nzchar(arch)) {
      file.path(pkg_dir, "libs", arch, capi_so)
    } else {
      file.path(pkg_dir, "libs", capi_so)
    }
    if (file.exists(capi_path)) {
      library.dynam("dseams_capi", pkgname, dirname(pkg_dir), local = TRUE)
      capi_pkg <- "dseams_capi"
    } else if (file.exists(file.path(pkg_dir, "src", capi_so))) {
      dyn.load(file.path(pkg_dir, "src", capi_so), local = TRUE)
      capi_pkg <- "dseams_capi"
    }
  }
  routines <- getDLLRegisteredRoutines(getLoadedDLLs()[[capi_pkg]])$.Call
  for (name in .capi_syms) {
    sym <- routines[[name]]
    if (is.null(sym)) {
      stop("C API symbol ", name, " is missing from ", capi_pkg, call. = FALSE)
    }
    .capi[[name]] <- sym
  }
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

.onUnload <- function(libpath) {
  dlls <- getLoadedDLLs()
  if ("dseams_capi" %in% names(dlls)) {
    tryCatch(
      library.dynam.unload("dseams_capi", libpath),
      error = function(e) dyn.unload(dlls[["dseams_capi"]][["path"]])
    )
  }
  library.dynam.unload("dseams", libpath)
}
