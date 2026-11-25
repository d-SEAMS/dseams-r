#!/usr/bin/env python3
# Copyright (c) d-SEAMS developers
"""List vendored files whose own copyright or licence notice differs from
the licence that covers the part shipping them.

    python3 tools/audit-licence-headers.py [PKG]

PKG is the package tree after tools/vendor.sh (default: the current
directory). A part is one archive in src/chemfiles/external, the rest of
src/chemfiles, src/readcon-core, one crate in src/readcon-core/vendor, or
src/seams. Inside a part, a file is compared with the licence files of
the nearest directory above it that has any (LICENSE*, COPYING*, ...,
LICENSES/), or with the reference DECLARED names for trees that ship
without one. Each file is scanned in its first 120 and last 80 lines and
listed when it names a licence class the reference does not, carries a
restriction phrase, has a copyright line whose holder the reference
does not name, or credits a person (written by, authors of this code,
Author:, plugin by, contributed by, derived from code by) whom
inst/AUTHORS does not name. Every listed holder is marked by whether
inst/AUTHORS names it. A file named like a licence but with a source
suffix (tng/ci-scripts/copyright.py) is scanned as a source file.

The classification is by phrase, so the listing is for review; the
reviewed result is inst/AUTHORS and LICENSE.note. The exit status is 0
unless a part cannot be read.
"""

import re
import sys
import tarfile
import unicodedata
from pathlib import Path

HEAD_LINES = 120
TAIL_LINES = 80

CLASSES = [
    ("GPL", r"GNU General Public License|\bGPL(v[23])?\b"),
    ("LGPL", r"GNU (Lesser|Library) General Public License|\bLGPL"),
    ("Apache", r"Apache License"),
    ("MPL", r"Mozilla Public License"),
    ("BSL", r"Boost Software License"),
    ("NCSA", r"University of Illinois Open Source License|to deal with the Software"),
    ("MIT", r"Permission is hereby granted, free of charge"),
    ("BSD", r"Redistribution and use in source and binary forms"
            r"|\bBSD licen[cs]e\b|Revised BSD"),
    ("ISC", r"Permission to use, copy, modify,? and(/or)? distribute"),
    ("Zlib", r"altered source versions must be plainly marked"),
    ("public-domain", r"public domain"),
    ("Unicode", r"UNICODE LICENSE|Unicode License|UNICODE, INC\. LICENSE"),
    ("Unlicense", r"\bUnlicense\b|unlicense\.org"),
    ("CC", r"Creative Commons|\bCC-BY|\bCC0\b"),
]
SPDX_CLASS = [
    (r"^MIT", "MIT"), (r"^Apache-", "Apache"), (r"^0BSD$", "ISC"),
    (r"^ISC$", "ISC"), (r"^BSD-", "BSD"), (r"^Zlib$", "Zlib"),
    (r"^BSL-", "BSL"), (r"^MPL-", "MPL"), (r"^LGPL", "LGPL"),
    (r"^GPL", "GPL"), (r"^NCSA$", "NCSA"), (r"^Unlicense$", "Unlicense"),
    (r"^Unicode", "Unicode"), (r"^CC", "CC"),
]
RESTRICT = re.compile(
    r"closed[- ]source|not be sold|may not be sold|be sold for profit"
    r"|for any commercial|non-?commercial|do not allow|not allowed to"
    r"|without (the )?(express )?written permission of",
    re.I,
)
SPDX = re.compile(r"SPDX-License-Identifier:\s*([A-Za-z0-9.+\-() ]+)")
COPYRIGHT = re.compile(
    r"(?i)(?:copyright\s*(?:\(c\)|©)?\s*(?:\d{4}|\(c\))"
    r"|copyright\s*(?:\(c\)|©)\s*\w"
    r"|^copyright\s+(?:by\s+)?[A-Z][\w.]+"
    r"|\(c\)\s*(?:copyright\s*)?\d{4}"
    r"|\(c\)\s*copyright\s+[A-Z]"
    r"|©\s*\d{4})"
)
LICENCE_FILE = re.compile(
    r"^(LICEN[CS]E|COPYING|COPYRIGHT|UNLICENSE|NOTICE)([-._].*)?$", re.I
)
SOURCE_SUFFIXES = {
    ".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".rs", ".py",
    ".sh", ".pl", ".js", ".cmake", ".R", ".f", ".f90", ".bat",
}
CREDIT = re.compile(
    r"(?i:\bwritten by|\bauthors? of this (?:code|file)(?: is| are)?:?"
    r"|\bauthors?:|\bplugin by|\bcontributed by|\bderived from code by"
    r"|\boriginal(?:ly)? (?:code )?(?:written )?by)"
    r"\s+((?:[A-Z][\w.'\-]*,?\s+(?:and\s+)?)*[A-Z][\w.'\-]*)"
)
TEXT_SUFFIXES = {
    "", ".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".inl",
    ".ipp", ".rs", ".py", ".sh", ".cmake", ".txt", ".md", ".rst", ".in",
    ".cmakein", ".toml", ".json", ".yml", ".yaml", ".html", ".tex", ".pc",
    ".S", ".s", ".asm", ".def", ".R", ".f", ".f90", ".am", ".ac", ".m4",
    ".bat", ".cfg", ".pl", ".js", ".css", ".xml", ".natvis", ".supp",
    ".map", ".i", ".ipynb",
}

# Trees that ship no licence file. Each entry is (part, path prefix):
# (licence classes, holders), taken from the upstream project's licence.
DECLARED = {
    ("gemmi.tar.gz", "gemmi/"): ({"MPL"}, "Global Phasing Ltd."),
    ("zlib.tar.gz", "zlib/"): ({"Zlib"}, "Jean-loup Gailly and Mark Adler"),
    ("mmtf-cpp.tar.gz", "mmtf-cpp/msgpack-c/"): (
        {"BSL"}, "FURUHASHI Sadayuki and KONDO Takatoshi"),
}


def classes_of(text):
    found = {name for name, pat in CLASSES if re.search(pat, text, re.I)}
    if found & {"NCSA", "BSL"}:
        found.discard("MIT")
    for m in SPDX.finditer(text):
        for ident in re.findall(r"[A-Za-z0-9.+\-]+", m.group(1)):
            if ident in ("OR", "AND", "WITH"):
                continue
            cls = next((c for pat, c in SPDX_CLASS if re.match(pat, ident)), None)
            found.add(cls if cls else "SPDX:" + ident)
    return found


def holders_of(text):
    out = []
    for line in text.splitlines():
        h = re.sub(r"^[\s/*#!;%\-+|>\"'`]*", "", line)
        h = re.sub(r"[\s*/#]*$", "", h)
        if not COPYRIGHT.search(h):
            continue
        if re.search(r"(?i)copyright (notice|holders?|owner|license|statement)\b", h):
            continue
        if len(h) > 150:
            h = h[:150] + "..."
        out.append(h)
    return out


def key_words(h):
    s = re.sub(r"(?i)copyright|\(c\)|©|all rights reserved|\bby\b|\band\b", " ", h)
    s = re.sub(r"<[^>]*>|https?://\S+|\S+@\S+", " ", s)
    s = re.sub(r"[0-9,\-–.:;()\[\]\"'\\]+", " ", s)
    # Licence prose and Windows resource keys that sit on notice lines.
    stop = {"BSD", "MIT", "License", "Licence", "LICENSE", "See", "The", "THE",
            "Agreement", "VALUE", "Legal", "LegalCopyright"}
    return [w for w in s.split() if len(w) > 2 and not w.islower() and w not in stop]


def fold(text):
    text = unicodedata.normalize("NFKD", text)
    return "".join(c for c in text if not unicodedata.combining(c)).lower()


def named_in(h, text):
    words = key_words(h)
    if not words:
        return True
    low = fold(text)
    return all(fold(w) in low for w in words)


def head_tail(data):
    text = data.decode("utf-8", "replace")
    lines = text.splitlines()
    if len(lines) <= HEAD_LINES + TAIL_LINES:
        return text
    return "\n".join(lines[:HEAD_LINES] + lines[-TAIL_LINES:])


def is_text(name, data):
    if b"\0" in data:
        return False
    try:
        data.decode("utf-8")
    except UnicodeDecodeError:
        return Path(name).suffix in TEXT_SUFFIXES
    return True


def is_licence_file(name):
    return bool(LICENCE_FILE.match(name)) and Path(name).suffix not in SOURCE_SUFFIXES


def credits_of(text):
    out = []
    for line in text.splitlines():
        line = re.sub(r"<[^>]*>|\S+@\S+|[()]", " ", line)
        for m in CREDIT.finditer(line):
            names = []
            for w in m.group(1).split():
                w = w.strip(",")
                if w == "and":
                    continue
                # A full stop after a word longer than an initial ends
                # the sentence, and with it the name.
                if w.endswith(".") and not re.fullmatch(r"(?:[A-Z]\.)+", w):
                    names.append(w.rstrip("."))
                    break
                names.append(w)
            # A credit names a person or body: at least two capitalised
            # words, as in "Henri Menke" or "Julien Ferte".
            if len(names) >= 2 and " ".join(names) not in out:
                out.append(" ".join(names))
    return out


def licence_dirs(files):
    dirs = {}
    for p in files:
        parent, _, name = p.rpartition("/")
        if is_licence_file(name):
            dirs.setdefault(parent, []).append(p)
        elif parent.endswith("LICENSES") or parent == "LICENSES":
            dirs.setdefault(parent.rpartition("/")[0] if "/" in parent else "", []).append(p)
    return {d: sorted(v) for d, v in dirs.items()}


def reference(part, path, files, ldirs):
    """Return (label, classes, text) of the licence covering path."""
    best = None
    for (dpart, prefix), (cls, holders) in DECLARED.items():
        if dpart == part and path.startswith(prefix):
            if best is None or len(prefix) > len(best[0]):
                best = (prefix, "declared " + "/".join(sorted(cls)) + " for " + prefix,
                        set(cls), holders)
    d = path
    while True:
        d = d.rpartition("/")[0] if "/" in d else ""
        if d in ldirs and (best is None or len(d) + 1 > len(best[0])):
            text = "\n".join(files[p].decode("utf-8", "replace") for p in ldirs[d])
            return ", ".join(ldirs[d]), classes_of(text), text
        if d == "":
            break
    if best:
        return best[1], best[2], best[3]
    return "NONE", set(), ""


def audit(part, label, files, authors, extra_ref=None):
    ldirs = licence_dirs(files)
    if extra_ref:
        ldirs.setdefault("", []).extend(extra_ref)
    print("== " + label)
    top = reference(part, "x", files, ldirs) if "" in ldirs else None
    if top:
        print("   top-level licence: {} [{}]".format(top[0], ", ".join(sorted(top[1]))))
    scanned = listed = 0
    summary = {}
    binary = []
    for path in sorted(files):
        if path in sum(ldirs.values(), []):
            continue
        if not is_text(path, files[path]):
            binary.append(path)
            continue
        scanned += 1
        ref_label, ref_cls, ref_text = reference(part, path, files, ldirs)
        text = head_tail(files[path])
        extra = sorted(c for c in classes_of(text) if c not in ref_cls)
        restrict = sorted({m.group(0).lower() for m in RESTRICT.finditer(text)})
        foreign = []
        for h in holders_of(text):
            if not named_in(h, ref_text) and h not in foreign:
                foreign.append(h)
        credits = [c for c in credits_of(text) if not named_in(c, authors)]
        if not (extra or restrict or foreign or credits):
            continue
        listed += 1
        print("   - {}  (reference: {})".format(path, ref_label))
        if extra:
            print("       classes: " + ", ".join(extra))
            for c in extra:
                summary.setdefault("class " + c, []).append(path)
        if restrict:
            print("       restriction: " + ", ".join(restrict))
            for r in restrict:
                summary.setdefault("restriction " + r, []).append(path)
        for h in foreign:
            mark = "named in inst/AUTHORS" if named_in(h, authors) else "NOT NAMED in inst/AUTHORS"
            print("       holder: {}  [{}]".format(h, mark))
            summary.setdefault("holder {}  [{}]".format(" ".join(key_words(h)), mark), []).append(path)
        for c in credits:
            print("       credit: {}  [NOT NAMED in inst/AUTHORS]".format(c))
            summary.setdefault("credit {}  [NOT NAMED in inst/AUTHORS]".format(c), []).append(path)
    for path in binary:
        print("   - {}  (not scanned: binary or unknown type)".format(path))
    print("   files scanned: {}, listed: {}, not scanned: {}".format(scanned, listed, len(binary)))
    for key in sorted(summary):
        print("   summary: {} files: {}".format(len(summary[key]), key))
    print()


def from_tar(path):
    files = {}
    with tarfile.open(path) as tar:
        for m in tar.getmembers():
            if m.isfile():
                files[m.name] = tar.extractfile(m).read()
    return files


def from_dir(root, skip=()):
    files = {}
    for p in sorted(root.rglob("*")):
        rel = p.relative_to(root).as_posix()
        if p.suffix in (".o", ".so", ".a", ".dll"):
            continue
        if p.is_file() and not any(rel == s or rel.startswith(s + "/") for s in skip):
            files[rel] = p.read_bytes()
    return files


def main():
    pkg = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    authors = (pkg / "inst/AUTHORS").read_text(encoding="utf-8")
    for archive in sorted((pkg / "src/chemfiles/external").glob("*.tar.gz")):
        audit(archive.name, "src/chemfiles/external/" + archive.name,
              from_tar(archive), authors)
    audit("chemfiles", "src/chemfiles (outside external/)",
          from_dir(pkg / "src/chemfiles", skip=("external",)), authors)
    audit("readcon-core", "src/readcon-core (outside vendor/)",
          from_dir(pkg / "src/readcon-core", skip=("vendor", "target", "cargo-home")),
          authors)
    for crate in sorted(p for p in (pkg / "src/readcon-core/vendor").iterdir() if p.is_dir()):
        audit(crate.name, "src/readcon-core/vendor/" + crate.name, from_dir(crate), authors)
    audit("seams", "src/seams", from_dir(pkg / "src/seams"), authors)


if __name__ == "__main__":
    main()
