#!/bin/sh
# Scripted checks for two control-flow bugs in tools/find-readers.sh that
# the testthat suite cannot see, because they are about which directory
# configure-time detection picks, not about what a finished build reads.
#
#   sh tools/test-find-readers.sh [path/to/find-readers.sh]
#
# Case A: an explicit READCON_LIBDIR (no READCON_ROOT) must win over a
# readcon-core.pc already on the ambient PKG_CONFIG_PATH, the same way an
# explicit CHEMFILES_ROOT/LIBDIR must. Before the fix, add_pc_path() only
# ever looked at *_ROOT, so a *_LIBDIR-only request left PKG_CONFIG_PATH
# untouched and the ambient, unrelated .pc won the pkg-config lookup
# before the explicit directory was ever tried.
#
# Case B: once pkg-config has found and rejected a too-old readcon-core.pc,
# the version-blind manual directory scan must not then accept the same
# (or another) unversioned candidate. Before the fix, a version rejection
# left `con=0`, and the caller read that as "pkg-config did not find
# readcon-core" and fell through to manual_readcon(), which has no way to
# read the crate version back out of readcon-core.hpp and so accepted
# whatever library it found.
#
# Case D: an explicit READCON_LIBDIR with its own (empty) pkgconfig
# directory must not fall through to a too-old readcon-core.pc that only
# pkg-config's built-in default directories can see. scoped_pc_dirs()
# points PKG_CONFIG_PATH at the explicit directory, but pkg-config still
# consults its compiled-in defaults unless PKG_CONFIG_LIBDIR also names a
# replacement; the fake .pc here lives where only PKG_CONFIG_LIBDIR
# (simulating those defaults) can reach it, never PKG_CONFIG_PATH.
#
# Case E: is_windows() has two independent ways to see Windows: $OS, and
# `uname -s` reporting MINGW/MSYS/CYGWIN (as a plain MSYS2 shell outside
# Rtools would). Case C above exercises $OS; this exercises uname by
# shimming it on PATH.
#
# All cases reuse a real, already-built readcon-core (from
# tools/install-readcon.sh) for its headers and library, laid out under
# directories with their own, distinguishing fake .pc files. The fake
# .pc Versions are deliberately wrong for their directory; only the
# script's control flow is under test, not whether an old readcon-core
# actually builds.
#
# The script under test defaults to tools/find-readers.sh (repo-relative
# to this file). Pass a path (e.g. to a worktree of an older commit) to
# run the same cases against a different revision of the script.

set -eu

here=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
script=${1:-"$here/tools/find-readers.sh"}
if [ ! -f "$script" ]; then
  echo "test-find-readers.sh: $script does not exist" >&2
  exit 1
fi

: "${R_HOME:=$(R RHOME)}"
if [ ! -x "${R_HOME}/bin/R" ]; then
  echo "test-find-readers.sh: no R under R_HOME=${R_HOME}" >&2
  exit 1
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/find-readers-test.XXXXXX")
trap 'rm -rf "$work"' EXIT

fail=0
ok() { printf 'ok - %s\n' "$1"; }
not_ok() {
  printf 'not ok - %s\n' "$1"
  fail=1
}

# A real, already-installed readcon-core: tools/install-readcon.sh writes
# one into CONDA_PREFIX (or PREFIX), which is where the pixi `readers`
# environment and CI's readers job put it.
real_readcon=${READCON_TEST_PREFIX:-}
if [ -z "$real_readcon" ]; then
  for d in "${CONDA_PREFIX:-}" "${PREFIX:-}"; do
    if [ -n "$d" ] && [ -f "$d/include/readcon-core.hpp" ] && \
       [ -f "$d/lib/pkgconfig/readcon-core.pc" ]; then
      real_readcon=$d
      break
    fi
  done
fi
if [ -z "$real_readcon" ]; then
  cat >&2 <<'EOF'
test-find-readers.sh: no built readcon-core found (checked $CONDA_PREFIX
and $PREFIX). Run tools/install-readcon.sh first, or set
READCON_TEST_PREFIX to an install it made.
EOF
  exit 1
fi
real_ver=$(sed -n 's/^Version:[[:space:]]*//p' "$real_readcon/lib/pkgconfig/readcon-core.pc")
if [ -z "$real_ver" ]; then
  echo "test-find-readers.sh: could not read Version from $real_readcon's readcon-core.pc" >&2
  exit 1
fi

# $1 directory to create, $2 fake Version, $3 1 to also write a .pc
# (pkg-config-discoverable), 0 for headers and library only (manual-scan
# only, like conda-forge's chemfiles).
make_readcon_tree() {
  dir=$1
  fake_ver=$2
  with_pc=$3
  mkdir -p "$dir/include" "$dir/lib"
  ln -s "$real_readcon/include/readcon-core.hpp" "$dir/include/readcon-core.hpp"
  for f in "$real_readcon"/lib/libreadcon_core.*; do
    [ -f "$f" ] && ln -s "$f" "$dir/lib/$(basename "$f")"
  done
  if [ "$with_pc" -eq 1 ]; then
    mkdir -p "$dir/lib/pkgconfig"
    cat >"$dir/lib/pkgconfig/readcon-core.pc" <<EOF
prefix=$dir
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: readcon-core
Description: real $real_ver readcon-core, relabeled $fake_ver for find-readers.sh tests
Version: $fake_ver
Libs: -L\${libdir} -lreadcon_core
Cflags: -I\${includedir}
EOF
  fi
}

# Runs the script under test in a sanitized environment: only PATH,
# R_HOME, HOME and whatever the caller passes through survive, so a
# case cannot be fooled by this shell's own ambient PKG_CONFIG_PATH or
# CONDA_PREFIX (set by `pixi run`, among others).
run_find_readers() {
  run_find_readers_path "$PATH" "$@"
}

# Same, but with an explicit PATH, so a case can prepend a directory of
# shimmed commands (e.g. a fake uname) ahead of the real tools.
run_find_readers_path() {
  path=$1
  shift
  env -i PATH="$path" R_HOME="$R_HOME" HOME="${HOME:-$work}" "$@" \
    sh "$script" bundled
}

get_var() {
  printf '%s\n' "$1" | sed -n "s/^$2=//p" | sed "s/^'//; s/'\$//"
}

echo "# readcon-core under test: $real_readcon ($real_ver)"
echo "# script under test: $script"

# --- Case A: an explicit READCON_LIBDIR (no READCON_ROOT) must win over
# a readcon-core.pc on the ambient PKG_CONFIG_PATH. ---

global_dir=$work/case-a-global
explicit_dir=$work/case-a-explicit
make_readcon_tree "$global_dir" "0.20.0" 1
make_readcon_tree "$explicit_dir" "" 0

out=$(run_find_readers \
  PKG_CONFIG_PATH="$global_dir/lib/pkgconfig" \
  READCON_LIBDIR="$explicit_dir/lib" \
  CHEMFILES_ROOT="$work/no-such-chemfiles-dir")
con=$(get_var "$out" dseams_readcon)
cppflags=$(get_var "$out" dseams_reader_cppflags)
case "$cppflags" in
  *"-I$explicit_dir/include"*)
    if [ "$con" = "1" ]; then
      ok "READCON_LIBDIR alone wins over a readcon-core.pc on PKG_CONFIG_PATH"
    else
      not_ok "READCON_LIBDIR's own headers were used but dseams_readcon=$con (expected 1)"
    fi
    ;;
  *"-I$global_dir/include"*)
    not_ok "the ambient PKG_CONFIG_PATH readcon-core.pc (0.20.0) won over READCON_LIBDIR=$explicit_dir/lib"
    ;;
  *)
    not_ok "neither the explicit nor the global readcon-core was used (cppflags: $cppflags)"
    ;;
esac

# --- Case B: a version pkg-config rejects must disable the reader, not
# fall back to a version-blind manual acceptance of the same library. ---

rejected_dir=$work/case-b-rejected
make_readcon_tree "$rejected_dir" "0.16.1" 1

out=$(run_find_readers \
  PKG_CONFIG_PATH="$rejected_dir/lib/pkgconfig" \
  CONDA_PREFIX="$rejected_dir" \
  CHEMFILES_ROOT="$work/no-such-chemfiles-dir")
con=$(get_var "$out" dseams_readcon)
if [ "$con" = "0" ]; then
  ok "a readcon-core.pc claiming 0.16.1 (really $real_ver) is rejected, not manually re-accepted"
else
  not_ok "a readcon-core.pc claiming 0.16.1 (really $real_ver) was accepted anyway (dseams_readcon=$con)"
fi

# Same case, but as an explicit READCON_ROOT: the version rejection must
# hold there too.
out=$(run_find_readers \
  READCON_ROOT="$rejected_dir" \
  CHEMFILES_ROOT="$work/no-such-chemfiles-dir")
con=$(get_var "$out" dseams_readcon)
if [ "$con" = "0" ]; then
  ok "READCON_ROOT pointing at a rejected 0.16.1 .pc is rejected, not manually re-accepted"
else
  not_ok "READCON_ROOT pointing at a rejected 0.16.1 .pc was accepted anyway (dseams_readcon=$con)"
fi

# --- Case D: an explicit READCON_LIBDIR's own (empty) pkgconfig
# directory must not fall through to a too-old readcon-core.pc that
# only PKG_CONFIG_LIBDIR's default-directory replacement can see.
# PKG_CONFIG_PATH is left unset throughout, so only PKG_CONFIG_LIBDIR
# stands in for pkg-config's compiled-in default directories.
#
# This case pins PKG_CONFIG to a real pkgconf binary when one is on the
# system outside any activated build environment. A pixi/conda-forge
# environment's own "pkg-config" is a wrapper script that unconditionally
# appends that environment's own default directories to whatever
# PKG_CONFIG_LIBDIR the caller sets, which would make this case
# non-deterministic (it would see that environment's own, correctly
# versioned, readcon-core.pc instead of either fake one); see REPORT.md
# for that caveat's effect on a pixi-environment build's own isolation. ---

case_d_pc=${PKG_CONFIG:-pkg-config}
if [ -x /usr/bin/pkg-config ]; then
  case_d_pc=/usr/bin/pkg-config
fi

case_d_defaults=$work/case-d-defaults
case_d_explicit=$work/case-d-explicit
make_readcon_tree "$case_d_defaults" "0.16.1" 1
make_readcon_tree "$case_d_explicit" "" 0
# An empty pkgconfig directory, so scoped_pc_dirs() finds somewhere to
# scope to, but the explicit directory's own pkg-config lookup finds
# nothing there -- only a buggy fallback to the ambient default
# directories would find the 0.16.1 .pc.
mkdir -p "$case_d_explicit/lib/pkgconfig"

out=$(run_find_readers \
  PKG_CONFIG="$case_d_pc" \
  PKG_CONFIG_LIBDIR="$case_d_defaults/lib/pkgconfig" \
  READCON_LIBDIR="$case_d_explicit/lib" \
  CHEMFILES_ROOT="$work/no-such-chemfiles-dir" \
  2>"$work/case-d.stderr")
con=$(get_var "$out" dseams_readcon)
cppflags=$(get_var "$out" dseams_reader_cppflags)
if grep -q '0\.16\.1' "$work/case-d.stderr"; then
  not_ok "READCON_LIBDIR=$case_d_explicit/lib still reached the 0.16.1 .pc on the simulated PKG_CONFIG_LIBDIR default path"
else
  case "$cppflags" in
    *"-I$case_d_explicit/include"*)
      if [ "$con" = "1" ]; then
        ok "READCON_LIBDIR's own (empty) pkgconfig excludes the simulated PKG_CONFIG_LIBDIR default path"
      else
        not_ok "READCON_LIBDIR's own headers were used but dseams_readcon=$con (expected 1)"
      fi
      ;;
    *)
      not_ok "READCON_LIBDIR=$case_d_explicit/lib did not end up using its own directory (dseams_readcon=$con, cppflags: $cppflags)"
      ;;
  esac
fi

# --- Sanity: a correctly-versioned explicit root is still accepted (the
# fix must not just disable readcon-core outright). ---

good_dir=$work/case-c-good
make_readcon_tree "$good_dir" "$real_ver" 1
out=$(run_find_readers \
  READCON_ROOT="$good_dir" \
  CHEMFILES_ROOT="$work/no-such-chemfiles-dir")
con=$(get_var "$out" dseams_readcon)
if [ "$con" = "1" ]; then
  ok "READCON_ROOT with a correctly-versioned .pc ($real_ver) is still accepted"
else
  not_ok "READCON_ROOT with a correctly-versioned .pc ($real_ver) was rejected (dseams_readcon=$con)"
fi

# --- Case C: -Wl,-rpath must appear only off Windows (reviewer claim 3).
# $OS=Windows_NT is how Rtools' MSYS2 shell marks a Windows build; see
# is_windows() in find-readers.sh. ---

out=$(run_find_readers \
  READCON_ROOT="$good_dir" \
  CHEMFILES_ROOT="$work/no-such-chemfiles-dir")
libs=$(get_var "$out" dseams_reader_libs)
case "$libs" in
  *"-Wl,-rpath,"*) ok "a non-Windows run links readcon-core with -Wl,-rpath" ;;
  *) not_ok "a non-Windows run did not add -Wl,-rpath (libs: $libs)" ;;
esac

out=$(run_find_readers \
  OS="Windows_NT" \
  READCON_ROOT="$good_dir" \
  CHEMFILES_ROOT="$work/no-such-chemfiles-dir")
libs=$(get_var "$out" dseams_reader_libs)
case "$libs" in
  *"-Wl,-rpath,"*) not_ok "OS=Windows_NT still added -Wl,-rpath (libs: $libs)" ;;
  *) ok "OS=Windows_NT (as configure.win runs under) adds no -Wl,-rpath" ;;
esac

# --- Case E: is_windows()'s uname branch, for a plain MSYS2/Cygwin shell
# that runs with no $OS=Windows_NT (unlike Rtools). Shims uname on PATH
# ahead of the real one. ---

winshim=$work/winshim
mkdir -p "$winshim"
cat >"$winshim/uname" <<'EOF'
#!/bin/sh
echo "MINGW64_NT-10.0-19045"
EOF
chmod +x "$winshim/uname"

out=$(run_find_readers_path "$winshim:$PATH" \
  READCON_ROOT="$good_dir" \
  CHEMFILES_ROOT="$work/no-such-chemfiles-dir")
libs=$(get_var "$out" dseams_reader_libs)
case "$libs" in
  *"-Wl,-rpath,"*) not_ok "a shimmed uname reporting MINGW64_NT still added -Wl,-rpath (libs: $libs)" ;;
  *) ok "a shimmed uname reporting MINGW64_NT (is_windows()'s uname branch) adds no -Wl,-rpath" ;;
esac

if [ "$fail" -ne 0 ]; then
  echo "# find-readers.sh checks failed"
  exit 1
fi
echo "# all find-readers.sh checks passed"
