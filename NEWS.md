# dseams 2.14.1 (2026-11-17)

* Prepare the package's initial CRAN submission.
* Keep the R package patch version separate from the pinned seams-core
  version. This release binds seams-core `v2.14.0`.
* Remove the unpublished package-site URL from package metadata.

# dseams 2.14.0 (2026-11-17)

* Initial release prepared for submission to CRAN.
* Classify ice with CHILL+ (`chill_plus`), count primitive rings
  (`primitive_rings`), find hexagonal and double-diamond cages (`cages`,
  `signature_cages`), and compute Steinhardt parameters (`steinhardt`,
  `q4_q6`) and shell symmetry labels (`symmetry`) on one LAMMPS or XYZ
  frame.
* The engine is the bundled copy of the seams-core tag `v2.14.0`.
  Installing the source package does not use the network; an install from
  git copies or downloads that tag, as pinned in `tools/seams-core.ref`.
* `DSEAMS_SYSTEM_ENGINE=1` links an installed seams-core through
  pkg-config, and `SEAMS_LIBDIR` links a seams-core build tree.
* The package has its own repository, <https://github.com/d-SEAMS/dseams-r>.
