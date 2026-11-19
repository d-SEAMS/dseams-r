# dseams

Ice classification and ring statistics for molecular simulations. `dseams`
reads one frame of a LAMMPS dump or an XYZ file and returns data frames:
CHILL+ labels, primitive rings, hexagonal and double-diamond cages, and
Steinhardt order parameters. The calculations are the
[d-SEAMS](https://dseams.info) engine.

## Installation

A C++20 compiler is required. The package compiles the engine as it
installs.

```r
install.packages("remotes")
remotes::install_github("d-SEAMS/dseams-r")
```

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

A video walk-through of the same dumps:
<https://odysee.com/dseams-r:e0c4871fe0399cf259531b5961c436abd79acadb>.
