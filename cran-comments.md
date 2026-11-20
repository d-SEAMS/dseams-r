## Submission

This is a new submission.

The package compiles a copy of the d-SEAMS engine (C++20, in `src/seams`)
together with the R glue, readcon-core, and patched chemfiles 0.10.4.
`tools/vendor.sh` makes that copy from the seams-core tag `v2.14.1` when
the source package is built. The tarball carries the engine, the vendored
readcon-core crates, and chemfiles, so installing it does not use the
network. Building the bundled copy needs Cargo, rustc >= 1.88, cmake, and
objcopy. In the copy, `[[nodiscard]]` is removed (the upstream build
silences those warnings with `-Wno-unused-result`) and the engine's
console output and `exit` go through `src/dseams_r_io.cpp` to
`Rprintf`/`REprintf` and an R error. The same file provides the symbols
the bundled readers would otherwise resolve to `abort`, `exit`, and the
C and C++ consoles.

## R CMD check results

0 errors | 0 warnings | 2 notes

* checking CRAN incoming feasibility ... NOTE
  Maintainer: 'Rohit Goswami <rgoswami@ieee.org>'

  New submission

* checking for future file timestamps ... NOTE
  unable to verify current time

Checked with `R CMD check --as-cran --no-manual` on R 4.5.3 (2026-03-11),
x86_64-conda-linux-gnu, conda-forge GCC 14.4.0, on Ubuntu 24.04.
conda-forge's R adds `-march=nocona`; that flag is the toolchain's and
was named with `_R_CHECK_COMPILATION_FLAGS_KNOWN_=-march=nocona`. Both
`R CMD build` and `R CMD check` were run with `--no-manual`, so neither
the PDF nor the HTML manual was built in this check. Tests: 131 passed, 8
skipped. The skips are the comparisons that need `DSEAMS_ROOT` and
`SEAMS_BIN`, which a CRAN machine does not have. The shipped CON, PDB,
GRO, and XYZ files are read by tests that do not skip. The same tarball
was also checked with the network blocked and cargo offline: the readers
still built, and the same tests passed. That run's CRAN-incoming note is
the URL check failing because the network was blocked, plus the same
future-timestamp note.

A second check on the same host linked `libseams` and `libseams_lang`
from a seams-core 2.14.1 build (`R CMD check --no-manual`, `DSEAMS_ROOT`,
`SEAMS_LIBDIR`, `SEAMS_BIN` and `SEAMS_CPP_ORACLE` set). That run was
Status: OK, with 118 passed and none skipped.

The R-CMD-check workflow also checks Ubuntu (R release and devel), macOS
and Windows, with `--as-cran --no-manual`. A `v*` tag on
d-SEAMS/dseams-r runs `.github/workflows/release.yml`, which repeats that
check and, only when it reports no errors and no warnings, publishes the
source tarball.

The examples and tests run with at most two threads when
`_R_CHECK_LIMIT_CORES_` is set.
