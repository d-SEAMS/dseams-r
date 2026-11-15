# Contributing to dseams

This repository holds the R package. The engine it binds is
[seams-core](https://github.com/d-SEAMS/seams-core); its
[contributing guide](https://github.com/d-SEAMS/seams-core/blob/main/CONTRIBUTING.md)
and the [code of conduct](CODE_OF_CONDUCT.md) apply here. Engine bugs go
to seams-core, bugs in the R interface to
<https://github.com/d-SEAMS/dseams-r/issues>.

## Checks

`src/seams` and `inst/extdata` are produced by `tools/vendor.sh` from a
seams-core source tree (`SEAMS_CORE_SRC`, or the revision in
`tools/seams-core.ref`, which it downloads). They are not stored in git.
`configure` runs that script when they are missing.

```sh
SEAMS_CORE_SRC=/path/to/seams-core sh tools/vendor.sh
R CMD build .
DSEAMS_ROOT=/path/to/seams-core R CMD check --as-cran dseams_*.tar.gz
```

`pixi run vendor`, `pixi run build` and `pixi run check` do the same in an
environment that has R and every package in Suggests.

Moving to a new engine release means changing `tools/seams-core.ref`, the
`Version` in `DESCRIPTION` and the version in `src/Makevars.win`
together; `tools/vendor.sh` refuses a `Makevars.win` that disagrees with
`DESCRIPTION`. A new engine source file is listed once in the `seams/*.o`
block of `src/Makevars.in` and once in `src/Makevars.win`.

Use at most two compile jobs (`MAKEFLAGS=-j2`). Tests and examples use at
most two OpenMP threads when `_R_CHECK_LIMIT_CORES_` is set.

Coverage of the R sources:

```r
covr::package_coverage()
```

The C++ engine is covered by the seams-core tests. `covr` reports the R
functions and the small amount of glue that R executes.
