# Copyright (c) d-SEAMS developers
# Download the pinned seams-core source and print the directory it unpacks
# to. configure and configure.win call this only when src/seams is missing
# and no seams-core checkout is named, which is the case for an install
# from git. A source package from R CMD build already holds src/seams and
# never reaches this script.
#
#   Rscript tools/fetch-engine.R DESTDIR

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) {
  stop("usage: Rscript tools/fetch-engine.R DESTDIR", call. = FALSE)
}
dest <- args[[1L]]

pin <- readLines(file.path("tools", "seams-core.ref"), warn = FALSE)
pin <- pin[grepl("^SEAMS_CORE_[A-Z]+=", pin)]
value <- function(key) {
  hit <- sub(paste0("^", key, "="), "", pin[startsWith(pin, paste0(key, "="))])
  if (length(hit) != 1L || !nzchar(hit)) {
    stop("tools/seams-core.ref has no ", key, call. = FALSE)
  }
  hit
}
repo <- Sys.getenv("SEAMS_CORE_REPO", value("SEAMS_CORE_REPO"))
ref <- Sys.getenv("SEAMS_CORE_REF", value("SEAMS_CORE_REF"))
url <- sprintf("https://github.com/%s/archive/%s.tar.gz", repo, ref)

dir.create(dest, recursive = TRUE, showWarnings = FALSE)
tarball <- file.path(dest, "seams-core.tar.gz")
message("fetch-engine: downloading ", url)
old <- options(timeout = max(600, getOption("timeout")))
status <- tryCatch(
  utils::download.file(url, tarball, mode = "wb", quiet = TRUE),
  error = function(e) {
    message("fetch-engine: ", conditionMessage(e))
    1L
  }
)
options(old)
if (!identical(status, 0L) || !file.exists(tarball)) {
  stop("could not download ", url, call. = FALSE)
}
before <- list.dirs(dest, recursive = FALSE)
if (utils::untar(tarball, exdir = dest) != 0L) {
  stop("could not unpack ", tarball, call. = FALSE)
}
unlink(tarball)
root <- setdiff(list.dirs(dest, recursive = FALSE), before)
if (length(root) != 1L) {
  stop("expected one directory in ", url, call. = FALSE)
}
cat(normalizePath(root, winslash = "/"), "\n", sep = "")
