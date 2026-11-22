#!/usr/bin/env python3
# Copyright (c) d-SEAMS developers
"""Keep __STRICT_ANSI__ defined in vendored fmt/os.h under MinGW.

    python3 tools/chemfiles-fmt-mingw.py CHEMFILES_TREE
    python3 tools/chemfiles-fmt-mingw.py --check CHEMFILES_TREE

chemfiles 0.10.4 unpacks external/fmt.tar.gz and compiles fmt with
-std=c++11 (set in chemfiles' cmake/CompilerFlags.cmake, which forces
CMAKE_CXX_EXTENSIONS OFF and appends -std=c++11 to CMAKE_CXX_FLAGS).
fmt 6's include/fmt/os.h undefines __STRICT_ANSI__ under __MINGW32__
and __CYGWIN__ as a workaround for a 2013 legacy MinGW.org bug
(sourceforge.net/p/mingw/bugs/2024), before including format.h and
<limits>.

Under Rtools GCC 14 (libstdc++ 14), <limits> selects an IEEE binary64
path for std::numeric_limits<__float128> when __STRICT_ANSI__ is
defined, and hex-float Q literals (0x1.0p-16382Q) when it is not.
Undefining __STRICT_ANSI__ while GCC is still in strict -std=c++11
mode causes libstdc++ 14 to emit those literals and GCC to reject them
(exponent has no digits; unable to find numeric literal operator
'operator""Q'). libstdc++ itself warns that undefining __STRICT_ANSI__
is unsupported.

A CMake cache flag (-DCMAKE_CXX_EXTENSIONS=ON) cannot override
chemfiles' non-cache set(CMAKE_CXX_EXTENSIONS OFF) or the -std=c++11
appended by CompilerFlags.cmake. Removing the obsolete #undef block
from fmt/include/fmt/os.h fixes the cause directly (matching upstream
fmt, which dropped the #undef __STRICT_ANSI__ workaround). MinGW-w64
declares every CRT/POSIX symbol fmt/src/os.cc calls under -std=c++11.

The archive is repacked with gzip mtime 0 and the members' own
metadata, so a re-vendor gives the same bytes. A second run changes
nothing. tools/vendor-readers.sh runs the first form.
"""

import gzip
import io
import re
import sys
import tarfile
from pathlib import Path

ARCHIVE = "fmt.tar.gz"
MEMBER = "fmt/include/fmt/os.h"

OLD = (
    "#ifndef FMT_OS_H_\n"
    "#define FMT_OS_H_\n"
    "\n"
    "#if defined(__MINGW32__) || defined(__CYGWIN__)\n"
    "// Workaround MinGW bug https://sourceforge.net/p/mingw/bugs/2024/.\n"
    "#  undef __STRICT_ANSI__\n"
    "#endif\n"
    "\n"
    "#include <cerrno>\n"
)
NEW = (
    "#ifndef FMT_OS_H_\n"
    "#define FMT_OS_H_\n"
    "\n"
    "// Keep __STRICT_ANSI__ intact under MinGW-w64: libstdc++ 14 uses\n"
    "// __float128 Q literals in <limits> when __STRICT_ANSI__ is unset,\n"
    "// which GCC rejects under chemfiles' -std=c++11.\n"
    "#include <cerrno>\n"
)
UNDEF_RE = re.compile(r"^\s*#\s*undef\s+__STRICT_ANSI__\b", re.MULTILINE)


def fail(msg):
    sys.exit("chemfiles-fmt-mingw.py: " + msg)


def read_text(data, where):
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        fail("{} is not UTF-8".format(where))


def patched(text):
    return (
        NEW in text
        and OLD not in text
        and UNDEF_RE.search(text) is None
        and '#include "format.h"' in text
    )


def apply_text(text, where):
    if patched(text):
        return text, False
    if text.count(OLD) != 1:
        fail("{} does not have the MinGW __STRICT_ANSI__ undef block".format(where))
    text = text.replace(OLD, NEW, 1)
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
        fail("{} still undefines __STRICT_ANSI__".format(MEMBER))


def main():
    argv = sys.argv[1:]
    check_only = bool(argv) and argv[0] == "--check"
    if check_only:
        argv = argv[1:]
    if len(argv) != 1:
        print(
            "usage: chemfiles-fmt-mingw.py [--check] CHEMFILES_TREE",
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
