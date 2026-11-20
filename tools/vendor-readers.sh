#!/bin/sh
# Copyright (c) d-SEAMS developers
# Vendor readcon-core (Rust, cargo) and patched chemfiles 0.10.4 into the
# package tree so `R CMD INSTALL` of the source tarball builds both offline.
#
#   sh tools/vendor-readers.sh SEAMS_CORE_SRC PKG
#
# SEAMS_CORE_SRC is the seams-core tree tools/vendor.sh just copied. The
# readcon-core git pin is subprojects/readcon-core.wrap. The chemfiles
# archive URL and sha256 are scripts/dist_vendor.py and
# cmake/ChemfilesDep.cmake. READCON_SRC, when set, is a readcon-core
# checkout used instead of cloning the wrap revision.
set -eu

root=$1
pkg=$2

if ! command -v python3 >/dev/null 2>&1; then
  echo "vendor-readers.sh: python3 is required to vendor readcon-core and chemfiles" >&2
  exit 1
fi
if ! command -v cargo >/dev/null 2>&1 || ! command -v rustc >/dev/null 2>&1; then
  echo "vendor-readers.sh: rustc >= 1.88 and cargo are required to vendor readcon-core" >&2
  exit 1
fi
rustc_ok=$(rustc --version | awk '
  $1 == "rustc" {
    split($2, a, ".")
    if (a[1] > 1 || (a[1] == 1 && a[2] >= 88)) ok = 1
  }
  END { print ok + 0 }
')
if [ "$rustc_ok" != 1 ]; then
  echo "vendor-readers.sh: rustc >= 1.88 is required (found $(rustc --version))" >&2
  exit 1
fi

wrap=$root/subprojects/readcon-core.wrap
if [ ! -f "$wrap" ]; then
  echo "vendor-readers.sh: $wrap is missing" >&2
  exit 1
fi
readcon_url=$(sed -n 's/^url *= *//p' "$wrap")
readcon_rev=$(sed -n 's/^revision *= *//p' "$wrap")
if [ -z "$readcon_url" ] || [ -z "$readcon_rev" ]; then
  echo "vendor-readers.sh: $wrap has no url and revision" >&2
  exit 1
fi

chem_meta=$(python3 - "$root/scripts/dist_vendor.py" "$root/cmake/ChemfilesDep.cmake" << 'PY'
import re
import sys
from pathlib import Path

dist = Path(sys.argv[1]).read_text()
cmake = Path(sys.argv[2]).read_text()
url = re.search(r"https://github.com/chemfiles/chemfiles/archive/refs/tags/[^\" ]+", dist)
digest = re.search(r"URL_HASH SHA256=([0-9a-f]{64})", cmake)
if url is None or digest is None:
    sys.exit("vendor-readers.sh: chemfiles URL or sha256 not found")
if digest.group(1) not in dist:
    sys.exit("vendor-readers.sh: chemfiles sha256 in dist_vendor.py and ChemfilesDep.cmake differ")
print(url.group(0))
print(digest.group(1))
PY
)
chem_url=$(printf '%s\n' "$chem_meta" | sed -n '1p')
chem_sha=$(printf '%s\n' "$chem_meta" | sed -n '2p')

work=${TMPDIR:-/tmp}/dseams-readers-$$
mkdir -p "$work"
cleanup_work() {
  rm -rf "$work"
}
trap cleanup_work EXIT

# readcon-core: library sources plus a lockfile of the default
# dependencies, vendored so cargo build --offline does not touch crates.io.
readcon_src=${READCON_SRC:-}
if [ -z "$readcon_src" ]; then
  if ! command -v git >/dev/null 2>&1; then
    echo "vendor-readers.sh: git is required to clone readcon-core $readcon_rev" >&2
    exit 1
  fi
  case "${DSEAMS_NO_DOWNLOAD:-}" in
    1|yes|true|TRUE)
      echo "vendor-readers.sh: DSEAMS_NO_DOWNLOAD is set; set READCON_SRC to a readcon-core tree" >&2
      exit 1
      ;;
  esac
  git clone --depth 1 --branch "$readcon_rev" "$readcon_url" "$work/readcon-core"
  readcon_src=$work/readcon-core
fi
if [ ! -f "$readcon_src/src/lib.rs" ] || [ ! -f "$readcon_src/include/readcon-core.hpp" ]; then
  echo "vendor-readers.sh: $readcon_src is not a readcon-core tree" >&2
  exit 1
fi

dest=$pkg/src/readcon-core
rm -rf "$dest"
mkdir -p "$dest"
cp "$pkg/tools/readcon-Cargo.toml" "$dest/Cargo.toml"
cp "$readcon_src/build.rs" "$readcon_src/LICENSE" "$dest/"
cp -R "$readcon_src/src" "$readcon_src/include" "$dest/"
# [[nodiscard]] on the C++ wrapper becomes a warning under R CMD check
# when a caller discards the value. The engine copy drops it for the
# same reason.
for f in "$dest"/include/*.h "$dest"/include/*.hpp; do
  sed -e 's/\[\[nodiscard\]\] *//g' \
    -e 's/\[\[deprecated([^]]*)\]\] *//g' \
    -e '/#pragma GCC diagnostic/d' \
    -e '/#pragma clang diagnostic/d' "$f" > "$f.tmp"
  mv "$f.tmp" "$f"
done
(
  cd "$dest"
  cargo generate-lockfile
  cargo vendor vendor >/dev/null
)
if [ ! -f "$dest/vendor/dlpk/.cargo-checksum.json" ]; then
  echo "vendor-readers.sh: cargo vendor did not write readcon-core checksums" >&2
  exit 1
fi
# Cargo looks up .cargo-checksum.json. That name is a hidden file, which
# R CMD check notes. The tarball stores the same bytes as
# cargo-checksum.json, and src/Makevars restores the dotted name before
# cargo runs. Other dotted vendor files are not needed to build.
find "$dest/vendor" -name '.cargo-checksum.json' -exec sh -c \
  'mv "$1" "$(dirname "$1")/cargo-checksum.json"' _ {} \;
# Drop checksum entries for the hidden files removed above. Cargo refuses
# to build offline when a listed file is absent.
python3 - "$dest/vendor" << 'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
for checksum in root.rglob("cargo-checksum.json"):
    data = json.loads(checksum.read_text())
    files = data.get("files")
    if not isinstance(files, dict):
        continue
    data["files"] = {
        name: digest
        for name, digest in files.items()
        if (checksum.parent / name).is_file()
    }
    checksum.write_text(json.dumps(data, separators=(",", ":")) + "\n")
PY
find "$dest/vendor" -depth \( \
  -name '.cargo_vcs_info.json' -o -name '.github' -o -name '.ignore' \
  -o -name '.vim' -o -name '.reuse' -o -name '.travis.yml' \
  -o -name '.rustfmt.toml' -o -name '.codecov.yml' -o -name '.gitignore' \
  \) -exec rm -rf {} +
{
  echo "readcon-core sources for the bundled CON reader."
  echo "revision: $readcon_rev"
  echo "upstream: $readcon_url"
  echo "Cargo.toml is tools/readcon-Cargo.toml. Crates are vendored for cargo --offline."
} > "$dest/README"

# chemfiles 0.10.4 with the seams-core patches (mmCIF, MOL2, frame visit,
# Apple zlib, fmt/libc++). cmake builds this tree at install time.
case "${DSEAMS_NO_DOWNLOAD:-}" in
  1|yes|true|TRUE)
    if [ -z "${CHEMFILES_TARBALL:-}" ]; then
      echo "vendor-readers.sh: DSEAMS_NO_DOWNLOAD is set; set CHEMFILES_TARBALL to chemfiles 0.10.4" >&2
      exit 1
    fi
    ;;
esac
archive=$work/chemfiles.tar.gz
if [ -n "${CHEMFILES_TARBALL:-}" ]; then
  cp "$CHEMFILES_TARBALL" "$archive"
else
  python3 - "$chem_url" "$archive" << 'PY'
import sys
import urllib.request
urllib.request.urlretrieve(sys.argv[1], sys.argv[2])
PY
fi
python3 - "$archive" "$chem_sha" << 'PY'
import hashlib
import sys
got = hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest()
if got != sys.argv[2]:
    sys.exit("vendor-readers.sh: chemfiles sha256 {} != {}".format(got, sys.argv[2]))
PY
tar -xzf "$archive" -C "$work"
chem_src=$work/chemfiles-0.10.4
if [ ! -d "$chem_src" ]; then
  echo "vendor-readers.sh: chemfiles archive did not contain chemfiles-0.10.4" >&2
  exit 1
fi
patches=$root/cmake/patches
for name in chemfiles-0.10.4-mmcif.patch chemfiles-0.10.4-mol2.patch \
  chemfiles-0.10.4-frame-visit.patch; do
  patch -p1 -d "$chem_src" -i "$patches/$name"
done
(
  cd "$chem_src"
  sh "$patches/chemfiles-0.10.4-zlib-apple.sh"
  sh "$patches/chemfiles-0.10.4-fmt-libcxx.sh"
)
rm -rf "$pkg/src/chemfiles"
mv "$chem_src" "$pkg/src/chemfiles"
if ! grep -q seams_with_frame "$pkg/src/chemfiles/src/Trajectory.cpp"; then
  echo "vendor-readers.sh: chemfiles frame-visit patch did not apply" >&2
  exit 1
fi
# Tests and diagnostic pragmas are not part of the library the package
# compiles, and R CMD check rejects both the pragmas and the hidden files.
rm -rf "$pkg/src/chemfiles/tests"
find "$pkg/src/chemfiles" -name '*.cpp' -o -name '*.hpp' -o -name '*.h' \
  -o -name '*.c' -o -name '*.cc' | while read -r f; do
  if grep -q '#pragma \(GCC\|clang\) diagnostic' "$f"; then
    sed -e '/#pragma GCC diagnostic/d' -e '/#pragma clang diagnostic/d' \
      "$f" > "$f.tmp"
    mv "$f.tmp" "$f"
  fi
done
find "$pkg/src/chemfiles" -depth \( \
  -name '.codecov.yml' -o -name '.github' -o -name '.gitignore' \
  -o -name '.travis.yml' -o -name '.clang-format' \
  \) -exec rm -rf {} +

python3 "$pkg/tools/patch-lang-nframes.py" "$pkg/src/seams/seams_lang.cpp"

extdata=$pkg/inst/extdata
mkdir -p "$extdata"
con=$root/input/eon/tiny_multi_cuh2.con
if [ ! -f "$con" ]; then
  echo "vendor-readers.sh: $con is missing; the CON example is part of the package" >&2
  exit 1
fi
cp "$con" "$extdata/tiny_multi_cuh2.con"
cp "$pkg/tools/readers/tiny.pdb" "$pkg/tools/readers/tiny.gro" \
  "$pkg/tools/readers/tiny.xyz" "$extdata/"

echo "vendor-readers.sh: readcon-core $readcon_rev and chemfiles 0.10.4"
