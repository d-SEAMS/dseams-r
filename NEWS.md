# dseams (development version)

* Register the C `.Call()` entry points under their `seams_r_*` symbol
  names so `cpp11::cpp_register()`, `pkgload::load_all()`, and
  `testthat::test_local()` regenerate `src/cpp11.cpp` without symbol
  mismatches.
* Name Ruhila Goswami (`ctb`, ORCID 0000-0002-5443-9356) in the README,
  with the same role and ORCID as DESCRIPTION.
* Rewrite vendored crate checksums after the hidden files are removed.
  Cargo hashes every path named in those checksums, and a missing path
  stops the offline build of readcon-core.
* Bundle readcon-core and patched chemfiles in the source package. A
  default install reads CON files and the chemfiles formats the engine
  reads, including PDB and GRO, and the source tarball builds those
  libraries without a network connection. Building the bundled copy
  needs GNU make, Cargo, rustc >= 1.88, cmake >= 3.15, and objcopy (or
  llvm-objcopy), all named in `SystemRequirements`. Cargo and CMake run
  at most two jobs, and Cargo writes nothing under the user's home.
* The bundled chemfiles also builds every VMD molfile plugin that
  chemfiles lists as compilable and whose reader returns atoms, so
  `read_frame()` reads 30 more formats, among them PQR, XSF, Gaussian
  cube, AMBER7 restart and parm7, CHARMM coordinates, Maestro, VTF,
  DESRES trajectories, and VASP POSCAR, OUTCAR, XDATCAR and vasprun.xml.
  `tools/chemfiles-molfiles.py` enables them on every vendor. Counting
  frames no longer passes a null timestep to a plugin, and an empty file
  or a plugin that finds no atoms is an error instead of a crash.
* `inst/AUTHORS` names the authors of readcon-core, every vendored Rust
  crate, chemfiles, and the libraries chemfiles bundles, and
  `LICENSE.note` gives each one's licence. The `Copyright` field of
  DESCRIPTION points to both.
* `LICENSE.note` and `inst/AUTHORS` list each vendored file whose
  licence or copyright holder differs from its library's: in the VMD
  molfile plugins, `abinitplugin.c` (open-source use only), the D. E.
  Shaw Research BSD-3-Clause files, Georgia Tech's `ply.c` (not to be
  sold) and the Regents of the University of California's `ReadPARM.h`,
  and in the other bundled libraries, the copied code and documentation
  under other terms. `LICENSE.note` states the conditions these place on
  redistribution.
* Restore reader guidance for source and linked-engine installs, native
  object ownership, and the complete R language-task example.
* Redirect the former standalone print and summary reference pages to their
  consolidated API topics.
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
