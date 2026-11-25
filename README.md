# dseams

Ice classification and ring statistics for molecular simulations. `dseams`
reads one frame of a LAMMPS dump, an XYZ file, a CON file, or a
chemfiles trajectory and returns data frames:
CHILL+ labels, primitive rings, hexagonal and double-diamond cages, and
Steinhardt order parameters. The calculations are the
[d-SEAMS](https://dseams.info) engine.

## Documentation

- [Function reference and vignette](https://r.dseams.info/)
- [R chapter of the d-SEAMS book](https://docs.dseams.info/stable/r.html)
- [Video walk-through](https://odysee.com/dseams-r:e0c4871fe0399cf259531b5961c436abd79acadb)

## Installation

A C++20 compiler, GNU make, Cargo, rustc >= 1.88, cmake >= 3.15,
objcopy (from GNU binutils, or llvm-objcopy), and the SQLite3 library and
headers (Debian and Ubuntu `libsqlite3-dev`; the macOS SDK and Rtools have
them) are required. On macOS the build needs `llvm-objcopy`, from `PATH`
or from Homebrew's `llvm` (`brew install llvm`). On 64-bit Intel Windows,
install Rtools and add the Rust target with `rustup target add x86_64-pc-windows-gnu`; on ARM64
Windows the target is `aarch64-pc-windows-gnullvm`. The package
compiles the engine, readcon-core, and Chemfiles as it installs.

```r
install.packages("remotes")
remotes::install_github("d-SEAMS/dseams-r")
```

An `R CMD build` source tarball carries the engine, vendored Rust
dependencies for readcon-core and Linkcell, and patched chemfiles. It
installs without a separate seams-core checkout or a network connection.
A git checkout copies the engine
from `SEAMS_CORE_SRC` or downloads the revision in `tools/seams-core.ref`;
set `DSEAMS_NO_DOWNLOAD=1` to require a local source tree. The
[R API guide](https://github.com/d-SEAMS/dseams-r/blob/main/docs/api/r.md#installing-from-source) also shows how to link
an existing seams-core installation or build tree.

## Classify one frame

`ice1h.lammpstrj` is a 2x2x2 ice Ih cell: 128 oxygen sites, every one
hexagonal ice, and 256 primitive six-membered rings.

```r
library(dseams)
frame <- read_frame(dseams_example("ice1h.lammpstrj"), type = -1L)
frame
table(chill_plus(frame)$name)
primitive_rings(frame, graph = "cutoff", max_depth = 6L)
```

`type = -1` keeps every atom. A positive `type` keeps that LAMMPS species,
and `type = 0` guesses oxygen. `vignette("classifying-ice", package = "dseams")`
repeats this crystal and then a mixed TIP4P frame, including cages and
order parameters. The function reference is at
<https://r.dseams.info/reference/>.

## Authors

Rohit Goswami (`aut`, `cre`), ORCID 0000-0002-2393-8056, and Amrita
Goswami (`aut`), ORCID 0000-0001-8706-2383, wrote the package.
Ruhila Goswami (`ctb`), ORCID 0000-0002-5443-9356, contributed. The
d-SEAMS core team (`cph`) holds the copyright in the seams-core engine
sources bundled in `src/seams`. These are the DESCRIPTION `Authors@R`
roles.

## Citation

Goswami, Goswami and Singh (2020), Journal of Chemical Information and
Modeling. <https://doi.org/10.1021/acs.jcim.0c00031>. `citation("dseams")`
prints the record.

Report bugs at <https://github.com/d-SEAMS/dseams-r/issues>.
