# Copyright (c) d-SEAMS developers
# covr runs the installed tests with tools::testInstalledPackage(), which
# has no 00_pkg_src. It installs with --with-keep.source, so the srcref of
# an installed function names the file it was parsed from. nframes lives in
# R/, and the package root is two directories above that file.

kept_source_dir <- function() {
  fn <- get0("nframes", envir = asNamespace("dseams"), inherits = FALSE)
  if (!is.function(fn)) {
    return(character())
  }
  file <- utils::getSrcFilename(fn, full.names = TRUE)
  if (length(file) != 1L || is.na(file) || !nzchar(file) || !file.exists(file)) {
    return(character())
  }
  dirname(dirname(file))
}
