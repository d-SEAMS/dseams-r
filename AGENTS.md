# Contributing to dseams-r

This file is the working contract for anyone changing this repository. The
README is for users of the package; this file is for people editing it.

## What lives here and what does not

This repository holds the R package `dseams` on top of the d-SEAMS engine.
The engine, the C API (`libseams`, header `include/seams.h`), the language
ABI (`libseams_lang`, header `bindings/cxx/seams_lang.h`), the `seams` CLI
and the C++ reference `binding_oracle` live in
[d-SEAMS/seams-core](https://github.com/d-SEAMS/seams-core).

- A new analysis, a changed result, a C API or ABI function, a reader for a
  new file format, or a bug inside the engine: change seams-core first.
  Bind it here once a seams-core commit carries it, and move the pin.
- An R function, an S3 method, the C/C++ glue in `src/*.c` and `src/*.cpp`,
  `configure`, `tools/vendor.sh`, docs, examples or tests: change it here.
- Do not commit engine sources. `src/seams/` and `inst/extdata/` are
  written by `tools/vendor.sh` and ignored by git. The copy changes only
  through `tools/vendor.sh` (which strips `[[nodiscard]]` and routes console
  output and `exit` through `src/dseams_r_io.h`), never by hand.

## Layout

| Path | Contents |
|---|---|
| `DESCRIPTION`, `NAMESPACE` | Package metadata; `NAMESPACE` and `man/` are written by roxygen2 |
| `R/` | `dseams.R` (frames and analyses), `capi.R` (`seams_*` C API wrappers), `s3.R`, `dseams-package.R`, `cpp11.R` (generated) |
| `src/` | `dseams.cpp` (cpp11, `libseams_lang`), `seams_call.c` (`.Call` into `libseams`), `dseams_r_io.*`, `Makevars.in`, `Makevars.win` |
| `configure`, `configure.win`, `cleanup` | Make `src/Makevars`; choose the bundled copy or a linked engine |
| `tools/seams-core.ref` | `SEAMS_CORE_REPO` and `SEAMS_CORE_REF`, the seams-core revision the copy and CI use |
| `tools/vendor.sh` | Copies the engine sources and example dumps from a seams-core tree, or from the pin |
| `tools/fetch-engine.R` | Downloads the pinned seams-core source with base R |
| `tests/testthat/` | `test-api.R`, `test-ice.R`, `test-s3.R`, `test-doc-examples.R` |
| `inst/examples/` | Scripts the d-SEAMS site includes; `test-doc-examples.R` runs them |
| `vignettes/` | `classifying-ice.Rmd` |
| `docs/` | API, tutorial and language-task pages for the d-SEAMS site |
| `pixi.toml`, `pixi.lock` | R, compilers and every Suggests package for local checks |
| `.github/workflows/r-cmd-check.yml` | Bundled checks on Linux, macOS and Windows; a linked check against seams-core built at the pin |
| `.github/workflows/test-coverage.yml` | covr on the R code, linked against seams-core built at the pin, reported in the job summary |

## How the package finds the engine

`configure` takes the first that applies:

1. `SEAMS_LIBDIR`: link `libseams_lang` there and `libseams` from
   `SEAMS_SO_DIR` (default: the `src/` beside it). Headers come from
   `SEAMS_INCLUDE` and `SEAMS_H_DIR`, or from the seams-core tree in
   `DSEAMS_ROOT`.
2. `DSEAMS_SYSTEM_ENGINE=1`: link the `seams` and `seams-lang` pkg-config
   modules; their version must equal `Version` in `DESCRIPTION`.
3. Otherwise compile the bundled copy in `src/seams`.

In every mode `src/seams`, `src/readcon-core`, `src/chemfiles`, and
`inst/extdata` must exist. `configure` and `configure.win` read
`tools/vendored-sentinels` and run `tools/vendor.sh` when any entry is
missing. `tools/vendor.sh` writes them from `SEAMS_CORE_SRC` or
`DSEAMS_ROOT`, else from the revision in `tools/seams-core.ref`, which
it downloads unless `DSEAMS_NO_DOWNLOAD=1`. `configure.win` applies the
same rustc, cargo, cmake and objcopy requirements as a bundled Unix
build, and it refuses a `Makevars.win` whose `SEAMS_LANG_VERSION` is
not `Version` from DESCRIPTION.
The same step vendors readcon-core (the wrap revision in that seams-core
tree, crates included) and patched chemfiles 0.10.4. A tarball from
`R CMD build` carries those copies and installs with no network. The
bundled compile needs GNU make, Cargo, rustc >= 1.88, cmake >= 3.15,
and objcopy (or llvm-objcopy), and it always builds the CON reader and
chemfiles. Cargo and CMake run at most two jobs, and Cargo's home is
`src/readcon-core/cargo-home`, which the build removes. A linked engine
needs the same readers: configure seams-core with
`meson setup build -Dwith_chemfiles=enabled -Dwith_readcon=enabled`, as
CI does. Its reader probe rejects a chemfiles without all 37 VMD molfile
readers and builds the patched 0.10.4 copy instead.

## Build and test

All builds and checks run on a build host, not on a laptop. With a
seams-core checkout at the pin configured as above and built in `build/`
(meson targets `src/libseams.so`, `bindings/libseams_lang.so`, `seams`,
`bindings/binding_oracle`):

```bash
# DSEAMS_ROOT is a seams-core checkout at the pin, already built.
export SEAMS_BIN="$DSEAMS_ROOT/build/seams"

# bundled copy
pixi run sh tools/vendor.sh "$DSEAMS_ROOT"
pixi run R CMD build --no-manual .
pixi run R CMD check --as-cran --no-manual dseams_*.tar.gz

# linked against that build
SEAMS_LIBDIR=$DSEAMS_ROOT/build/bindings \
SEAMS_CPP_ORACLE=$DSEAMS_ROOT/build/bindings/binding_oracle \
  pixi run sh -c 'R CMD build --no-manual . && R CMD check --no-manual dseams_*.tar.gz'
```

`R CMD check --as-cran` needs `checkbashisms` and `qpdf` on `PATH`. The conda-forge R
adds `-march=nocona`; `_R_CHECK_COMPILATION_FLAGS_KNOWN_=-march=nocona`
names it as a toolchain flag (the `pixi run check` task sets it).

Every check must pass before a change is called done: no ERROR, no
WARNING. On Ubuntu's R 4.3.3 the bundled `--as-cran` check reports four
NOTEs and the linked check three; `cran-comments.md` quotes them and says
which come from the host. Without `qpdf` that R also reports a WARNING;
`cran-comments.md` names it. Fix the code under test; do
not skip, loosen or delete a test to get there. A test changes only when the
behavior it pins changes on purpose, and the commit says so. Without
`DSEAMS_ROOT`, `SEAMS_BIN` and `SEAMS_CPP_ORACLE` some tests report a skip;
CI sets them, and so should a local run that touches an analysis.
`SEAMS_CPP_ORACLE` must come from the build the package links.
The cubic-ice test needs `mW_cubic.lammpstrj` from the Hugging Face
dataset `d-SEAMS/seams-core-inputs`. `tests/testthat/helper-inputs.R`
uses a verified copy in `$DSEAMS_ROOT/input/traj` or `DSEAMS_INPUT_CACHE`,
else fetches it at the revision and SHA-256 that `input/fetch.py` pins at
the seams-core ref. With no local copy and no `fetch.py` it skips on CRAN
and offline; `DSEAMS_REQUIRE_DATA=1`, which CI sets, makes that an error,
and CI checks `DSEAMS_INPUTS_LOG` and the testthat log afterwards. Move
those pins with `SEAMS_CORE_REF`.

## When the engine changes

1. Move `SEAMS_CORE_REF` in `tools/seams-core.ref`.
2. If the engine gained or lost a translation unit that `libseams_lang` or
   `seams_api.cpp` needs, edit the `seams/*.o` block in both
   `src/Makevars.in` and `src/Makevars.win`; `tools/vendor.sh` refuses lists
   that differ.
3. Wrap new C API symbols in `src/seams_call.c` and `R/capi.R`, document
   them with roxygen2, regenerate `man/` and `NAMESPACE`, and extend the
   tests.
4. If the chemfiles pin changes the molfile plugins it lists as
   compilable, `tools/chemfiles-molfiles.py` stops the vendor. Run
   `sh tools/probe-molfiles.sh src/chemfiles/external/molfiles.tar.gz
   PLUGIN...` and update its `READERS` or `EXCLUDED` table, then the
   molfiles entries in `inst/AUTHORS` and `LICENSE.note`.

## Commits and changelog

- [Conventional Commits](https://www.conventionalcommits.org/): `feat`,
  `fix`, `docs`, `test`, `build`, `ci`, `refactor`, `style`, `chore`, with a
  scope where it helps (`fix(configure): ...`). One logical change per
  commit; formatter-only changes go in their own `style:` commit.
- ASCII punctuation in code, docs and commit messages. Comments say what the
  code does and why, in the present tense; history belongs in the commit.
- Every user-visible change adds a bullet to `NEWS.md` under the top
  heading `# dseams (development version)`, which a release renames to
  `# dseams X.Y.Z`.

## Releases

The package version is the seams-core version it binds.

1. seams-core tags the release (`vX.Y.Z` on d-SEAMS/seams-core).
2. Here: set `SEAMS_CORE_REPO=d-SEAMS/seams-core` and
   `SEAMS_CORE_REF=vX.Y.Z` in `tools/seams-core.ref`, `Version: X.Y.Z` in
   `DESCRIPTION`, `SEAMS_LANG_VERSION` in `src/Makevars.win`, rename the
   `NEWS.md` heading, update `version` in `CITATION.cff`, `codemeta.json`
   and `cran-comments.md`, and
   wait for CI on that commit.
3. `sh tools/vendor.sh`, `R CMD build .`, and submit that tarball.
4. Tag `vX.Y.Z` here.
