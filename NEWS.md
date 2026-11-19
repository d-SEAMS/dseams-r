# dseams (development version)

* Optional chemfiles and readcon-core readers. `read_frame()`,
  `nframes()`, and `seams_system_read()` read LAMMPS dumps and XYZ files
  on every build. When chemfiles (>= 0.10.4, < 0.11) is found they also
  read the chemfiles formats (PDB, GRO, DCD, and the rest of that set).
  When readcon-core (>= 0.16.2) is found they also read `.con` files,
  and `.convel` files when the engine routes that extension.
  `dseams_features()` reports which readers were compiled in. A build
  with neither library still reads LAMMPS dumps and XYZ files.
* Record ORCID 0000-0002-5443-9356 for Ruhila Goswami, and name the
  exported analyses and the optional readers in DESCRIPTION.

* Rewrite the README, the vignette, and the help pages around reading one
  frame and reading the data frames that come back. Every exported
  function has a runnable example.
* `print()` on a frame reports `atoms` instead of `nop`. `summary()` on
  a system handle reports the loaded frame.
* Give the site favicon an SVG media type that browsers accept.
* Publish the srr standards note and link it from the navbar as
  rOpenSci standards.

# dseams 2.14.1 (2026-11-17)

* Update the bundled d-SEAMS engine to seams-core 2.14.1.
* Scale neighbour searches across OpenMP threads.
* Copy less data during ring and cage searches.
* Use fewer CPUs for engine calls when other processes keep the machine busy.
* Preserve the caller's thread-affinity settings and restore temporary worker
  placement after each analysis.
* Reuse large freed buffers between analyses on glibc to reduce run-to-run
  timing variation. Set `SEAMS_MALLOC_TUNE=0` to retain the process defaults.
* Fix races in k-nearest-neighbour construction and concurrent ring and cage
  diagnostics.

# dseams 2.14.0 (2026-11-17)

* Initial package release.
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
