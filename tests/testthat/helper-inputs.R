# Large trajectories live in the d-SEAMS/seams-core-inputs dataset, not in
# git. These pins are the ones input/fetch.py carries at the seams-core
# revision in tools/seams-core.ref (v2.14.2). seams_input() checks a
# DSEAMS_ROOT fetch.py against them and stops on a difference.
seams_inputs_revision <- "163ca2d8dfcb7ef21d88aea1c67381d841f63641"
seams_inputs_sha256 <- c(
  "mW_cubic.lammpstrj" =
    "66d854880bb9431abc9eb25d68b0622d94a0160dd03e1ac7d636343d9830485d"
)

file_sha256 <- function(path) {
  tools_ns <- asNamespace("tools")
  if (exists("sha256sum", envir = tools_ns, inherits = FALSE)) {
    return(unname(get("sha256sum", envir = tools_ns)(path)))
  }
  for (cmd in list(c("sha256sum"), c("shasum", "-a", "256"))) {
    tool <- Sys.which(cmd[[1L]])
    if (nzchar(tool)) {
      out <- system2(tool, c(cmd[-1L], shQuote(path)), stdout = TRUE)
      return(strsplit(trimws(out[[1L]]), "[[:space:]]+")[[1L]][[1L]])
    }
  }
  stop("no SHA-256 tool: R < 4.5 needs sha256sum or shasum on PATH")
}

has_sha256 <- function(path, expected) {
  file.exists(path) && identical(file_sha256(path), expected)
}

# The verified local copy of a pinned input. With DSEAMS_ROOT the file
# goes to $DSEAMS_ROOT/input/traj through that tree's input/fetch.py;
# otherwise to DSEAMS_INPUT_CACHE (default: the session temp directory)
# through download.file(). A verified copy is not downloaded again. A
# failed download or a different digest is an error, not a skip.
seams_input <- function(name) {
  expected <- seams_inputs_sha256[[name]]
  root <- Sys.getenv("DSEAMS_ROOT", unset = "")
  fetch_py <- if (nzchar(root)) file.path(root, "input", "fetch.py") else ""
  dest <- if (nzchar(root)) {
    file.path(root, "input", "traj")
  } else {
    Sys.getenv("DSEAMS_INPUT_CACHE", unset = file.path(tempdir(), "seams-inputs"))
  }
  path <- file.path(dest, name)
  if (has_sha256(path, expected)) {
    return(path)
  }
  python <- Sys.which("python3")
  if (nzchar(fetch_py) && file.exists(fetch_py) && nzchar(python)) {
    pins <- readLines(fetch_py, warn = FALSE)
    if (!any(grepl(seams_inputs_revision, pins, fixed = TRUE)) ||
        !any(grepl(expected, pins, fixed = TRUE))) {
      stop(fetch_py, " does not pin revision ", seams_inputs_revision,
           " and sha256 ", expected, " for ", name)
    }
    status <- system2(python, c(shQuote(fetch_py), name, "--output-dir", shQuote(dest)))
    if (!identical(as.integer(status), 0L)) {
      stop("input/fetch.py ", name, " exited with status ", status)
    }
  } else {
    dir.create(dest, recursive = TRUE, showWarnings = FALSE)
    url <- paste0(
      "https://huggingface.co/datasets/d-SEAMS/seams-core-inputs/resolve/",
      seams_inputs_revision, "/traj/", name
    )
    partial <- paste0(path, ".partial")
    on.exit(unlink(partial), add = TRUE)
    old <- options(timeout = max(300, getOption("timeout")))
    on.exit(options(old), add = TRUE)
    status <- utils::download.file(url, partial, mode = "wb", quiet = TRUE)
    if (!identical(as.integer(status), 0L)) {
      stop("could not download ", url)
    }
    got <- file_sha256(partial)
    if (!identical(got, expected)) {
      stop(name, ": expected sha256 ", expected, ", downloaded ", got)
    }
    file.rename(partial, path)
  }
  if (!has_sha256(path, expected)) {
    stop(path, " does not have sha256 ", expected)
  }
  path
}
