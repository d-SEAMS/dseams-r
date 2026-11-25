#!/bin/sh
# Copyright (c) d-SEAMS developers
# Rename symbols Writing R Extensions rejects, inside one static archive,
# onto the wrappers in src/dseams_r_io.cpp. The archive is rewritten in
# place. Signatures of the replacements match the symbols they stand in for.
#
# printf, vprintf, __printf_chk and __vprintf_chk write to the R console
# and return 0. They do not return a character count. puts returns 0.
# putchar returns the character it wrote. sprintf, vsprintf and the
# checked sprintf wrappers return the count from vsnprintf. The checked
# sprintf wrappers clamp an object size above INT_MAX, such as the
# (size_t)-1 Darwin passes for an unknown size, to INT_MAX, and stop with
# an R error when vsnprintf fails or the text does not fit. __assert_rtn, the Darwin assert handler, stops with an R
# error that names the failed assertion.
#
# The generic list is ELF and COFF names, and it is emitted only from
# the *) branch. Darwin has its own list of Mach-O names. Each C symbol
# and its target gain one leading underscore. The iostream targets are
# the literal asm labels in src/dseams_r_io.cpp, which Mach-O does not
# prefix.
# ___stdoutp and ___stderrp are the FILE* variables the macOS SDK uses
# for stdout and stderr. They are renamed onto the FILE* objects
# dseams_r_stdout and dseams_r_stderr, not onto functions.
# Windows is the *) branch plus the UCRT function __acrt_iob_func and
# its dllimport slot __imp___acrt_iob_func.
set -eu

generic_map() {
  cat << 'EOF'
abort dseams_r_abort
__assert_rtn dseams_r_assert_rtn
exit dseams_r_exit
_exit dseams_r__exit
_Exit dseams_r__Exit
printf dseams_r_printf
vprintf dseams_r_vprintf
__printf_chk dseams_r_printf_chk
__vprintf_chk dseams_r_vprintf_chk
puts dseams_r_puts
putchar dseams_r_putchar
sprintf dseams_r_sprintf
vsprintf dseams_r_vsprintf
__sprintf_chk dseams_r_sprintf_chk
__vsprintf_chk dseams_r_vsprintf_chk
stdout dseams_r_stdout
stderr dseams_r_stderr
_ZSt4cout dseams_r_cout
_ZSt4cerr dseams_r_cerr
_ZNSt3__14coutE dseams_r_cout_libcxx
_ZNSt3__14cerrE dseams_r_cerr_libcxx
EOF
}

darwin_map() {
  cat << 'EOF'
_abort _dseams_r_abort
___assert_rtn _dseams_r_assert_rtn
_exit _dseams_r_exit
__exit _dseams_r__exit
__Exit _dseams_r__Exit
_printf _dseams_r_printf
_vprintf _dseams_r_vprintf
___printf_chk _dseams_r_printf_chk
___vprintf_chk _dseams_r_vprintf_chk
_puts _dseams_r_puts
_putchar _dseams_r_putchar
_sprintf _dseams_r_sprintf
_vsprintf _dseams_r_vsprintf
___sprintf_chk _dseams_r_sprintf_chk
___vsprintf_chk _dseams_r_vsprintf_chk
___stdoutp _dseams_r_stdout
___stderrp _dseams_r_stderr
__ZSt4cout dseams_r_cout
__ZSt4cerr dseams_r_cerr
__ZNSt3__14coutE dseams_r_cout_libcxx
__ZNSt3__14cerrE dseams_r_cerr_libcxx
EOF
}

windows_map() {
  cat << 'EOF'
__acrt_iob_func dseams_r___acrt_iob_func
__imp___acrt_iob_func dseams_r___imp___acrt_iob_func
EOF
}

# Darwin never sees the generic list: _exit is the Mach-O name of exit
# there, and also the ELF name of _exit. Emitting both renames _exit twice.
symbol_map() {
  system_name=$1
  case "$system_name" in
    Darwin)
      darwin_map
      ;;
    *)
      generic_map
      case "$system_name" in
        MINGW*|MSYS*|CYGWIN*|Windows*)
          windows_map
          ;;
      esac
      ;;
  esac
}

emit_map() {
  map=$(symbol_map "$1")
  dups=$(printf '%s\n' "${map}" | awk 'NF { print $1 }' | sort | uniq -d)
  if [ -n "${dups}" ]; then
    printf 'reader-symbols.sh: duplicate source symbols for %s:\n%s\n' "$1" "${dups}" >&2
    exit 1
  fi
  printf '%s\n' "${map}"
}

if [ "$#" -eq 2 ] && [ "$1" = "--print-map" ]; then
  emit_map "$2"
  exit 0
fi

if [ "$#" -ne 2 ] && [ "$#" -ne 3 ]; then
  echo "usage: reader-symbols.sh OBJCOPY ARCHIVE [SYSTEM]" >&2
  echo "   or: reader-symbols.sh --print-map SYSTEM" >&2
  exit 2
fi

objcopy=$1
archive=$2
system_name=${3:-$(uname -s 2>/dev/null || echo unknown)}

set -- "$objcopy"
while read -r from to; do
  [ -n "${from}" ] || continue
  set -- "$@" --redefine-sym "${from}=${to}"
done << EOF
$(emit_map "$system_name")
EOF
set -- "$@" "$archive"
"$@"
