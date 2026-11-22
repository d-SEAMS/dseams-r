#!/usr/bin/env python3
# Copyright (c) d-SEAMS developers
"""Use the GCC bit scan in the vendored lzma when the compiler is MinGW.

    python3 tools/chemfiles-lzma-mingw.py CHEMFILES_TREE
    python3 tools/chemfiles-lzma-mingw.py --check CHEMFILES_TREE

chemfiles 0.10.4 unpacks external/lzma.tar.gz and compiles liblzma.
liblzma/common/memcmplen.h takes its 64-bit fast path on x86-64, then
calls _BitScanForward64 whenever _M_X64 is defined. MinGW-w64 defines
_M_X64 from <stddef.h> (the macro is not a compiler predefined, and
<stddef.h> is included from sysdefs.h after config.h). GCC does not
declare _BitScanForward64 unless <intrin.h> is included, and Rtools
GCC 14 rejects the implicit declaration. The GCC builtin __builtin_ctzll
is the path the same function already uses when _M_X64 is unset.

config.h cannot fix this. TUKLIB_FAST_UNALIGNED_ACCESS is set from
__x86_64__ as well as _M_X64, and an #undef of _M_X64 in the generated
config is undone by the <stddef.h> that follows it. The test that
selects the intrinsic is in the upstream header, so the header is what
changes. The condition is the one xz 5.4.4 uses: the intrinsic only for
MSVC and the Intel compiler, which is where <intrin.h> provides it, and
<intrin.h> included only for MSVC. GCC and Clang, including MinGW, keep
__builtin_ctzll. The archive is repacked with gzip mtime 0 and the
members' own metadata, so a re-vendor gives the same bytes. A second
run changes nothing. tools/vendor-readers.sh runs the first form.
"""

import gzip
import io
import sys
import tarfile
from pathlib import Path

ARCHIVE = "lzma.tar.gz"
MEMBER = "lzma/liblzma/common/memcmplen.h"

OLD_IF = "#\tif defined(_M_X64) // MSVC or Intel C compiler on Windows\n"
NEW_IF = (
    "#\tif (defined(_MSC_VER) || defined(__INTEL_COMPILER)) "
    "&& defined(_M_X64)\n"
)
ANCHOR = "#ifdef HAVE_IMMINTRIN_H\n#\tinclude <immintrin.h>\n#endif\n"
INTRIN = (
    "// _BitScanForward64 is an MSVC intrinsic declared by <intrin.h>.\n"
    "// The Intel compiler provides it without the header. MinGW defines\n"
    "// _M_X64 later, from <stddef.h>, and GCC does not declare the name.\n"
    "#if defined(TUKLIB_FAST_UNALIGNED_ACCESS) \\\n"
    "\t\t&& defined(_MSC_VER) \\\n"
    "\t\t&& defined(_M_X64) \\\n"
    "\t\t&& !defined(__INTEL_COMPILER)\n"
    "#\tinclude <intrin.h>\n"
    "#endif\n"
)


def fail(msg):
    sys.exit("chemfiles-lzma-mingw.py: " + msg)


def read_text(data, where):
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        fail("{} is not UTF-8".format(where))


def patched(text):
    return (
        NEW_IF in text
        and INTRIN in text
        and "__builtin_ctzll" in text
        and "_BitScanForward64" in text
        and OLD_IF not in text
    )


def apply_text(text, where):
    if patched(text):
        return text, False
    if text.count(OLD_IF) != 1:
        fail("{} does not have the MinGW _BitScanForward64 condition".format(where))
    if text.count(ANCHOR) != 1:
        fail("{} does not have the immintrin include".format(where))
    if "__builtin_ctzll" not in text or "_BitScanForward64" not in text:
        fail("{} does not have both bit-scan paths".format(where))
    text = text.replace(ANCHOR, ANCHOR + "\n" + INTRIN, 1)
    text = text.replace(OLD_IF, NEW_IF, 1)
    if not patched(text):
        fail("{} was not patched".format(where))
    return text, True


def rewrite(path):
    with tarfile.open(path, "r:gz") as src:
        fmt = src.format
        members = []
        changed = False
        found = False
        for member in src.getmembers():
            data = None
            if member.isfile():
                data = src.extractfile(member).read()
                if member.name == MEMBER:
                    found = True
                    where = "{}:{}".format(path.name, member.name)
                    text, did = apply_text(read_text(data, where), where)
                    if did:
                        data = text.encode("utf-8")
                        member.size = len(data)
                        changed = True
            members.append((member, data))
    if not found:
        fail("{} has no {}".format(path.name, MEMBER))
    if not changed:
        return False
    raw = io.BytesIO()
    with tarfile.open(fileobj=raw, mode="w", format=fmt) as dst:
        for member, data in members:
            dst.addfile(member, io.BytesIO(data) if data is not None else None)
    with open(path, "wb") as out:
        with gzip.GzipFile(filename="", mode="wb", fileobj=out, mtime=0) as gz:
            gz.write(raw.getvalue())
    return True


def check(tree):
    path = tree / "external" / ARCHIVE
    if not path.is_file():
        fail("no {}".format(path))
    with tarfile.open(path, "r:gz") as tar:
        try:
            member = tar.getmember(MEMBER)
        except KeyError:
            fail("{} has no {}".format(ARCHIVE, MEMBER))
        text = read_text(tar.extractfile(member).read(), MEMBER)
    if not patched(text):
        fail("{} still takes _BitScanForward64 for every _M_X64".format(MEMBER))


def main():
    argv = sys.argv[1:]
    check_only = bool(argv) and argv[0] == "--check"
    if check_only:
        argv = argv[1:]
    if len(argv) != 1:
        print(
            "usage: chemfiles-lzma-mingw.py [--check] CHEMFILES_TREE",
            file=sys.stderr,
        )
        return 2
    tree = Path(argv[0])
    if not (tree / "CMakeLists.txt").is_file():
        fail("{} is not a chemfiles tree".format(tree))
    if not check_only:
        rewrite(tree / "external" / ARCHIVE)
    check(tree)
    return 0


if __name__ == "__main__":
    sys.exit(main())
