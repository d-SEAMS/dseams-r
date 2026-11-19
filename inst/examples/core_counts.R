# Copyright (c) d-SEAMS developers
# Ice Ih and sII census through the dseams package.
# Ice Ih: 128 hexagonal, 256 six-rings.
# sII: 136 clathrate, 144 five-rings, 16 six-rings.
# DSEAMS_ROOT is a seams-core checkout; the dumps are its input/traj.
library(dseams)
root <- Sys.getenv("DSEAMS_ROOT", unset = "")
stopifnot(nzchar(root))

census <- function(path) {
  frame <- read_frame(path)
  list(
    ice = chill_plus(frame, cutoff = 3.5, graph = "cutoff"),
    rings = primitive_rings(frame, cutoff = 3.5, graph = "cutoff")
  )
}

ice <- census(file.path(root, "input", "traj", "ice1h.lammpstrj"))
stopifnot(
  sum(ice$ice$name == "hexagonal") == 128L,
  ice$rings$n[ice$rings$size == 6L] == 256L
)
sii <- census(file.path(root, "input", "traj", "genice_sII.lammpstrj"))
stopifnot(
  sum(sii$ice$name == "clathrate") == 136L,
  sii$rings$n[sii$rings$size == 5L] == 144L,
  sii$rings$n[sii$rings$size == 6L] == 16L
)
cat("r hexagonal 128 rings6 256 clathrate 136 rings5 144\n")
