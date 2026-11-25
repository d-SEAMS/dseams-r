#!/usr/bin/env python3
# Copyright (c) d-SEAMS developers
"""Write chemfiles' generated config.h and exports.h with LF line endings.

    python3 tools/chemfiles-lf-headers.py CHEMFILES_TREE
    python3 tools/chemfiles-lf-headers.py --check CHEMFILES_TREE

chemfiles 0.10.4 generates include/chemfiles/config.h with configure_file()
and include/chemfiles/exports.h with generate_export_header(), which calls
configure_file() too. Without NEWLINE_STYLE, configure_file() opens its
output as a text-mode stream (cmMakefile::ConfigureFile adds
std::ios::binary only when a newline style is given), so a Windows build
writes both headers with CRLF. The package installs chemfiles into
src/chemfiles-install, and R CMD check on Windows reports the two headers
under "checking line endings in C/C++/Fortran sources/headers".

config.h gets NEWLINE_STYLE LF. generate_export_header() has no newline
option, so it writes exports.h.in in the build directory, and a second
configure_file(@ONLY NEWLINE_STYLE LF) writes include/chemfiles/exports.h.
configure_file() reads its input in text mode and drops a trailing CR, and
the generated export header holds no @VAR@ reference and no #cmakedefine,
so that pass changes the line endings only. A second run changes nothing.
tools/vendor-readers.sh runs the first form.
"""

import sys
from pathlib import Path

OLD_CONFIG = (
    "configure_file (\n"
    '  "${PROJECT_SOURCE_DIR}/include/chemfiles/config.in.h"\n'
    '  "${PROJECT_BINARY_DIR}/include/chemfiles/config.h"\n'
    ")\n"
)
NEW_CONFIG = (
    "configure_file (\n"
    '  "${PROJECT_SOURCE_DIR}/include/chemfiles/config.in.h"\n'
    '  "${PROJECT_BINARY_DIR}/include/chemfiles/config.h"\n'
    "  NEWLINE_STYLE LF\n"
    ")\n"
)
OLD_EXPORTS = (
    "generate_export_header(chemfiles\n"
    "    BASE_NAME CHFL\n"
    "    EXPORT_FILE_NAME ${PROJECT_BINARY_DIR}/include/chemfiles/exports.h\n"
    ")\n"
)
NEW_EXPORTS = (
    "generate_export_header(chemfiles\n"
    "    BASE_NAME CHFL\n"
    "    EXPORT_FILE_NAME ${PROJECT_BINARY_DIR}/exports.h.in\n"
    ")\n"
    "configure_file(\n"
    '  "${PROJECT_BINARY_DIR}/exports.h.in"\n'
    '  "${PROJECT_BINARY_DIR}/include/chemfiles/exports.h"\n'
    "  @ONLY NEWLINE_STYLE LF\n"
    ")\n"
)
EDITS = ((OLD_CONFIG, NEW_CONFIG), (OLD_EXPORTS, NEW_EXPORTS))


def fail(msg):
    sys.exit("chemfiles-lf-headers.py: " + msg)


def patched(text):
    return all(new in text and old not in text for old, new in EDITS)


def apply_text(text, where):
    if patched(text):
        return text, False
    for old, new in EDITS:
        if new in text:
            continue
        if text.count(old) != 1:
            fail("{} does not have the expected block:\n{}".format(where, old))
        text = text.replace(old, new, 1)
    if not patched(text):
        fail("{} was not patched".format(where))
    return text, True


def read_text(path):
    try:
        return path.read_bytes().decode("utf-8")
    except UnicodeDecodeError:
        fail("{} is not UTF-8".format(path))


def main():
    argv = sys.argv[1:]
    check_only = bool(argv) and argv[0] == "--check"
    if check_only:
        argv = argv[1:]
    if len(argv) != 1:
        print(
            "usage: chemfiles-lf-headers.py [--check] CHEMFILES_TREE",
            file=sys.stderr,
        )
        return 2
    path = Path(argv[0]) / "CMakeLists.txt"
    if not path.is_file():
        fail("{} is not a chemfiles tree".format(argv[0]))
    text = read_text(path)
    if check_only:
        if not patched(text):
            fail("{} does not write config.h and exports.h with LF".format(path))
        return 0
    text, changed = apply_text(text, str(path))
    if changed:
        path.write_bytes(text.encode("utf-8"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
