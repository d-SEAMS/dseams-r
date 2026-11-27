# Copyright (c) d-SEAMS developers

# R CMD check runs with the working directory set to tests/, and copies
# that directory away from the rest of the source tree. Walk up from both
# places, and from 00_pkg_src, until the symbol script is found. The same
# walk is in test-submission.R. covr has no 00_pkg_src; kept_source_dir()
# is used only when that walk finds nothing.
portability_root <- function() {
  starts <- unique(c(
    normalizePath(testthat::test_path("."), mustWork = FALSE),
    normalizePath(getwd(), mustWork = FALSE),
    normalizePath(testthat::test_path(".."), mustWork = FALSE),
    normalizePath(testthat::test_path("../.."), mustWork = FALSE)
  ))
  for (start in starts) {
    if (!nzchar(start) || !dir.exists(start)) {
      next
    }
    dir <- start
    for (i in seq_len(6L)) {
      helper <- file.path(dir, "tools", "reader-symbols.sh")
      if (file.exists(file.path(dir, "DESCRIPTION")) && file.exists(helper)) {
        return(normalizePath(dir))
      }
      src <- file.path(dir, "00_pkg_src", "dseams")
      src_helper <- file.path(src, "tools", "reader-symbols.sh")
      src_desc <- file.path(src, "DESCRIPTION")
      if (file.exists(src_desc) && file.exists(src_helper)) {
        return(normalizePath(src))
      }
      parent <- dirname(dir)
      if (identical(parent, dir)) {
        break
      }
      dir <- parent
    }
  }
  kept <- kept_source_dir()
  if (length(kept) == 1L && nzchar(kept)) {
    helper <- file.path(kept, "tools", "reader-symbols.sh")
    if (file.exists(file.path(kept, "DESCRIPTION")) && file.exists(helper)) {
      return(normalizePath(kept))
    }
  }
  NULL
}

# Output goes through a file, so system2() returns the exit status rather
# than warning on a non-zero one; the refusal tests expect a failure.
run_capture <- function(cmd, args) {
  log <- tempfile("dseams-run-")
  on.exit(unlink(log), add = TRUE)
  status <- system2(cmd, args, stdout = log, stderr = log)
  out <- if (file.exists(log)) readLines(log) else character()
  list(status = as.integer(status), out = out)
}

read_map <- function(root, format) {
  script <- file.path(root, "tools", "reader-symbols.sh")
  got <- run_capture("sh", c(script, "--print-map", format))
  expect_identical(got$status, 0L, info = paste(got$out, collapse = "\n"))
  lines <- got$out[nzchar(got$out)]
  parts <- strsplit(lines, " ", fixed = TRUE)
  list(
    lines = lines,
    from = vapply(parts, `[[`, "", 1L),
    to = vapply(parts, `[[`, "", 2L)
  )
}

wrapper_symbols <- function(root) {
  lines <- readLines(file.path(root, "src", "dseams_r_io.cpp"), warn = FALSE)
  asm <- character()
  funs <- character()
  vars <- character()
  for (line in lines) {
    m <- regexec("__asm__\\(\"([^\"]+)\"\\)", line)
    g <- regmatches(line, m)[[1L]]
    if (length(g) == 2L) {
      asm <- c(asm, g[[2L]])
    }
    m <- regexec("\\b(dseams_r_[A-Za-z0-9_]+)\\s*\\(", line)
    g <- regmatches(line, m)[[1L]]
    if (length(g) == 2L) {
      funs <- c(funs, g[[2L]])
    }
    m <- regexec("\\b(dseams_r_[A-Za-z0-9_]+)\\s*;", line)
    g <- regmatches(line, m)[[1L]]
    if (length(g) == 2L) {
      vars <- c(vars, g[[2L]])
    }
    m <- regexec("\\(\\*(dseams_r_[A-Za-z0-9_]+)\\)", line)
    g <- regmatches(line, m)[[1L]]
    if (length(g) == 2L) {
      vars <- c(vars, g[[2L]])
    }
  }
  # A use such as `= dseams_r___acrt_iob_func;` matches the semicolon
  # pattern too. A name that is called is a function.
  funs <- unique(funs)
  vars <- setdiff(unique(vars), funs)
  list(asm = unique(asm), funs = funs, vars = vars, lines = lines)
}

defined_wrappers <- function(found) {
  unique(c(found$asm, found$funs, found$vars))
}

test_that("each object format map names every source once", {
  root <- portability_root()
  expect_false(is.null(root))
  for (format in c("elf", "mach-o", "coff")) {
    map <- read_map(root, format)
    expect_gt(length(map$lines), 0L)
    expect_identical(
      anyDuplicated(sub(" .*", "", map$lines)),
      0L,
      info = format
    )
  }
})

test_that("Mach-O targets are the Mach-O names of the wrappers", {
  root <- portability_root()
  expect_false(is.null(root))
  darwin <- read_map(root, "mach-o")
  linux <- read_map(root, "elf")
  windows <- read_map(root, "coff")
  found <- wrapper_symbols(root)
  defined <- defined_wrappers(found)

  # Mach-O does not prefix an asm label, so the iostream targets are the
  # labels themselves. Every other target carries the underscore.
  is_asm <- darwin$to %in% found$asm
  expect_setequal(darwin$to[is_asm], found$asm)
  expect_true(all(startsWith(darwin$to[!is_asm], "_")))
  darwin_names <- ifelse(is_asm, darwin$to, sub("^_", "", darwin$to))
  expect_true(all(darwin_names %in% defined))
  expect_true(all(linux$to %in% defined))
  expect_true(all(windows$to %in% defined))
  expect_setequal(darwin_names, linux$to)

  stdout_target <- sub("^_", "", darwin$to[darwin$from == "___stdoutp"])
  stderr_target <- sub("^_", "", darwin$to[darwin$from == "___stderrp"])
  expect_identical(stdout_target, "dseams_r_stdout")
  expect_identical(stderr_target, "dseams_r_stderr")
  expect_true(stdout_target %in% found$vars)
  expect_true(stderr_target %in% found$vars)
  expect_false(stdout_target %in% found$funs)
  expect_false(stderr_target %in% found$funs)
  expect_false(any(grepl("dseams_r___stdoutp", found$lines, fixed = TRUE)))
  expect_false(any(grepl("dseams_r___stderrp", found$lines, fixed = TRUE)))

  expect_false("printf" %in% darwin$from)
  expect_true("_printf" %in% darwin$from)
  expect_true("printf" %in% linux$from)
  expect_false("__acrt_iob_func" %in% linux$from)
  expect_false("__acrt_iob_func" %in% darwin$from)
  expect_true("__acrt_iob_func" %in% windows$from)
  expect_true("__imp___acrt_iob_func" %in% windows$from)
  expect_identical(
    windows$to[windows$from == "__imp___acrt_iob_func"],
    "dseams_r___imp___acrt_iob_func"
  )
  expect_true("dseams_r___imp___acrt_iob_func" %in% found$vars)
  expect_true("dseams_r___acrt_iob_func" %in% found$funs)
})

# An ar archive of MEMBERS, a named list of raw vectors, in the layout
# the platform archivers write: a GNU archive has a "/" symbol table and a
# "//" name table before the objects, a BSD archive stores each name in
# the member after a "#1/N" header and starts with __.SYMDEF.
write_ar <- function(path, members, bsd = FALSE) {
  pad <- function(x, n) formatC(x, width = -n, flag = "-")
  header <- function(name, size) {
    charToRaw(paste0(
      pad(name, 16L), pad("0", 12L), pad("0", 6L), pad("0", 6L),
      pad("644", 8L), pad(as.character(size), 10L), "`\n"
    ))
  }
  member <- function(name, data) {
    if (bsd) {
      stored <- c(charToRaw(name), as.raw(rep(0L, 8L - nchar(name) %% 8L)))
      body <- c(stored, data)
      out <- c(header(paste0("#1/", length(stored)), length(body)), body)
    } else {
      out <- c(header(name, length(data)), data)
    }
    if (length(out) %% 2L == 1L) c(out, charToRaw("\n")) else out
  }
  bytes <- charToRaw("!<arch>\n")
  if (bsd) {
    bytes <- c(bytes, member("__.SYMDEF SORTED", as.raw(c(0, 0, 0, 0))))
  } else {
    bytes <- c(bytes, member("/", as.raw(c(0, 0, 0, 0))))
    bytes <- c(bytes, member("//", charToRaw("a_long_member_name.o/\n")))
  }
  for (name in names(members)) {
    bytes <- c(bytes, member(if (bsd) name else paste0(name, "/"), members[[name]]))
  }
  writeBin(bytes, path)
  path
}

object_bytes <- function(magic) c(as.raw(strtoi(magic, 16L)), as.raw(rep(0L, 60L)))

# An objcopy that records its arguments, one per line, in LOG.
recording_objcopy <- function(dir, log) {
  stub <- file.path(dir, "objcopy-stub")
  writeLines(c(
    "#!/bin/sh",
    sprintf("for a in \"$@\"; do printf '%%s\\n' \"$a\"; done > '%s'", log)
  ), stub)
  Sys.chmod(stub, "755")
  stub
}

test_that("the symbol map follows the object format of the archive", {
  root <- portability_root()
  expect_false(is.null(root))
  script <- file.path(root, "tools", "reader-symbols.sh")
  dir <- tempfile("dseams-ar-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  log <- file.path(dir, "objcopy.log")
  stub <- recording_objcopy(dir, log)

  cases <- list(
    list(format = "elf", magic = c("7f", "45", "4c", "46"), bsd = FALSE),
    list(format = "mach-o", magic = c("cf", "fa", "ed", "fe"), bsd = TRUE),
    list(format = "mach-o", magic = c("ce", "fa", "ed", "fe"), bsd = FALSE),
    list(format = "coff", magic = c("64", "86", "05", "00"), bsd = FALSE),
    list(format = "coff", magic = c("64", "aa", "02", "00"), bsd = FALSE),
    list(format = "coff", magic = c("00", "00", "ff", "ff"), bsd = FALSE)
  )
  for (case in cases) {
    info <- paste(case$format, paste(case$magic, collapse = ""))
    archive <- write_ar(
      file.path(dir, "lib.a"),
      list(reader.o = object_bytes(case$magic)),
      bsd = case$bsd
    )
    got <- run_capture("sh", c(script, "--format", archive))
    expect_identical(got$status, 0L, info = info)
    expect_identical(got$out, case$format, info = info)

    unlink(log)
    got <- run_capture("sh", c(script, stub, archive))
    expect_identical(got$status, 0L, info = paste(c(info, got$out), collapse = "\n"))
    args <- readLines(log)
    expect_identical(args[[length(args)]], archive, info = info)
    pairs <- args[which(args == "--redefine-sym") + 1L]
    map <- read_map(root, case$format)
    expect_identical(pairs, paste0(map$from, "=", map$to), info = info)
  }

  # The first object decides; a member with no object magic is passed over.
  archive <- write_ar(
    file.path(dir, "mixed.a"),
    list(
      notes.txt = charToRaw("not an object\n"),
      reader.o = object_bytes(c("cf", "fa", "ed", "fe")),
      other.o = object_bytes(c("7f", "45", "4c", "46"))
    )
  )
  got <- run_capture("sh", c(script, "--format", archive))
  expect_identical(got$out, "mach-o")
})

test_that("an archive with no object member is refused", {
  root <- portability_root()
  expect_false(is.null(root))
  script <- file.path(root, "tools", "reader-symbols.sh")
  dir <- tempfile("dseams-ar-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  log <- file.path(dir, "objcopy.log")
  stub <- recording_objcopy(dir, log)

  archive <- write_ar(file.path(dir, "lib.a"), list(notes.txt = charToRaw("text\n")))
  got <- run_capture("sh", c(script, stub, archive))
  expect_false(identical(got$status, 0L))
  expect_true(any(grepl("has no ELF, Mach-O or COFF member", got$out, fixed = TRUE)))
  expect_false(file.exists(log))

  not_ar <- file.path(dir, "plain.o")
  writeBin(object_bytes(c("7f", "45", "4c", "46")), not_ar)
  got <- run_capture("sh", c(script, "--format", not_ar))
  expect_false(identical(got$status, 0L))
  expect_true(any(grepl("is not an ar archive", got$out, fixed = TRUE)))
})

# The floor tools/chemfiles-cmake-floor.py writes: CMake 4 refuses a
# minimum below 3.5, and CMake 3.31 warns below a policy version of 3.10.
cmake_floor_problems <- function(text, where) {
  calls <- regmatches(
    text,
    gregexpr("cmake_minimum_required\\s*\\([^)]*\\)", text,
      ignore.case = TRUE, perl = TRUE
    )
  )[[1L]]
  bad <- character()
  pattern <- paste0(
    "^cmake_minimum_required\\s*\\(\\s*VERSION\\s+([0-9]+(?:\\.[0-9]+)*)",
    "(?:\\.\\.\\.([0-9]+(?:\\.[0-9]+)*))?(?:\\s+FATAL_ERROR)?\\s*\\)$"
  )
  for (call in calls) {
    m <- regmatches(call, regexec(pattern, call, ignore.case = TRUE, perl = TRUE))[[1L]]
    if (length(m) != 3L) {
      bad <- c(bad, paste0(where, ": cannot parse ", call))
      next
    }
    low <- numeric_version(m[[2L]])
    policy <- if (nzchar(m[[3L]])) numeric_version(m[[3L]]) else low
    if (low < "3.5" || policy < "3.10") {
      bad <- c(bad, paste0(where, ": ", call))
    }
  }
  list(n = length(calls), bad = bad)
}

is_cmake_file <- function(path) {
  base <- basename(path)
  base == "CMakeLists.txt" | endsWith(base, ".cmake")
}

# The regular files of a .tar.gz whose names pass keep(), as a named list
# of raw vectors. utils::untar() runs the system tar, and Windows tar.exe
# exits 1 on the UTF-8 member name tests/data/<Cyrillic>.xml in
# pugixml.tar.gz; R's internal tar warns on every pax header. This reads
# ustar headers, pax "x" path records and GNU "L" long names itself.
tar_gz_members <- function(tarball, keep) {
  con <- gzfile(tarball, "rb")
  chunks <- list()
  repeat {
    chunk <- readBin(con, "raw", n = 1048576L)
    if (length(chunk) == 0L) {
      break
    }
    chunks[[length(chunks) + 1L]] <- chunk
  }
  close(con)
  bytes <- do.call(c, chunks)
  field <- function(block, from, len) {
    x <- block[from:(from + len - 1L)]
    end <- match(as.raw(0L), x, nomatch = len + 1L)
    rawToChar(x[seq_len(end - 1L)])
  }
  utf8 <- function(x) {
    Encoding(x) <- "UTF-8"
    x
  }
  out <- list()
  long_name <- NULL
  pos <- 0L
  while (pos + 512L <= length(bytes)) {
    block <- bytes[pos + seq_len(512L)]
    if (all(block == as.raw(0L))) {
      break
    }
    size <- strtoi(trimws(field(block, 125L, 12L)), base = 8L)
    stopifnot(!is.na(size))
    type <- field(block, 157L, 1L)
    data <- bytes[pos + 512L + seq_len(size)]
    pos <- pos + 512L + 512L * ((size + 511L) %/% 512L)
    if (type == "x") {
      records <- strsplit(rawToChar(data), "\n", fixed = TRUE)[[1L]]
      path <- grep("^[0-9]+ path=", records, value = TRUE, useBytes = TRUE)
      if (length(path)) {
        long_name <- utf8(sub("^[0-9]+ path=", "", path[[1L]], useBytes = TRUE))
      }
      next
    }
    if (type == "L") {
      long_name <- utf8(field(data, 1L, size))
      next
    }
    if (type == "g") {
      next
    }
    name <- long_name
    long_name <- NULL
    if (is.null(name)) {
      name <- utf8(field(block, 1L, 100L))
      prefix <- field(block, 346L, 155L)
      if (identical(field(block, 258L, 5L), "ustar") && nzchar(prefix)) {
        name <- utf8(paste0(prefix, "/", name))
      }
    }
    if (type %in% c("0", "", "7") && keep(name)) {
      out[[name]] <- data
    }
  }
  out
}

test_that("every vendored chemfiles CMake file meets the CMake 4 floor", {
  root <- portability_root()
  expect_false(is.null(root))
  chem <- file.path(root, "src", "chemfiles")
  expect_true(file.exists(file.path(chem, "CMakeLists.txt")))

  seen <- 0L
  bad <- character()
  files <- list.files(chem, recursive = TRUE, full.names = TRUE, all.files = TRUE)
  for (path in files[is_cmake_file(files)]) {
    got <- cmake_floor_problems(
      paste(readLines(path, warn = FALSE), collapse = "\n"),
      substring(path, nchar(chem) + 2L)
    )
    seen <- seen + got$n
    bad <- c(bad, got$bad)
  }
  tarballs <- list.files(file.path(chem, "external"), "\\.tar\\.gz$", full.names = TRUE)
  expect_gt(length(tarballs), 0L)
  for (tarball in tarballs) {
    members <- tar_gz_members(tarball, is_cmake_file)
    for (member in names(members)) {
      con <- rawConnection(members[[member]])
      text <- paste(readLines(con, warn = FALSE), collapse = "\n")
      close(con)
      got <- cmake_floor_problems(text, paste0(basename(tarball), ":", member))
      seen <- seen + got$n
      bad <- c(bad, got$bad)
    }
  }
  expect_gt(seen, 0L)
  expect_identical(bad, character(), info = paste(bad, collapse = "\n"))
})

# src/chemfiles is not installed. When the source tree is present these
# tests check the MinGW and libc++ paths develop takes in the bundled
# chemfiles: tools/chemfiles-molfiles.py adds <type_traits> to MMTF.cpp
# and selects gnu++11 under MinGW, and Makevars.win passes -include
# intrin.h and -DDESRES_WIN32. An installed package is checked by reading
# the water those readers decode. tools/readers holds tiny.mae and
# tiny.mmtf; vendor-readers.sh copies them into inst/extdata, and the
# same files sit beside this test for an install whose extdata predates
# that copy. The geometry is tools/readers/tiny.pdb.
reader_water <- function(name) {
  shipped <- system.file("extdata", name, package = "dseams")
  path <- if (nzchar(shipped)) shipped else testthat::test_path(name)
  expect_true(file.exists(path), info = name)
  path
}

expect_one_water <- function(path) {
  expect_identical(nframes(path), 1L, label = path)
  xyz <- unname(positions(read_frame(path, type = -1L)))
  expect_equal(
    xyz,
    rbind(c(0, 0, 0), c(0.957, 0, 0), c(-0.24, 0.927, 0)),
    tolerance = 1e-5,
    label = path
  )
}

read_text <- function(path) {
  expect_true(file.exists(path), info = path)
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

test_that("every chemfiles source reaching mmtf-cpp includes type_traits first", {
  root <- portability_root()
  if (!is.null(root)) {
    src <- file.path(root, "src", "chemfiles", "src")
    files <- list.files(src, pattern = "\\.cpp$", recursive = TRUE, full.names = TRUE)
    # msgpack-c, inside mmtf-cpp, uses std::remove_volatile without
    # including <type_traits>. MMTF.hpp includes mmtf/structure_data.hpp.
    reach <- "#include <mmtf/|#include \"chemfiles/formats/MMTF.hpp\""
    users <- character()
    for (path in files) {
      text <- read_text(path)
      first <- regexpr(reach, text)
      if (first < 0L) {
        next
      }
      users <- c(users, basename(path))
      traits <- regexpr("#include <type_traits>", text, fixed = TRUE)
      expect_gt(traits, 0L, label = basename(path))
      expect_gt(first, traits, label = basename(path))
    }
    expect_setequal(users, c("MMTF.cpp", "FormatFactory.cpp"))
  }
  expect_one_water(reader_water("tiny.mmtf"))
})

test_that("the Windows chemfiles build takes the MinGW paths", {
  root <- portability_root()
  if (!is.null(root)) {
    mk <- readLines(file.path(root, "src", "Makevars.win"), warn = FALSE)
    cflags <- grep("-DCMAKE_C_FLAGS=", mk, fixed = TRUE, value = TRUE)
    cxxflags <- grep("-DCMAKE_CXX_FLAGS=", mk, fixed = TRUE, value = TRUE)
    expect_length(cflags, 1L)
    expect_length(cxxflags, 1L)
    expect_true(grepl("-include intrin.h", cflags, fixed = TRUE))
    expect_true(grepl("-DDESRES_WIN32", cxxflags, fixed = TRUE))
    flags <- read_text(file.path(root, "src", "chemfiles", "cmake", "CompilerFlags.cmake"))
    mingw <- paste(
      "if(MINGW)",
      "    set(CMAKE_CXX_EXTENSIONS ON)",
      "    set(CHFL_CXX11_FLAG \"-std=gnu++11\")",
      sep = "\n"
    )
    expect_true(grepl(mingw, flags, fixed = TRUE))
  }
  expect_one_water(reader_water("tiny.mae"))
})

# tools/chemfiles-lf-headers.py. Without NEWLINE_STYLE, configure_file()
# writes config.h and exports.h with CRLF on Windows, and R CMD check
# reports them under src/chemfiles-install. That directory exists only
# after a bundled install in the same tree, as in R CMD check's
# 00_pkg_src.
test_that("chemfiles writes its generated headers with LF line endings", {
  root <- portability_root()
  expect_false(is.null(root))
  chem <- file.path(root, "src", "chemfiles")
  text <- paste(readLines(file.path(chem, "CMakeLists.txt"), warn = FALSE), collapse = "\n")
  config <- paste(
    "configure_file (",
    "  \"${PROJECT_SOURCE_DIR}/include/chemfiles/config.in.h\"",
    "  \"${PROJECT_BINARY_DIR}/include/chemfiles/config.h\"",
    "  NEWLINE_STYLE LF",
    ")",
    sep = "\n"
  )
  exports <- paste(
    "    EXPORT_FILE_NAME ${PROJECT_BINARY_DIR}/exports.h.in",
    ")",
    "configure_file(",
    "  \"${PROJECT_BINARY_DIR}/exports.h.in\"",
    "  \"${PROJECT_BINARY_DIR}/include/chemfiles/exports.h\"",
    "  @ONLY NEWLINE_STYLE LF",
    ")",
    sep = "\n"
  )
  expect_true(grepl(config, text, fixed = TRUE))
  expect_true(grepl(exports, text, fixed = TRUE))
  installed <- file.path(root, "src", "chemfiles-install", "include", "chemfiles")
  for (name in c("config.h", "exports.h")) {
    path <- file.path(installed, name)
    if (file.exists(path)) {
      bytes <- readBin(path, "raw", file.info(path)$size)
      expect_false(any(bytes == as.raw(13L)), info = path)
    }
  }
})

test_that("bundled readers are compiled with NDEBUG", {
  root <- portability_root()
  expect_false(is.null(root))
  cmake_flags <- c(
    "-DCMAKE_C_FLAGS=",
    "-DCMAKE_CXX_FLAGS=",
    "-DCMAKE_C_FLAGS_RELEASE=",
    "-DCMAKE_CXX_FLAGS_RELEASE="
  )
  flags <- c(
    "-DCHFL_SYSTEM_LZMA=OFF",
    "CARGO_PROFILE_RELEASE_DEBUG=false",
    "CARGO_PROFILE_RELEASE_DEBUG_ASSERTIONS=false",
    "CARGO_PROFILE_RELEASE_OVERFLOW_CHECKS=false",
    "CFLAGS=\"$(CFLAGS) -DNDEBUG\""
  )
  for (name in c("src/Makevars.in", "src/Makevars.win")) {
    lines <- readLines(file.path(root, name), warn = FALSE)
    text <- paste(lines, collapse = "\n")
    # Makevars.win adds Windows flags before -DNDEBUG on some lines.
    for (key in cmake_flags) {
      line <- grep(paste0(key, "\""), lines, fixed = TRUE, value = TRUE)
      expect_length(line, 1L)
      expect_true(grepl("-DNDEBUG\"", line, fixed = TRUE), info = paste(name, key))
    }
    for (flag in flags) {
      expect_true(grepl(flag, text, fixed = TRUE), info = paste(name, flag))
    }
    expect_false(grepl("readcon-apple-builtins.sh", text, fixed = TRUE))
  }
  cargo <- paste(
    readLines(file.path(root, "tools/readcon-Cargo.toml"), warn = FALSE),
    collapse = "\n"
  )
  expect_true(grepl("debug = false", cargo, fixed = TRUE))
  expect_true(grepl("debug-assertions = false", cargo, fixed = TRUE))
  expect_true(grepl("overflow-checks = false", cargo, fixed = TRUE))
  expect_false(grepl("readcon-apple-builtins.sh", cargo, fixed = TRUE))
})

test_that("rustc's staticlib licences are listed", {
  root <- portability_root()
  expect_false(is.null(root))
  authors <- paste(
    readLines(file.path(root, "inst/AUTHORS"), warn = FALSE),
    collapse = "\n"
  )
  note <- paste(
    readLines(file.path(root, "LICENSE.note"), warn = FALSE),
    collapse = "\n"
  )
  names <- c(
    "Rust standard library",
    "compiler_builtins 0.1.160",
    "compiler-rt",
    "addr2line 0.27.1",
    "gimli 0.34.0",
    "hashbrown 0.17.1",
    "object 0.39.1",
    "rustc-demangle 0.1.28",
    "libm",
    "Crossbeam Project Developers",
    "Unicode, Inc",
    "windows-link"
  )
  for (name in names) {
    expect_true(grepl(name, authors, fixed = TRUE), info = paste("AUTHORS", name))
    expect_true(grepl(name, note, fixed = TRUE), info = paste("LICENSE.note", name))
  }
  texts <- c(
    "inst/licenses/readcon-sysroot/rust-LICENSE-MIT",
    "inst/licenses/readcon-sysroot/rust-LICENSE-APACHE",
    "inst/licenses/readcon-sysroot/Unicode-3.0.txt",
    "inst/licenses/readcon-sysroot/compiler-builtins-LICENSE.txt",
    "inst/licenses/readcon-sysroot/compiler-rt-LICENSE.TXT",
    "inst/licenses/readcon-sysroot/compiler-rt-CREDITS.TXT",
    "inst/licenses/readcon-sysroot/libm-LICENSE.txt",
    "inst/licenses/readcon-sysroot/addr2line-LICENSE-MIT",
    "inst/licenses/readcon-sysroot/addr2line-LICENSE-APACHE",
    "inst/licenses/readcon-sysroot/gimli-LICENSE-MIT",
    "inst/licenses/readcon-sysroot/gimli-LICENSE-APACHE",
    "inst/licenses/readcon-sysroot/hashbrown-LICENSE-MIT",
    "inst/licenses/readcon-sysroot/hashbrown-LICENSE-APACHE",
    "inst/licenses/readcon-sysroot/object-LICENSE-MIT",
    "inst/licenses/readcon-sysroot/object-LICENSE-APACHE",
    "inst/licenses/readcon-sysroot/rustc-demangle-LICENSE-MIT",
    "inst/licenses/readcon-sysroot/rustc-demangle-LICENSE-APACHE"
  )
  for (path in texts) {
    expect_true(file.exists(file.path(root, path)), info = path)
    expect_true(grepl(path, note, fixed = TRUE), info = path)
  }
})

engine_object_names <- function(path) {
  lines <- readLines(path, warn = FALSE)
  hits <- grep("^[[:space:]]*seams/[A-Za-z0-9_]+\\.o", lines, value = TRUE)
  sub("^[[:space:]]*seams/([A-Za-z0-9_]+)\\.o.*", "\\1", hits)
}

vendored_sentinel_lines <- function(root) {
  got <- run_capture("sh", c(file.path(root, "tools", "vendored-tree.sh"), "--list"))
  expect_identical(got$status, 0L, info = paste(got$out, collapse = "\n"))
  raw <- readLines(file.path(root, "tools", "vendored-sentinels"), warn = FALSE)
  raw <- sub("\r$", "", raw)
  raw <- raw[nzchar(raw) & !startsWith(raw, "#")]
  expect_identical(got$out, raw)
  raw
}

run_in <- function(dir, script) {
  log <- tempfile("dseams-cfg-")
  old <- getwd()
  # The temp tree is a bundled configure. A linked R CMD check exports
  # SEAMS_LIBDIR and DSEAMS_ROOT, and configure would then link instead
  # of applying the bundled checksum rule this test reads.
  link_vars <- c(
    "SEAMS_LIBDIR", "SEAMS_INCLUDE", "SEAMS_H_DIR", "SEAMS_SO_DIR",
    "DSEAMS_SYSTEM_ENGINE", "DSEAMS_ROOT"
  )
  saved <- Sys.getenv(link_vars, unset = NA_character_)
  Sys.unsetenv(link_vars)
  on.exit(
    {
      setwd(old)
      unlink(log)
      missing <- is.na(saved)
      if (any(!missing)) {
        do.call(Sys.setenv, as.list(saved[!missing]))
      }
      if (any(missing)) {
        Sys.unsetenv(link_vars[missing])
      }
    },
    add = TRUE
  )
  setwd(dir)
  # system2 passes each argument as one word. A shell command string
  # would split, so the script is named and the working directory is
  # the tree under test.
  status <- system2("sh", script, stdout = log, stderr = log)
  out <- if (file.exists(log)) readLines(log, warn = FALSE) else character()
  list(status = as.integer(status), out = out)
}

plant_sentinels <- function(base, listed) {
  for (path in listed) {
    rel <- sub("/$", "", path)
    dest <- file.path(base, rel)
    unlink(dest, recursive = TRUE)
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    if (endsWith(path, "/")) {
      dir.create(dest, recursive = TRUE, showWarnings = FALSE)
    } else {
      writeLines("x", dest)
    }
  }
}

write_vendor_stub <- function(base) {
  writeLines(
    c(
      "#!/bin/sh",
      "printf '%s\\n' invoked >> tools/vendor-invoked",
      "exit 0"
    ),
    file.path(base, "tools", "vendor.sh")
  )
}

vendor_was_invoked <- function(base) {
  file.exists(file.path(base, "tools", "vendor-invoked"))
}

clear_vendor_marker <- function(base) {
  unlink(file.path(base, "tools", "vendor-invoked"))
}

copy_configure_scripts <- function(root, base) {
  dir.create(file.path(base, "tools"), recursive = TRUE, showWarnings = FALSE)
  rels <- c(
    "configure",
    "configure.win",
    "tools/ensure-vendored.sh",
    "tools/vendored-tree.sh",
    "tools/vendored-sentinels",
    "tools/bundled-tools.sh"
  )
  for (rel in rels) {
    ok <- file.copy(file.path(root, rel), file.path(base, rel), overwrite = TRUE)
    expect_true(ok, info = rel)
  }
  writeLines(c("Package: dseams", "Version: 0.0.0"), file.path(base, "DESCRIPTION"))
}

test_that("configure and configure.win read one vendored sentinel list", {
  root <- portability_root()
  expect_false(is.null(root))
  listed <- vendored_sentinel_lines(root)
  expect_gt(length(listed), 0L)
  expect_true(any(endsWith(listed, "/")))
  expect_true("src/readcon-core/Cargo.toml" %in% listed)
  expect_true("src/chemfiles/src/Trajectory.cpp" %in% listed)
  expect_true("inst/extdata/tiny.pdb" %in% listed)
  unix <- readLines(file.path(root, "configure"), warn = FALSE)
  win <- readLines(file.path(root, "configure.win"), warn = FALSE)
  expect_true(any(grepl(
    "sh tools/ensure-vendored.sh configure",
    unix,
    fixed = TRUE
  )))
  expect_true(any(grepl(
    "sh tools/ensure-vendored.sh configure.win",
    win,
    fixed = TRUE
  )))
  expect_true(any(grepl(
    "sh tools/vendored-tree.sh --require-checksum configure",
    unix,
    fixed = TRUE
  )))
  expect_true(any(grepl(
    "sh tools/vendored-tree.sh --require-checksum configure.win",
    win,
    fixed = TRUE
  )))
  for (path in listed) {
    expect_false(any(grepl(path, unix, fixed = TRUE)), info = path)
    expect_false(any(grepl(path, win, fixed = TRUE)), info = path)
  }
  in_objs <- engine_object_names(file.path(root, "src", "Makevars.in"))
  win_objs <- engine_object_names(file.path(root, "src", "Makevars.win"))
  expect_gt(length(in_objs), 0L)
  expect_identical(in_objs, win_objs)
  quoted <- 'reader-symbols.sh "$(OBJCOPY)" "$@"'
  for (name in c("Makevars.in", "Makevars.win")) {
    lines <- readLines(file.path(root, "src", name), warn = FALSE)
    expect_identical(sum(grepl(quoted, lines, fixed = TRUE)), 2L, info = name)
  }
})

test_that("each missing vendored sentinel makes both configure scripts vendor", {
  root <- portability_root()
  expect_false(is.null(root))
  listed <- vendored_sentinel_lines(root)
  base <- tempfile("dseams-vendor-")
  dir.create(base)
  on.exit(unlink(base, recursive = TRUE), add = TRUE)
  copy_configure_scripts(root, base)
  write_vendor_stub(base)
  plant_sentinels(base, listed)

  for (script in c("configure", "configure.win")) {
    clear_vendor_marker(base)
    got <- run_in(base, script)
    expect_false(any(grepl("cannot open", got$out, fixed = TRUE)), info = script)
    expect_false(vendor_was_invoked(base), info = paste(script, paste(got$out, collapse = "\n")))
    expect_false(any(listed %in% got$out), info = script)
  }
  expect_true(any(grepl(
    "configure: src/readcon-core/vendor is missing; the source package has no vendored crates",
    run_in(base, "configure")$out,
    fixed = TRUE
  )))

  for (path in listed) {
    plant_sentinels(base, listed)
    unlink(file.path(base, sub("/$", "", path)), recursive = TRUE)
    expect_false(file.exists(file.path(base, sub("/$", "", path))))
    for (script in c("configure", "configure.win")) {
      write_vendor_stub(base)
      clear_vendor_marker(base)
      got <- run_in(base, script)
      others <- setdiff(listed, path)
      expect_true(vendor_was_invoked(base), info = paste(script, path, paste(got$out, collapse = "\n")))
      expect_true(path %in% got$out, info = paste(script, path, paste(got$out, collapse = "\n")))
      expect_false(any(others %in% got$out), info = paste(script, path))
    }
  }

  dirs <- listed[endsWith(listed, "/")]
  expect_gt(length(dirs), 0L)
  for (path in dirs) {
    plant_sentinels(base, listed)
    rel <- sub("/$", "", path)
    unlink(file.path(base, rel), recursive = TRUE)
    writeLines("not-a-directory", file.path(base, rel))
    for (script in c("configure", "configure.win")) {
      write_vendor_stub(base)
      clear_vendor_marker(base)
      got <- run_in(base, script)
      expect_true(vendor_was_invoked(base), info = paste(script, path))
      expect_true(path %in% got$out, info = paste(script, path, paste(got$out, collapse = "\n")))
    }
  }

  plant_sentinels(base, listed)
  dir.create(file.path(base, "src"), showWarnings = FALSE)
  writeLines(
    "SEAMS_LANG_VERSION='\"9.9.9\"'",
    file.path(base, "src", "Makevars.win")
  )
  clear_vendor_marker(base)
  bad <- run_in(base, "configure.win")
  expect_false(vendor_was_invoked(base))
  expect_true(any(grepl(
    "configure.win: src/Makevars.win does not carry version 0.0.0",
    bad$out,
    fixed = TRUE
  )), info = paste(bad$out, collapse = "\n"))

  writeLines(
    "SEAMS_LANG_VERSION='\"0.0.0\"'",
    file.path(base, "src", "Makevars.win")
  )
  clear_vendor_marker(base)
  good <- run_in(base, "configure.win")
  expect_false(vendor_was_invoked(base))
  expect_false(any(grepl("does not carry version", good$out, fixed = TRUE)))
})

test_that("the CMake floor check rejects the minimums chemfiles shipped", {
  for (call in c(
    "cmake_minimum_required(VERSION 2.8.12)",
    "cmake_minimum_required(VERSION 3.4)",
    "cmake_minimum_required(VERSION 3.5 FATAL_ERROR)",
    "cmake_minimum_required(VERSION 3.5...3.9)",
    "cmake_minimum_required(${MIN})"
  )) {
    expect_length(cmake_floor_problems(call, "x")$bad, 1L)
  }
  for (call in c(
    "cmake_minimum_required(VERSION 3.5...3.10)",
    "cmake_minimum_required(VERSION 3.5...3.10 FATAL_ERROR)",
    "cmake_minimum_required(VERSION 3.15)"
  )) {
    expect_length(cmake_floor_problems(call, "x")$bad, 0L)
  }
})

plant_header_package <- function(authors, note, header) {
  base <- tempfile("dseams-authors-")
  dir.create(file.path(base, "src", "chemfiles", "external"), recursive = TRUE)
  dir.create(file.path(base, "src", "readcon-core", "vendor"), recursive = TRUE)
  dir.create(file.path(base, "src", "seams"), recursive = TRUE)
  writeLines(
    c(
      "Package: toy",
      "Authors@R: c(",
      authors,
      "    )",
      "Description: toy"
    ),
    file.path(base, "DESCRIPTION")
  )
  writeLines(note, file.path(base, "LICENSE.note"))
  writeLines(header, file.path(base, "src", "seams", "sample.c"))
  base
}

test_that("a header author missing from Authors@R and LICENSE.note fails the check", {
  python <- Sys.which("python3")
  expect_true(nzchar(python))
  root <- portability_root()
  expect_false(is.null(root))
  script <- file.path(root, "tools", "check-header-authors.py")
  header <- "/* VTF plugin by Zora Quill */"
  covered <- plant_header_package(
    "    person(\"Zora\", \"Quill\", role = \"ctb\")",
    "nothing else",
    header
  )
  got <- run_capture(python, c(script, covered))
  expect_identical(got$status, 0L, info = paste(got$out, collapse = "\n"))

  noted <- plant_header_package(
    "    person(\"Other\", \"Person\", role = \"ctb\")",
    "The sample is by Zora Quill.",
    header
  )
  got <- run_capture(python, c(script, noted))
  expect_identical(got$status, 0L, info = paste(got$out, collapse = "\n"))

  bare <- plant_header_package(
    "    person(\"Other\", \"Person\", role = \"ctb\")",
    "no author of the sample is named here",
    header
  )
  got <- run_capture(python, c(script, bare))
  expect_identical(got$status, 1L, info = paste(got$out, collapse = "\n"))
  text <- paste(got$out, collapse = "\n")
  expect_true(grepl("sample.c", text, fixed = TRUE))
  expect_true(grepl("Zora", text, fixed = TRUE))
  expect_true(grepl("Quill", text, fixed = TRUE))

  empty <- tempfile("dseams-authors-empty-")
  dir.create(empty)
  got <- run_capture(python, c(script, empty))
  expect_identical(got$status, 2L, info = paste(got$out, collapse = "\n"))

  real <- run_capture(python, c(script, root))
  expect_identical(real$status, 0L, info = paste(real$out, collapse = "\n"))
  expect_true(any(grepl(
    "header authors are named in Authors@R or LICENSE.note",
    real$out,
    fixed = TRUE
  )))
})

test_that("the license field names the vendored restrictions", {
  root <- portability_root()
  expect_false(is.null(root))
  desc <- read.dcf(file.path(root, "DESCRIPTION"))
  expect_identical(unname(desc[, "License"]), "MIT + file LICENSE")
  expect_identical(unname(desc[, "License_restricts_use"]), "yes")
  expect_true(grepl("Olaf", desc[, "Authors@R"], fixed = TRUE))
  expect_true(grepl("Lenz", desc[, "Authors@R"], fixed = TRUE))
  expect_true(grepl("Henri", desc[, "Authors@R"], fixed = TRUE))
  expect_true(grepl("Menke", desc[, "Authors@R"], fixed = TRUE))
  licence <- paste(readLines(file.path(root, "LICENSE"), warn = FALSE), collapse = "\n")
  expect_true(grepl("abinitplugin.c", licence, fixed = TRUE))
  expect_true(grepl("ply.c", licence, fixed = TRUE))
  expect_true(grepl("ply.h", licence, fixed = TRUE))
  expect_true(grepl("closed-source", licence, fixed = TRUE))
  expect_true(grepl("not sold", licence, fixed = TRUE))
  expect_true(grepl("LICENSE.note", licence, fixed = TRUE))
  info <- tools:::analyze_license(desc[, "License"])
  expect_true(info$is_canonical)
  expect_true(info$is_standardizable)
  expect_identical(
    tools:::`.license_component_is_for_stub_and_ok`(
      "MIT + file LICENSE",
      root
    ),
    0L
  )
  expect_length(tools:::.check_package_license(file.path(root, "DESCRIPTION")), 0L)
  parsed <- utils:::.read_authors_at_R_field(desc[, "Authors@R"])
  expect_true(any(grepl("Olaf", parsed$given, fixed = TRUE)))
  expect_true(any(grepl("Lenz", parsed$family, fixed = TRUE)))
})

test_that("a kept srcref names the source tree the portability checks read", {
  root <- portability_root()
  expect_false(is.null(root))
  got <- kept_source_dir()
  # One result either way: no srcref leaves the walk in place, and a srcref
  # names that same tree. The expectation count does not depend on which.
  expect_true(
    length(got) == 0L || identical(normalizePath(got, mustWork = TRUE), root)
  )
})
