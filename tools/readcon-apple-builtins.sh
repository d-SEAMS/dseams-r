#!/bin/sh
# Copyright (c) d-SEAMS developers
# compiler-rt, archived inside a Rust staticlib by rustc, calls
# ___assert_rtn from int_util.c on Apple and abort() on every other
# platform. The call is not under NDEBUG and not under debug_assertions,
# so a release profile still archives the object. R CMD check reports
# ___assert_rtn as assert(). This replaces that one object with the
# abort() the other platforms already use. tools/reader-symbols.sh then
# renames abort onto dseams_r_abort, as it does for the rest of the
# archive. An object that references ___assert_rtn and is not this
# compiler-rt definition is a failure: it is a real assert, and this
# script does not rename it away.
#
#   sh tools/readcon-apple-builtins.sh ARCHIVE
#
# CC is the compiler make is using. It may contain flags.
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: readcon-apple-builtins.sh ARCHIVE" >&2
  exit 2
fi

# Make passes $@ as a path relative to src/. ar runs from a temporary
# directory, so a relative path would be looked up there.
case "$1" in
  /*) archive=$1 ;;
  *) archive=$(pwd)/$1 ;;
esac
if [ ! -f "$archive" ]; then
  echo "readcon-apple-builtins.sh: $archive is not a file" >&2
  exit 1
fi

if ! command -v nm >/dev/null 2>&1; then
  echo "readcon-apple-builtins.sh: nm is not on PATH" >&2
  exit 1
fi
if [ -z "${CC:-}" ]; then
  echo "readcon-apple-builtins.sh: CC is not set" >&2
  exit 1
fi

# Names nm -P prints. Empty when the object has no such line.
# nm returns 0 when the object has no undefined symbols.
symbol_lines() {
  nm -P "$1"
}

has_undefined() {
  symbol_lines "$1" | awk -v name="$2" '$1 == name && $2 == "U" { found = 1 } END { exit !found }'
}

has_defined() {
  symbol_lines "$1" | awk -v name="$2" '$1 == name && $2 ~ /^[TtWw]$/ { found = 1 } END { exit !found }'
}

work=$(mktemp -d "${TMPDIR:-/tmp}/dseams-readcon-builtins.XXXXXX")
trap 'rm -rf "$work"' EXIT
( cd "$work" && ar x "$archive" )

replaced=
others=
for obj in "$work"/*; do
  [ -f "$obj" ] || continue
  case "$obj" in
    *.o) ;;
    *) continue ;;
  esac
  if ! has_undefined "$obj" "___assert_rtn"; then
    continue
  fi
  if has_defined "$obj" "___compilerrt_abort_impl"; then
    if [ -n "$replaced" ]; then
      echo "readcon-apple-builtins.sh: two compiler-rt abort objects define ___compilerrt_abort_impl" >&2
      exit 1
    fi
    replaced=$(basename "$obj")
  else
    others="$others $(basename "$obj")"
  fi
done

if [ -n "$others" ]; then
  echo "readcon-apple-builtins.sh: ___assert_rtn is referenced outside compiler-rt:$others" >&2
  exit 1
fi
if [ -z "$replaced" ]; then
  exit 0
fi

cat > "$work/compilerrt_abort.c" << 'EOF'
/* The Apple compiler-rt int_util.c calls __assert_rtn. Every other
   platform calls abort(). dseams_r_abort is what the archive's abort
   becomes, and it stops through Rf_error. */
void abort(void) __attribute__((noreturn));

__attribute__((noreturn)) void __compilerrt_abort_impl(
    const char *file, int line, const char *function) {
  (void)file;
  (void)line;
  (void)function;
  abort();
}
EOF

# CC is the compiler command make exported. It may contain flags, and
# those flags contain no quotes, so the expansion is the command.
$CC -c -O2 -DNDEBUG -fPIC "$work/compilerrt_abort.c" -o "$work/compilerrt_abort.o"

ar d "$archive" "$replaced"
ar r "$archive" "$work/compilerrt_abort.o"
if command -v ranlib >/dev/null 2>&1; then
  ranlib "$archive"
else
  ar s "$archive"
fi

rm -f "$work"/*.o
( cd "$work" && ar x "$archive" )
left=
for obj in "$work"/*; do
  [ -f "$obj" ] || continue
  case "$obj" in
    *.o) ;;
    *) continue ;;
  esac
  if has_undefined "$obj" "___assert_rtn"; then
    left="$left $(basename "$obj")"
  fi
done
if [ -n "$left" ]; then
  echo "readcon-apple-builtins.sh: ___assert_rtn remains in:$left" >&2
  exit 1
fi
if ! has_defined "$work/compilerrt_abort.o" "___compilerrt_abort_impl" \
  && ! has_defined "$work/compilerrt_abort.o" "__compilerrt_abort_impl"; then
  echo "readcon-apple-builtins.sh: the replacement does not define __compilerrt_abort_impl" >&2
  exit 1
fi
