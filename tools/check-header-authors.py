#!/usr/bin/env python3
# Copyright (c) d-SEAMS developers
"""Fail when a vendored source header names someone DESCRIPTION and
LICENSE.note do not.

    python3 tools/check-header-authors.py [PKG]

PKG is the package tree after tools/vendor.sh (default: the current
directory). A header author is a copyright holder or a credited person
(written by, author, plugin by, contributed by, derived from), read with
the same rules as tools/audit-licence-headers.py. The name is recorded
when every significant word of it occurs in the Authors@R field or in
LICENSE.note. inst/AUTHORS is not enough: a person listed only there,
such as the second author of a plugin header, still fails this check.

The script exits 1 when any such name is absent. It exits 2 when
DESCRIPTION, LICENSE.note, or a vendored tree cannot be read, so a
package that has not been vendored does not pass.
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


def authors_at_r(description):
    start = description.find("Authors@R:")
    end = description.find("\nDescription:")
    if start < 0 or end < 0 or end < start:
        return None
    return description[start:end]


def missing_words(audit, name, reference):
    folded = audit.fold(reference)
    return [word for word in audit.key_words(name) if audit.fold(word) not in folded]


def scan_files(audit, files, reference, found):
    for path in sorted(files):
        data = files[path]
        if not audit.is_text(path, data):
            continue
        if audit.is_licence_file(Path(path).name):
            continue
        text = audit.head_tail(data)
        for kind, names in (
            ("copyright", audit.holders_of(text)),
            ("credit", audit.credits_of(text)),
        ):
            for name in names:
                absent = missing_words(audit, name, reference)
                if not absent:
                    continue
                key = (path, kind, name)
                if key not in found:
                    found[key] = absent


def require_dir(path):
    if not path.is_dir():
        print("check-header-authors.py: missing directory " + path.as_posix(),
              file=sys.stderr)
        return False
    return True


def main():
    pkg = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    audit = load_audit(Path(__file__).resolve().parent / "audit-licence-headers.py")
    description_path = pkg / "DESCRIPTION"
    note_path = pkg / "LICENSE.note"
    trees = [
        pkg / "src" / "chemfiles" / "external",
        pkg / "src" / "chemfiles",
        pkg / "src" / "readcon-core",
        pkg / "src" / "readcon-core" / "vendor",
        pkg / "src" / "seams",
    ]
    if not description_path.is_file() or not note_path.is_file():
        print("check-header-authors.py: DESCRIPTION and LICENSE.note are required",
              file=sys.stderr)
        return 2
    if not all(require_dir(path) for path in trees):
        return 2
    description = description_path.read_text(encoding="utf-8")
    authors = authors_at_r(description)
    if authors is None:
        print("check-header-authors.py: DESCRIPTION has no Authors@R field",
              file=sys.stderr)
        return 2
    reference = authors + "\n" + note_path.read_text(encoding="utf-8")
    found = {}
    try:
        for archive in sorted((pkg / "src" / "chemfiles" / "external").glob("*.tar.gz")):
            scan_files(audit, audit.from_tar(archive), reference, found)
        scan_files(
            audit,
            audit.from_dir(pkg / "src" / "chemfiles", skip=("external",)),
            reference,
            found,
        )
        scan_files(
            audit,
            audit.from_dir(
                pkg / "src" / "readcon-core",
                skip=("vendor", "target", "cargo-home"),
            ),
            reference,
            found,
        )
        vendor = pkg / "src" / "readcon-core" / "vendor"
        for crate in sorted(path for path in vendor.iterdir() if path.is_dir()):
            scan_files(audit, audit.from_dir(crate), reference, found)
        scan_files(audit, audit.from_dir(pkg / "src" / "seams"), reference, found)
    except OSError as exc:
        print("check-header-authors.py: " + str(exc), file=sys.stderr)
        return 2
    if not found:
        print("header authors are named in Authors@R or LICENSE.note")
        return 0
    for (path, kind, name), absent in sorted(found.items()):
        print(
            "missing header {0} in {1}: {2}".format(kind, path, name)
        )
        print("  words not in Authors@R or LICENSE.note: " + ", ".join(absent))
    print(
        "check-header-authors.py: {0} header author name(s) missing".format(len(found)),
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
