# Copyright (c) d-SEAMS developers

# R CMD check runs with the working directory set to tests/, and copies
# that directory away from the rest of the source tree. Walk up from both
# places, and from 00_pkg_src, until the symbol script is found. The same
# walk is in test-submission.R.
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
  NULL
}

run_capture <- function(cmd, args) {
  out <- system2(cmd, args, stdout = TRUE, stderr = TRUE)
  status <- attr(out, "status")
  if (is.null(status)) {
    status <- 0L
  }
  list(status = as.integer(status), out = out)
}

read_map <- function(root, system_name) {
  script <- file.path(root, "tools", "reader-symbols.sh")
  got <- run_capture("sh", c(script, "--print-map", system_name))
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

test_that("each platform map names every source once", {
  root <- portability_root()
  expect_false(is.null(root))
  for (system_name in c("Linux", "Darwin", "Windows_NT")) {
    map <- read_map(root, system_name)
    expect_gt(length(map$lines), 0L)
    expect_identical(
      anyDuplicated(sub(" .*", "", map$lines)),
      0L,
      info = system_name
    )
  }
})

test_that("Darwin targets are the Mach-O names of the wrappers", {
  root <- portability_root()
  expect_false(is.null(root))
  darwin <- read_map(root, "Darwin")
  linux <- read_map(root, "Linux")
  windows <- read_map(root, "Windows_NT")
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
    members <- utils::untar(tarball, list = TRUE)
    members <- members[is_cmake_file(members)]
    if (length(members) == 0L) {
      next
    }
    dir <- tempfile("cmake-floor-")
    utils::untar(tarball, files = members, exdir = dir)
    for (member in members) {
      got <- cmake_floor_problems(
        paste(readLines(file.path(dir, member), warn = FALSE), collapse = "\n"),
        paste0(basename(tarball), ":", member)
      )
      seen <- seen + got$n
      bad <- c(bad, got$bad)
    }
    unlink(dir, recursive = TRUE)
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

test_that("the MMTF reader includes type_traits before mmtf-cpp", {
  root <- portability_root()
  if (!is.null(root)) {
    text <- read_text(file.path(root, "src", "chemfiles", "src", "formats", "MMTF.cpp"))
    traits <- regexpr("#include <type_traits>", text, fixed = TRUE)
    mmtf <- regexpr("#include <mmtf/", text, fixed = TRUE)
    expect_gt(traits, 0L)
    expect_gt(mmtf, traits)
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
    "CFLAGS=\"$(CFLAGS) -DNDEBUG\"",
    "sh ../tools/readcon-apple-builtins.sh"
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
  }
  cargo <- paste(
    readLines(file.path(root, "tools/readcon-Cargo.toml"), warn = FALSE),
    collapse = "\n"
  )
  expect_true(grepl("debug = false", cargo, fixed = TRUE))
  expect_true(grepl("debug-assertions = false", cargo, fixed = TRUE))
  expect_true(grepl("overflow-checks = false", cargo, fixed = TRUE))
  script <- readLines(
    file.path(root, "tools/readcon-apple-builtins.sh"),
    warn = FALSE
  )
  body <- paste(script, collapse = "\n")
  expect_true(grepl("abort();", body, fixed = TRUE))
  expect_false(any(grepl("objcopy", script, fixed = TRUE)))
  expect_false(any(grepl("___assert_rtn=", script, fixed = TRUE)))
})

test_that("compiler-rt ___assert_rtn is replaced and another assert is not", {
  root <- portability_root()
  expect_false(is.null(root))
  # R CMD check puts a fake R on PATH that exits. The real binary is
  # under R.home("bin").
  cc <- system2(
    file.path(R.home("bin"), "R"),
    c("CMD", "config", "CC"),
    stdout = TRUE
  )
  expect_length(cc, 1L)
  expect_true(nzchar(cc))
  # system2 splits an argument on spaces, so the compiler and its flags
  # are separate arguments. CC is exported for the script, which splits
  # that value itself.
  cc_parts <- strsplit(cc, "[[:space:]]+")[[1L]]
  # R CMD check does not always keep the compiler's directory on PATH.
  # R CMD config CC is the bare name; the conda toolchain sits next to R.
  if (!file.exists(cc_parts[[1L]])) {
    found <- Sys.which(cc_parts[[1L]])
    if (!nzchar(found)) {
      found <- file.path(dirname(dirname(R.home())), "bin", cc_parts[[1L]])
    }
    cc_parts[[1L]] <- found
  }
  expect_true(file.exists(cc_parts[[1L]]), info = cc_parts[[1L]])
  dir <- tempfile("compilerrt-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  old_cc <- Sys.getenv("CC", unset = NA_character_)
  on.exit(
    if (is.na(old_cc)) Sys.unsetenv("CC") else Sys.setenv(CC = old_cc),
    add = TRUE
  )
  Sys.setenv(CC = cc)
  writeLines(
    "void dseams_probe_symbol(void) {}\n",
    file.path(dir, "probe.c")
  )
  probe <- file.path(dir, "probe.o")
  got <- run_capture(cc_parts[[1L]], c(
    cc_parts[-1L],
    "-c",
    "-O2",
    file.path(dir, "probe.c"),
    "-o",
    probe
  ))
  expect_identical(got$status, 0L, info = paste(got$out, collapse = "\n"))
  syms <- run_capture("nm", c("-P", probe))
  expect_identical(syms$status, 0L, info = paste(syms$out, collapse = "\n"))
  prefixed <- any(grepl("^_dseams_probe_symbol ", syms$out))
  bare <- any(grepl("^dseams_probe_symbol ", syms$out))
  expect_true(prefixed || bare)
  if (prefixed) {
    assert_c <- "__assert_rtn"
    impl_c <- "__compilerrt_abort_impl"
  } else {
    assert_c <- "___assert_rtn"
    impl_c <- "___compilerrt_abort_impl"
  }
  writeLines(
    sprintf(
      paste0(
        "void %s(const char *func, const char *file, int line, const char *expr);\n",
        "void %s(const char *file, int line, const char *function) {\n",
        "  %s(function, file, line, \"libcompiler_rt abort\");\n",
        "}\n"
      ),
      assert_c, impl_c, assert_c
    ),
    file.path(dir, "crt.c")
  )
  writeLines(
    sprintf(
      paste0(
        "void %s(const char *func, const char *file, int line, const char *expr);\n",
        "void extra_assert(void) { %s(\"f\", \"g\", 1, \"e\"); }\n"
      ),
      assert_c, assert_c
    ),
    file.path(dir, "extra.c")
  )
  writeLines(
    "int other_reader(int x) { return x + 1; }\n",
    file.path(dir, "other.c")
  )
  compile <- function(name) {
    src <- file.path(dir, paste0(name, ".c"))
    obj <- file.path(dir, paste0(name, ".o"))
    compiled <- run_capture(cc_parts[[1L]], c(
      cc_parts[-1L],
      "-c",
      "-O2",
      "-fPIC",
      src,
      "-o",
      obj
    ))
    expect_identical(
      compiled$status,
      0L,
      info = paste(compiled$out, collapse = "\n")
    )
    obj
  }
  crt_o <- compile("crt")
  extra_o <- compile("extra")
  other_o <- compile("other")
  ok <- file.path(dir, "libok.a")
  bad <- file.path(dir, "libbad.a")
  archived <- run_capture("ar", c("rcs", ok, crt_o, other_o))
  expect_identical(archived$status, 0L)
  archived <- run_capture("ar", c("rcs", bad, crt_o, other_o, extra_o))
  expect_identical(archived$status, 0L)
  before <- run_capture("ar", c("t", bad))$out
  script <- file.path(root, "tools", "readcon-apple-builtins.sh")
  run_script <- function(archive) {
    run_capture("sh", c(script, archive))
  }
  # system2 warns when a captured command returns non-zero. The status
  # is the result under test, so the output goes to files, which does
  # not warn, and the expectation still requires the failure.
  bad_out <- tempfile("compilerrt-out-")
  bad_err <- tempfile("compilerrt-err-")
  bad_status <- system2(
    "sh",
    c(script, bad),
    stdout = bad_out,
    stderr = bad_err
  )
  bad_run <- list(
    status = as.integer(bad_status),
    out = c(
      readLines(bad_out, warn = FALSE),
      readLines(bad_err, warn = FALSE)
    )
  )
  expect_identical(bad_run$status, 1L, info = paste(bad_run$out, collapse = "\n"))
  expect_true(any(grepl("outside compiler-rt", bad_run$out, fixed = TRUE)))
  after <- run_capture("ar", c("t", bad))$out
  expect_identical(sort(after), sort(before))
  ok_run <- run_script(ok)
  expect_identical(ok_run$status, 0L, info = paste(ok_run$out, collapse = "\n"))
  listed <- run_capture("nm", c("-P", ok))
  expect_identical(listed$status, 0L, info = paste(listed$out, collapse = "\n"))
  expect_false(any(grepl("___assert_rtn", listed$out, fixed = TRUE)))
  expect_true(any(grepl("^_?abort U", listed$out)))
  expect_true(any(grepl("compilerrt_abort_impl T", listed$out, fixed = TRUE)))
  # src/Makevars passes a path relative to src/. The script extracts
  # members from a temporary directory, so that relative path has to be
  # resolved before ar runs.
  rel <- tempfile("compilerrt-rel-")
  dir.create(rel)
  archived <- run_capture("ar", c(
    "rcs",
    file.path(rel, "libreadcon_core.a"),
    crt_o,
    other_o
  ))
  expect_identical(archived$status, 0L)
  old_wd <- getwd()
  on.exit(setwd(old_wd), add = TRUE)
  setwd(rel)
  rel_run <- run_script("libreadcon_core.a")
  setwd(old_wd)
  expect_identical(rel_run$status, 0L, info = paste(rel_run$out, collapse = "\n"))
  rel_nm <- run_capture("nm", c("-P", file.path(rel, "libreadcon_core.a")))
  expect_identical(rel_nm$status, 0L, info = paste(rel_nm$out, collapse = "\n"))
  expect_false(any(grepl("___assert_rtn", rel_nm$out, fixed = TRUE)))
  expect_true(any(grepl("compilerrt_abort_impl T", rel_nm$out, fixed = TRUE)))
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
