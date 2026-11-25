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

# Where a pinned input may already be on disk: $DSEAMS_ROOT/input/traj,
# then DSEAMS_INPUT_CACHE (default: the session temp directory).
seams_input_dirs <- function() {
  root <- Sys.getenv("DSEAMS_ROOT", unset = "")
  cache <- Sys.getenv("DSEAMS_INPUT_CACHE",
                      unset = file.path(tempdir(), "seams-inputs"))
  c(if (nzchar(root)) file.path(root, "input", "traj"), cache)
}

seams_inputs_online <- function() {
  ok <- tryCatch(
    length(curlGetHeaders("https://huggingface.co", timeout = 10L)) > 0L,
    error = function(e) FALSE
  )
  isTRUE(ok)
}

# The verified local copy of a pinned input, in this order:
#
# 1. A copy in seams_input_dirs() with the pinned digest. A copy with any
#    other digest is an error.
# 2. $DSEAMS_ROOT/input/fetch.py, when DSEAMS_ROOT and python3 are there.
#    It must pin the same revision and digest; any failure is an error.
# 3. download.file() into DSEAMS_INPUT_CACHE. With no local source this
#    needs the network, so the test skips on CRAN (NOT_CRAN unset) and
#    when huggingface.co does not answer. DSEAMS_REQUIRE_DATA=1 turns
#    both skips into errors. A failed download or a different digest is
#    always an error.
#
# DSEAMS_INPUTS_LOG, when set, gets one line per resolved input:
# "<name> <sha256> <path>".
seams_input <- function(name) {
  expected <- seams_inputs_sha256[[name]]
  path <- seams_input_resolve(name, expected)
  log <- Sys.getenv("DSEAMS_INPUTS_LOG", unset = "")
  if (nzchar(log)) {
    cat(paste(name, expected, path), "\n", sep = "", file = log, append = TRUE)
  }
  path
}

seams_input_resolve <- function(name, expected) {
  for (dir in seams_input_dirs()) {
    path <- file.path(dir, name)
    if (file.exists(path)) {
      got <- file_sha256(path)
      if (!identical(got, expected)) {
        stop(path, ": expected sha256 ", expected, ", found ", got,
             "; delete it to fetch the pinned copy")
      }
      return(path)
    }
  }
  root <- Sys.getenv("DSEAMS_ROOT", unset = "")
  fetch_py <- if (nzchar(root)) file.path(root, "input", "fetch.py") else ""
  python <- Sys.which("python3")
  if (nzchar(fetch_py) && file.exists(fetch_py) && nzchar(python)) {
    dest <- file.path(root, "input", "traj")
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
    path <- file.path(dest, name)
    if (!has_sha256(path, expected)) {
      stop(path, " does not have sha256 ", expected)
    }
    return(path)
  }
  if (!identical(Sys.getenv("DSEAMS_REQUIRE_DATA"), "1")) {
    why <- paste0(
      name, " is not in DSEAMS_ROOT/input/traj or DSEAMS_INPUT_CACHE and"
    )
    if (!identical(Sys.getenv("NOT_CRAN"), "true")) {
      testthat::skip(paste(why, "network tests do not run on CRAN"))
    }
    if (!seams_inputs_online()) {
      testthat::skip(paste(why, "huggingface.co is not reachable"))
    }
  }
  dest <- seams_input_dirs()[[length(seams_input_dirs())]]
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(dest, name)
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
  if (!file.rename(partial, path)) {
    stop("could not move ", partial, " to ", path)
  }
  path
}
