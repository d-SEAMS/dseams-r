# dseams (development version)

* Release cage, neighbour, ring, fingerprint, and brine handles, and the
  position and fingerprint scratch buffers, when an R allocation in those
  C wrappers fails. The handles are freed by `R_UnwindProtect` and the
  scratch buffers are R-managed, so an out-of-memory longjmp does not
  leak them.
* Fix `nframes()` on a readcon `.con` file when the package is linked
  against `libseams` and `libseams_lang`. Both libraries export
  `seams_path_nframes` with different arguments, and the linker bound
  the language one, which reports no frames for `.con`.
* Isolate `dseams` (`libseams_lang`) and `dseams_capi` (`libseams`) in
  linked-engine builds so `seams_path_nframes()` and `seams_last_error()`
  never collide across the two shared libraries, and delegate `nframes()`
  to the engine with no R-side extension whitelist.
* Expand `test-readers.R` with per-format read fixtures for all 18
  engine-supported formats (native LAMMPS and XYZ, chemfiles MOL2,
  mmCIF, CIF, PDB, GRO, DCD, XTC, TRR, TNG, NetCDF, SDF, CML, CSSR,
  Tinker ARC, MMTF, and readcon `.con`) and remove the unsupported
  `LAMMPS data` claim from `read_frame()` documentation.
* Wrap the remaining active `libseams` C API functions:
  `seams_capi_info()`, `seams_label_name()`, `seams_ring_symmetry_name()`,
  `seams_system_set_atoms()`, `seams_system_box()`,
  `seams_system_positions()`, `seams_system_types()`,
  `seams_system_ids()`, `seams_system_symmetry()`, `seams_q4q6()`,
  `seams_q6bar()`, `seams_ql()`, `seams_cages_labels()`,
  `seams_signature_cages_edge()`, `seams_neighbours()`, `seams_rings()`,
  `seams_rings_chordless()`, `seams_fingerprint_atoms()`, and
  `seams_brine()`.
* Credit Ruhila Goswami with ORCID 0000-0002-5443-9356 in `README.md`
  to match `DESCRIPTION`.
* Restore reader guidance for source and linked-engine installs, native
  object ownership, and the complete R language-task example.
* Redirect the former standalone print and summary reference pages to their
  consolidated API topics.
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
* Fix `tools/find-readers.sh`: an explicit `CHEMFILES_ROOT`/`CHEMFILES_LIBDIR`
  or `READCON_ROOT`/`READCON_LIBDIR` now wins over a pkg-config module on the
  ambient `PKG_CONFIG_PATH` instead of sometimes losing to it; a
  `readcon-core.pc` version pkg-config rejects as too old no longer falls
  through to the version-blind manual directory scan, which could silently
  re-accept it; and the optional readers' `-Wl,-rpath` link flag is added
  only off Windows, so `configure.win` no longer emits it.
* Fix `tools/find-readers.sh` further: an explicit `CHEMFILES_ROOT`/
  `CHEMFILES_LIBDIR` or `READCON_ROOT`/`READCON_LIBDIR` now also scopes
  `PKG_CONFIG_LIBDIR`, not just `PKG_CONFIG_PATH`, so a too-old module on
  pkg-config's own compiled-in default directories can no longer answer in
  its place; both variables are restored afterwards, unset again if they
  were unset before. `tools/test-find-readers.sh` now runs as part of the
  CI job that builds chemfiles and readcon-core.

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
