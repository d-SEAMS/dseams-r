#!/usr/bin/env python3
# Copyright (c) d-SEAMS developers
"""Include <type_traits> in the msgpack-c that chemfiles vendors.

    python3 tools/chemfiles-msgpack-type-traits.py CHEMFILES_TREE
    python3 tools/chemfiles-msgpack-type-traits.py --check CHEMFILES_TREE

chemfiles 0.10.4 unpacks external/mmtf-cpp.tar.gz and compiles
src/formats/MMTF.cpp against mmtf-cpp/msgpack-c. The C++11 branch of
include/msgpack/v1/cpp_config_decl.hpp does `using std::remove_volatile`
after including <memory> and <tuple> only. libc++ 23 (and the current
Apple clang, which uses libc++) no longer declares that name through
those headers, so the using-declaration fails. v2/cpp_config_decl.hpp
then fails on `using v1::remove_volatile` because the v1 declaration
did not happen. Including <type_traits> is the upstream fix, msgpack-c
commit 9b801f087ab7434f2ab1ab3c0f48a966c19d3b70 (pull 1162, released in
8.0.0). The vendored header is the older copy inside mmtf-cpp, so the
same line is applied here rather than replacing msgpack-c.

The archive is repacked with gzip mtime 0 and the members' own
metadata, so a re-vendor gives the same bytes. A second run changes
nothing. tools/vendor-readers.sh runs the first form; the portability
test checks the shipped archive.
"""

import gzip
import io
import sys
import tarfile
from pathlib import Path

ARCHIVE = "mmtf-cpp.tar.gz"
MEMBER = "mmtf-cpp/msgpack-c/include/msgpack/v1/cpp_config_decl.hpp"
OLD = "#include <memory>\n#include <tuple>\n\nnamespace msgpack {\n"
NEW = (
    "#include <memory>\n#include <tuple>\n#include <type_traits>\n"
    "\nnamespace msgpack {\n"
)


def fail(msg):
    sys.exit("chemfiles-msgpack-type-traits.py: " + msg)


def read_text(data, where):
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        fail("{} is not UTF-8".format(where))


def patched(text):
    return NEW in text and "using std::remove_volatile;" in text


def apply_text(text, where):
    if patched(text):
        if OLD in text:
            fail("{} has both the old and the new include block".format(where))
        return text, False
    if text.count(OLD) != 1:
        fail("{} does not have the msgpack-c C++11 include block".format(where))
    return text.replace(OLD, NEW, 1), True


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
        fail("{} does not include <type_traits> before std::remove_volatile".format(MEMBER))
    if OLD in text:
        fail("{} still has the unpatched include block".format(MEMBER))
    # v2 imports the name from v1. It needs no edit of its own once v1
    # declares remove_volatile.
    v2 = "mmtf-cpp/msgpack-c/include/msgpack/v2/cpp_config_decl.hpp"
    with tarfile.open(path, "r:gz") as tar:
        try:
            member = tar.getmember(v2)
        except KeyError:
            fail("{} has no {}".format(ARCHIVE, v2))
        text = read_text(tar.extractfile(member).read(), v2)
    if "using v1::remove_volatile;" not in text:
        fail("{} no longer imports remove_volatile from v1".format(v2))


def main():
    argv = sys.argv[1:]
    check_only = bool(argv) and argv[0] == "--check"
    if check_only:
        argv = argv[1:]
    if len(argv) != 1:
        print(
            "usage: chemfiles-msgpack-type-traits.py [--check] CHEMFILES_TREE",
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
