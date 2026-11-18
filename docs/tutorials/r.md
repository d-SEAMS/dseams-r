# R tutorial

d-SEAMS 2.14.1.

```bash
git clone https://github.com/d-SEAMS/dseams-r
R CMD INSTALL dseams-r
Rscript -e 'library(dseams); print(packageVersion("dseams"))'
```

`R CMD INSTALL` compiles the package's own copy of the engine. In a git
checkout `tools/vendor.sh` makes that copy
from the seams-core tree `SEAMS_CORE_SRC` names, or downloads the
seams-core tag pinned in `tools/seams-core.ref` (`v2.14.1`). `SEAMS_LIBDIR`
(with `DSEAMS_ROOT`) links a seams-core build tree instead, and
`DSEAMS_SYSTEM_ENGINE=1` an installed one found by pkg-config.

The vignette runs on the example dumps in `inst/extdata`, which ship with
the package. With `DSEAMS_ROOT` set to a seams-core checkout, the
testthat suite also checks the cubic dump in its `input/traj`:

```bash
DSEAMS_ROOT=/path/to/seams-core R CMD check dseams_2.14.1.tar.gz
```


## Nucleation example

```{figure} https://raw.githubusercontent.com/d-SEAMS/seams-core/v2.14.1/docs/nucleation/figshare-4096.png
:alt: Classifier results for an mW nucleation trajectory
:width: 480px

CHILL+, q6-bar, OVITO, and diamond-CNA results for a 4,096-molecule mW
nucleation trajectory.
```

