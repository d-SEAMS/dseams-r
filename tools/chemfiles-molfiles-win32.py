#!/usr/bin/env python3
# Copyright (c) d-SEAMS developers
"""Select the DESRES Windows paths of dtrplugin and maeffplugin on MinGW.

    python3 tools/chemfiles-molfiles-win32.py CHEMFILES_TREE
    python3 tools/chemfiles-molfiles-win32.py --check CHEMFILES_TREE

chemfiles unpacks external/molfiles.tar.gz and compiles every plugin
tools/chemfiles-molfiles.py enables, including dtrplugin and
maeffplugin. Both files take a Windows path only when DESRES_WIN32 is
set, and they set that macro only for _MSC_VER.

MinGW (the Rtools toolchain) defines _WIN32 and not _MSC_VER, so
dtrplugin.cxx includes <sys/mman.h> and the compile stops. That include
is not called: read_file() mallocs a buffer and read()s the frame. The
DESRES_WIN32 branch is that read path, with binary open and the Windows
directory calls. Defining the macro for every _WIN32 selects it.
_MSC_VER implies _WIN32, so the MSVC build is unchanged. The Unix
branch, including <sys/mman.h>, stays for everything else.

maeffplugin.cxx defines M_PI and M_PI_2 on the same macro. MinGW's
math.h does not declare them, so the plugin is the next file the
Windows build fails on. The same guard selects those definitions.
snprintf stays the MinGW function: that override is still under
_MSC_VER.

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

ARCHIVE = "molfiles.tar.gz"
OLD = (
    "#if defined(_MSC_VER)\n"
    "#ifndef DESRES_WIN32\n"
    "#define DESRES_WIN32\n"
    "#endif\n"
    "#endif\n"
)
PATCHES = {
    "molfiles/src/dtrplugin.hxx": (
        "/* MinGW defines _WIN32 and not _MSC_VER, and it has no\n"
        "   <sys/mman.h>. The branch this selects reads each frame\n"
        "   with read(). _MSC_VER implies _WIN32. */\n"
        "#if defined(_WIN32)\n"
        "#ifndef DESRES_WIN32\n"
        "#define DESRES_WIN32\n"
        "#endif\n"
        "#endif\n"
    ),
    "molfiles/src/maeffplugin.cxx": (
        "/* MinGW defines _WIN32 and not _MSC_VER. This branch defines\n"
        "   M_PI, which MinGW's math.h does not. _MSC_VER implies\n"
        "   _WIN32. */\n"
        "#if defined(_WIN32)\n"
        "#ifndef DESRES_WIN32\n"
        "#define DESRES_WIN32\n"
        "#endif\n"
        "#endif\n"
    ),
}


def fail(msg):
    sys.exit("chemfiles-molfiles-win32.py: " + msg)


def read_text(data, where):
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        fail("{} is not UTF-8".format(where))


def apply_text(text, new, where):
    if new in text:
        if OLD in text:
            fail("{} has both the MSVC guard and the _WIN32 guard".format(where))
        return text, False
    if text.count(OLD) != 1:
        fail("{} does not have the DESRES_WIN32 guard".format(where))
    return text.replace(OLD, new, 1), True


def rewrite(path):
    with tarfile.open(path, "r:gz") as src:
        fmt = src.format
        members = []
        changed = False
        found = set()
        for member in src.getmembers():
            data = None
            if member.isfile():
                data = src.extractfile(member).read()
                new = PATCHES.get(member.name)
                if new is not None:
                    found.add(member.name)
                    where = "{}:{}".format(path.name, member.name)
                    text, did = apply_text(read_text(data, where), new, where)
                    if did:
                        data = text.encode("utf-8")
                        member.size = len(data)
                        changed = True
            members.append((member, data))
    missing = [name for name in PATCHES if name not in found]
    if missing:
        fail("{} lacks {}".format(path.name, ", ".join(missing)))
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
        for name, new in PATCHES.items():
            try:
                member = tar.getmember(name)
            except KeyError:
                fail("{} has no {}".format(ARCHIVE, name))
            text = read_text(tar.extractfile(member).read(), name)
            if new not in text:
                fail("{} does not select DESRES_WIN32 for _WIN32".format(name))
            if OLD in text:
                fail("{} still selects DESRES_WIN32 only for _MSC_VER".format(name))
        cxx_name = "molfiles/src/dtrplugin.cxx"
        try:
            member = tar.getmember(cxx_name)
        except KeyError:
            fail("{} has no {}".format(ARCHIVE, cxx_name))
        cxx = read_text(tar.extractfile(member).read(), cxx_name)
    # The mmap include stays on the non-Windows branch. The read path
    # is the function both branches call.
    if "#ifndef DESRES_WIN32" not in cxx or "#include <sys/mman.h>" not in cxx:
        fail("{} dropped the non-Windows mmap include".format(cxx_name))
    if "void *read_file(" not in cxx or "read(fd, mapping, framesize)" not in cxx:
        fail("{} no longer reads a frame with read()".format(cxx_name))
    guard = cxx.find("#ifndef DESRES_WIN32")
    include = cxx.find("#include <sys/mman.h>")
    windows = cxx.find("windows version")
    if not (0 <= guard < include < windows):
        fail("{} does not keep <sys/mman.h> on the non-Windows branch".format(cxx_name))


def main():
    argv = sys.argv[1:]
    check_only = bool(argv) and argv[0] == "--check"
    if check_only:
        argv = argv[1:]
    if len(argv) != 1:
        print(
            "usage: chemfiles-molfiles-win32.py [--check] CHEMFILES_TREE",
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
