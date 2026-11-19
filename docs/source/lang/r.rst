R
=

``dseams`` reads one LAMMPS dump or XYZ frame and returns data frames
of CHILL+ labels, primitive rings, cages, and Steinhardt parameters.

.. code-block:: r

   library(dseams)
   frame <- read_frame(dseams_example("ice1h.lammpstrj"), type = -1L)
   table(chill_plus(frame)$name)
   primitive_rings(frame, graph = "cutoff", max_depth = 6L)
   cages(frame)

``ice1h.lammpstrj`` is a 2x2x2 ice Ih cell. All 128 oxygens are
hexagonal, the cutoff graph holds 256 primitive six-rings, and every
oxygen sits in a hexagonal cage.
``vignette("classifying-ice", package = "dseams")`` repeats this frame
and then a mixed TIP4P frame. The function reference is
https://r.dseams.info/reference/.
