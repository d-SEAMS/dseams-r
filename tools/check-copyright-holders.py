#!/usr/bin/env python3
# Copyright (c) d-SEAMS developers
"""Fail when vendored copyright holders, inst/COPYRIGHTS and LICENSE.note disagree.

    python3 tools/check-copyright-holders.py [PKG]

A copyright holder is a notice line read by tools/audit-licence-headers.py
(the same header scan as tools/check-header-authors.py, licence files
excluded). Every significant word of such a line has to occur in
inst/COPYRIGHTS. Each inst/COPYRIGHTS line has to occur in LICENSE.note
once whitespace is collapsed. Authors@R is compared with this file by
the test, not here: that field is R's to parse.

The script exits 1 when a list disagrees. It exits 2 when DESCRIPTION's
tree, inst/COPYRIGHTS, LICENSE.note, or a vendored directory cannot be
read, so a package that has not been vendored does not pass.
"""

import importlib.util
import sys
from pathlib import Path


def load_audit(script):
    spec = importlib.util.spec_from_file_location("audit_licence_headers", script)
    if spec is None or spec.loader is None:
        raise ImportError(script)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def copyright_lines(path):
    lines = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        lines.append(line)
    return lines


def require_dir(path):
    if not path.is_dir():
        print(
            "check-copyright-holders.py: missing directory " + path.as_posix(),
            file=sys.stderr,
        )
        return False
    return True


def scan_words(audit, files, folded, gaps):
    for path in sorted(files):
        data = files[path]
        if not audit.is_text(path, data):
            continue
        if audit.is_licence_file(Path(path).name):
            continue
        text = audit.head_tail(data)
        for holder in audit.holders_of(text):
            missing = [
                word
                for word in audit.key_words(holder)
                if audit.fold(word) not in folded
            ]
            if missing:
                gaps.append((path, holder, missing))


def main():
    pkg = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    audit = load_audit(Path(__file__).resolve().parent / "audit-licence-headers.py")
    copyrights_path = pkg / "inst" / "COPYRIGHTS"
    note_path = pkg / "LICENSE.note"
    trees = [
        pkg / "src" / "chemfiles" / "external",
        pkg / "src" / "chemfiles",
        pkg / "src" / "readcon-core",
        pkg / "src" / "readcon-core" / "vendor",
        pkg / "src" / "seams",
    ]
    if not copyrights_path.is_file() or not note_path.is_file():
        print(
            "check-copyright-holders.py: inst/COPYRIGHTS and LICENSE.note are required",
            file=sys.stderr,
        )
        return 2
    if not all(require_dir(path) for path in trees):
        return 2
    lines = copyright_lines(copyrights_path)
    if not lines:
        print("check-copyright-holders.py: inst/COPYRIGHTS has no holders", file=sys.stderr)
        return 1
    folded = audit.fold("\n".join(lines))
    note = " ".join(note_path.read_text(encoding="utf-8").split())
    problems = []
    for line in lines:
        if line not in note:
            problems.append("inst/COPYRIGHTS line absent from LICENSE.note: " + line)
    gaps = []
    try:
        for archive in sorted((pkg / "src" / "chemfiles" / "external").glob("*.tar.gz")):
            scan_words(audit, audit.from_tar(archive), folded, gaps)
        scan_words(
            audit,
            audit.from_dir(pkg / "src" / "chemfiles", skip=("external",)),
            folded,
            gaps,
        )
        scan_words(
            audit,
            audit.from_dir(
                pkg / "src" / "readcon-core",
                skip=("vendor", "target", "cargo-home"),
            ),
            folded,
            gaps,
        )
        vendor = pkg / "src" / "readcon-core" / "vendor"
        for crate in sorted(path for path in vendor.iterdir() if path.is_dir()):
            scan_words(audit, audit.from_dir(crate), folded, gaps)
        scan_words(audit, audit.from_dir(pkg / "src" / "seams"), folded, gaps)
    except OSError as exc:
        print("check-copyright-holders.py: " + str(exc), file=sys.stderr)
        return 2
    for path, holder, missing in gaps:
        problems.append(
            "vendored copyright word missing from inst/COPYRIGHTS in {0}: {1}".format(
                path, ", ".join(missing)
            )
        )
        problems.append("  notice: " + holder)
    if problems:
        for problem in problems:
            print(problem)
        print(
            "check-copyright-holders.py: {0} problem(s)".format(len(problems)),
            file=sys.stderr,
        )
        return 1
    print("vendored copyright holders match inst/COPYRIGHTS and LICENSE.note")
    return 0


if __name__ == "__main__":
    sys.exit(main())
