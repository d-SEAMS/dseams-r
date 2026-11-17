## Submission

This is a new submission.

The package compiles a copy of the d-SEAMS engine (C++20, in `src/seams`)
together with the R glue. `tools/vendor.sh` makes that copy from the
seams-core tag `v2.14.0` when the source package is built; installing the
source package does not use the network. In the copy, `[[nodiscard]]` is
removed (the upstream build silences those warnings with
`-Wno-unused-result`) and the engine's console output and `exit` go
through `src/dseams_r_io.cpp` to `Rprintf`/`REprintf` and an R error.

## R CMD check results

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility ... NOTE
  Maintainer: 'Rohit Goswami <rgoswami@ieee.org>'

  New submission

The exact `dseams_2.14.0.tar.gz` submitted here was checked on Ubuntu
24.04 with:

* R 4.5.3 (2026-03-11), x86_64-conda-linux-gnu, conda-forge GCC 14.4.0;
* R Under development (unstable) (2026-11-16 r90914),
  x86_64-pc-linux-gnu.

Both checks used `R CMD check --as-cran`, built the PDF and HTML manuals,
and reported the result above. They linked `libseams` and
`libseams_lang` from the seams-core `v2.14.0` build and set
`SEAMS_BIN` and `SEAMS_CPP_ORACLE` from that same build. The test result
was 118 passed and none skipped in each check.

The same tarball was also installed without the linked engine into an
empty user library, exercising the bundled engine that CRAN will compile.
The installed package read its shipped 128-water ice Ih frame, classified
all 128 waters as hexagonal ice, and found 256 six-membered rings.

There are no reverse dependencies because this is a new submission. The
examples and tests run with at most two threads when
`_R_CHECK_LIMIT_CORES_` is set.
