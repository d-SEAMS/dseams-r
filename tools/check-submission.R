# Copyright (c) d-SEAMS developers
# The rOpenSci draft pastes DESCRIPTION into a fence. This compares that
# fence to the file, byte for byte, and checks that Ruhila Goswami's
# contributor role and ORCID are the same in DESCRIPTION, codemeta.json,
# the draft, and README.md.
#
#   Rscript tools/check-submission.R
#   Rscript tools/check-submission.R --write
#
# --write replaces the fenced block with the current DESCRIPTION. The
# check fails when any required file is missing.

read_text <- function(path) {
  size <- file.info(path)$size
  if (is.na(size)) {
    stop("missing file: ", path, call. = FALSE)
  }
  # size 0 still needs a defined character value.
  raw <- if (size == 0L) raw(0L) else readBin(path, "raw", n = size)
  txt <- rawToChar(raw)
  Encoding(txt) <- "UTF-8"
  txt
}

extract_description_block <- function(md) {
  marker <- "Paste the full DESCRIPTION file inside a code block below:"
  idx <- regexpr(marker, md, fixed = TRUE)
  if (idx < 0L) {
    stop("submission draft has no DESCRIPTION paste marker", call. = FALSE)
  }
  rest <- substring(md, idx)
  m <- regexpr("(?s)```\\n(.*?)\\n```", rest, perl = TRUE)
  if (m < 0L) {
    stop("submission draft has no fenced block after the DESCRIPTION marker",
         call. = FALSE)
  }
  cap <- attr(m, "capture.start")[1L]
  len <- attr(m, "capture.length")[1L]
  # The capture stops before the newline that closes the fence. DESCRIPTION
  # keeps that trailing newline, so put it back.
  paste0(substring(rest, cap, cap + len - 1L), "\n")
}

replace_description_block <- function(md, desc) {
  marker <- "Paste the full DESCRIPTION file inside a code block below:"
  idx <- regexpr(marker, md, fixed = TRUE)
  if (idx < 0L) {
    stop("submission draft has no DESCRIPTION paste marker", call. = FALSE)
  }
  head <- substring(md, 1L, idx - 1L)
  rest <- substring(md, idx)
  m <- regexpr("(?s)```\\n(.*?)\\n```", rest, perl = TRUE)
  if (m < 0L) {
    stop("submission draft has no fenced block after the DESCRIPTION marker",
         call. = FALSE)
  }
  start <- attr(m, "capture.start")[1L]
  len <- attr(m, "capture.length")[1L]
  # desc already ends with a newline. The fence supplies the newline
  # before the closing backticks, so drop one from the end of desc.
  if (!endsWith(desc, "\n")) {
    stop("DESCRIPTION does not end with a newline", call. = FALSE)
  }
  body <- substring(desc, 1L, nchar(desc) - 1L)
  paste0(
    head,
    substring(rest, 1L, start - 1L),
    body,
    substring(rest, start + len)
  )
}

# Exact records. A role or ORCID that drifts fails the check.
ruhila_description <- paste0(
  "    person(\"Ruhila\", \"Goswami\", role = \"ctb\",\n",
  "           comment = c(ORCID = \"0000-0002-5443-9356\")),"
)
ruhila_codemeta <- paste0(
  "      \"givenName\": \"Ruhila\",\n",
  "      \"familyName\": \"Goswami\",\n",
  "      \"@id\": \"https://orcid.org/0000-0002-5443-9356\""
)
ruhila_readme <- "Ruhila Goswami (`ctb`), ORCID 0000-0002-5443-9356"
ruhila_draft <- "Ruhila Goswami a contributor (`ctb`) in the DESCRIPTION."

check_submission <- function(root) {
  root <- normalizePath(root, mustWork = TRUE)
  problems <- character()
  need <- c(
    "DESCRIPTION",
    "codemeta.json",
    "README.md",
    file.path("docs", "ropensci-submission.md")
  )
  missing <- need[!file.exists(file.path(root, need))]
  if (length(missing)) {
    stop(
      "required file missing under ", root, ": ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  desc <- read_text(file.path(root, "DESCRIPTION"))
  meta <- read_text(file.path(root, "codemeta.json"))
  readme <- read_text(file.path(root, "README.md"))
  draft_path <- file.path(root, "docs", "ropensci-submission.md")
  draft <- read_text(draft_path)
  block <- extract_description_block(draft)
  if (!identical(block, desc)) {
    problems <- c(problems, "fenced DESCRIPTION does not match DESCRIPTION")
  }
  if (!grepl(ruhila_description, desc, fixed = TRUE)) {
    problems <- c(problems, "DESCRIPTION is missing Ruhila Goswami as ctb")
  }
  if (!grepl(ruhila_description, block, fixed = TRUE)) {
    problems <- c(problems, "submission fence is missing Ruhila Goswami as ctb")
  }
  contributor <- sub("(?s).*\"contributor\":", "", meta, perl = TRUE)
  contributor <- sub("(?s)\"copyrightHolder\".*", "", contributor, perl = TRUE)
  if (!grepl(ruhila_codemeta, contributor, fixed = TRUE)) {
    problems <- c(
      problems,
      "codemeta.json contributor record is missing Ruhila Goswami's ORCID"
    )
  }
  if (!grepl(ruhila_readme, readme, fixed = TRUE)) {
    problems <- c(problems, "README.md is missing Ruhila Goswami's role and ORCID")
  }
  if (!grepl(ruhila_draft, draft, fixed = TRUE)) {
    problems <- c(problems, "submission prose is missing Ruhila Goswami as ctb")
  }
  if (!grepl("0000-0002-5443-9356", draft, fixed = TRUE)) {
    problems <- c(problems, "submission draft is missing Ruhila Goswami's ORCID")
  }
  problems
}

write_submission_description <- function(root) {
  root <- normalizePath(root, mustWork = TRUE)
  draft_path <- file.path(root, "docs", "ropensci-submission.md")
  desc <- read_text(file.path(root, "DESCRIPTION"))
  md <- read_text(draft_path)
  updated <- replace_description_block(md, desc)
  # Write bytes unchanged, including the final newline the file already has.
  writeBin(charToRaw(updated), draft_path)
  problems <- check_submission(root)
  if (length(problems)) {
    stop(paste(problems, collapse = "\n"), call. = FALSE)
  }
  invisible(draft_path)
}

script_root <- function() {
  cmd <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", cmd, value = TRUE)
  if (length(file_arg) != 1L) {
    return(normalizePath("."))
  }
  normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1L])), ".."))
}

if (sys.nframe() == 0L) {
  root <- script_root()
  args <- commandArgs(trailingOnly = TRUE)
  if (identical(args, "--write")) {
    write_submission_description(root)
    cat("rewrote the DESCRIPTION fence in docs/ropensci-submission.md\n")
  } else if (length(args)) {
    stop("usage: Rscript tools/check-submission.R [--write]", call. = FALSE)
  }
  problems <- check_submission(root)
  if (length(problems)) {
    stop(paste(problems, collapse = "\n"), call. = FALSE)
  }
  cat("submission DESCRIPTION matches the file; Ruhila Goswami's record matches\n")
}
