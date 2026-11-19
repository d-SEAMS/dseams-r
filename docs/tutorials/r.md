# Classify ice from R

`dseams` reads one frame and returns data frames of CHILL+ labels,
primitive rings, cages, and Steinhardt order parameters. LAMMPS dumps
and XYZ files are read on every build. Chemfiles formats are read when
chemfiles is compiled in, and readcon `.con` files are read when
readcon-core is. readcon-core also defines `.convel`; this engine
routes `.con`.

Install needs a C++20 compiler. The package compiles the engine as it
installs.

```bash
git clone https://github.com/d-SEAMS/dseams-r
R CMD INSTALL dseams-r
```

From inside R the same install is:

```r
install.packages("remotes")
remotes::install_github("d-SEAMS/dseams-r")
```

The package ships three dumps. `ice1h.lammpstrj` is a 2x2x2 ice Ih cell.

```r
library(dseams)
frame <- read_frame(dseams_example("ice1h.lammpstrj"), type = -1L)
table(chill_plus(frame)$name)
primitive_rings(frame, graph = "cutoff", max_depth = 6L)
cages(frame)
```

Every one of the 128 oxygens is hexagonal ice, the cutoff graph holds
256 primitive six-rings, and every oxygen sits in a hexagonal cage.
`vignette("classifying-ice", package = "dseams")` continues with a
mixed TIP4P frame: the cutoff neighbour list and the mutual
four-neighbour list, then q4, q6, and a cage census.

![CHILL+, q6-bar, OVITO, and diamond-CNA results for a 4,096-molecule mW nucleation trajectory.](https://raw.githubusercontent.com/d-SEAMS/seams-core/v2.14.1/docs/nucleation/figshare-4096.png)
