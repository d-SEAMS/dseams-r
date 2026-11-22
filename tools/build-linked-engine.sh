#!/bin/sh
# Copyright (c) d-SEAMS developers
# Build a seams-core checkout with the readers the bundled copy has, for
# the linked checks (SEAMS_LIBDIR).
#
#   sh tools/build-linked-engine.sh SEAMS_CORE_TREE [BUILD_DIR]
#
# The bundled copy differs from seams-core at the pin in two reader
# changes that tools/vendor-readers.sh makes: tools/patch-lang-nframes.py
# counts CON frames in seams_path_nframes, and chemfiles registers the
# VMD molfile readers from tools/chemfiles-molfiles.py. tests/testthat
# requires both from the build under test, without a skip. This script
# applies the same nframes patch to bindings/cxx/seams_lang.cpp, builds
# the chemfiles tree in src/chemfiles (written by tools/vendor.sh, so run
# that first) as a static PIC library, and configures seams-core with
# -Dchemfiles_dir pointing at it and readcon-core required. It stops when
# meson does not report both readers. Run it where meson, ninja, cmake,
# cargo, python3 and a C++ compiler are on PATH, such as `pixi run` in
# the seams-core tree.
set -eu

die() {
  printf 'build-linked-engine.sh: %s\n' "$1" >&2
  exit 1
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: build-linked-engine.sh SEAMS_CORE_TREE [BUILD_DIR]" >&2
  exit 2
fi

pkg=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
root=$(CDPATH= cd -- "$1" && pwd)
build=${2:-${root}/build}
chem_src=${pkg}/src/chemfiles
chem_prefix=${build}-chemfiles

[ -f "${root}/meson.build" ] && [ -f "${root}/bindings/cxx/seams_lang.cpp" ] \
  || die "${root} is not a seams-core tree"
[ -f "${chem_src}/CMakeLists.txt" ] \
  || die "${chem_src} is missing; run tools/vendor.sh first"
grep -q seams_with_frame "${chem_src}/src/Trajectory.cpp" \
  || die "${chem_src} does not carry the seams-core chemfiles patches"
grep -q 'VMD molfile pqrplugin' "${chem_src}/src/formats/Molfile.cpp" \
  || die "${chem_src} does not register the VMD molfile readers"
for tool in meson ninja cmake python3; do
  command -v "${tool}" >/dev/null 2>&1 || die "${tool} is not on PATH"
done

python3 "${pkg}/tools/patch-lang-nframes.py" "${root}/bindings/cxx/seams_lang.cpp"

chem_build=$(mktemp -d "${TMPDIR:-/tmp}/dseams-linked-chemfiles.XXXXXX")
trap 'rm -rf "${chem_build}"' EXIT
rm -rf "${chem_prefix}"
cmake -G Ninja -S "${chem_src}" -B "${chem_build}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${chem_prefix}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DBUILD_SHARED_LIBS=OFF \
  -DCHFL_BUILD_TESTS=OFF \
  -DCHFL_BUILD_DOCUMENTATION=OFF \
  -DCHFL_SYSTEM_ZLIB=OFF \
  -DCHFL_SYSTEM_LZMA=OFF \
  -DCHFL_SYSTEM_BZIP2=OFF
cmake --build "${chem_build}"
cmake --install "${chem_build}"
[ -f "${chem_prefix}/lib/libchemfiles.a" ] \
  || die "chemfiles did not install ${chem_prefix}/lib/libchemfiles.a"

# A static library, so the unpatched conda libchemfiles.so that may sit
# first on the rpath cannot stand in for it at run time.
set -- -Dchemfiles_dir="${chem_prefix}" -Dwith_chemfiles=enabled -Dwith_readcon=enabled
if [ -d "${build}/meson-private" ]; then
  set -- --reconfigure "$@"
fi
summary=${chem_build}/meson-setup.log
(cd "${root}" && meson setup "${build}" "$@") | tee "${summary}"
grep -E 'readers \(chemfiles\) *: *YES \(0\.10\.4, chemfiles_dir\)' "${summary}" >/dev/null \
  || die "meson did not take chemfiles from ${chem_prefix}"
grep -E '\.con reader \(readcon-core\) *: *YES' "${summary}" >/dev/null \
  || die "meson did not enable the readcon-core .con reader"

ninja -C "${build}" seams src/libseams.so bindings/libseams_lang.so bindings/binding_oracle
