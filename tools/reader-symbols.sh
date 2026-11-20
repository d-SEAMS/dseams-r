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
"$objcopy" \
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
