# Copyright (c) d-SEAMS developers
# The rOpenSci draft pastes DESCRIPTION into a fence. This compares that
# fence to the file after normalizing Windows line endings. It checks that
# Ruhila Goswami's role and ORCID match in DESCRIPTION, codemeta.json,
# the draft, and README.md.
#
# This file is installed with the package so tests can source it through
# system.file() when tools/ is not beside the test run. The command line
# is tools/check-submission.R, which sources this file:
#
#   Rscript tools/check-submission.R
#   Rscript tools/check-submission.R --write
#   Rscript tools/check-submission.R --test-log PATH
#
# --write replaces the fenced block with the current DESCRIPTION. The
# check fails when any required file is missing. Every testthat summary
# in cran-comments.md and the draft must show FAIL 0 and WARN 0.
# --test-log (or DSEAMS_TEST_LOG) is the output of a bundled test run:
# its last summary must be that clean line, and it must be the latest
# summary the draft records. That is the last testthat totals line
# after the last "The testthat run inside the bundled check printed".
# The log is matched by bytes, so reader output in it need not be UTF-8.

read_text <- function(path) {
  size <- file.info(path)$size
  if (is.na(size)) {
    stop("missing file: ", path, call. = FALSE)
  }
  # size 0 still needs a defined character value.
  raw <- if (size == 0L) raw(0L) else readBin(path, "raw", n = size)
  txt <- rawToChar(raw)
  Encoding(txt) <- "UTF-8"
  gsub("\r\n", "\n", txt, fixed = TRUE)
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

test_summary_pattern <- "\\[ FAIL [0-9]+ \\| WARN [0-9]+ \\| SKIP [0-9]+ \\| PASS [0-9]+ \\]"

# Each bundled-check record in the draft opens with this sentence.
# The latest record is the last testthat totals line after the last
# copy. The first totals line after an earlier copy is a previous run.
bundled_marker <- "The testthat run inside the bundled check printed"

extract_test_summaries <- function(text) {
  regmatches(text, gregexpr(test_summary_pattern, text, useBytes = TRUE))[[1L]]
}

clean_summary <- function(summary) {
  grepl("^\\[ FAIL 0 \\| WARN 0 \\| ", summary)
}

extract_bundled_summary <- function(md) {
  flat <- gsub("\\s+", " ", md)
  hits <- gregexpr(bundled_marker, flat, fixed = TRUE)[[1L]]
  if (hits[[1L]] < 0L) {
    return(NULL)
  }
  # The last copy of the marker opens the latest record. Totals lines
  # that follow an earlier copy are history, including when the latest
  # record does not repeat the marker and only adds a later totals line.
  idx <- hits[[length(hits)]]
  found <- extract_test_summaries(substring(flat, idx))
  if (length(found) == 0L) {
    return(NULL)
  }
  found[[length(found)]]
}

# A test log can hold bytes that are not UTF-8. Do not mark the string.
read_log_text <- function(path) {
  size <- file.info(path)$size
  if (is.na(size)) {
    stop("missing file: ", path, call. = FALSE)
  }
  raw <- if (size == 0L) raw(0L) else readBin(path, "raw", n = size)
  rawToChar(raw)
}

# cran-comments.md and the rOpenSci draft are plain ASCII. A Unicode
# quotation mark copied out of a check log fails this.
ascii_text <- function(path) {
  size <- file.info(path)$size
  if (is.na(size)) {
    return(FALSE)
  }
  raw <- if (size == 0L) raw(0L) else readBin(path, "raw", n = size)
  !any(as.integer(raw) > 127L)
}

check_submission <- function(root, test_log = NULL) {
  root <- normalizePath(root, mustWork = TRUE)
  problems <- character()
  need <- c(
    "DESCRIPTION",
    "codemeta.json",
    "README.md",
    "cran-comments.md",
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
  comments_path <- file.path(root, "cran-comments.md")
  draft <- read_text(draft_path)
  comments <- read_text(comments_path)
  if (!ascii_text(draft_path)) {
    problems <- c(problems, "docs/ropensci-submission.md is not ASCII")
  }
  if (!ascii_text(comments_path)) {
    problems <- c(problems, "cran-comments.md is not ASCII")
  }
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
  # Every test run either document records passes without warnings.
  for (doc in list(
    list(name = "docs/ropensci-submission.md", text = draft),
    list(name = "cran-comments.md", text = comments)
  )) {
    for (summary in extract_test_summaries(doc$text)) {
      if (!clean_summary(summary)) {
        problems <- c(problems, paste0(
          doc$name, " records a test run with failures or warnings: ", summary
        ))
      }
    }
  }
  if (is.null(test_log)) {
    env_log <- Sys.getenv("DSEAMS_TEST_LOG", unset = "")
    if (nzchar(env_log)) {
      test_log <- env_log
    }
  }
  if (!is.null(test_log) && nzchar(test_log)) {
    found <- extract_test_summaries(read_log_text(test_log))
    if (length(found) == 0L) {
      problems <- c(problems, "test log has no testthat summary line")
    } else {
      log_summary <- found[[length(found)]]
      if (!clean_summary(log_summary)) {
        problems <- c(problems, paste0(
          "test log ends with failures or warnings: ", log_summary
        ))
      }
      draft_summary <- extract_bundled_summary(draft)
      if (is.null(draft_summary)) {
        problems <- c(problems, paste0(
          "docs/ropensci-submission.md has no bundled-check test_check() summary (after \"",
          bundled_marker, "\")"
        ))
      } else if (!identical(charToRaw(draft_summary), charToRaw(log_summary))) {
        problems <- c(problems, paste0(
          "docs/ropensci-submission.md records the bundled check as ",
          draft_summary, "; the test log ends with ", log_summary
        ))
      }
    }
  }
  problems
}

write_submission_description <- function(root) {
  root <- normalizePath(root, mustWork = TRUE)
  draft_path <- file.path(root, "docs", "ropensci-submission.md")
  desc <- read_text(file.path(root, "DESCRIPTION"))
  md <- read_text(draft_path)
  updated <- replace_description_block(md, desc)
  # Keep the draft's final newline and write LF line endings.
  writeBin(charToRaw(updated), draft_path)
  problems <- check_submission(root)
  if (length(problems)) {
    stop(paste(problems, collapse = "\n"), call. = FALSE)
  }
  invisible(draft_path)
}
