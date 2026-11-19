R
=

Read the ice Ih cell shipped with the package. Each oxygen has four
neighbours inside 3.5 angstrom, so the directed pair count is four per
water. CHILL+ labels all 128 waters hexagonal, and the cutoff graph
holds 256 primitive six-rings.

.. code-block:: r

   library(dseams)
   frame <- read_frame(dseams_example("ice1h.lammpstrj"), type = -1L)
   nrow(positions(frame))
   table(chill_plus(frame, graph = "cutoff")$name)
   primitive_rings(frame, graph = "cutoff", max_depth = 6L)

The positions are the coordinates in the file. The ring table has one
row for each size that occurs. ``name`` is the CHILL+ label.
