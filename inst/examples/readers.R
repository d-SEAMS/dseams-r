# Copyright (c) d-SEAMS developers
# Frames shipped in the package. CON goes through readcon-core. PDB and
# GRO go through chemfiles. XYZ is read by chemfiles, then the native
# reader if chemfiles refuses the file. Nothing here consults DSEAMS_ROOT.
library(dseams)

con <- dseams_example("tiny_multi_cuh2.con")
stopifnot(
  nframes(con) == 2L,
  nrow(positions(read_frame(con, type = -1L))) == 4L,
  nrow(positions(read_frame(con, frame = 2L, type = -1L))) == 4L
)

pdb <- dseams_example("tiny.pdb")
stopifnot(
  nframes(pdb) == 1L,
  nrow(positions(read_frame(pdb, type = -1L))) == 3L
)

gro <- dseams_example("tiny.gro")
stopifnot(
  nframes(gro) == 1L,
  nrow(positions(read_frame(gro, type = -1L))) == 3L
)

xyz <- dseams_example("tiny.xyz")
stopifnot(
  nframes(xyz) == 1L,
  nrow(positions(read_frame(xyz, type = -1L))) == 2L
)

cat("r readers ok\n")
