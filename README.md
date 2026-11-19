# dseams

Ice classification and ring statistics for molecular simulations. `dseams`
reads one frame and returns data frames: CHILL+ labels, primitive rings,
cages, Steinhardt q4 and q6, hydrogen bonds, radial distribution
functions, prisms, domains, monolayers, fingerprints, coordination,
density profiles, and jump_tau90. LAMMPS dumps and XYZ files are read on
every build. Chemfiles formats are read when chemfiles was present
at compile time, and readcon `.con` files are read when readcon-core
was. readcon-core also defines `.convel`; this engine routes `.con`
(`dseams_features()`). The calculations are the
[d-SEAMS](https://dseams.info) engine.

## Documentation

- [Function reference and vignette](https://r.dseams.info/)
- [R chapter of the d-SEAMS book](https://docs.dseams.info/stable/r.html)
- [Video walk-through](https://odysee.com/dseams-r:e0c4871fe0399cf259531b5961c436abd79acadb)

## Installation

A C++20 compiler is required. The package compiles the engine as it
installs.

```r
install.packages("remotes")
remotes::install_github("d-SEAMS/dseams-r")
```

An `R CMD build` source tarball carries the engine and installs without a
separate seams-core checkout or a network connection. A git checkout instead
copies the engine from `SEAMS_CORE_SRC` or downloads the revision in
`tools/seams-core.ref`; set `DSEAMS_NO_DOWNLOAD=1` to require a local source
tree. The [R API guide](docs/api/r.md#installing-from-source) also shows how
to link an existing seams-core installation or build tree.

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

## Citation

Goswami, Goswami and Singh (2020), Journal of Chemical Information and
Modeling. <https://doi.org/10.1021/acs.jcim.0c00031>. `citation("dseams")`
prints the record.

Report bugs at <https://github.com/d-SEAMS/dseams-r/issues>.
