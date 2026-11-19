# Copyright (c) d-SEAMS developers
# print and summary methods. The frame printer stays in dseams.R.

#' @rdname read_frame
#' @export
summary.dseams_frame <- function(object, ...) {
  cat("dseams frame", object$frame, "from", object$path, "\n", sep = " ")
  cat("atoms", nop_(object$ptr), "type filter", object$type, "\n", sep = " ")
  invisible(object)
}

#' @param x A `dseams_ice` data frame.
#' @param ... Ignored.
#' @rdname chill_plus
#' @export
print.dseams_ice <- function(x, ...) {
  cat("CHILL+ labels,", nrow(x), "atoms\n")
  base::print(table(x$name))
  invisible(x)
}

#' @param object A `dseams_ice` data frame.
#' @rdname chill_plus
#' @export
summary.dseams_ice <- function(object, ...) {
  base::print(table(object$name))
  invisible(object)
}

#' @param x A `dseams_cages` data frame.
#' @param ... Ignored.
#' @rdname cages
#' @export
print.dseams_cages <- function(x, ...) {
  cat(
    "cages hexagonal", attr(x, "n_ih"),
    "cubic", attr(x, "n_ic"),
    "both", attr(x, "n_both"),
    "water", attr(x, "n_water"),
    "\n"
  )
  invisible(x)
}

#' @param object A `dseams_cages` data frame.
#' @rdname cages
#' @export
summary.dseams_cages <- function(object, ...) {
  base::print(table(object$name))
  invisible(object)
}

#' @param x A `dseams_rings` data frame.
#' @param ... Ignored.
#' @rdname primitive_rings
#' @export
print.dseams_rings <- function(x, ...) {
  base::print(ring_table(x))
  invisible(x)
}

# Subsetting keeps the dseams_rings class, which would print through
# print.dseams_rings again.
ring_table <- function(x) {
  rows <- x[, c("size", "n")]
  class(rows) <- "data.frame"
  rows
}

#' @param object A `dseams_rings` data frame.
#' @rdname primitive_rings
#' @export
summary.dseams_rings <- function(object, ...) {
  base::print(ring_table(object))
  invisible(object)
}

#' @param x A `dseams_steinhardt` data frame.
#' @param ... Ignored.
#' @rdname steinhardt
#' @export
print.dseams_steinhardt <- function(x, ...) {
  cat("Steinhardt parameters,", nrow(x), "atoms, mean ql", mean(x$ql), "\n")
  invisible(x)
}

#' @param object A `dseams_steinhardt` data frame.
#' @rdname steinhardt
#' @export
summary.dseams_steinhardt <- function(object, ...) {
  cat("mean ql", mean(object$ql), "mean qlbar", mean(object$qlbar), "\n")
  invisible(object)
}

#' @param x A `dseams_q4_q6` data frame.
#' @param ... Ignored.
#' @rdname q4_q6
#' @export
print.dseams_q4_q6 <- function(x, ...) {
  cat("q4 q6,", nrow(x), "atoms, mean q6", mean(x$q6), "\n")
  invisible(x)
}

#' @param object A `dseams_q4_q6` data frame.
#' @rdname q4_q6
#' @export
summary.dseams_q4_q6 <- function(object, ...) {
  cat("mean q4", mean(object$q4), "mean q6", mean(object$q6), "\n")
  invisible(object)
}

#' @param x A `dseams_system`.
#' @param ... Ignored.
#' @rdname seams_system_new
#' @export
print.dseams_system <- function(x, ...) {
  n <- tryCatch(seams_system_count(x), error = function(e) NA_integer_)
  cat("dseams system", n, "atoms\n")
  invisible(x)
}

#' @param object A `dseams_system`.
#' @rdname seams_system_new
#' @export
summary.dseams_system <- function(object, ...) {
  cat("one loaded frame\n")
  base::print(object)
  invisible(object)
}

#' @param x A `dseams_chill` vector.
#' @param ... Ignored.
#' @rdname seams_chill
#' @export
print.dseams_chill <- function(x, ...) {
  cat("CHILL counts\n")
  base::print(stats::setNames(as.integer(x), names(x)))
  invisible(x)
}

#' @param object A `dseams_chill` vector.
#' @rdname seams_chill
#' @export
summary.dseams_chill <- function(object, ...) {
  base::print(object)
  invisible(object)
}
