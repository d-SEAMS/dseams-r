#!/bin/sh
# Copyright (c) d-SEAMS developers
# Rename symbols Writing R Extensions rejects, inside one static archive,
# onto the wrappers in src/dseams_r_io.cpp. The archive is rewritten in
# place. Signatures of the replacements match the symbols they stand in for.
set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: reader-symbols.sh OBJCOPY ARCHIVE" >&2
  exit 2
fi

objcopy=$1
archive=$2
prefix=
stdout_symbol=stdout
stderr_symbol=stderr
if [ "$(uname -s)" = Darwin ]; then
  prefix=_
  stdout_symbol=__stdoutp
  stderr_symbol=__stderrp
fi
"$objcopy" \
  --redefine-sym "${prefix}abort=${prefix}dseams_r_abort" \
  --redefine-sym "${prefix}__assert_rtn=${prefix}dseams_r_assert_rtn" \
  --redefine-sym "${prefix}exit=${prefix}dseams_r_exit" \
  --redefine-sym "${prefix}_exit=${prefix}dseams_r__exit" \
  --redefine-sym "${prefix}_Exit=${prefix}dseams_r__Exit" \
  --redefine-sym "${prefix}printf=${prefix}dseams_r_printf" \
  --redefine-sym "${prefix}puts=${prefix}dseams_r_puts" \
  --redefine-sym "${prefix}putchar=${prefix}dseams_r_putchar" \
  --redefine-sym "${prefix}sprintf=${prefix}dseams_r_sprintf" \
  --redefine-sym "${prefix}vsprintf=${prefix}dseams_r_vsprintf" \
  --redefine-sym "${prefix}__printf_chk=${prefix}dseams_r_printf_chk" \
  --redefine-sym "${prefix}__sprintf_chk=${prefix}dseams_r_sprintf_chk" \
  --redefine-sym "${prefix}__vsprintf_chk=${prefix}dseams_r_vsprintf_chk" \
  --redefine-sym "${prefix}${stdout_symbol}=${prefix}dseams_r_stdout" \
  --redefine-sym "${prefix}${stderr_symbol}=${prefix}dseams_r_stderr" \
  --redefine-sym "${prefix}_ZSt4cout=dseams_r_cout" \
  --redefine-sym "${prefix}_ZSt4cerr=dseams_r_cerr" \
  --redefine-sym "${prefix}_ZNSt3__14coutE=dseams_r_cout_libcxx" \
  --redefine-sym "${prefix}_ZNSt3__14cerrE=dseams_r_cerr_libcxx" \
  "$archive"
