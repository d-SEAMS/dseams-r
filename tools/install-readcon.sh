#!/bin/sh
# Install upstream readcon-core into a prefix with cargo-c.
#
# conda-forge does not ship readcon-core. The engine links the C++ header
# and pkg-config module from lode-org/readcon-core, tag v0.16.2, which is
# the revision seams-core 2.14.1 wraps. cargo-c writes readcon-core.pc,
# libreadcon_core, and include/readcon-core.hpp.
#
#   sh tools/install-readcon.sh [prefix]
#
# The prefix defaults to CONDA_PREFIX. READCON_REF selects the tag
# (default v0.16.2). READCON_SRC, when set, is an existing checkout and
# is not cloned.

set -e

prefix=${1:-${CONDA_PREFIX:-}}
if [ -z "$prefix" ]; then
  echo "install-readcon.sh: pass a prefix or set CONDA_PREFIX" >&2
  exit 1
fi

ref=${READCON_REF:-v0.16.2}
src=${READCON_SRC:-}
cloned=""
if [ -z "$src" ]; then
  cloned=$(mktemp -d "${TMPDIR:-/tmp}/readcon-src.XXXXXX")
  git clone --depth 1 --branch "$ref" https://github.com/lode-org/readcon-core.git "$cloned/readcon-core"
  src=$cloned/readcon-core
fi
if [ ! -f "$src/Cargo.toml" ] || [ ! -f "$src/include/readcon-core.hpp" ]; then
  echo "install-readcon.sh: $src is not a readcon-core checkout" >&2
  exit 1
fi

# conda-forge's cargo-c binary is `cargo-cinstall cinstall`. A cargo
# that grew the subcommand accepts `cargo cinstall`.
if cargo-cinstall cinstall --help >/dev/null 2>&1; then
  installer="cargo-cinstall cinstall"
elif cargo cinstall --help >/dev/null 2>&1; then
  installer="cargo cinstall"
else
  echo "install-readcon.sh: cargo-c is not installed (cargo cinstall)" >&2
  exit 1
fi

# --libdir lib keeps the library next to the rest of the prefix. The
# cargo-c default is the multiarch directory, which this prefix does not
# search.
# shellcheck disable=SC2086
( cd "$src" && $installer --prefix "$prefix" --libdir lib )

if [ -n "$cloned" ]; then
  rm -rf "$cloned"
fi

pc=""
for d in "$prefix/lib/pkgconfig" "$prefix/lib64/pkgconfig" "$prefix/share/pkgconfig"; do
  if [ -f "$d/readcon-core.pc" ]; then
    pc=$d/readcon-core.pc
    break
  fi
done
if [ -z "$pc" ]; then
  echo "install-readcon.sh: readcon-core.pc was not installed under $prefix" >&2
  exit 1
fi
echo "install-readcon.sh: $ref -> $pc"
