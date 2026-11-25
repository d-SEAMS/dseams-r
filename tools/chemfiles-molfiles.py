#!/usr/bin/env python3
# Copyright (c) d-SEAMS developers
"""Finish a chemfiles 0.10.4 tree that has the seams-core patches.

    python3 tools/chemfiles-molfiles.py CHEMFILES_TREE

seams-core's chemfiles-0.10.4-molfiles.patch builds the VMD molfile
plugins and registers each reader as a chemfiles format through the
Molfile<F> wrapper. This script checks that the patched tree builds
PLUGINS: every plugin chemfiles lists as "not yet enabled but that should
compile without issue" is in PLUGINS or in EXCLUDED with its reason, and
external/CMakeLists.txt sets VMD_MOLFILE_PLUGINS to exactly PLUGINS. A
seams-core pin that changes the plugin list stops the script, so the
change is reviewed here (tools/probe-molfiles.sh prints what a plugin
registers) before it ships.

It also makes two edits the patches do not: MinGW builds chemfiles with
-std=gnu++11, and MMTF.cpp includes <type_traits>.
"""

import re
import sys
import tarfile
from pathlib import Path

# The three chemfiles default plugins, the 27 on its "should compile" list
# that read atoms, and dmsplugin (DESRES .dms, links SQLite3),
# cpmdlogplugin and gaussianplugin, which compile once the molfile-sources
# patch adds the QM fields they write.
PLUGINS = {
    "gromacsplugin", "moldenplugin", "psfplugin",
    "abinitplugin", "bgfplugin", "binposplugin", "carplugin", "corplugin",
    "cpmdplugin", "cubeplugin", "dlpolyplugin", "dtrplugin", "gamessplugin",
    "jsplugin", "maeffplugin", "mdfplugin", "namdbinplugin", "parm7plugin",
    "parmplugin", "pqrplugin", "rst7plugin", "tinkerplugin",
    "vasp5xdatcarplugin", "vaspoutcarplugin", "vaspposcarplugin",
    "vaspxdatcarplugin", "vaspxmlplugin", "vtfplugin", "xbgfplugin",
    "xsfplugin",
    "dmsplugin", "cpmdlogplugin", "gaussianplugin",
}

VOLUMETRIC = "reads volumetric data only; Molfile<F> needs atoms"
GRAPHICS = "reads graphics meshes only; Molfile<F> needs atoms"
EXCLUDED = {
    "cifplugin": "no cifplugin source in molfiles.tar.gz, so the build cannot find it",
    "crdplugin": "AMBER crd and crdbox carry no atom count; it comes from a "
                 "separate topology file, which Molfile<F> cannot pass",
    "babelplugin": "runs an external Open Babel 1.x 'babel' executable through "
                   "system() with the file name in the command; it reads nothing itself",
    "basissetplugin": "reads quantum-chemistry basis sets only; Molfile<F> needs atoms",
    "msmsplugin": GRAPHICS,
    "graspplugin": GRAPHICS,
    "molemeshplugin": GRAPHICS,
    "offplugin": GRAPHICS,
    "raster3dplugin": GRAPHICS,
    "stlplugin": GRAPHICS,
    "avsplugin": VOLUMETRIC,
    "biomoccaplugin": VOLUMETRIC,
    "brixplugin": VOLUMETRIC,
    "ccp4plugin": VOLUMETRIC,
    "dsn6plugin": VOLUMETRIC,
    "dxplugin": VOLUMETRIC,
    "edmplugin": VOLUMETRIC,
    "fs4plugin": VOLUMETRIC,
    "grdplugin": VOLUMETRIC,
    "gridplugin": VOLUMETRIC,
    "mapplugin": VOLUMETRIC,
    "pbeqplugin": VOLUMETRIC,
    "phiplugin": VOLUMETRIC,
    "pltplugin": VOLUMETRIC,
    "situsplugin": VOLUMETRIC,
    "spiderplugin": VOLUMETRIC,
    "uhbdplugin": VOLUMETRIC,
    "vaspchgcarplugin": VOLUMETRIC,
    "vaspparchgplugin": VOLUMETRIC,
}


def fail(msg):
    sys.exit("chemfiles-molfiles.py: " + msg)


def replace_once(text, old, new, where):
    if text.count(old) != 1:
        fail("expected one '{}' in {}".format(old.strip(), where))
    return text.replace(old, new)


def check_plugins(chem):
    cmake = chem / "external/CMakeLists.txt"
    text = cmake.read_text(encoding="utf-8")
    try:
        block = text.split("# Plugins not yet enabled but that should compile without issue:")[1]
        block = block.split("# Plugins with a chemfiles specific implementation")[0]
    except IndexError:
        fail("{} has no list of plugins that should compile".format(cmake))
    listed = set(re.findall(r"\b(\w+plugin)\b", block))
    if PLUGINS & set(EXCLUDED):
        fail("both built and excluded: {}".format(sorted(PLUGINS & set(EXCLUDED))))
    unknown = listed - PLUGINS - set(EXCLUDED)
    if unknown:
        fail("chemfiles lists {} as compilable; build or exclude each one".format(sorted(unknown)))
    built = re.search(r"set\(VMD_MOLFILE_PLUGINS\n(.*?)\)", text, re.S)
    if built is None:
        fail("{} does not set VMD_MOLFILE_PLUGINS".format(cmake))
    built = set(built.group(1).split())
    if built != PLUGINS:
        fail("VMD_MOLFILE_PLUGINS adds {} and lacks {}; is the molfiles patch applied?".format(
            sorted(built - PLUGINS), sorted(PLUGINS - built)))
    with tarfile.open(chem / "external/molfiles.tar.gz") as tar:
        sources = [m.name for m in tar.getmembers() if m.isfile()]
    for plugin in sorted(PLUGINS):
        hits = [s for s in sources if re.fullmatch(r"molfiles/src/" + plugin + r"[^/]*\.c[^/]*", s)]
        if len(hits) != 1:
            fail("molfiles.tar.gz has {} sources for {}".format(len(hits), plugin))


def main():
    if len(sys.argv) != 2:
        fail("usage: chemfiles-molfiles.py CHEMFILES_TREE")
    chem = Path(sys.argv[1])
    check_plugins(chem)

    # MinGW's standard library uses GNU floating-point literals in C++11.
    flags = chem / "cmake/CompilerFlags.cmake"
    text = flags.read_text(encoding="utf-8")
    text = replace_once(
        text, 'CHECK_COMPILER_FLAG(CXX "-std=c++11" COMPILER_SUPPORTS_CXX11)',
        'CHECK_COMPILER_FLAG(CXX "${CHFL_CXX11_FLAG}" COMPILER_SUPPORTS_CXX11)', flags)
    text = replace_once(
        text, 'set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11")',
        'set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CHFL_CXX11_FLAG}")', flags)
    text = replace_once(
        text, 'set(CMAKE_CXX_EXTENSIONS OFF)',
        'if(MINGW)\n'
        '    set(CMAKE_CXX_EXTENSIONS ON)\n'
        '    set(CHFL_CXX11_FLAG "-std=gnu++11")\n'
        'else()\n'
        '    set(CMAKE_CXX_EXTENSIONS OFF)\n'
        '    set(CHFL_CXX11_FLAG "-std=c++11")\n'
        'endif()', flags)
    flags.write_text(text, encoding="utf-8")

    # Bundled msgpack uses type traits without including their header.
    mmtf = chem / "src/formats/MMTF.cpp"
    text = mmtf.read_text(encoding="utf-8")
    text = replace_once(text, "#include <unordered_set>\n",
                        "#include <unordered_set>\n#include <type_traits>\n", mmtf)
    mmtf.write_text(text, encoding="utf-8")

    for plugin in sorted(PLUGINS):
        print("chemfiles-molfiles.py: builds {}".format(plugin))


if __name__ == "__main__":
    main()
