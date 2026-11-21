## Submission

This is a new submission.

The package compiles a copy of the d-SEAMS engine (C++20, in `src/seams`)
together with the R glue, readcon-core, and patched chemfiles 0.10.4.
`tools/vendor.sh` makes that copy from the seams-core tag `v2.14.1` when
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
C and C++ consoles. On macOS that rewrite needs llvm-objcopy. GNU
objcopy does not rewrite Mach-O archives.

`molfiles/src/ply.c` and `molfiles/src/ply.h` (Georgia Institute of
Technology, 1998) permit use, copying, modification, and distribution
on condition that the software is not sold. They are shipped and are
not compiled. `molfiles/src/plyplugin.cxx` includes `ply.c`, so that
condition would apply if plyplugin were compiled. plyplugin is not in
the compiled list. `LICENSE.note` states this.

## R CMD check results

0 errors | 0 warnings | 1 note

`pixi run check` ran `R CMD check --as-cran --no-manual` on the bundled
tarball `dseams_2.14.1.tar.gz`. It finished:

```
Status: 1 NOTE
```

The note is:

```
* checking CRAN incoming feasibility ... [3s/16s] NOTE
Maintainer: 'Rohit Goswami <rgoswami@ieee.org>'

New submission

Size of tarball: 7950141 bytes
```

Installed package size is reported as INFO, not as a note:

```
* checking installed package size ... INFO
  installed size is 15.0Mb
  sub-directories of 1Mb or more:
    libs  14.4Mb
```

Checked on R 4.5.3 (2026-03-11), platform `x86_64-conda-linux-gnu`, on
Ubuntu 24.04.5 LTS. R was compiled by
`x86_64-conda-linux-gnu-cc (conda-forge gcc 14.4.0-7) 14.4.0` and
`GNU Fortran (conda-forge gcc 14.4.0-7) 14.4.0`.
conda-forge's R adds `-march=nocona`; that flag is the toolchain's and
was named with `_R_CHECK_COMPILATION_FLAGS_KNOWN_=-march=nocona`.
`checking compilation flags used ... OK`. The check used `--no-manual`,
so it does not check the PDF or HTML manual.

The install prints `rustc 1.100.0 (0ef1bc386 2026-11-09)`,
`cargo 1.100.0 (3acc79c0c 2026-11-05)`, and
`Running CMake version 3.28.3`. The C++ compile line defines
`-DSEAMS_HAS_READCON=1`.

`DSEAMS_ROOT`, `SEAMS_BIN`, and `SEAMS_CPP_ORACLE` were unset. The
testthat run inside that check prints:

```
[ FAIL 0 | WARN 0 | SKIP 8 | PASS 215 ]
```

Seven skips are `DSEAMS_ROOT is not set` (`test-doc-examples.R` lines
21, 27, 32, 37, 54, and 73, and `test-ice.R` line 89). One skip is
`SEAMS_BIN is not set` (`test-ice.R` line 73).

The examples print `nframes()` of `tiny_multi_cuh2.con` as 2 and
`read_frame()` as `dseams frame 1 atoms 4`.

A check linked against a built seams-core and a check with no network
were not run.

The R-CMD-check workflow runs on pushes and pull requests to `main`,
`develop`, and `release/**`, on Ubuntu (R release and devel), macOS,
and Windows, with `--no-manual` and `--as-cran`. The macOS job installs
Homebrew llvm and puts `llvm-objcopy` on `PATH`. A `v*` tag on
d-SEAMS/dseams-r runs `.github/workflows/release.yml`, which runs
`R CMD check --as-cran --no-manual` and exits if the `Status:` line
contains `ERROR` or `WARNING`. Those workflow runs are not results
recorded here.
