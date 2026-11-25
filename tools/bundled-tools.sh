#!/bin/sh
# Tools a bundled build needs. configure and configure.win source this
# file. The functions set CARGO, CMAKE and OBJCOPY in the caller, and
# they refuse a rustc, cmake or objcopy the build cannot use. The
# discovery matches the historical configure behaviour, including the
# macOS search for Homebrew's llvm-objcopy.

find_tool() {
  for _bt_tool in "$@"; do
    if command -v "${_bt_tool}" >/dev/null 2>&1; then
      command -v "${_bt_tool}"
      return 0
    fi
  done
  return 0
}

discover_reader_tools() {
  CARGO=$(find_tool cargo)
  CMAKE=$(find_tool cmake)
  OBJCOPY=$(find_tool objcopy llvm-objcopy)
  if [ "$(uname -s)" = Darwin ]; then
    OBJCOPY=$(find_tool llvm-objcopy)
    # Homebrew's llvm is keg-only, so its llvm-objcopy is often not on PATH.
    # brew names the keg; without brew on PATH, its two default prefixes
    # (Apple silicon, then Intel) are tried.
    if [ -z "${OBJCOPY}" ] && command -v brew >/dev/null 2>&1 \
      && _bt_llvm_prefix=$(brew --prefix llvm 2>/dev/null) \
      && [ -x "${_bt_llvm_prefix}/bin/llvm-objcopy" ]; then
      OBJCOPY="${_bt_llvm_prefix}/bin/llvm-objcopy"
    fi
    for _bt_keg in /opt/homebrew/opt/llvm/bin /usr/local/opt/llvm/bin; do
      if [ -z "${OBJCOPY}" ] && [ -x "${_bt_keg}/llvm-objcopy" ]; then
        OBJCOPY="${_bt_keg}/llvm-objcopy"
      fi
    done
  fi
}

require_reader_tools() {
  _bt_label=$1
  if [ -z "${CARGO}" ] || [ -z "${CMAKE}" ] || ! command -v rustc >/dev/null 2>&1; then
    printf '%s\n' "${_bt_label}: the bundled build needs rustc >= 1.88, cargo, and cmake >= 3.15 on PATH" >&2
    exit 1
  fi
  # cmake --install, which the chemfiles rule runs, is new in 3.15.
  _bt_cmake_ok=$("${CMAKE}" --version | awk '
    $1 == "cmake" && $2 == "version" {
      split($3, a, ".")
      if (a[1] > 3 || (a[1] == 3 && a[2] >= 15)) ok = 1
    }
    END { print ok + 0 }
  ')
  if [ "${_bt_cmake_ok}" != 1 ]; then
    printf '%s\n' "${_bt_label}: cmake >= 3.15 is required to build chemfiles (found $("${CMAKE}" --version | sed -n 1p))" >&2
    exit 1
  fi
  _bt_rustc_ok=$(rustc --version | awk '
    $1 == "rustc" {
      split($2, a, ".")
      if (a[1] > 1 || (a[1] == 1 && a[2] >= 88)) ok = 1
    }
    END { print ok + 0 }
  ')
  if [ "${_bt_rustc_ok}" != 1 ]; then
    printf '%s\n' "${_bt_label}: rustc >= 1.88 is required to build readcon-core (found $(rustc --version))" >&2
    exit 1
  fi
  if [ -z "${OBJCOPY}" ]; then
    printf '%s\n' "${_bt_label}: objcopy (GNU binutils) or llvm-objcopy (required on macOS, on PATH or from Homebrew llvm) is needed to build the bundled readers" >&2
    exit 1
  fi
  # A program named llvm-objcopy can be a wrapper around another objcopy.
  # Only LLVM's rewrites Mach-O symbol names, and its --version says LLVM.
  if [ "$(uname -s)" = Darwin ] \
    && ! "${OBJCOPY}" --version 2>/dev/null | sed -n 1p | grep -i -q llvm; then
    printf '%s\n' "${_bt_label}: on macOS the bundled readers need LLVM's llvm-objcopy; ${OBJCOPY} --version does not report LLVM" >&2
    exit 1
  fi
}

# Makevars.win bakes SEAMS_LANG_VERSION. Unix configure substitutes the
# version from DESCRIPTION instead, so a stale Windows file would build
# the wrong string. vendor.sh and configure.win both call this.
require_makevars_win_version() {
  _bt_root=$1
  _bt_version=$2
  _bt_label=$3
  _bt_mk=${_bt_root}/src/Makevars.win
  if [ ! -f "${_bt_mk}" ] || ! grep -q "SEAMS_LANG_VERSION='\"${_bt_version}\"'" "${_bt_mk}"; then
    printf '%s\n' "${_bt_label}: src/Makevars.win does not carry version ${_bt_version}" >&2
    return 1
  fi
  return 0
}

# basename safe to assign in a makefile. The directory may contain
# spaces; the name itself may not, and it may not introduce make syntax.
make_tool_name() {
  _bt_tool=$1
  _bt_label=$2
  _bt_base=$(basename "${_bt_tool}")
  case "${_bt_base}" in
    *[!A-Za-z0-9._-]*)
      printf '%s\n' "${_bt_label}: the tool name ${_bt_base} cannot be written into a makefile" >&2
      return 1
      ;;
  esac
  printf '%s\n' "${_bt_base}"
}
