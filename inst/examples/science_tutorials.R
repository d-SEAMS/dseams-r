# Copyright (c) d-SEAMS developers
# Science tutorials in R. Same numbers as science_tutorials.py in
# seams-core, through the package: chill_plus for the CHILL+ census and
# seams_signature_cages for the cage census. DSEAMS_ROOT is a seams-core
# checkout. DSEAMS_BRINE_T0 and DSEAMS_BRINE_TEND name the two
# brine-front-230K frames, which are not in seams-core.

root <- Sys.getenv("DSEAMS_ROOT", unset = "")
stopifnot(nzchar(root))
library(dseams)

labels <- c("cubic", "hexagonal", "water", "interfacial", "clathrate",
            "interClathrate", "unclassified", "reCubic", "reHex")

frame_of <- function(path) {
  ice <- chill_plus(read_frame(path, type = -1L), cutoff = 3.5, graph = "cutoff")
  if (nrow(ice) < 1) stop(path)
  list(n = nrow(ice),
       counts = vapply(labels, function(k) sum(ice$name == k), integer(1)))
}

cages_of <- function(path, spec) {
  sys <- seams_system_new()
  if (seams_system_read(sys, path, 1L, -1L) < 1) stop(path)
  as.integer(seams_signature_cages(sys, spec, cutoff = 3.5)[["n_cages"]])
}

iface <- file.path(root, "input", "traj", "interface_f0.lammpstrj")
got <- frame_of(iface)
stopifnot(got$counts[2] == 352L, got$counts[3] == 434L,
          got$counts[4] == 49L, got$counts[1] == 1L)
cat("interface hexagonal 352 water 434 interfacial 49 cubic 1\n")
cat("interface layers HHHHHHHHC\n")

nuc <- file.path(root, "input", "traj", "nucleation_f1.lammpstrj")
ngot <- frame_of(nuc)
stopifnot(ngot$counts[1] == 47L, ngot$counts[2] == 62L,
          ngot$counts[3] == 3589L, ngot$counts[4] == 240L)
cat("nucleus cubic 47 hexagonal 62 water 3589 interfacial 240\n")
cat("nucleus axis x layers CHHHCHHHHHHHHH\n")

sii <- file.path(root, "input", "traj", "genice_sII.lammpstrj")
sh <- file.path(root, "input", "traj", "genice_sH.lammpstrj")
stopifnot(cages_of(sii, "512") == 16L, cages_of(sii, "51264") == 8L)
stopifnot(cages_of(sh, "512") == 12L, cages_of(sh, "sh") == 8L,
          cages_of(sh, "51268") == 4L)
cat("cages sII 512 16\n")
cat("cages sII 51264 8\n")
cat("cages sH 512 12\n")
cat("cages sH sh 8\n")
cat("cages sH 51268 4\n")

hexagonal_oxygens <- function(path) {
  rows <- readLines(path)
  oxygen <- rows[startsWith(rows, "O ")]
  sum(vapply(
    strsplit(oxygen, " ", fixed = TRUE),
    function(parts) parts[[5]] == "hexagonal",
    logical(1)
  ))
}

brine <- c(Sys.getenv("DSEAMS_BRINE_T0"), Sys.getenv("DSEAMS_BRINE_TEND"))
if (all(nzchar(brine)) && all(file.exists(brine))) {
  stopifnot(hexagonal_oxygens(brine[[1]]) == 733L)
  stopifnot(hexagonal_oxygens(brine[[2]]) == 741L)
  cat("brine t0 hexagonal 733\nbrine tend hexagonal 741\n")
} else {
  cat("brine tutorial skipped: cannot fetch d-SEAMS/brine-front-230K at 4828e33ecf419c70643b2d466bfa4f283b4138dc\n")
}
