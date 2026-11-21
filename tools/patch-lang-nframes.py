#!/usr/bin/env python3
# Copyright (c) d-SEAMS developers
"""Count CON frames in the copied seams_lang binding.

seams_path_nframes in bindings/cxx/seams_lang.cpp returns a LAMMPS count
for a .con path. The C API counts those frames through readcon-core.
The R nframes() call uses the language binding, so the copy grows the
same branch, calling sinp::forEachConFrame which the header already
declares when SEAMS_HAS_READCON is set.
"""

import sys
from pathlib import Path

ANCHOR = """\
    if (ext == "lammpstrj" || ext == "dump") {
      const int frames = sinp::nLammpsFrames(path);
      if (frames <= 0) {
        set_error("unreadable dump");
        return -1;
      }
      return frames;
    }
"""

INSERT = ANCHOR + """\
#ifdef SEAMS_HAS_READCON
    if (ext == "con") {
      int frames = 0;
      sinp::forEachConFrame(
          path, 1, 0,
          [&](int, molSys::PointCloud<molSys::Point<double>, double> &cloud) {
            if (cloud.nop > 0) {
              frames += 1;
            }
          });
      if (frames <= 0) {
        set_error("unreadable trajectory");
        return -1;
      }
      return frames;
    }
#endif
"""


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: patch-lang-nframes.py src/seams/seams_lang.cpp", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    text = path.read_text()
    if INSERT in text:
        return 0
    if ANCHOR not in text:
        print(
            "patch-lang-nframes: dump-frame counter not found in {}".format(path),
            file=sys.stderr,
        )
        return 1
    path.write_text(text.replace(ANCHOR, INSERT, 1))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
