#!/bin/sh
# Copyright (c) d-SEAMS developers
# Rewrite one static archive with tools/reader-symbols.sh and check the
# undefined names with nm. CI runs this on Linux and macOS. A missing
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
brew_llvm_objcopy() {
  if ! command -v brew >/dev/null 2>&1; then
    return 0
  fi
  prefix=$(brew --prefix llvm 2>/dev/null) || return 0
  if [ -n "${prefix}" ] && [ -x "${prefix}/bin/llvm-objcopy" ]; then
    printf '%s\n' "${prefix}/bin/llvm-objcopy"
  fi
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

config_lines CC > "${work}/cc"
config_lines AR > "${work}/ar"
sh "${symbols}" --print-map "${system_name}" > "${work}/map"
if [ ! -s "${work}/map" ]; then
  die "the symbol map for ${system_name} is empty"
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

"${nm}" -u "${archive}" | awk '/(^|[[:space:]])U([[:space:]]|$)/ { print $NF }' > "${work}/before"
while read -r from to; do
  [ -n "${from}" ] || continue
  if ! grep -F -x -q -- "${from}" "${work}/before"; then
    die "before rewrite, ${from} is not an undefined symbol in the archive"
  fi
done < "${work}/map"

sh "${symbols}" "${objcopy}" "${archive}" "${system_name}"

"${nm}" -u "${archive}" | awk '/(^|[[:space:]])U([[:space:]]|$)/ { print $NF }' > "${work}/after"
while read -r from to; do
  [ -n "${from}" ] || continue
  if ! grep -F -x -q -- "${to}" "${work}/after"; then
    die "after rewrite, ${to} is not an undefined symbol in the archive"
  fi
  if grep -F -x -q -- "${from}" "${work}/after"; then
    die "after rewrite, source symbol ${from} is still undefined"
  fi
done < "${work}/map"
