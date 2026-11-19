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

The package returns positions rather than the engine's neighbour list.
The complete example therefore counts directed cutoff pairs from those
positions using the minimum image of the orthorhombic box. It also expands
the sparse ring table to one histogram entry for every size from 0 through
6.

.. literalinclude:: ../../../inst/examples/lang_tasks.R
   :language: r

``tests/testthat/test-doc-examples.R`` runs this file and checks four
directed pairs per water, 256 six-rings, and one CHILL+ label per atom.
