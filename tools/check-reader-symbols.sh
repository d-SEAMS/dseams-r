#!/bin/sh
# Copyright (c) d-SEAMS developers
# Rewrite one static archive with tools/reader-symbols.sh and check the
# undefined names with nm. Then compile a reader that calls abort(),
# check the rewrite renames that call, and check that a rewrite which
# misses abort is rejected. CI runs this on Linux and macOS. A missing
# tool is a failure: this script does not skip.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
symbols=${root}/tools/reader-symbols.sh
system_name=${1:-$(uname -s 2>/dev/null || echo unknown)}

die() {
  printf 'check-reader-symbols.sh: %s\n' "$1" >&2
  exit 1
}

find_tool() {
  for tool in "$@"; do
    if command -v "${tool}" >/dev/null 2>&1; then
      command -v "${tool}"
      return 0
    fi
  done
  return 0
}

objcopy_is_llvm() {
  "$1" --version 2>/dev/null | awk 'NR==1 { print tolower($0) }' | grep -q llvm
}

# Homebrew llvm is keg-only, so llvm-objcopy is often absent from PATH.
# brew names the keg; without brew on PATH, its two default prefixes
# (Apple silicon, then Intel) are tried, as configure does.
brew_llvm_objcopy() {
  if command -v brew >/dev/null 2>&1 \
    && prefix=$(brew --prefix llvm 2>/dev/null) \
    && [ -n "${prefix}" ] && [ -x "${prefix}/bin/llvm-objcopy" ]; then
    printf '%s\n' "${prefix}/bin/llvm-objcopy"
    return 0
  fi
  for keg in /opt/homebrew/opt/llvm/bin /usr/local/opt/llvm/bin; do
    if [ -x "${keg}/llvm-objcopy" ]; then
      printf '%s\n' "${keg}/llvm-objcopy"
      return 0
    fi
  done
  return 0
}

case "${system_name}" in
  Darwin)
    objcopy=$(find_tool llvm-objcopy)
    if [ -z "${objcopy}" ]; then
      objcopy=$(brew_llvm_objcopy)
    fi
    if [ -z "${objcopy}" ]; then
      objcopy=$(find_tool objcopy)
    fi
    if [ -z "${objcopy}" ]; then
      die "llvm-objcopy is not on PATH and Homebrew llvm was not found"
    fi
    if ! objcopy_is_llvm "${objcopy}"; then
      die "on Darwin, llvm-objcopy is required for Mach-O symbol rewriting (found ${objcopy})"
    fi
    ;;
  *)
    objcopy=$(find_tool objcopy llvm-objcopy)
    if [ -z "${objcopy}" ]; then
      die "objcopy (GNU binutils) or llvm-objcopy is not on PATH"
    fi
    ;;
esac

nm=$(find_tool nm llvm-nm)
if [ -z "${nm}" ]; then
  die "nm or llvm-nm is not on PATH"
fi
if ! command -v R >/dev/null 2>&1; then
  die "R is not on PATH, so the C compiler and ar cannot be read from R CMD config"
fi

# Print the program and each flag on its own line. The caller reads them
# back without splitting on spaces inside a flag.
config_lines() {
  key=$1
  line=$(R CMD config "${key}") || die "R CMD config ${key} failed"
  line=$(printf '%s' "${line}" | tr -d '\r')
  set -f
  old_ifs=${IFS}
  IFS=' '
  # The flags R CMD config emits for this package contain no spaces.
  # shellcheck disable=SC2086
  set -- ${line}
  IFS=${old_ifs}
  set +f
  if [ "$#" -lt 1 ] || [ -z "$1" ]; then
    die "R CMD config ${key} did not name a program"
  fi
  if ! command -v "$1" >/dev/null 2>&1 && [ ! -x "$1" ]; then
    die "R CMD config ${key} names '$1', which is not executable"
  fi
  printf '%s\n' "$@"
}

work=$(mktemp -d "${TMPDIR:-/tmp}/dseams-symbols.XXXXXX")
trap 'rm -rf "${work}"' EXIT

# The objects R's compiler writes on this host. reader-symbols.sh reads
# the format from the archive, and must reach the same answer.
case "${system_name}" in
  Darwin) format=mach-o ;;
  MINGW* | MSYS* | CYGWIN* | Windows*) format=coff ;;
  *) format=elf ;;
esac

config_lines CC > "${work}/cc"
config_lines AR > "${work}/ar"
sh "${symbols}" --print-map "${format}" > "${work}/map"
if [ ! -s "${work}/map" ]; then
  die "the ${format} symbol map is empty"
fi

src=${work}/fixture.c
obj=${work}/fixture.o
archive=${work}/libfixture.a
i=0
while read -r from to; do
  [ -n "${from}" ] || continue
  i=$((i + 1))
  printf 'extern char dseams_fix_%s __asm__("%s");\n' "${i}" "${from}"
done < "${work}/map" > "${src}"
printf '\nunsigned long dseams_r_touch(void) {\n  unsigned long n = 0;\n' >> "${src}"
i=0
while read -r from to; do
  [ -n "${from}" ] || continue
  i=$((i + 1))
  printf '  n ^= (unsigned long)&dseams_fix_%s;\n' "${i}"
done < "${work}/map" >> "${src}"
printf '  return n;\n}\n' >> "${src}"

set --
while read -r arg; do
  set -- "$@" "${arg}"
done < "${work}/cc"
compiler=$1
shift
"${compiler}" "$@" -c "${src}" -o "${obj}"

set --
while read -r arg; do
  set -- "$@" "${arg}"
done < "${work}/ar"
archiver=$1
shift
"${archiver}" "$@" crs "${archive}" "${obj}"

# Write the undefined names of ARCHIVE to OUT, one per line, as the
# object file spells them: Mach-O names keep their leading underscore,
# which the Darwin map also carries. nm -P prints "name type ..." on
# GNU nm, llvm-nm and Apple nm. Plain nm -u differs: GNU nm prints a U
# column, llvm-nm and Apple nm print bare names for Mach-O. The member
# header nm prints must name MEMBER, so the archive read is the one built.
undefined_symbols() {
  u_archive=$1
  u_member=$2
  u_out=$3
  if ! "${nm}" -u -P "${u_archive}" > "${u_out}.nm"; then
    printf 'check-reader-symbols.sh: %s -u -P %s failed\n' "${nm}" "${u_archive}" >&2
    return 1
  fi
  if ! grep -F -q -- "${u_member}" "${u_out}.nm"; then
    printf 'check-reader-symbols.sh: nm output for %s does not name member %s:\n' \
      "${u_archive}" "${u_member}" >&2
    cat "${u_out}.nm" >&2
    return 1
  fi
  awk '$2 == "U" { print $1 }' "${u_out}.nm" > "${u_out}"
  if [ ! -s "${u_out}" ]; then
    printf 'check-reader-symbols.sh: nm lists no undefined symbols in %s:\n' "${u_archive}" >&2
    cat "${u_out}.nm" >&2
    return 1
  fi
  return 0
}

# Each map source in SOURCES must be undefined in ARCHIVE before the
# rewrite. Prints the first missing one and fails.
require_sources() {
  r_list=$1
  r_sources=$2
  r_when=$3
  while read -r from to; do
    [ -n "${from}" ] || continue
    if ! grep -F -x -q -- "${from}" "${r_list}"; then
      printf 'check-reader-symbols.sh: %s, %s is not an undefined symbol in the archive\n' \
        "${r_when}" "${from}" >&2
      return 1
    fi
  done < "${r_sources}"
  return 0
}

# After the rewrite no map source may be undefined, and the wrapper each
# source maps to must be undefined in its place when SOURCES held it.
require_rewritten() {
  w_list=$1
  w_before=$2
  w_map=$3
  status=0
  while read -r from to; do
    [ -n "${from}" ] || continue
    if grep -F -x -q -- "${from}" "${w_list}"; then
      printf 'check-reader-symbols.sh: after rewrite, source symbol %s is still undefined\n' \
        "${from}" >&2
      status=1
    fi
    if grep -F -x -q -- "${from}" "${w_before}" \
      && ! grep -F -x -q -- "${to}" "${w_list}"; then
      printf 'check-reader-symbols.sh: after rewrite, %s is not an undefined symbol in the archive\n' \
        "${to}" >&2
      status=1
    fi
  done < "${w_map}"
  return "${status}"
}

undefined_symbols "${archive}" fixture.o "${work}/before" || exit 1
require_sources "${work}/before" "${work}/map" "before rewrite" || exit 1

found=$(sh "${symbols}" --format "${archive}")
if [ "${found}" != "${format}" ]; then
  die "reader-symbols.sh reads ${archive} as ${found}, not ${format}"
fi
sh "${symbols}" "${objcopy}" "${archive}"

undefined_symbols "${archive}" fixture.o "${work}/after" || exit 1
require_rewritten "${work}/after" "${work}/before" "${work}/map" || exit 1

# A reader that really calls abort(). The compiler spells the call the
# way the platform does, so the map's spelling of abort must match it.
abort_from=$(awk '$2 ~ /^_?dseams_r_abort$/ { print $1 }' "${work}/map")
if [ -z "${abort_from}" ]; then
  die "the ${format} map has no entry for abort"
fi
awk -v f="${abort_from}" '$1 == f' "${work}/map" > "${work}/abort-map"

reader_src=${work}/reader.c
reader_obj=${work}/reader.o
cat > "${reader_src}" << 'EOF'
#include <stdlib.h>

int dseams_reader_fail(int code) {
  if (code != 0) {
    abort();
  }
  return code;
}
EOF
set --
while read -r arg; do
  set -- "$@" "${arg}"
done < "${work}/cc"
shift
"${compiler}" "$@" -c "${reader_src}" -o "${reader_obj}"
set --
while read -r arg; do
  set -- "$@" "${arg}"
done < "${work}/ar"
shift

# The real rewrite turns abort into the wrapper.
"${archiver}" "$@" crs "${work}/libreader.a" "${reader_obj}"
undefined_symbols "${work}/libreader.a" reader.o "${work}/reader-before" || exit 1
require_sources "${work}/reader-before" "${work}/abort-map" "in the abort() reader" || exit 1
sh "${symbols}" "${objcopy}" "${work}/libreader.a"
undefined_symbols "${work}/libreader.a" reader.o "${work}/reader-after" || exit 1
require_rewritten "${work}/reader-after" "${work}/reader-before" "${work}/map" || exit 1

# A rewrite that renames every map symbol except abort must be rejected,
# and the rejection must name abort.
"${archiver}" "$@" crs "${work}/libmissed.a" "${reader_obj}"
set -- "${objcopy}"
while read -r from to; do
  [ -n "${from}" ] || continue
  [ "${from}" = "${abort_from}" ] && continue
  set -- "$@" --redefine-sym "${from}=${to}"
done < "${work}/map"
"$@" "${work}/libmissed.a"
undefined_symbols "${work}/libmissed.a" reader.o "${work}/missed-after" || exit 1
if require_rewritten "${work}/missed-after" "${work}/reader-before" "${work}/map" \
  2> "${work}/missed.log"; then
  die "a rewrite that leaves ${abort_from} undefined was accepted"
fi
if ! grep -F -q -- "source symbol ${abort_from} is still undefined" "${work}/missed.log"; then
  cat "${work}/missed.log" >&2
  die "the rejected rewrite did not name ${abort_from}"
fi
