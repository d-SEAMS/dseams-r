# R

`dseams` is the R package for one trajectory frame. It reads a LAMMPS
dump or an XYZ file and returns data frames. The function reference,
with a runnable example on every page, is
<https://r.dseams.info/reference/>.

```r
install.packages("remotes")
remotes::install_github("d-SEAMS/dseams-r")
```

A C++20 compiler is required. The package compiles the engine as it
installs.

## Read a frame

```r
library(dseams)
path <- dseams_example("ice1h.lammpstrj")
nframes(path)
frame <- read_frame(path, type = -1L)
head(positions(frame))
```

`read_frame()` returns a `dseams_frame`. `positions()` is a numeric
matrix with columns `x`, `y`, and `z` in the units of the file.
`nframes()` is the number of LAMMPS timesteps. An XYZ file counts as
one frame.

`type = 0` guesses oxygen (LAMMPS type 2, otherwise type 1). A positive
type keeps that species. A negative type keeps every atom.
`ice1h.lammpstrj` is oxygen only, so `type = -1` and the guessed oxygen
type both keep all 128 sites. In `exampleTraj.lammpstrj`, type 2 is
oxygen and type 1 is hydrogen.

`print()` on a frame reports the frame index and the atom count.
`summary()` adds the file and the type filter.

## CHILL+

```r
ice <- chill_plus(frame)
table(ice$name)
```

The result is a data frame with columns `atom`, `type`, `label`, and
`name`. `print()` counts the names. It does not print the rows. On this
cell the count is 128 `hexagonal`.

| `name` | Meaning |
| --- | --- |
| `cubic` | Cubic ice, Ic |
| `hexagonal` | Hexagonal ice, Ih |
| `interfacial` | Ice-like, and not cubic or hexagonal |
| `clathrate` | Clathrate |
| `interClathrate` | Interfacial clathrate |
| `water` | Liquid or amorphous |
| `unclassified` | None of the above |
| `reCubic` | Reclassified as cubic ice by q6 |
| `reHex` | Reclassified as hexagonal ice by q6 |

`graph = "cutoff"` (the default) bonds every pair closer than `cutoff`
angstrom. `graph = "mutual"` keeps the mutual four nearest neighbours
inside `cutoff + 1.5`. `rule = "chill+"` is the published rule.
`rule = "ovito-chill+"` averages q3 over the whole shell and skips the
interfacial-neighbour test.

On `exampleTraj.lammpstrj`, oxygen type 2, the cutoff list gives 9
`interClathrate` and 241 `water`. The mutual list gives 1 `clathrate`,
7 `interClathrate`, and 242 `water`.

Nguyen, A. H. and Molinero, V. (2015). Identification of clathrate
hydrates, hexagonal ice, cubic ice, and liquid water in simulations:
the CHILL+ algorithm. The Journal of Physical Chemistry B 119,
9369-9376. <https://doi.org/10.1021/jp510289t>

## Rings

```r
primitive_rings(frame, graph = "cutoff", max_depth = 6L)
```

The result has columns `size` and `n`. Ice Ih on the cutoff graph has
256 rings of size 6. The default graph is `"mutual"`, not `"cutoff"`.
On the mixed frame the mutual list, kept out to depth 6, has 224
six-rings.

Franzblau, D. S. (1991). Computation of ring statistics for network
models of solids. Physical Review B 44, 4925.
<https://doi.org/10.1103/PhysRevB.44.4925>

## Cages and shell symmetry

```r
cages(frame)
table(symmetry(frame))
signature_cages(frame, "512")
```

`cages()` returns one row per atom (`atom`, `cage`, `name`). The
attributes `n_ih`, `n_ic`, `n_both`, and `n_water` are disjoint and sum
to the number of atoms. On ice Ih they are 128 hexagonal, 0 cubic, 0
both, and 0 water. `cage` is 0 water, 1 hexagonal, 2 cubic, 3 both.
`graph = "seeded"` is the default. `"mutual"`, `"cutoff"`, and
`"knn-union"` are the other graphs.

`symmetry()` is an integer code per atom: 0 ice Ih, 1 ice Ic, 2
stacking-disordered, -1 otherwise.

`signature_cages()` counts closed cages of one ring census. `"512"` is
twelve pentagons. The return value is `c(n_cages, n_atoms)`.

## Steinhardt parameters

```r
tip <- read_frame(dseams_example("exampleTraj.lammpstrj"), type = 2L)
summary(steinhardt(tip, order_l = 3L)$ql)
head(q4_q6(frame))
```

`steinhardt()` returns `atom`, `ql`, and `qlbar` for one degree.
Degrees 3, 4, 6, 8, and 12 are computed. `qlbar` is the Lechner-Dellago
neighbour average. `q4_q6()` returns `q4`, `q6`, `q4bar`, and `q6bar`
on the cutoff shell. On the mixed frame the mean local q3 is 0.3749.

Steinhardt, P. J., Nelson, D. R. and Ronchetti, M. (1983).
Bond-orientational order in liquids and glasses. Physical Review B 28,
784. <https://doi.org/10.1103/PhysRevB.28.784>

## Two frames

```r
both <- read_frame(dseams_example("exampleTraj.lammpstrj"), type = -1L)
jump_tau90(both, both, dt = 1, oxygen_type = 2L, hydrogen_type = 1L)
```

`jump_tau90()` returns `dt` when any water's H-H vector rotates by at
least 90 degrees, and `NaN` otherwise. Both frames need oxygen and
hydrogen. Comparing a frame with itself returns `NaN`.

## A system handle

`seams_system_new()` returns an empty handle. `seams_system_read()`
loads one frame into it and returns the atom count. Each later
`seams_*` function analyses that frame. R frees the handle when the
object is collected. A failed read stops with the engine's message and
leaves the previous frame in place.

```r
sys <- seams_system_new()
seams_system_read(sys, dseams_example("ice1h.lammpstrj"))
seams_chill(sys)
seams_cages(sys)
```

`seams_chill()` returns the nine population counts in the label order
above. `graph = 0` is the cutoff list and `graph = 1` is the mutual
list. `rule = 0` is the published CHILL+ rule and `rule = 1` is the
OVITO variant. `seams_cages()` returns `n_hex`, `n_cubic`, `n_water`,
and `n_both`. The other `seams_*` functions are the same analyses one
handle at a time: neighbour lists, radial distribution, coordination,
hydrogen bonds, density, rings, prisms, monolayers, fingerprints, and
site tables. Each page in the reference shows the arguments and a
runnable example.

`dseams_threads()` reports the OpenMP thread count, and
`dseams_threads(n)` sets it for later calls from this R session.
`dseams_version()` is the engine version this package was built with.

## Errors

A missing path stops in `normalizePath` before the engine is called.
An empty handle stops with the engine's message. Either failure is an
ordinary R error, so `tryCatch()` sees it.
