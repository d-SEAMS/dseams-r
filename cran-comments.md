## Submission

This is a new submission.

The package compiles a copy of the d-SEAMS engine (C++20, in `src/seams`)
together with the R glue, readcon-core, and patched chemfiles 0.10.4.
`tools/vendor.sh` makes that copy from the seams-core tag `v2.14.2` when
the source package is built. The tarball carries the engine, the vendored
readcon-core crates, and chemfiles, so installing it does not use the
network. Building the bundled copy needs GNU make, Cargo, rustc >= 1.88
(on Windows with the `x86_64-pc-windows-gnu` target, which R's MinGW
toolchain links), cmake >= 3.15, objcopy (or llvm-objcopy), and SQLite3,
which chemfiles' DESRES `.dms` reader links, as `SystemRequirements` states. Cargo and CMake run with at most two jobs, and Cargo's home is a
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

## R CMD check results for 2.14.2

`R CMD check --as-cran --no-manual` ran on Ubuntu 24.04.5 LTS with
Ubuntu's R 4.3.3 (`r-base-core` 4.3.3-2build2, compiled by gcc 13.2.0),
with qpdf 11.9.0 and checkbashisms on `PATH`. The CRAN incoming checks
were on, and no `_R_CHECK_*` variable was set except
`_R_CHECK_FORCE_SUGGESTS_=true`. `DSEAMS_ROOT` was a seams-core v2.14.2
tree and `DSEAMS_REQUIRE_DATA=1`. The install printed
`rustc 1.100.0 (0ef1bc386 2026-11-09)`,
`cargo 1.100.0 (3acc79c0c 2026-11-05)` and cmake 4.4.5. R prints curly
quotes; they are written as ASCII apostrophes below.

The bundled check, which compiles the engine copy as CRAN does, finished:

```
Status: 4 NOTEs
```

0 errors | 0 warnings | 4 notes

```
* checking CRAN incoming feasibility ... NOTE
Maintainer: 'Rohit Goswami <rgoswami@ieee.org>'

New submission

Size of tarball: 9480802 bytes
* checking installed package size ... NOTE
  installed size is 14.4Mb
  sub-directories of 1Mb or more:
    libs  13.7Mb
* checking for future file timestamps ... NOTE
unable to verify current time
* checking compilation flags used ... NOTE
Compilation used the following non-portable flag(s):
  '-mno-omit-leaf-frame-pointer'
```

Where each note comes from:

- New submission and the size of the tarball: the package. The tarball
  carries the engine, readcon-core with its vendored crates, and
  chemfiles with every reader and format it builds, so installing needs
  no network. No reader, format or licence file is left out to make it
  smaller. Two builds of the same tree differ by a few hundred bytes,
  because the tarball records when it was built; the bundled and linked
  checks here built the tarball separately.
- Installed size: the package. `libs` is the one shared library, which
  holds the engine and the chemfiles and readcon-core readers. After
  linking, `src/Makevars` removes its debug sections with the debug-only
  strip command in R's `Makeconf` (`strip --strip-debug` here). The
  symbol table that the compiled-code check reads stays. Before that
  step the same check reported `installed size is 75.6Mb` with
  `libs  74.8Mb`.
- Future file timestamps: the check host. R could not get the current
  time from the web service it asks, so it could not compare the file
  times to it.
- `-mno-omit-leaf-frame-pointer`: the check host. Ubuntu builds R with
  that flag in `CXXFLAGS` (`R CMD config CXXFLAGS` prints it), and R
  passes it to every compile. The package's `Makevars` does not add it.

Without qpdf on `PATH` the same R also reports
`'qpdf' is needed for checks on size reduction of PDFs` as a WARNING;
that comes from the host, not the package.

The check linked against a seams-core v2.14.2 build (`SEAMS_LIBDIR`)
finished with `Status: 3 NOTEs`: the same incoming feasibility note
(`Size of tarball: 9481298 bytes`), the same timestamp note and the
same compilation flag note. Its installed size check is OK.

The testthat run inside the bundled check printed:

```
[ FAIL 0 | WARN 0 | SKIP 2 | PASS 429 ]
```

The two skips are `SEAMS_BIN is not set` (`test-ice.R` line 77) and
`SEAMS_CPP_ORACLE is not set` (`test-doc-examples.R` line 99): those
tests compare against the seams-core executable and the C++ oracle of
the build the package links, and a bundled build links none. The linked
check, with `SEAMS_BIN` and `SEAMS_CPP_ORACLE` from that build, printed:

```
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 433 ]
```

In both, the cubic-ice test read `mW_cubic.lammpstrj` with SHA-256
`66d854880bb9431abc9eb25d68b0622d94a0160dd03e1ac7d636343d9830485d`.
That 1.4 MB file is not in the package. With no copy in
`$DSEAMS_ROOT/input/traj` or `DSEAMS_INPUT_CACHE` and no
`$DSEAMS_ROOT/input/fetch.py`, the test downloads the pinned copy, and
on CRAN it skips instead with:

```
Reason: mW_cubic.lammpstrj is not in DSEAMS_ROOT/input/traj or DSEAMS_INPUT_CACHE and network tests do not run on CRAN
```

Run against the installed package in a network namespace with no
network, the test skipped with that reason when `NOT_CRAN` was unset,
skipped with `... and huggingface.co is not reachable` when
`NOT_CRAN=true`, and failed with `cannot open URL` when
`DSEAMS_REQUIRE_DATA=1`.

The R-CMD-check workflow runs on pushes and pull requests to `main`,
`develop`, and `release/**`, on Ubuntu (R release and devel), macOS,
and Windows, with `--no-manual` and `--as-cran`. The Linux jobs
install binutils and qpdf. The macOS job installs Homebrew llvm and
qpdf and puts `llvm-objcopy` on `PATH`. Those jobs then run
`tools/check-reader-symbols.sh`, which fails if objcopy, nm, ar, or
the C compiler is missing. Every job that runs the tests sets
`DSEAMS_REQUIRE_DATA=1` and `DSEAMS_INPUTS_LOG`, and afterwards
`tools/check-test-inputs.R` fails unless testthat reported no failures,
the cubic-ice test read `mW_cubic.lammpstrj` with its pinned SHA-256,
and no test skipped for want of it. A `v*` tag on d-SEAMS/dseams-r runs
`.github/workflows/release.yml`, which runs
`R CMD check --as-cran --no-manual` and exits if the `Status:` line
contains `ERROR` or `WARNING`. Those workflow runs are not results
recorded here.
