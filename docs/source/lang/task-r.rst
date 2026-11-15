R
=

``read_frame``, ``chill_plus``, and ``primitive_rings`` are the R front.
The package returns positions rather than the neighbour list, so the
example counts directed cutoff pairs of those positions under the
minimum image of the dump's box. The ring table omits empty sizes; the
printed histogram still has one integer per size from 0 through 6.

.. literalinclude:: ../../../inst/examples/lang_tasks.R
   :language: r

``tests/testthat/test-doc-examples.R`` runs this file when
``DSEAMS_ROOT`` names a seams-core checkout, and checks four directed
pairs per water, 256 six-rings, and one CHILL+ label per atom.
