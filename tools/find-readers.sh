#!/bin/sh
# Detect the optional trajectory readers and print shell assignments.
#
#   sh tools/find-readers.sh bundled|linked
#
# bundled: look for chemfiles and readcon-core, and when one is usable
# print the -D, -I, and -l flags the engine copy needs. linked: the
# readers are already inside libseams. Print -DSEAMS_HAS_CHEMFILES and
# -DSEAMS_HAS_READCON when that library was built with them, so the R
# side can report the same set.
#
# Search order for a library, in bundled mode: CHEMFILES_ROOT or
# CHEMFILES_LIBDIR (READCON_ROOT, READCON_LIBDIR), then pkg-config
# (chemfiles, readcon-core). An unusable or out-of-range library is left
# off. The CRAN build finds neither and still configures.
#
# stdout is assignments. The human line is dseams_reader_message.

set -e

mode=${1:-bundled}
PC=${PKG_CONFIG:-pkg-config}

sq() {
  printf "'"
  printf '%s' "$1" | sed "s/'/'\\\\''/g"
  printf "'"
}

ver_ge() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    split(a, A, ".")
    split(b, B, ".")
    for (i = 1; i <= 3; i++) {
      ai = A[i] + 0
      bi = B[i] + 0
      if (ai > bi) exit 0
      if (ai < bi) exit 1
    }
    exit 0
  }'
}

ver_lt() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    split(a, A, ".")
    split(b, B, ".")
    for (i = 1; i <= 3; i++) {
      ai = A[i] + 0
      bi = B[i] + 0
      if (ai < bi) exit 0
      if (ai > bi) exit 1
    }
    exit 1
  }'
}

have_pc() {
  command -v "$PC" >/dev/null 2>&1 && "$PC" --exists "$1" >/dev/null 2>&1
}

add_pc_path() {
  root=$1
  if [ -z "$root" ]; then
    return 0
  fi
  for d in "$root/lib/pkgconfig" "$root/lib64/pkgconfig" "$root/share/pkgconfig"; do
    if [ -d "$d" ]; then
      if [ -n "${PKG_CONFIG_PATH:-}" ]; then
        PKG_CONFIG_PATH="$d:$PKG_CONFIG_PATH"
      else
        PKG_CONFIG_PATH="$d"
      fi
      export PKG_CONFIG_PATH
    fi
  done
}

# $1 directory, $2 library stem (chemfiles, seams-chemfiles, readcon_core)
has_lib() {
  dir=$1
  base=$2
  if [ -z "$dir" ] || [ ! -d "$dir" ]; then
    return 1
  fi
  if [ -f "$dir/lib${base}.so" ] || [ -f "$dir/lib${base}.dylib" ] || \
     [ -f "$dir/lib${base}.a" ] || [ -f "$dir/lib${base}.dll" ] || \
     [ -f "$dir/${base}.lib" ] || [ -f "$dir/lib${base}.dll.a" ]; then
    return 0
  fi
  for f in "$dir"/lib${base}.so.*; do
    if [ -f "$f" ]; then
      return 0
    fi
  done
  return 1
}

r_cxx() {
  if [ -z "${R_HOME:-}" ] || [ ! -x "${R_HOME}/bin/R" ]; then
    return 1
  fi
  # R CMD config CXX is sometimes "compiler -std=...". The program name
  # is the first word. The standard flag from CXX20STD is applied after
  # it, so the package's C++20 mode wins.
  raw=$("${R_HOME}/bin/R" CMD config CXX)
  DSEAMS_CXX=$(printf '%s\n' "$raw" | awk '{print $1}')
  DSEAMS_CXXEXTRA=$(printf '%s\n' "$raw" | awk '{ $1 = ""; sub(/^ /, ""); print }')
  DSEAMS_CXXFLAGS=$("${R_HOME}/bin/R" CMD config CXXFLAGS)
  DSEAMS_CXXSTD=$("${R_HOME}/bin/R" CMD config CXX20STD)
  if [ -z "$DSEAMS_CXX" ] || [ ! -x "$DSEAMS_CXX" ]; then
    # A bare name is resolved on PATH.
    if ! command -v "$DSEAMS_CXX" >/dev/null 2>&1; then
      return 1
    fi
  fi
  return 0
}

# Compile and link $1 (a .cpp path). Extra args are compiler and linker flags.
try_link() {
  src=$1
  shift
  if ! r_cxx; then
    return 1
  fi
  # shellcheck disable=SC2086
  "$DSEAMS_CXX" $DSEAMS_CXXEXTRA $DSEAMS_CXXSTD $DSEAMS_CXXFLAGS \
    -o "$probe_dir/probe" "$src" "$@" >"$probe_dir/log" 2>&1
}

probe_dir=$(mktemp -d "${TMPDIR:-/tmp}/dseams-readers.XXXXXX")
cleanup() {
  rm -rf "$probe_dir"
}
trap cleanup EXIT

chem=0
con=0
chem_ver=""
con_ver=""
chem_note=""
con_note=""
patched=0
cppflags=""
libs=""

# Remember a library that compiled. $1 cflags, $2 libs, $3 version, $4 note.
# Sets chem_found via the caller.

note_probe_fail() {
  if [ -s "$probe_dir/log" ]; then
    printf '%s\n' "find-readers.sh: probe failed:" >&2
    sed -n '1,40p' "$probe_dir/log" >&2
  fi
}

adopt_chemfiles() {
  cflags=$1
  link=$2
  ver=$3
  # The public headers have to compile. A .pc that names a missing
  # include tree is not a reader.
  cat >"$probe_dir/chem.cpp" <<'EOF'
#include <chemfiles.hpp>
#include <stdio.h>
int main(void) {
  printf("%d.%d.%d\n", CHEMFILES_VERSION_MAJOR, CHEMFILES_VERSION_MINOR,
         CHEMFILES_VERSION_PATCH);
  return 0;
}
EOF
  if ! try_link "$probe_dir/chem.cpp" $cflags $link; then
    note_probe_fail
    return 1
  fi
  got=$("$probe_dir/probe" 2>/dev/null || true)
  if [ -z "$ver" ]; then
    ver=$got
  fi
  if [ -z "$ver" ] || ! ver_ge "$ver" "0.10.4" || ! ver_lt "$ver" "0.11"; then
    printf '%s\n' "find-readers.sh: chemfiles ${ver:-unknown} is outside >=0.10.4 <0.11" >&2
    return 1
  fi
  # The vendored seams-chemfiles exports seams_with_frame. Upstream
  # chemfiles does not, and the engine then uses the public API.
  cat >"$probe_dir/patched.cpp" <<'EOF'
#include <chemfiles.hpp>
namespace chemfiles {
int seams_with_frame(const std::string &path, const std::string &format,
                     std::size_t step, const std::string &topology,
                     const std::string &selection, bool read, bool empty_xyz,
                     int (*visit)(const Frame &frame, const std::size_t *ids,
                                  std::size_t nids, void *user),
                     void *user, std::string &error, std::size_t &nsteps);
}
int main(void) {
  std::string error;
  std::size_t nsteps = 0;
  return chemfiles::seams_with_frame("", "", 0, "", "", false, false, nullptr,
                                     nullptr, error, nsteps);
}
EOF
  patched=0
  if try_link "$probe_dir/patched.cpp" $cflags $link; then
    patched=1
  fi
  chem=1
  chem_ver=$ver
  cppflags="$cppflags $cflags -DSEAMS_HAS_CHEMFILES=1"
  if [ "$patched" -eq 1 ]; then
    cppflags="$cppflags -DSEAMS_CHEMFILES_PATCHED=1"
    chem_note="patched"
  fi
  libs="$libs $link"
  return 0
}

adopt_readcon() {
  cflags=$1
  link=$2
  ver=$3
  if [ -n "$ver" ] && ! ver_ge "$ver" "0.16.2"; then
    printf '%s\n' "find-readers.sh: readcon-core $ver is older than 0.16.2" >&2
    return 1
  fi
  cat >"$probe_dir/readcon.cpp" <<'EOF'
#include <readcon-core.hpp>
int main(int argc, char **argv) {
  if (argc > 10) {
    readcon::ConFrameIterator frames(argv[1]);
    for (auto &&frame : frames) {
      (void)frame;
    }
  }
  return 0;
}
EOF
  if ! try_link "$probe_dir/readcon.cpp" $cflags $link; then
    note_probe_fail
    return 1
  fi
  con=1
  con_ver=$ver
  cppflags="$cppflags $cflags -DSEAMS_HAS_READCON=1"
  libs="$libs $link"
  return 0
}

pc_cflags() {
  "$PC" --cflags "$1" 2>/dev/null || true
}

pc_libs() {
  "$PC" --libs "$1" 2>/dev/null || true
}

pc_ver() {
  "$PC" --modversion "$1" 2>/dev/null || true
}

pc_libdir() {
  "$PC" --variable=libdir "$1" 2>/dev/null || true
}

with_rpath() {
  link=$1
  dir=$2
  if [ -n "$dir" ]; then
    printf '%s -Wl,-rpath,%s' "$link" "$dir"
  else
    printf '%s' "$link"
  fi
}

try_chemfiles_pc() {
  if ! have_pc chemfiles; then
    return 1
  fi
  cflags=$(pc_cflags chemfiles)
  link=$(with_rpath "$(pc_libs chemfiles)" "$(pc_libdir chemfiles)")
  ver=$(pc_ver chemfiles)
  adopt_chemfiles "$cflags" "$link" "$ver"
}

try_readcon_pc() {
  if ! have_pc readcon-core; then
    return 1
  fi
  cflags=$(pc_cflags readcon-core)
  link=$(with_rpath "$(pc_libs readcon-core)" "$(pc_libdir readcon-core)")
  ver=$(pc_ver readcon-core)
  adopt_readcon "$cflags" "$link" "$ver"
}

# $1 prefix, $2 explicit libdir, $3 stem
manual_chemfiles() {
  root=$1
  libdir=$2
  inc=""
  lib=""
  stem="chemfiles"
  if [ -n "$root" ] && [ -f "$root/include/chemfiles.hpp" ]; then
    inc="$root/include"
  fi
  for d in $libdir ${root:+$root/lib} ${root:+$root/lib64}; do
    if has_lib "$d" seams-chemfiles && ! has_lib "$d" chemfiles; then
      stem="seams-chemfiles"
      lib=$d
      break
    fi
    if has_lib "$d" chemfiles; then
      stem="chemfiles"
      lib=$d
      break
    fi
  done
  if [ -z "$inc" ] && [ -n "$lib" ] && [ -f "$lib/../include/chemfiles.hpp" ]; then
    inc=$(CDPATH= cd -- "$lib/../include" && pwd)
  fi
  if [ -z "$inc" ] || [ -z "$lib" ]; then
    return 1
  fi
  adopt_chemfiles "-I$inc" "$(with_rpath "-L$lib -l$stem" "$lib")" ""
}

manual_readcon() {
  root=$1
  libdir=$2
  inc=""
  lib=""
  if [ -n "$root" ] && [ -f "$root/include/readcon-core.hpp" ]; then
    inc="$root/include"
  fi
  for d in $libdir ${root:+$root/lib} ${root:+$root/lib64}; do
    if has_lib "$d" readcon_core; then
      lib=$d
      break
    fi
  done
  if [ -z "$inc" ] && [ -n "$lib" ] && [ -f "$lib/../include/readcon-core.hpp" ]; then
    inc=$(CDPATH= cd -- "$lib/../include" && pwd)
  fi
  if [ -z "$inc" ] || [ -z "$lib" ]; then
    return 1
  fi
  adopt_readcon "-I$inc" "$(with_rpath "-L$lib -lreadcon_core" "$lib")" ""
}

scan_linked() {
  chem_have=0
  chem_lack=0
  con_have=0
  con_lack=0
  # A missing directory must not leave `for dir in ;`, which is a
  # syntax error. "." is scanned only when a real directory was not named.
  for dir in ${SEAMS_SO_DIR:-.} ${SEAMS_LIBDIR:-.} ${SEAMS_SCAN_DIR:-.}; do
    if [ "$dir" = "." ] || [ ! -d "$dir" ]; then
      continue
    fi
    for f in "$dir"/libyodaLib.so "$dir"/libyodaLib.dylib \
             "$dir"/libseams.so "$dir"/libseams.dylib \
             "$dir"/libyodaLib.so.* "$dir"/libseams.so.*; do
      if [ ! -f "$f" ]; then
        continue
      fi
      if LC_ALL=C grep -a -q -F "needs chemfiles, which this build lacks" "$f"; then
        chem_lack=1
      fi
      if LC_ALL=C grep -a -q -F "chemfiles cannot read " "$f"; then
        chem_have=1
      fi
      if LC_ALL=C grep -a -q -F "readcon-core is not in this build" "$f"; then
        con_lack=1
      fi
      if LC_ALL=C grep -a -q -F "Cannot open .con file " "$f"; then
        con_have=1
      fi
    done
  done
  case "${SEAMS_CPPFLAGS:-}" in
    *SEAMS_HAS_CHEMFILES*) chem_have=1 ;;
  esac
  case "${SEAMS_CPPFLAGS:-}" in
    *SEAMS_HAS_READCON*) con_have=1 ;;
  esac
  if [ "$chem_have" -eq 1 ] && [ "$chem_lack" -eq 0 ]; then
    chem=1
    chem_note="linked"
  fi
  if [ "$con_have" -eq 1 ] && [ "$con_lack" -eq 0 ]; then
    con=1
    con_note="linked"
  fi
  # The defines ride on the R objects that report the features. The
  # reader code itself stays in the library this package links.
  case "${SEAMS_CPPFLAGS:-}" in
    *SEAMS_HAS_CHEMFILES*) ;;
    *)
      if [ "$chem" -eq 1 ]; then
        cppflags="$cppflags -DSEAMS_HAS_CHEMFILES=1"
      fi
      ;;
  esac
  case "${SEAMS_CPPFLAGS:-}" in
    *SEAMS_HAS_READCON*) ;;
    *)
      if [ "$con" -eq 1 ]; then
        cppflags="$cppflags -DSEAMS_HAS_READCON=1"
      fi
      ;;
  esac
}

if [ "$mode" = "linked" ]; then
  scan_linked
else
  saved_pc=${PKG_CONFIG_PATH:-}
  if [ -n "${CHEMFILES_ROOT:-}" ] || [ -n "${CHEMFILES_LIBDIR:-}" ]; then
    PKG_CONFIG_PATH=$saved_pc
    add_pc_path "${CHEMFILES_ROOT:-}"
    if ! try_chemfiles_pc; then
      manual_chemfiles "${CHEMFILES_ROOT:-}" "${CHEMFILES_LIBDIR:-}" || true
    fi
    PKG_CONFIG_PATH=$saved_pc
    export PKG_CONFIG_PATH
  else
    try_chemfiles_pc || true
    # conda-forge chemfiles 0.10 ships headers and libchemfiles without
    # a chemfiles.pc. The active prefix is the place that install lives.
    if [ "$chem" -eq 0 ]; then
      for root in ${CONDA_PREFIX:-} ${PREFIX:-}; do
        if [ -n "$root" ] && [ -f "$root/include/chemfiles.hpp" ]; then
          if manual_chemfiles "$root" "$root/lib"; then
            break
          fi
        fi
      done
    fi
  fi
  if [ -n "${READCON_ROOT:-}" ] || [ -n "${READCON_LIBDIR:-}" ]; then
    PKG_CONFIG_PATH=$saved_pc
    add_pc_path "${READCON_ROOT:-}"
    if ! try_readcon_pc; then
      manual_readcon "${READCON_ROOT:-}" "${READCON_LIBDIR:-}" || true
    fi
    PKG_CONFIG_PATH=$saved_pc
    export PKG_CONFIG_PATH
  else
    try_readcon_pc || true
    if [ "$con" -eq 0 ]; then
      for root in ${CONDA_PREFIX:-} ${PREFIX:-}; do
        if [ -n "$root" ] && [ -f "$root/include/readcon-core.hpp" ]; then
          if manual_readcon "$root" "$root/lib"; then
            break
          fi
        fi
      done
    fi
  fi
fi

chem_word="off"
con_word="off"
if [ "$chem" -eq 1 ]; then
  chem_word="on"
  if [ -n "$chem_ver" ]; then
    chem_word="on ($chem_ver)"
  fi
  if [ -n "$chem_note" ]; then
    if [ -n "$chem_ver" ]; then
      chem_word="on ($chem_ver, $chem_note)"
    else
      chem_word="on ($chem_note)"
    fi
  fi
fi
if [ "$con" -eq 1 ]; then
  con_word="on"
  if [ -n "$con_ver" ]; then
    con_word="on ($con_ver)"
  fi
  if [ -n "$con_note" ]; then
    if [ -n "$con_ver" ]; then
      con_word="on ($con_ver, $con_note)"
    else
      con_word="on ($con_note)"
    fi
  fi
fi

# Trim the leading space left by the first append.
cppflags=$(printf '%s' "$cppflags" | sed 's/^ *//')
libs=$(printf '%s' "$libs" | sed 's/^ *//')

message="readers: LAMMPS and XYZ on; chemfiles $chem_word; readcon $con_word"

printf 'dseams_chemfiles=%s\n' "$chem"
printf 'dseams_readcon=%s\n' "$con"
printf 'dseams_reader_cppflags=%s\n' "$(sq "$cppflags")"
printf 'dseams_reader_libs=%s\n' "$(sq "$libs")"
printf 'dseams_reader_message=%s\n' "$(sq "$message")"
