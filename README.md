# dseams

Ice classification and ring statistics for molecular simulations. `dseams`
is the R interface to the [d-SEAMS](https://dseams.info) engine: CHILL+
labels, primitive rings, hexagonal and double-diamond cages, and Steinhardt
order parameters.

## Installation

```r
# install.packages("remotes")
remotes::install_github("d-SEAMS/dseams-r")
```

A C++20 compiler is required (`SystemRequirements` in `DESCRIPTION`).
OpenMP is used when R was built with it.

## How the package gets the engine

The package compiles its own copy of the
[seams-core](https://github.com/d-SEAMS/seams-core) engine sources, kept
in `src/seams` together with the example dumps in `inst/extdata`. That
copy is what a source package from `R CMD build`, and so a CRAN or
r-universe tarball, carries: installing such a tarball needs no seams-core
checkout, no installed library and no network. This is the layout CRAN and
rOpenSci accept for a bundled C/C++ library (the package is
self-contained, builds with R's own toolchain flags, and the engine
copyright holders are listed in `DESCRIPTION`).

The copy is not stored in git. In a git checkout `configure` (and
`configure.win`) runs `tools/vendor.sh`, which makes it from the first of:

1. `SEAMS_CORE_SRC` (or `DSEAMS_ROOT`), a seams-core source tree;
2. the seams-core revision pinned in `tools/seams-core.ref`, downloaded
   from GitHub by `tools/fetch-engine.R`. `DSEAMS_NO_DOWNLOAD=1` turns
   this step into an error.

`install_github` takes the second path. The pin is the seams-core commit
that becomes the `v2.14.0` tag; `src/seams/README` records the revision a
copy came from.

To link an engine that is already built instead of compiling the copy:

```sh
# an installed seams-core, found through the seams and seams-lang
# pkg-config modules; the version must equal the package version
DSEAMS_SYSTEM_ENGINE=1 R CMD INSTALL .

# a seams-core build tree
DSEAMS_ROOT=/path/to/seams-core \
  SEAMS_LIBDIR=/path/to/seams-core/build/bindings \
  R CMD INSTALL --preclean .
```

`SEAMS_LIBDIR` is the directory of `libseams_lang`. `SEAMS_INCLUDE`
(`seams_lang.h`), `SEAMS_H_DIR` (`seams.h`) and `SEAMS_SO_DIR` (`libseams`
and the generated `seams_version.h`) default to the places they occupy in
the seams-core tree that `DSEAMS_ROOT` names and in its build directory.

## Use

```r
library(dseams)
frame <- read_frame(dseams_example("ice1h.lammpstrj"), type = -1L)
table(chill_plus(frame)$name)
primitive_rings(frame, graph = "cutoff", max_depth = 6L)
```

`vignette("classifying-ice", package = "dseams")` walks through the same
dumps. Report bugs at <https://github.com/d-SEAMS/dseams-r/issues>.

## Development

```sh
pixi run vendor            # SEAMS_CORE_SRC=/path/to/seams-core, or the pin
pixi run build
pixi run check
```

With `DSEAMS_ROOT` set to a seams-core checkout the test suite also reads
the cubic ice dump in its `input/traj`; with `SEAMS_BIN` set to a `seams`
executable of the same version it compares the cage census with the CLI.
See [CONTRIBUTING.md](CONTRIBUTING.md).

The package is MIT licensed. Cite Goswami, Goswami and Singh (2020)
<doi:10.1021/acs.jcim.0c00031>. `citation("dseams")` prints the record.
