# dseams (development version)

* The vendored chemfiles build uses a new `chemfiles-build.XXXXXX`
  directory under `src` for that build, and removes it afterwards.
  `$(TEMP)/dseams-chemfiles-build` is not used, so two installs do not
  share one cmake build directory. `cleanup` and `cleanup.win` remove
  a directory that a stopped build leaves behind.

* `configure.win` refuses `SEAMS_LIBDIR` and `DSEAMS_SYSTEM_ENGINE`.
  Windows builds only the bundled engine. `cleanup.win` removes
  `src/rust-target.mk` and the object files, reader build trees and
  `src/Makevars` that a Windows build writes. R runs `cleanup.win`
  instead of `cleanup`.

* `License` stays `MIT + file LICENSE`, and `License_restricts_use` is
  `yes`. File `LICENSE` names the restricted components whose terms
  `LICENSE.note` quotes: `abinitplugin.c` may not be part of a
  closed-source project, and `ply.c` and `ply.h` may not be sold.
* `Authors@R` credits Olaf Lenz for `vtfplugin.c`, beside Henri Menke.
  `LICENSE.note` names the copyright holders and credited authors that
  vendored source headers name. `tools/check-header-authors.py` fails
  when one of those names is absent from `Authors@R` and from
  `LICENSE.note`.
* `configure` and `configure.win` read one list, `tools/vendored-sentinels`,
  and run `tools/vendor.sh` when any entry is missing, including
  `src/readcon-core/Cargo.toml`, `src/chemfiles/src/Trajectory.cpp` and
  `inst/extdata/tiny.pdb`. `configure.win` applies the bundled requirements
  on rustc >= 1.88, cargo, cmake >= 3.15 and objcopy, stops when the
  readcon crate checksum is absent, stops when `src/Makevars.win` does
  not carry `Version` from DESCRIPTION, and records the cargo, cmake and
  objcopy it found in `src/rust-target.mk`.
* The R API page says a linked engine reads only the formats its seams-core
  build enabled, and gives the `meson setup` line with the chemfiles and
  readcon readers required, as the linked CI job builds it.
* The bundled `FormatFactory.cpp` includes `<type_traits>` before
  `chemfiles/formats/MMTF.hpp`, as `MMTF.cpp` does, so neither source
  that reaches mmtf-cpp's msgpack-c depends on another header for
  `std::remove_volatile` (missing through libc++'s headers).
* `tools/reader-symbols.sh` picks the ELF, Mach-O or COFF symbol names
  from the magic number of the first object in the archive instead of
  from `uname`, so an archive built for another platform gets that
  platform's names, and an archive with no such object is an error.
  `--format ARCHIVE` prints the format it reads.
* The checked `sprintf` wrappers of the bundled readers clamp the object
  size to `INT_MAX` before calling `vsnprintf`. Darwin's `__sprintf_chk`
  passes `(size_t)-1` for an unknown size, for which `vsnprintf` returned
  -1 and wrote nothing. A negative `vsnprintf` count is now an R error.
* On macOS the bundled readers need LLVM's `llvm-objcopy`: GNU objcopy
  does not rewrite Mach-O archives. `configure` takes it from `PATH`, else
  from Homebrew's keg-only `llvm` (`brew --prefix llvm`, or
  `/opt/homebrew/opt/llvm/bin` and `/usr/local/opt/llvm/bin` when `brew`
  is not on `PATH`), and stops when the program it chose does not report
  LLVM in `--version`.
* The linked CI jobs configure seams-core with chemfiles and readcon-core
  enabled, so `meson setup` stops instead of building an engine without
  them. The engine they build registers the same 58 chemfiles formats as
  the bundled copy, the 37 VMD molfile readers among them.
* The shared library loses its debug sections after linking, through the
  debug-only strip command in R's `Makeconf` (`strip --strip-debug`,
  `strip -S` on macOS). The symbol table, every reader and every format
  stay; `DSEAMS_KEEP_DEBUG=1` keeps the debug sections.
* The bundled chemfiles carries every seams-core chemfiles patch, not
  only the mmCIF, MOL2 and frame-visit ones. `tools/vendor-readers.sh`
  applies them in the order seams-core's `ChemfilesDep.cmake` uses and
  stops when the pinned seams-core has a patch it does not apply. The
  LAMMPS Data reader reports an unknown header line instead of looping,
  readers of hostile files check their sizes, counts and indices (in
  chemfiles and in its molfiles, TNG, mmtf-cpp and gemmi sources), and
  `span` builds under `NDEBUG`. The molfile readers come from seams-core's
  molfiles patch, which registers the same 33 formats as before plus the
  DESRES `.dms`, Gromacs `.g96`, CPMD 3.x output (`.out`) and Gaussian
  log readers. `tools/chemfiles-molfiles.py` now checks that plugin list
  and keeps the MinGW and MMTF edits. The DESRES reader links SQLite3,
  which `SystemRequirements` names.
* The cubic-ice test runs instead of skipping when `DSEAMS_ROOT` has no
  `input/traj/mW_cubic.lammpstrj` (seams-core moved that file out of git
  into the Hugging Face dataset `d-SEAMS/seams-core-inputs`). The test
  helper uses a copy in `$DSEAMS_ROOT/input/traj` or `DSEAMS_INPUT_CACHE`,
  else `$DSEAMS_ROOT/input/fetch.py` when `DSEAMS_ROOT` and `python3` are
  there, else `download.file()` into `DSEAMS_INPUT_CACHE` or the session
  temp directory, and checks the SHA-256 pinned by seams-core v2.14.2. A
  local copy with another digest, a failing `fetch.py`, a failed download
  or a different digest fails the test. Only with no local source does the
  test skip, on CRAN and when huggingface.co is unreachable, and it says
  why; `DSEAMS_REQUIRE_DATA=1` turns that skip into an error.
* `LICENSE.note` quotes the terms of `abinitplugin.c` (Rob Lahaye) and of
  `ply.c` and `ply.h` (Greg Turk, Georgia Institute of Technology) as their
  headers give them, `inst/AUTHORS` names their authors, and DESCRIPTION
  lists the holders of the molfile files that carry their own terms in
  `Authors@R` and `Copyright`.
* `LICENSE.note` lists `tngplugin.cxx` under BSD with TNG's terms, the
  LGPL-2.1-or-later TNG developer scripts, the Apache-2.0
  `iralib_interf.h` (Miha Gunde) in the engine, and the named holders of
  the vendored crates; `either` 1.19.0 names none upstream, and
  `inst/AUTHORS` credits its author, Ulrik Sverdrup. `Authors@R` adds Henri
  Menke (`vtfplugin.c`) and Miha Gunde. `tools/audit-licence-headers.py`
  also reports credited authors that `inst/AUTHORS` does not name.
* The vendored `linkcell` and `minimage` crates no longer ship their
  `CITATION.cff`, which R CMD check reports as a CITATION file outside
  `inst/`. Their author, Rohit Goswami, is listed for both crates in
  `inst/AUTHORS`, and their licences stay in `LICENSE.note`.
* `tools/vendor-readers.sh` stops when a vendored crate still has a
  dotted path or a path ending in `.d` after its removal list runs.
  R CMD build hides the first and drops the second (its exclude pattern
  `^src/.*\.d$`), and a checksum that still lists such a file makes the
  offline cargo build stop.
* The bundled chemfiles writes its generated `config.h` and `exports.h`
  with LF line endings on every platform. `configure_file()` without
  `NEWLINE_STYLE` writes through a text-mode stream, which is CRLF on
  Windows, and R CMD check there reported both headers under
  `src/chemfiles-install`. `tools/chemfiles-lf-headers.py` sets
  `NEWLINE_STYLE LF` on `config.h` and passes the export header through
  one more `configure_file(@ONLY NEWLINE_STYLE LF)`.
* `inst/AUTHORS` and `LICENSE.note` name the Rust standard library,
  compiler-rt, libm, and the other crates rustc archives into
  `libreadcon_core.a` that the vendor tree does not already list.
  Their licence texts are in `inst/licenses/readcon-sysroot`.
* The bundled chemfiles and readcon-core static libraries are built with
  `-DNDEBUG`. The CMake Release flags had replaced CMake's default, so
  `assert` stayed in `libchemfiles.a`. readcon-core's release profile
  leaves Rust debug assertions and overflow checks off, and the cargo
  line passes `-DNDEBUG` to a C file it compiles.
* `tiny.mae` and `tiny.mmtf` are one water molecule shipped with the
  package. The Maestro plugin and the MMTF reader return that water.
  The portability tests read these files, so they run from an installed
  package as well as from the source tree.
* On Windows, readcon-core is built for the Rust GNU target of the
  Rtools compiler: `aarch64-pc-windows-gnullvm` when the compiler's
  `-dumpmachine` names aarch64, else `x86_64-pc-windows-gnu`.
  `RUST_TARGET` still overrides it. `configure.win` stops with the
  `rustup target add` command to run when that target's standard
  library is missing, and CMake is run with the "Unix Makefiles"
  generator so it uses the MinGW compilers instead of Visual Studio.
* The bundled chemfiles builds with CMake 4. CMake 4 refuses a
  `cmake_minimum_required()` below 3.5, and chemfiles 0.10.4 and the
  libraries it unpacks from `external/*.tar.gz` (zlib, lzma, bzip2, fmt,
  toml11, tng, molfiles, pugixml, mmtf-cpp) asked for 2.8 to 3.5.
  `tools/chemfiles-cmake-floor.py` rewrites each of those 15 calls to
  `VERSION 3.5...3.10` when the readers are vendored and refuses a tree
  that still has one below; a test checks the shipped tree. The policy
  version stays below 3.22, so every chemfiles target compiles with the
  same flags as before. All formats and molfile plugins are kept.
* `LICENSE.note` and `inst/AUTHORS` record the copyright headers on
  `hoomdplugin.c` (Axel Kohlmeyer, 2009) and `plyplugin.cxx` (the
  University of Illinois, 1995-2016). Both are distributed under the
  UIUC licence that chemfiles vendors with the VMD molfile plugins.
  `plyplugin.cxx` includes `ply.c` and is not compiled; the "not sold"
  condition on `ply.c` would apply if it were.
* The bundled readers' symbol rewrite also covers `vprintf` and
  `__vprintf_chk`, which write to the R console and return 0. On
  Windows the UCRT `__acrt_iob_func` and its dllimport slot are
  rewritten too; stdin still comes from the C runtime. On macOS the
  rewrite uses the Mach-O names, which carry one more leading underscore
  (`___printf_chk`, `__ZSt4cout`).
  `tools/reader-symbols.sh --print-map FORMAT` prints the rename list
  for one object format and stops on a duplicate source name.

# dseams 2.14.2 (2026-11-24)

- The bundled engine uses Linkcell for neighbour lists. R source packages carry the Rust dependencies for offline installation.
- `read_frame()` reports an error when an empty file yields a frame with zero atoms.
- `nframes()` uses the core C API for CON files in bundled and linked-engine installs.

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
