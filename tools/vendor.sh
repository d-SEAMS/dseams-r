#!/bin/sh
# Copyright (c) d-SEAMS developers
# Copy the engine sources that libseams_lang needs into src/seams, and the
# example dumps into inst/extdata, and (via tools/vendor-readers.sh) the
# readcon-core and chemfiles sources, so that `R CMD build` makes a source
# package which compiles with no seams-core checkout and no network.
#
#   sh tools/vendor.sh [SEAMS_CORE_SRC]
#
# The seams-core source tree is the argument, else $SEAMS_CORE_SRC, else
# $DSEAMS_ROOT. With none of them, tools/fetch-engine.R downloads the
# revision pinned in tools/seams-core.ref, unless DSEAMS_NO_DOWNLOAD is set.
# A named tree at another revision is copied all the same, and
# src/seams/README records which one it was. The list of engine objects is
# the seams/*.o block of src/Makevars.in, so that file is the one place to
# add a source.
set -e

pkg=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
root=${1:-${SEAMS_CORE_SRC:-${DSEAMS_ROOT:-}}}
fetched=
trap 'if [ -n "$fetched" ]; then rm -rf "$fetched"; fi' EXIT
if [ -z "$root" ]; then
  case "${DSEAMS_NO_DOWNLOAD:-}" in
    1|yes|true|TRUE)
      echo "vendor.sh: DSEAMS_NO_DOWNLOAD is set; name a seams-core tree with SEAMS_CORE_SRC" >&2
      exit 1
      ;;
  esac
  rscript=Rscript
  for cand in "${R_HOME:+$R_HOME/bin/Rscript}" \
    "${R_HOME:+$R_HOME/bin${R_ARCH_BIN:-}/Rscript.exe}" \
    "${R_HOME:+$R_HOME/bin/Rscript.exe}"; do
    if [ -n "$cand" ] && [ -f "$cand" ]; then
      rscript=$cand
      break
    fi
  done
  fetched="${TMPDIR:-${TEMP:-/tmp}}/dseams-engine-$$"
  mkdir -p "$fetched"
  fetched_out=$("$rscript" --vanilla "$pkg/tools/fetch-engine.R" "$pkg/tools/seams-core.ref" "$fetched")
  root=$(printf '%s\n' "$fetched_out" | tail -n 1 | tr -d '\r')
  if [ -z "$root" ] || [ ! -d "$root" ]; then
    echo "vendor.sh: could not fetch seams-core; set SEAMS_CORE_SRC to a checkout" >&2
    exit 1
  fi
  SEAMS_CORE_REV=$(sed -n 's/^SEAMS_CORE_REF=//p' "$pkg/tools/seams-core.ref")
fi
if [ ! -f "$root/src/mol_sys.cpp" ] || [ ! -f "$root/bindings/cxx/seams_lang.cpp" ]; then
  echo "vendor.sh: $root is not a seams-core source tree" >&2
  exit 1
fi
root=$(CDPATH= cd -- "$root" && pwd)

dest=$pkg/src/seams
rm -rf "$dest"
mkdir -p "$dest/include"

engine=$(sed -n 's|^[[:space:]]*seams/\([A-Za-z0-9_]*\)\.o.*|\1|p' "$pkg/src/Makevars.in")
if [ -z "$engine" ]; then
  echo "vendor.sh: no seams/*.o objects listed in src/Makevars.in" >&2
  exit 1
fi
engine_win=$(sed -n 's|^[[:space:]]*seams/\([A-Za-z0-9_]*\)\.o.*|\1|p' "$pkg/src/Makevars.win")
if [ "$engine" != "$engine_win" ]; then
  echo "vendor.sh: src/Makevars.in and src/Makevars.win list different engine objects" >&2
  exit 1
fi
version=$(sed -n 's/^Version:[[:space:]]*//p' "$pkg/DESCRIPTION")
. "$pkg/tools/bundled-tools.sh"
require_makevars_win_version "$pkg" "$version" vendor.sh || exit 1
for name in $engine; do
  if [ "$name" = seams_lang ]; then
    cp "$root/bindings/cxx/seams_lang.cpp" "$dest/"
  else
    cp "$root/src/$name.cpp" "$dest/"
  fi
done
# seams_lang.cpp and seams_api.cpp share one shared object here, and both
# define seams_last_error and seams_path_nframes (with different
# signatures). The copied seams_lang.h renames the seams_lang pair, so
# dseams.cpp reaches seams_lang and seams_call.c reaches the C API.
awk '{ print } /^#define SEAMS_LANG_H_$/ {
  print "#define seams_last_error seams_lang_last_error"
  print "#define seams_path_nframes seams_lang_path_nframes"
}' "$root/bindings/cxx/seams_lang.h" > "$dest/seams_lang.h"
defs() {
  raw=$(sed -n 's/^[A-Za-z_][A-Za-z0-9_ *]*[ *]\(seams_[A-Za-z0-9_]*\)(.*/\1/p' "$1")
  if [ -n "$raw" ]; then
    printf '%s\n' "$raw" | sort -u
  fi
}
renamed=$(sed -n 's/^#define \(seams_[A-Za-z0-9_]*\) seams_lang_.*/\1/p' "$dest/seams_lang.h")
defs "$dest/seams_lang.cpp" > "$dest/.lang_all_defs"
rc=0
grep -vxF "$renamed" "$dest/.lang_all_defs" > "$dest/.lang_defs" || rc=$?
rm -f "$dest/.lang_all_defs"
if [ "$rc" -gt 1 ]; then
  exit "$rc"
fi
defs "$dest/seams_api.cpp" > "$dest/.api_defs"
clash=$(comm -12 "$dest/.lang_defs" "$dest/.api_defs")
rm -f "$dest/.lang_defs" "$dest/.api_defs"
if [ -n "$clash" ]; then
  echo "vendor.sh: seams_lang.cpp and seams_api.cpp both define:" $clash >&2
  exit 1
fi
cp "$root"/src/include/internal/*.h "$root"/src/include/internal/*.hpp "$dest/include/"
cp "$root/LICENSE" "$dest/LICENSE"

# Two edits make the copy an R package. [[nodiscard]] goes, as the meson
# build already silences it with -Wno-unused-result (R CMD check reports
# those warnings and a package may not pass -Wno-* flags). Console output
# and std::exit go through src/dseams_r_io.h (Writing R Extensions,
# "Printing" and "Writing portable packages").
for f in "$dest"/*.cpp "$dest"/include/*.h "$dest"/include/*.hpp; do
  sed -e 's/\[\[nodiscard\]\] *//g' "$f" > "$f.tmp"
  if grep -Eq 'std::(cerr|cout|exit)\b|fprintf\(stderr,' "$f.tmp"; then
    {
      echo '#include "dseams_r_io.h"'
      # BSD sed has no \b. The token is replaced when it ends the line or
      # is followed by a character that cannot continue an identifier, and
      # the call goes through dseams_r_io.h.
      sed -e 's/std::cerr$/dseams_r::err()/' \
        -e 's/std::cerr\([^A-Za-z0-9_]\)/dseams_r::err()\1/g' \
        -e 's/std::cout$/dseams_r::out()/' \
        -e 's/std::cout\([^A-Za-z0-9_]\)/dseams_r::out()\1/g' \
        -e 's/std::fprintf(stderr, */dseams_r::eprintf(/g' \
        -e 's/std::exit(/dseams_r::fail(/g' "$f.tmp"
    } > "$f"
    rm -f "$f.tmp"
  else
    mv "$f.tmp" "$f"
  fi
done
rc=0
left=$(grep -En 'std::(cerr|cout|exit|abort|printf)\b|(^|[^a-z_:])(printf|puts)\(|\bstdout\b|fprintf\(stderr' \
  "$dest"/*.cpp "$dest"/include/*.h "$dest"/include/*.hpp) || rc=$?
if [ "$rc" -gt 1 ]; then
  exit "$rc"
fi
if [ -n "$left" ]; then
  echo "vendor.sh: console calls left in the engine copy:" >&2
  echo "$left" >&2
  exit 1
fi

# The public C header for src/seams_call.c and seams_api.cpp. It goes in
# after the console check: its usage comment prints, and nothing in the
# package compiles that comment.
cp "$root/include/seams.h" "$dest/include/"
major=${version%%.*}
rest=${version#*.}
minor=${rest%%.*}
patch=${rest#*.}
sed -e "s/@MAJOR@/$major/" -e "s/@MINOR@/$minor/" -e "s/@PATCH@/$patch/" \
  -e "s/@STRING@/$version/" "$root/include/seams_version.h.in" > "$dest/include/seams_version.h"

# A tree unpacked by tools/fetch-engine.R is not a git checkout; its
# revision is the pin.
rev=${SEAMS_CORE_REV:-unknown}
# Only the root of a checkout names its own revision; a tree unpacked
# inside some other repository would report that repository's HEAD.
if [ -e "$root/.git" ] && command -v git >/dev/null 2>&1; then
  rev=$(git -C "$root" rev-parse HEAD)
  if ! git -C "$root" diff --quiet HEAD -- src include bindings/cxx; then
    rev="$rev-dirty"
  fi
fi
{
  echo "d-SEAMS engine sources, copied by tools/vendor.sh."
  echo "seams-core commit: $rev"
  echo "Upstream: https://github.com/d-SEAMS/seams-core"
} > "$dest/README"

extdata=$pkg/inst/extdata
mkdir -p "$extdata"
for f in ice1h.lammpstrj ice1h.source.txt exampleTraj.lammpstrj \
  nucleation_f1.lammpstrj nucleation_f1.source.txt; do
  cp "$root/input/traj/$f" "$extdata/"
done

sh "$pkg/tools/vendor-readers.sh" "$root" "$pkg"

echo "vendor.sh: $(echo $engine | wc -w | tr -d ' ') engine sources from $rev"
