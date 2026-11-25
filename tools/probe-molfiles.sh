#!/bin/sh
# Copyright (c) d-SEAMS developers
# Print what each VMD molfile plugin registers, to review a plugin before
# it moves between PLUGINS and EXCLUDED in tools/chemfiles-molfiles.py.
#
#   sh tools/probe-molfiles.sh MOLFILES_TAR_GZ PLUGIN...
#
# Each plugin is compiled as chemfiles compiles it (-DSTATIC_PLUGIN
# -DVMDPLUGIN=name) and linked into one program that registers it and
# prints one tab-separated line per reader: plugin, reader name, pretty
# name, extensions, author, then 0/1 for read_structure,
# read_next_timestep, read_timestep, read_bonds and
# read_volumetric_metadata. Needs a C and a C++ compiler (CC, CXX).
set -eu

if [ "$#" -lt 2 ]; then
  echo "usage: probe-molfiles.sh MOLFILES_TAR_GZ PLUGIN..." >&2
  exit 2
fi
archive=$1
shift
cc=${CC:-cc}
cxx=${CXX:-c++}

work=${TMPDIR:-/tmp}/dseams-molfiles-probe-$$
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT
tar -xzf "$archive" -C "$work"
m=$work/molfiles

{
  echo '#include <stdio.h>'
  echo '#include "molfile_plugin.h"'
  for p in "$@"; do
    echo "int ${p}_init(void); int ${p}_register(void*, vmdplugin_register_cb);"
  done
  cat << 'C'
static const char *cur;
static const char *s(const char *v) { return v ? v : ""; }
static int cb(void *v, vmdplugin_t *p) {
  molfile_plugin_t *m = (molfile_plugin_t *) p;
  (void) v;
  printf("%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\n", cur, s(m->name),
         s(m->prettyname), s(m->filename_extension), s(m->author),
         m->read_structure != 0, m->read_next_timestep != 0,
         m->read_timestep != 0, m->read_bonds != 0,
         m->read_volumetric_metadata != 0);
  return 0;
}
int main(void) {
C
  for p in "$@"; do
    echo "  cur = \"$p\"; ${p}_init(); ${p}_register(0, cb);"
  done
  echo '  return 0;'
  echo '}'
} > "$work/probe.c"

for p in "$@"; do
  src=
  n=0
  for f in "$m"/src/"$p"*.c*; do
    if [ -f "$f" ]; then
      src=$f
      n=$((n + 1))
    fi
  done
  if [ "$n" -ne 1 ]; then
    echo "probe-molfiles.sh: $n sources for $p" >&2
    exit 1
  fi
  case $src in
    *.c) comp=$cc ;;
    *) comp=$cxx ;;
  esac
  "$comp" -w -DSTATIC_PLUGIN -DVMDPLUGIN="$p" -I"$m/include" -I"$m/src" \
    -c "$src" -o "$work/$p.o"
done
"$cc" -w -I"$m/include" -c "$work/probe.c" -o "$work/probe.o"
"$cxx" "$work"/*.o -o "$work/probe" -lm
"$work/probe"
