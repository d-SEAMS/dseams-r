#!/usr/bin/env python3
# Copyright (c) d-SEAMS developers
"""Raise the CMake policy floor of the vendored chemfiles tree.

    python3 tools/chemfiles-cmake-floor.py CHEMFILES_TREE
    python3 tools/chemfiles-cmake-floor.py --check CHEMFILES_TREE

chemfiles 0.10.4 and the libraries it unpacks from external/*.tar.gz at
configure time (zlib, lzma, bzip2, fmt, toml11, tng, molfiles, ...) ask
for CMake 2.8 to 3.4. CMake 4 removed compatibility with versions below
3.5 and stops at the first such cmake_minimum_required(). CMake 3.31 and
later warn below 3.10.

The first form rewrites each cmake_minimum_required() below the floor,
in every CMakeLists.txt and *.cmake file of the tree and of each
external tarball, to VERSION 3.5...3.10 (keeping FATAL_ERROR), repacks
the tarballs it changed, and then runs the check. The tarballs are
written with gzip mtime 0 and their members' own metadata, so a
re-vendor gives the same bytes.

The policy version stops at 3.10 on purpose. With 3.22 or later, policy
CMP0128 makes CMake add -std=c17 for the C_EXTENSIONS OFF that chemfiles
sets, and lzma and the molfile plugins then lose the POSIX declarations
(sigset_t, strcasecmp) they compile with today. Policies 3.5 to 3.10 do
not change the flags any vendored target compiles with.

The check reads the same files and fails when a cmake_minimum_required()
has a minimum below 3.5 or a policy version (the ...max, else the
minimum) below 3.10, or when a file has a cmake_minimum_required() that
this script cannot parse. tools/vendor-readers.sh runs the first form on
every vendor; tests/testthat/test-portability.R checks the shipped tree.
"""

import gzip
import io
import re
import sys
import tarfile
from pathlib import Path

FLOOR_MIN = (3, 5)
FLOOR_POLICY = (3, 10)
NEW_RANGE = "3.5...3.10"

CALL = re.compile(r"cmake_minimum_required\s*\(([^)]*)\)", re.IGNORECASE)
ARGS = re.compile(
    r"^\s*VERSION\s+([0-9]+(?:\.[0-9]+)*)(?:\.\.\.([0-9]+(?:\.[0-9]+)*))?"
    r"(\s+FATAL_ERROR)?\s*$",
    re.IGNORECASE,
)


def fail(msg):
    sys.exit("chemfiles-cmake-floor.py: " + msg)


def version(text):
    parts = [int(p) for p in text.split(".")]
    return tuple((parts + [0, 0])[:2])


def is_cmake(name):
    base = name.rsplit("/", 1)[-1]
    return base == "CMakeLists.txt" or base.endswith(".cmake")


def problems(text, where):
    """Each cmake_minimum_required() in text that is below the floor."""
    bad = []
    for call in CALL.finditer(text):
        args = ARGS.match(call.group(1))
        if args is None:
            bad.append("{}: cannot parse '{}'".format(where, call.group(0)))
            continue
        low = version(args.group(1))
        policy = version(args.group(2)) if args.group(2) else low
        if low < FLOOR_MIN or policy < FLOOR_POLICY:
            bad.append("{}: '{}' is below VERSION 3.5 with policies 3.10".format(
                where, call.group(0)))
    return bad


def raise_floor(text):
    def repl(call):
        args = ARGS.match(call.group(1))
        if args is None:
            return call.group(0)
        low = version(args.group(1))
        policy = version(args.group(2)) if args.group(2) else low
        if low >= FLOOR_MIN and policy >= FLOOR_POLICY:
            return call.group(0)
        tail = " FATAL_ERROR" if args.group(3) else ""
        return "cmake_minimum_required(VERSION {}{})".format(NEW_RANGE, tail)

    return CALL.sub(repl, text)


def read_text(data, where):
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        fail("{} is not UTF-8".format(where))


def tree_files(tree):
    return sorted(
        p for p in tree.rglob("*")
        if p.is_file() and is_cmake(p.name)
    )


def tarballs(tree):
    found = sorted((tree / "external").glob("*.tar.gz"))
    if not found:
        fail("no external/*.tar.gz under {}".format(tree))
    return found


def rewrite_tarball(path):
    with tarfile.open(path, "r:gz") as src:
        fmt = src.format
        members = []
        changed = False
        for member in src.getmembers():
            data = None
            if member.isfile():
                data = src.extractfile(member).read()
                if is_cmake(member.name):
                    where = "{}:{}".format(path.name, member.name)
                    text = read_text(data, where)
                    new = raise_floor(text)
                    if new != text:
                        data = new.encode("utf-8")
                        member.size = len(data)
                        changed = True
            members.append((member, data))
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
    bad = []
    seen = 0
    for path in tree_files(tree):
        seen += 1
        rel = path.relative_to(tree).as_posix()
        bad += problems(read_text(path.read_bytes(), rel), rel)
    for path in tarballs(tree):
        with tarfile.open(path, "r:gz") as tar:
            for member in tar.getmembers():
                if member.isfile() and is_cmake(member.name):
                    seen += 1
                    where = "{}:{}".format(path.name, member.name)
                    data = tar.extractfile(member).read()
                    bad += problems(read_text(data, where), where)
    if seen == 0:
        fail("no CMake files under {}".format(tree))
    if bad:
        fail("CMake policy floor not met:\n  " + "\n  ".join(bad))
    if not CALL.search((tree / "CMakeLists.txt").read_text(encoding="utf-8")):
        fail("{}/CMakeLists.txt has no cmake_minimum_required()".format(tree))


def main():
    argv = sys.argv[1:]
    check_only = bool(argv) and argv[0] == "--check"
    if check_only:
        argv = argv[1:]
    if len(argv) != 1:
        print("usage: chemfiles-cmake-floor.py [--check] CHEMFILES_TREE", file=sys.stderr)
        return 2
    tree = Path(argv[0])
    if not (tree / "CMakeLists.txt").is_file():
        fail("{} is not a chemfiles tree".format(tree))
    if not check_only:
        for path in tree_files(tree):
            text = read_text(path.read_bytes(), str(path))
            new = raise_floor(text)
            if new != text:
                path.write_bytes(new.encode("utf-8"))
        for path in tarballs(tree):
            rewrite_tarball(path)
    check(tree)
    return 0


if __name__ == "__main__":
    sys.exit(main())
