## Submission

This is a new submission.

The package compiles a copy of the d-SEAMS engine (C++20, in `src/seams`)
together with the R glue, readcon-core, and patched chemfiles 0.10.4.
`tools/vendor.sh` makes that copy from the seams-core tag `v2.14.2` when
the source package is built. The tarball carries the engine, the vendored
readcon-core crates, and chemfiles, so installing it does not use the
network. Building the bundled copy needs GNU make, Cargo, rustc >= 1.88,
cmake >= 3.15, and objcopy (or llvm-objcopy), as `SystemRequirements`
states. Cargo and CMake run with at most two jobs, and Cargo's home is a
directory inside the package build, removed afterwards. In the copy, `[[nodiscard]]` is removed (the upstream build
silences those warnings with `-Wno-unused-result`) and the engine's
console output and `exit` go through `src/dseams_r_io.cpp` to
`Rprintf`/`REprintf` and an R error. The same file provides the symbols
the bundled readers would otherwise resolve to `abort`, `exit`, and the
C and C++ consoles.

## R CMD check results for 2.14.2

`R CMD check --no-manual` on R 4.5.3 (`x86_64-conda-linux-gnu`, Arch
Linux) reported zero errors, zero warnings, and one note. The note
listed the citation metadata that Cargo vendors with Linkcell and
Minimage under `src/readcon-core/vendor/`.

The source tarball check passed 167 assertions and skipped eight
comparisons that need a seams-core checkout or executable. The installed
package passed 195 assertions with zero skips when `DSEAMS_ROOT`,
`SEAMS_BIN`, and `SEAMS_CPP_ORACLE` pointed to the matching 2.14.2
fixtures, CLI, and C++ oracle. The standalone tarball check and the
installed-package run both used the bundled engine.

## R CMD check results for 2.14.1

0 errors | 0 warnings | 2 notes

* checking CRAN incoming feasibility ... NOTE
  Maintainer: ‘Rohit Goswami <rgoswami@ieee.org>’

  New submission

* checking HTML version of manual ... NOTE
  Skipping checking HTML validation: no command 'tidy' found.

`R CMD check --as-cran` finished `Status: 2 NOTEs`. The log is
`logs/check-ascran-00check.log`.

Checked on R 4.5.3 (2026-03-11), `x86_64-conda-linux-gnu`, on Ubuntu
24.04.5 LTS. That log says R was compiled by
`x86_64-conda-linux-gnu-cc (conda-forge gcc 14.4.0-7) 14.4.0`.
conda-forge's R adds `-march=nocona`; that flag is the toolchain's and
was named with `_R_CHECK_COMPILATION_FLAGS_KNOWN_=-march=nocona`. The
same log reports `checking compilation flags used ... OK` and
`checking PDF version of manual ... OK`. `R CMD build` (`logs/build.log`)
does not build the PDF manual. The HTML note is the missing `tidy`
command, quoted above from the check log.

The install log (`logs/check-ascran-00install.out`) prints
`rustc 1.100.0 (0ef1bc386 2026-11-09)`,
`cargo 1.100.0 (3acc79c0c 2026-11-05)`, and
`Running CMake version 3.28.3`. The C++ compile line defines
`-DSEAMS_HAS_READCON=1`.

`DSEAMS_ROOT`, `SEAMS_BIN`, and `SEAMS_CPP_ORACLE` were unset. The tests
in that check (`logs/check-ascran-testthat.Rout`) print:

```
[ FAIL 0 | WARN 0 | SKIP 8 | PASS 167 ]
```

Seven skips are `DSEAMS_ROOT is not set` and one is `SEAMS_BIN is not set`.
The shipped CON file is not one of those skips. The examples
(`logs/check-ascran-examples.Rout`) print `nframes()` of
`tiny_multi_cuh2.con` as 2 and `read_frame()` as `dseams frame 1 atoms 4`.
`logs/test-suite.log` prints `CON_READ nframes=2 nrow=4 class=dseams_frame`.
The string `readcon-core is not in this build; CON input needs it` is
not in these logs.

`testthat::test_local(".", load_package = "installed")` from this
checkout prints `[ FAIL 0 | WARN 0 | SKIP 8 | PASS 168 ]` with the same
eight skips (`logs/test-local.log`).
`testthat::test_check("dseams")`, with the working directory set to the
`tests/` directory of an installed copy outside this checkout, prints
`[ FAIL 0 | WARN 0 | SKIP 9 | PASS 166 ]` (`logs/test-check-call.log`).
The ninth skip is `tools/check-submission.R is not beside this test run`.

The source tarball is 7946434 bytes, from the CRAN-incoming note in
`logs/check-ascran-00check.log`.

A check linked against a built seams-core and a check with no network
were not run.

The R-CMD-check workflow file runs on Ubuntu (R release and devel),
macOS, and Windows, with `--no-manual` and `--as-cran`. A `v*` tag on
d-SEAMS/dseams-r runs `.github/workflows/release.yml`, which runs
`R CMD check --as-cran --no-manual` and exits if the `Status:` line
contains `ERROR` or `WARNING`. Those workflow runs are not results
recorded here.
