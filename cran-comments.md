## Submission

This is a new submission.

The package compiles a copy of the d-SEAMS engine (C++20, in `src/seams`)
together with the R glue. `tools/vendor.sh` makes that copy from the
seams-core tag `v2.14.1` when the source package is built; installing the
source package does not use the network. In the copy, `[[nodiscard]]` is
removed (the upstream build silences those warnings with
`-Wno-unused-result`) and the engine's console output and `exit` go
through `src/dseams_r_io.cpp` to `Rprintf`/`REprintf` and an R error.

## R CMD check results

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility ... NOTE
  Maintainer: 'Rohit Goswami <rgoswami@ieee.org>'

  New submission

Checked with `R CMD check --as-cran` on R 4.5.3 (2026-03-11),
x86_64-conda-linux-gnu, conda-forge GCC 14.4.0, on Ubuntu 24.04.
conda-forge's R adds `-march=nocona`; that flag is the toolchain's and
was named with `_R_CHECK_COMPILATION_FLAGS_KNOWN_=-march=nocona`. The PDF
manual (pdflatex) and the HTML manual were built. Tests: 112 passed, 2
skipped. The skips are the comparisons that need `SEAMS_BIN` and
`SEAMS_CPP_ORACLE`, which a CRAN machine does not have.

A second check on the same host linked `libseams` and `libseams_lang`
from a seams-core 2.14.1 build (`R CMD check --no-manual`, `SEAMS_BIN`
and `SEAMS_CPP_ORACLE` set). That run was Status: OK, with 118 passed and
none skipped.

The R-CMD-check workflow also checks Ubuntu (R release and devel), macOS
and Windows, with `--as-cran --no-manual`. A `v*` tag on
d-SEAMS/dseams-r runs `.github/workflows/release.yml`, which repeats that
check and, only when it reports no errors and no warnings, publishes the
source tarball.

The examples and tests run with at most two threads when
`_R_CHECK_LIMIT_CORES_` is set.
