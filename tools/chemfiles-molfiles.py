#!/usr/bin/env python3
# Copyright (c) d-SEAMS developers
"""Enable every VMD molfile reader that chemfiles 0.10.4 can build.

    python3 tools/chemfiles-molfiles.py CHEMFILES_TREE

chemfiles compiles three molfile plugins (gromacs, molden, psf) and lists
the others in external/CMakeLists.txt as "not yet enabled but that should
compile without issue". This script adds to VMD_MOLFILE_PLUGINS every
plugin on that list whose readers return atoms, and registers each such
reader as a chemfiles format through the Molfile<F> wrapper in
src/formats/Molfile.cpp. tools/vendor-readers.sh runs it on every vendor.

READERS is what each plugin registers, as printed by
tools/probe-molfiles.sh. A plugin on chemfiles' list that is in neither
READERS nor EXCLUDED stops the script, so a chemfiles update that changes
the list is reviewed here before it ships. SKIPPED_READERS are readers
of an enabled plugin that cannot work through Molfile<F>.

Molfile.cpp also changes in two ways the new plugins need: nsteps()
counts steps into scratch buffers instead of a null timestep, and the
constructor refuses an empty file and a plugin that reports no atoms.

Each reader becomes a format named after the plugin's pretty name
("VMD " is prefixed when a native chemfiles format has the same name).
Its extension is the reader's own name when the plugin lists it, else
the plugin's first listed extension; an extension a native format or an
earlier reader already holds is skipped, and a reader left with none is
reachable only by format name.
"""

import re
import sys
import tarfile
from pathlib import Path

# plugin: [(reader, pretty name, extensions, structure, coordinates, bonds)]
# structure: read_structure; coordinates: read_next_timestep or
# read_timestep; bonds: read_bonds.
READERS = {
    "abinitplugin": [("ABINIT", "ABINIT", "*|*_GEO|*_DEN|*_WFK|*_POT|*_VHA|*_VHXC|*_VXC", 1, 1, 0)],
    "carplugin": [("car", "InsightII car", "car", 1, 1, 0)],
    "cpmdplugin": [("cpmd", "CPMD", "cpmd", 0, 1, 0)],
    "gamessplugin": [("gamess", "GAMESS", "log", 1, 1, 0)],
    "mdfplugin": [("mdf", "InsightII MDF", "mdf", 1, 0, 1)],
    "namdbinplugin": [("namdbin", "NAMD Binary Coordinates", "coor", 0, 1, 0)],
    "parm7plugin": [("parm7", "AMBER7 Parm", "prmtop,parm7", 1, 0, 1)],
    "parmplugin": [("parm", "AMBER Parm", "parm", 1, 0, 1)],
    "vasp5xdatcarplugin": [("VASP_XDATCAR5", "VASP_XDATCAR5", "VASP_XDATCAR5", 1, 1, 0)],
    "vaspoutcarplugin": [("OUTCAR", "VASP_OUTCAR", "OUTCAR", 1, 1, 0)],
    "vaspposcarplugin": [("POSCAR", "VASP_POSCAR", "POSCAR", 1, 1, 0)],
    "vaspxdatcarplugin": [("XDATCAR", "VASP_XDATCAR", "XDATCAR", 1, 1, 0)],
    "vaspxmlplugin": [("xml", "VASP_xml", "xml", 1, 1, 0)],
    "dlpolyplugin": [
        ("dlpolyhist", "DL_POLY_C HISTORY", "dlpolyhist", 1, 1, 0),
        ("dlpoly3hist", "DL_POLY_4 HISTORY", "dlpolyhist", 1, 1, 0),
        ("dlpolyconfig", "DL_POLY CONFIG", "dlpolyconfig", 1, 1, 0),
    ],
    "tinkerplugin": [("tinker", "Tinker", "arc", 1, 1, 0)],
    "bgfplugin": [("bgf", "MSI Biograf Format", "bgf", 1, 1, 1)],
    "binposplugin": [("binpos", "Scripps Binpos", "binpos", 0, 1, 0)],
    "corplugin": [("cor", "CHARMM Coordinates", "cor", 1, 1, 0)],
    "cubeplugin": [("cube", "Gaussian Cube", "cub,cube", 1, 1, 0)],
    "dtrplugin": [("dtr", "DESRES Trajectory", "dtr,dtr/,stk,atr,atr/", 0, 1, 0)],
    "jsplugin": [("js", "js", "js", 1, 1, 1)],
    "maeffplugin": [("mae", "Maestro File", "mae,maeff,cms", 1, 1, 1)],
    "pqrplugin": [("pqr", "PQR", "pqr", 1, 1, 0)],
    "rst7plugin": [("rst7", "AMBER7 Restart", "rst7", 0, 1, 0)],
    "vtfplugin": [
        ("vsf", "VTF structure format", "vsf", 1, 0, 1),
        ("vcf", "VTF coordinate format", "vcf", 0, 1, 0),
        ("vtf", "VTF trajectory format", "vtf", 1, 1, 1),
    ],
    "xbgfplugin": [("xbgf", "Internal Paratool Format", "xbgf", 1, 1, 1)],
    "xsfplugin": [("xsf", "(Animated) XCrySDen Structure File", "axsf,xsf", 1, 1, 0)],
}

# Readers that never learn the atom count from their own file: VMD takes
# it from a structure loaded first, which Molfile<F> has no way to pass.
SKIPPED_READERS = {
    "vcf": "VTF coordinates without structure; the atom count comes from a "
           "separate structure file",
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

REFERENCE = "https://www.ks.uiuc.edu/Research/vmd/plugins/molfile/"


def fail(msg):
    sys.exit("chemfiles-molfiles.py: " + msg)


def replace_once(text, old, new, where):
    if text.count(old) != 1:
        fail("expected one '{}' in {}".format(old.strip(), where))
    return text.replace(old, new)


def native_formats(chem):
    names, exts = set(), set()
    for f in sorted((chem / "src/formats").glob("*.cpp")):
        text = f.read_text(encoding="utf-8")
        names.update(re.findall(r'metadata\.name = "([^"]+)"', text))
        exts.update(e.lower() for e in re.findall(r'metadata\.extension = "([^"]+)"', text))
    return names, exts


def plan(chem):
    names, taken = native_formats(chem)
    out = []
    for plugin in sorted(READERS):
        for reader, pretty, extensions, structure, coords, bonds in READERS[plugin]:
            if reader in SKIPPED_READERS:
                continue
            name = "VMD " + pretty if pretty in names else pretty
            names.add(name)
            candidates = [e.strip() for e in extensions.split(",")]
            candidates = [e for e in candidates if re.fullmatch(r"[A-Za-z0-9_]+", e)]
            if reader in candidates:
                candidates.remove(reader)
                candidates.insert(0, reader)
            ext = None
            for e in candidates:
                if "." + e.lower() not in taken:
                    ext = "." + e
                    taken.add(ext.lower())
                    break
            ident = "VMDFMT_" + re.sub(r"[^A-Za-z0-9]", "_", reader).upper()
            out.append(dict(plugin=plugin, reader=reader, name=name, ext=ext,
                            ident=ident, structure=structure, coords=coords,
                            bonds=bonds))
    return out


def metadata_cpp(r):
    ext = '"{}"'.format(r["ext"]) if r["ext"] else "nullopt"
    b = lambda v: "true" if v else "false"
    return """
template<> const FormatMetadata& chemfiles::format_metadata<Molfile<{ident}>>() {{
    static FormatMetadata metadata;
    metadata.name = "{name}";
    metadata.extension = {ext};
    metadata.description = "{name} (VMD molfile {plugin}, reader {reader})";
    metadata.reference = "{ref}";

    metadata.read = true;
    metadata.write = false;
    metadata.memory = false;

    metadata.positions = {pos};
    metadata.velocities = false;
    metadata.unit_cell = false;
    metadata.atoms = {atoms};
    metadata.bonds = {bonds};
    metadata.residues = false;
    return metadata;
}}
""".format(ident=r["ident"], name=r["name"], ext=ext, plugin=r["plugin"],
           reader=r["reader"], ref=REFERENCE, pos=b(r["coords"]),
           atoms=b(r["structure"]), bonds=b(r["bonds"]))


def main():
    if len(sys.argv) != 2:
        fail("usage: chemfiles-molfiles.py CHEMFILES_TREE")
    chem = Path(sys.argv[1])
    cmake = chem / "external/CMakeLists.txt"
    text = cmake.read_text(encoding="utf-8")
    try:
        block = text.split("# Plugins not yet enabled but that should compile without issue:")[1]
        block = block.split("# Plugins with a chemfiles specific implementation")[0]
    except IndexError:
        fail("{} has no list of plugins that should compile".format(cmake))
    listed = set(re.findall(r"\b(\w+plugin)\b", block))
    known = set(READERS) | set(EXCLUDED)
    if listed != known:
        fail("chemfiles lists {} but this script knows {}; run tools/probe-molfiles.sh "
             "and update READERS or EXCLUDED".format(
                 sorted(listed - known), sorted(known - listed)))

    with tarfile.open(chem / "external/molfiles.tar.gz") as tar:
        sources = [m.name for m in tar.getmembers() if m.isfile()]
    for plugin in READERS:
        hits = [s for s in sources if re.fullmatch(r"molfiles/src/" + plugin + r"[^/]*\.c[^/]*", s)]
        if len(hits) != 1:
            fail("molfiles.tar.gz has {} sources for {}".format(len(hits), plugin))

    old = "set(VMD_MOLFILE_PLUGINS\n    gromacsplugin moldenplugin psfplugin\n)"
    plugins = ["gromacsplugin", "moldenplugin", "psfplugin"] + sorted(READERS)
    new = "set(VMD_MOLFILE_PLUGINS\n" + "".join("    " + p + "\n" for p in plugins) + ")"
    cmake.write_text(replace_once(text, old, new, cmake), encoding="utf-8")

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

    readers = plan(chem)

    hpp = chem / "include/chemfiles/formats/Molfile.hpp"
    text = hpp.read_text(encoding="utf-8")
    text = replace_once(
        text, "    MOLDEN,             ///< Molden file format\n",
        "    MOLDEN,             ///< Molden file format\n"
        + "".join("    {},\n".format(r["ident"]) for r in readers), hpp)
    text = replace_once(
        text, "template<> const FormatMetadata& format_metadata<Molfile<MOLDEN>>();\n",
        "template<> const FormatMetadata& format_metadata<Molfile<MOLDEN>>();\n"
        + "".join("template<> const FormatMetadata& format_metadata<Molfile<{}>>();\n"
                  .format(r["ident"]) for r in readers), hpp)
    hpp.write_text(text, encoding="utf-8")

    cpp = chem / "src/formats/Molfile.cpp"
    text = cpp.read_text(encoding="utf-8")
    text = replace_once(
        text, "    PLUGINS_DATA(MOLDEN,  moldenplugin,  molden, false);\n",
        "    PLUGINS_DATA(MOLDEN,  moldenplugin,  molden, false);\n"
        + "".join("    PLUGINS_DATA({}, {}, {}, false);\n".format(
            r["ident"], r["plugin"], r["reader"]) for r in readers), cpp)
    text = replace_once(
        text, "template class chemfiles::Molfile<MOLDEN>;\n",
        "template class chemfiles::Molfile<MOLDEN>;\n"
        + "".join("template class chemfiles::Molfile<{}>;\n".format(r["ident"])
                  for r in readers), cpp)
    # Several plugins (rst7, crd) write through the timestep pointer
    # without the NULL check the molfile API asks for, so counting steps
    # with a null timestep crashes; count into scratch buffers instead.
    text = replace_once(
        text,
        "    size_t n = 0;\n"
        "    int status = MOLFILE_SUCCESS;\n"
        "    while (true) {\n"
        "        status = read_next_timestep(nullptr);\n",
        "    size_t n = 0;\n"
        "    int status = MOLFILE_SUCCESS;\n"
        "    std::vector<float> scratch_coords(3 * static_cast<size_t>(natoms_));\n"
        "    std::vector<float> scratch_velocities(3 * static_cast<size_t>(natoms_));\n"
        "    while (true) {\n"
        "        molfile_timestep_t scratch{nullptr, nullptr, 0, 0, 0, 90, 90, 90, 0};\n"
        "        scratch.coords = scratch_coords.data();\n"
        "        scratch.velocities = scratch_velocities.data();\n"
        "        status = read_next_timestep(&scratch);\n",
        cpp)
    # Plugins read the first lines without checking for end of file and
    # then loop or size arrays from garbage; refuse empty files first.
    text = replace_once(
        text,
        "    if (plugin_data_.init()) {\n",
        "    {\n"
        "        std::FILE* probe = std::fopen(path_.c_str(), \"rb\");\n"
        "        if (probe == nullptr) {\n"
        "            throw format_error(\"could not open the file at '{}'\", path_);\n"
        "        }\n"
        "        int first = std::fgetc(probe);\n"
        "        std::fclose(probe);\n"
        "        if (first == EOF) {\n"
        "            throw format_error(\"the file at '{}' is empty\", path_);\n"
        "        }\n"
        "    }\n"
        "\n"
        "    if (plugin_data_.init()) {\n",
        cpp)
    text = replace_once(
        text,
        "    read_topology();\n}\n\ntemplate <MolfileFormat F> Molfile<F>::~Molfile() {\n",
        "    if (natoms_ <= 0) {\n"
        "        plugin_handle_->close_file_read(data_);\n"
        "        data_ = nullptr;\n"
        "        plugin_data_.fini();\n"
        "        throw format_error(\n"
        "            \"the {} plugin found no atoms in '{}'\", plugin_data_.format(), path_\n"
        "        );\n"
        "    }\n"
        "\n"
        "    read_topology();\n}\n\ntemplate <MolfileFormat F> Molfile<F>::~Molfile() {\n",
        cpp)
    text = replace_once(text, "#include <cassert>\n", "#include <cassert>\n#include <cstdio>\n", cpp)
    text += "".join(metadata_cpp(r) for r in readers)
    cpp.write_text(text, encoding="utf-8")

    factory = chem / "src/FormatFactory.cpp"
    text = factory.read_text(encoding="utf-8")
    text = replace_once(
        text, "    extern template class Molfile<MOLDEN>;\n",
        "    extern template class Molfile<MOLDEN>;\n"
        + "".join("    extern template class Molfile<{}>;\n".format(r["ident"])
                  for r in readers), factory)
    text = replace_once(
        text, "    this->add_format<XYZFormat>();\n",
        "    this->add_format<XYZFormat>();\n"
        + "".join("    this->add_format<Molfile<{}>>();\n".format(r["ident"])
                  for r in readers), factory)
    factory.write_text(text, encoding="utf-8")

    for r in readers:
        print("chemfiles-molfiles.py: {}\t{}\t{}\t{}".format(
            r["plugin"], r["reader"], r["name"], r["ext"] or "(by name only)"))


if __name__ == "__main__":
    main()
