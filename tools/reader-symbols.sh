#!/bin/sh
# Copyright (c) d-SEAMS developers
# Rename symbols Writing R Extensions rejects, inside one static archive,
# onto the wrappers in src/dseams_r_io.cpp. The archive is rewritten in
# place. Signatures of the replacements match the symbols they stand in for.
#
# The symbol names depend on the object format of the archive members:
# ELF and COFF (x86-64) carry C names as written, Mach-O prefixes one
# underscore to every name, and the Windows UCRT reaches stdout and stderr
# through __acrt_iob_func, called directly or through its __imp_ import
# pointer. The format is read from the first object
# member, so a cross-built archive is treated by what it holds, not by the
# host. Without a recognisable member, the host decides.
set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: reader-symbols.sh OBJCOPY ARCHIVE" >&2
  exit 2
fi

objcopy=$1
archive=$2

ar_tool=
for tool in llvm-ar ar; do
  if command -v "$tool" >/dev/null 2>&1; then
    ar_tool=$tool
    break
  fi
done

# The first four bytes of an object file name its format.
format=
if [ -n "$ar_tool" ]; then
  members=$("$ar_tool" t "$archive" 2>/dev/null || true)
  while IFS= read -r member; do
    [ -n "$member" ] || continue
    magic=$("$ar_tool" p "$archive" "$member" 2>/dev/null |
      od -An -tx1 -N4 | tr -d ' \n')
    case "$magic" in
      7f454c46) format=elf ;;
      cffaedfe | cefaedfe | feedfacf | feedface) format=mach-o ;;
      6486* | 4c01* | 64aa* | c401* | 0000ffff) format=coff ;;
    esac
    [ -z "$format" ] || break
  done <<EOF
$members
EOF
fi

if [ -z "$format" ]; then
  case "$(uname -s 2>/dev/null || echo unknown)" in
    Darwin) format=mach-o ;;
    MINGW* | MSYS* | CYGWIN*) format=coff ;;
    *) format=elf ;;
  esac
fi

case "$format" in
  mach-o)
    exec "$objcopy" \
      --redefine-sym _abort=_dseams_r_abort \
      --redefine-sym _exit=_dseams_r_exit \
      --redefine-sym __exit=_dseams_r__exit \
      --redefine-sym __Exit=_dseams_r__Exit \
      --redefine-sym _printf=_dseams_r_printf \
      --redefine-sym _puts=_dseams_r_puts \
      --redefine-sym _putchar=_dseams_r_putchar \
      --redefine-sym _sprintf=_dseams_r_sprintf \
      --redefine-sym _vsprintf=_dseams_r_vsprintf \
      --redefine-sym ___stdoutp=_dseams_r_stdout \
      --redefine-sym ___stderrp=_dseams_r_stderr \
      --redefine-sym __ZSt4cout=_dseams_r_cout \
      --redefine-sym __ZSt4cerr=_dseams_r_cerr \
      --redefine-sym __ZNSt3__14coutE=_dseams_r_cout_libcxx \
      --redefine-sym __ZNSt3__14cerrE=_dseams_r_cerr_libcxx \
      "$archive"
    ;;
  coff)
    exec "$objcopy" \
      --redefine-sym abort=dseams_r_abort \
      --redefine-sym exit=dseams_r_exit \
      --redefine-sym _exit=dseams_r__exit \
      --redefine-sym _Exit=dseams_r__Exit \
      --redefine-sym printf=dseams_r_printf \
      --redefine-sym puts=dseams_r_puts \
      --redefine-sym putchar=dseams_r_putchar \
      --redefine-sym sprintf=dseams_r_sprintf \
      --redefine-sym vsprintf=dseams_r_vsprintf \
      --redefine-sym stdout=dseams_r_stdout \
      --redefine-sym stderr=dseams_r_stderr \
      --redefine-sym __acrt_iob_func=dseams_r_acrt_iob_func \
      --redefine-sym __imp___acrt_iob_func=__imp_dseams_r_acrt_iob_func \
      --redefine-sym _ZSt4cout=dseams_r_cout \
      --redefine-sym _ZSt4cerr=dseams_r_cerr \
      --redefine-sym _ZNSt3__14coutE=dseams_r_cout_libcxx \
      --redefine-sym _ZNSt3__14cerrE=dseams_r_cerr_libcxx \
      "$archive"
    ;;
  *)
    exec "$objcopy" \
      --redefine-sym abort=dseams_r_abort \
      --redefine-sym exit=dseams_r_exit \
      --redefine-sym _exit=dseams_r__exit \
      --redefine-sym _Exit=dseams_r__Exit \
      --redefine-sym printf=dseams_r_printf \
      --redefine-sym puts=dseams_r_puts \
      --redefine-sym putchar=dseams_r_putchar \
      --redefine-sym sprintf=dseams_r_sprintf \
      --redefine-sym vsprintf=dseams_r_vsprintf \
      --redefine-sym stdout=dseams_r_stdout \
      --redefine-sym stderr=dseams_r_stderr \
      --redefine-sym _ZSt4cout=dseams_r_cout \
      --redefine-sym _ZSt4cerr=dseams_r_cerr \
      --redefine-sym _ZNSt3__14coutE=dseams_r_cout_libcxx \
      --redefine-sym _ZNSt3__14cerrE=dseams_r_cerr_libcxx \
      "$archive"
    ;;
esac
