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
# an R error when vsnprintf fails or the text does not fit. __assert_rtn,
# the Darwin assert handler, stops with an R error that names the failed
# assertion.
#
# The map follows the object format of the archive members (ELF, Mach-O
# or COFF), read from their magic numbers, not the host. The generic list
# is ELF and COFF names. Mach-O has its own list: each C symbol and its
# target gain one leading underscore. The iostream targets are
# the literal asm labels in src/dseams_r_io.cpp, which Mach-O does not
# prefix.
# ___stdoutp and ___stderrp are the FILE* variables the macOS SDK uses
# for stdout and stderr. They are renamed onto the FILE* objects
# dseams_r_stdout and dseams_r_stderr, not onto functions.
# COFF is the generic list plus the UCRT function __acrt_iob_func and
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

# Mach-O never sees the generic list: _exit is the Mach-O name of exit
# there, and also the ELF name of _exit. Emitting both renames _exit twice.
symbol_map() {
  case "$1" in
    elf)
      generic_map
      ;;
    mach-o)
      darwin_map
      ;;
    coff)
      generic_map
      windows_map
      ;;
    *)
      printf 'reader-symbols.sh: unknown object format %s (elf, mach-o or coff)\n' "$1" >&2
      exit 2
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

die() {
  printf 'reader-symbols.sh: %s\n' "$1" >&2
  exit 1
}

# COUNT bytes of FILE from byte OFFSET, as written.
bytes_at() {
  dd if="$1" bs=1 skip="$2" count="$3" 2>/dev/null
}

# The object format of the first object member of a static archive, read
# from its magic number: 7f454c46 is ELF; cffaedfe, cefaedfe, feedfacf
# and feedface are 64- and 32-bit Mach-O in either byte order; COFF starts
# with its machine type (6486 x86-64, 4c01 i386, 64aa arm64, 41a6 arm64ec,
# c401 armnt) or 0000ffff for an import or big object. The archive
# layout is the common ar format: an 8-byte "!<arch>" line, then members
# with 60-byte headers whose size field (bytes 49-58) is decimal, padded
# to an even length. GNU and COFF symbol tables (/, /SYM64/), the GNU name
# table (//) and the BSD __.SYMDEF table are not objects. A BSD name of
# the form #1/N is stored in the first N bytes of the member.
archive_format() {
  a=$1
  [ -f "${a}" ] || die "${a} is not a file"
  [ "$(bytes_at "${a}" 0 8)" = '!<arch>' ] || die "${a} is not an ar archive"
  total=$(wc -c < "${a}" | tr -d ' ')
  off=8
  while [ $((off + 60)) -le "${total}" ]; do
    header=$(bytes_at "${a}" "${off}" 60)
    name=$(printf '%s' "${header}" | cut -c1-16 | sed 's/ *$//')
    size=$(printf '%s' "${header}" | cut -c49-58 | tr -d ' ')
    case "${size}" in
      '' | *[!0-9]*) die "${a}: malformed member header at byte ${off}" ;;
    esac
    data=$((off + 60))
    name_len=0
    case "${name}" in
      '#1/'*)
        name_len=${name#??/}
        case "${name_len}" in
          '' | *[!0-9]*) die "${a}: malformed BSD member name at byte ${off}" ;;
        esac
        name=$(bytes_at "${a}" "${data}" "${name_len}" | tr -d '\000')
        ;;
    esac
    case "${name}" in
      / | /SYM64/ | // | __.SYMDEF*) ;;
      *)
        magic=$(bytes_at "${a}" $((data + name_len)) 4 | od -An -tx1 | tr -d ' \n')
        case "${magic}" in
          7f454c46)
            echo elf
            return 0
            ;;
          cffaedfe | cefaedfe | feedfacf | feedface)
            echo mach-o
            return 0
            ;;
          6486???? | 4c01???? | 64aa???? | 41a6???? | c401???? | 0000ffff)
            echo coff
            return 0
            ;;
        esac
        ;;
    esac
    off=$((data + size + size % 2))
  done
  die "${a} has no ELF, Mach-O or COFF member"
}

usage() {
  echo "usage: reader-symbols.sh OBJCOPY ARCHIVE" >&2
  echo "   or: reader-symbols.sh --format ARCHIVE" >&2
  echo "   or: reader-symbols.sh --print-map elf|mach-o|coff" >&2
  exit 2
}

[ "$#" -eq 2 ] || usage
case "$1" in
  --print-map)
    emit_map "$2"
    exit 0
    ;;
  --format)
    archive_format "$2"
    exit 0
    ;;
esac

# The map follows the objects in the archive, not the host, so an archive
# built for another platform gets that platform's names.
objcopy=$1
archive=$2
format=$(archive_format "${archive}")

set -- "${objcopy}"
while read -r from to; do
  [ -n "${from}" ] || continue
  set -- "$@" --redefine-sym "${from}=${to}"
done << EOF
$(emit_map "${format}")
EOF
set -- "$@" "${archive}"
"$@"
