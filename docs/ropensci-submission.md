# rOpenSci software-review submission (draft)

Draft for Rohit Goswami to review. This file is the issue body, shaped
by the current "Submit software for review" issue form at
<https://github.com/ropensci/software-review/blob/main/.github/ISSUE_TEMPLATE/A-submit-software-for-review.md>
(the 16 HTML-comment markers below, such as `author1` and `repourl`,
match that form field for field; an older single-file
`.github/ISSUE_TEMPLATE.md` link some drafts of this kind cite no longer
resolves). It has not been opened on
<https://github.com/ropensci/software-review>. Confirm the author
attestations and the coauthor GitHub handles before pasting it into a new
issue.

The package is the root of <https://github.com/d-SEAMS/dseams-r>. The srr
assessment is `srr-standards.md`.

After acceptance, rOpenSci can co-submit a short paper to the Journal of
Open Source Software. No such paper is in the repository yet; write one
before asking for the co-submission in the review thread. It is separate
from the CRAN upload and from this issue.

---

<!---
Below, please enter values for (1) submitting author GitHub handle (replacing "@github_handle@); and (2) Repository URL (replacing "https://repourl"). Values for additional package authors may also be specified, replacing "@github_handle1", "@github_handle2" - delete these if not needed. DO NOT DELETE HTML SYMBOLS (everything between "<!" and ">"). Replace only "@github_handle" and "https://repourl". This comment may be deleted once it has been read and understood.
--->

Submitting Author Name: Rohit Goswami
Submitting Author Github Handle: <!--author1-->@HaoZeke<!--end-author1-->
Other Package Authors Github handles: (comma separated, delete if none) <!--author-others-->@amritagos, @RuhiRG<!--end-author-others-->
Repository:  <!--repourl-->https://github.com/d-SEAMS/dseams-r<!--end-repourl-->
Version submitted: 2.14.2
Submission type: <!--submission-type-->Standard<!--end-submission-type-->
Editor: <!--editor--> TBD <!--end-editor-->
Reviewers: <!--reviewers-list--> TBD <!--end-reviewers-list-->
<!--due-dates-list--><!--end-due-dates-list-->
Archive: TBD
Version accepted: TBD
Language: <!--language-->en<!--end-language-->

---

-   Paste the full DESCRIPTION file inside a code block below:

```
Package: dseams
Type: Package
Title: Ice Classification and Ring Statistics for Molecular Simulations
Version: 2.14.2
Date: 2026-11-24
Authors@R: c(
    person("Rohit", "Goswami", email = "rgoswami@ieee.org",
           role = c("aut", "cre"),
           comment = c(ORCID = "0000-0002-2393-8056")),
    person("Amrita", "Goswami", role = "aut",
           comment = c(ORCID = "0000-0001-8706-2383")),
    person("Ruhila", "Goswami", role = "ctb",
           comment = c(ORCID = "0000-0002-5443-9356")),
    person("d-SEAMS core team", role = "cph",
           comment = "seams-core engine sources bundled in src/seams")
    )
Description: Structural analysis of water and ice in molecular dynamics
    trajectories, using the 'd-SEAMS' engine (Goswami, Goswami and Singh
    (2020) <doi:10.1021/acs.jcim.0c00031>). Reads 'LAMMPS' dumps, 'XYZ'
    files, 'CON' files, and the trajectory formats from 'chemfiles',
    and returns data frames of 'CHILL+' ice labels
    (Nguyen and Molinero (2015) <doi:10.1021/jp510289t>), primitive
    ring counts (Franzblau (1991) <doi:10.1103/PhysRevB.44.4925>),
    hexagonal and double-diamond cages, and Steinhardt bond-orientational
    order parameters (Steinhardt, Nelson and Ronchetti (1983)
    <doi:10.1103/PhysRevB.28.784>). The engine is compiled from bundled
    C++ sources.
License: MIT + file LICENSE
Copyright: See file inst/AUTHORS for the bundled readcon-core, Rust
    crates, the Rust standard library and compiler-rt rustc links into
    that library, and chemfiles; LICENSE.note gives their licences.
URL: https://r.dseams.info/, https://docs.dseams.info,
    https://github.com/d-SEAMS/dseams-r,
    https://github.com/d-SEAMS/seams-core
BugReports: https://github.com/d-SEAMS/dseams-r/issues
Encoding: UTF-8
Depends:
    R (>= 4.2.0)
Suggests:
    covr,
    knitr,
    rmarkdown,
    testthat (>= 3.0.0)
LinkingTo:
    cpp11 (>= 0.4.0),
    RcppEigen (>= 0.3.4.0.0)
VignetteBuilder: knitr
SystemRequirements: C++20, GNU make, Cargo (Rust's package manager),
    rustc (>= 1.88; on Windows with the x86_64-pc-windows-gnu target),
    cmake (>= 3.15), objcopy (GNU binutils or LLVM)
NeedsCompilation: yes
Config/testthat/edition: 3
X-schema.org-keywords: molecular-dynamics, trajectory-analysis, ice,
    clathrate-hydrates, ring-statistics, d-seams
Roxygen: list(markdown = TRUE)
Config/roxygen2/version: 8.1.1
```

The R package is the root of that repository. Amrita Goswami is an
author (`aut`) and Ruhila Goswami a contributor (`ctb`) in the DESCRIPTION.

## Scope

- Please indicate which category or categories from our [package fit policies](https://devguide.ropensci.org/softwarereview_policies.html#package-categories) this package falls under: (Please check an appropriate box below. If you are unsure, we suggest you make a pre-submission inquiry.):

	- [ ] data retrieval
	- [ ] data extraction
	- [x] data munging
	- [ ] data deposition
    - [ ] data validation and testing
	- [ ] workflow automation
	- [ ] version control
	- [ ] citation management and bibliometrics
	- [ ] scientific software wrappers
	- [ ] field and lab reproducibility tools
	- [ ] database software bindings
	- [ ] geospatial data
	- [ ] translation
    - [ ] rOpenSci internal tools

- Explain how and why the package falls under these categories (briefly, 1-2 sentences):

  `dseams` is not a wrapper in the rOpenSci sense: the [package fit
  policies](https://devguide.ropensci.org/softwarereview_policies.html#package-categories)
  define "scientific software wrappers" as packages that wrap "non-R
  utility programs", and say this "does not include wrappers of other R
  packages or C/C++ libraries that can be included in R packages"; the
  d-SEAMS engine is C++ compiled into `dseams` itself (`LinkingTo: cpp11,
  RcppEigen`), not an external program invoked at run time. `data munging`
  fits what the package actually does: [the
  guide](https://devguide.ropensci.org/softwarereview_policies.html#package-categories)
  describes that category as tools "for handling data in specific
  scientific formats generated from scientific workflows". `read_frame()`
  (`R/dseams.R:50-62`) parses LAMMPS dump and XYZ trajectories (the output
  format of a molecular-dynamics workflow) into an R-native
  `dseams_frame`. That said, it is not a clean "reformat the file into a
  data frame" fit: `chill_plus()` (`R/dseams.R:144-156`) assigns each atom
  one of nine CHILL+ labels from a computed q3 order parameter and the
  published Nguyen-and-Molinero decision rule; `cages()`
  (`R/dseams.R:176-187`) and `primitive_rings()` (`R/dseams.R:209-222`)
  build a neighbour graph from the coordinates and classify or count ring
  and cage membership in it, values that are not present in the input
  file at all; and `symmetry()` (`R/dseams.R:286-294`) assigns a
  shell-symmetry code from an RMSD to a reference ice template.
  `steinhardt()` (`R/dseams.R:321-336`) and `q4_q6()` (`R/dseams.R:354-364`)
  are the closest to a plain reformat, computing bond-orientational order
  parameters per atom and returning them as data frames. See the
  presubmission-inquiry note below.

-   Who is the target audience and what are scientific applications of this package?

  People who analyse molecular-dynamics trajectories of water, ice, and
  clathrate hydrates in R. The functions identify hexagonal ice, cubic ice,
  clathrate cages, and the hydrogen-bond ring network in a frame.

-   Are there other R packages that accomplish the same thing? If so, how does yours differ or meet [our criteria for best-in-category](https://ropensci.github.io/dev_guide/policies.html#overlap)?

  Checked the live CRAN package index
  (<https://CRAN.R-project.org/web/packages/available_packages_by_name.html>;
  the command, the date, and every title hit are in
  `docs/cran-search.log`) for "chill", "clathrate", "hydrate",
  "molecular dynamics" and "franzblau": no CRAN package performs CHILL+
  ice classification, Franzblau primitive rings, or a clathrate/cage
  census. The only genuine "chill" hits are agricultural chill-hour
  models (`ChillModels`, `chillR`), an unrelated domain (a plain
  substring search on "chill" also matches `Achilles`, a clinical
  data-source package, which is neither agricultural nor related to
  ice). "molecular dynamics" matches two packages, not one: `SOMMD`
  does self-organising-map analysis of simulation output, not
  structure classification, and `xvm` reads and plots 'GROMACS' own
  scalar time series ('XVG'/'XPM' files: RMSD, energy, temperature),
  not 'LAMMPS' dumps or 'XYZ' trajectories, and computes none of
  CHILL+ labels, primitive rings, or cage or shell-symmetry classification.
  Neither package does what `dseams` does. Outside CRAN,
  [OVITO](https://www.ovito.org/) is, by its own description, "scientific
  data visualization and analysis software for particle-based simulation
  models" and can identify some of the same structures, but is not an R
  package and is not itself the d-SEAMS engine. `dseams` is the R
  binding of the d-SEAMS C++ engine; on `ice1h.lammpstrj` (every atom),
  the published CHILL+ reference count of 128 hexagonal waters that
  `R/dseams.R:120-121` documents and
  `tests/testthat/test-ice.R:10-11` asserts is the same count the engine's own
  Python and Julia binding docs record for the identical input
  ([`docs/api/python.md`](https://github.com/d-SEAMS/seams-core/blob/main/docs/api/python.md):
  "the same call returns 128 at index 1"; 
  [`docs/api/julia.md`](https://github.com/d-SEAMS/seams-core/blob/main/docs/api/julia.md):
  "published CHILL+ at 3.5 angstrom is 128 hexagonal"), in both
  `d-SEAMS/seams-core`.   The 256 primitive-ring count on the same file is
  this package's own tested value (`R/dseams.R:121`,
  `tests/testthat/test-ice.R:14`); this review did not find the same
  figure documented for the Python or Julia bindings specifically, so it
  is not claimed as cross-binding-verified.

-   (If applicable) Does your package comply with our [guidance around _Ethics, Data Privacy and Human Subjects Research_](https://devguide.ropensci.org/policies.html#ethics-data-privacy-and-human-subjects-research)?

  Not applicable. The package reads molecular-simulation trajectories. It
  does not collect or process data about people.

-   If you made a pre-submission inquiry, please paste the link to the corresponding issue, forum post, or other discussion, or `@tag` the editor you contacted.

  No pre-submission inquiry yet; see the recommendation and draft text
  below.

-   Explain reasons for any [`pkgcheck` items](https://docs.ropensci.org/pkgcheck/) which your package is unable to pass.

  This revision does not quote a pkgcheck run. The check section below
  records `R CMD check --as-cran` and the testthat summaries from this
  tree. Standards from the
  statistical-software track are assessed in
  `srr-standards.md`. `dseams` is not statistical
  software, so the category standards (Bayesian, regression, machine
  learning, distributions, exploratory data analysis, spatial, time
  series, unsupervised learning) do not apply, and the package does not
  carry `@srrstats` tags.

  Two exported names that other packages also use are kept:

  - Function names duplicated in other packages: `positions()` is also
    exported by `mixvlmc`, `splus2R` and `splusTimeSeries`, and
    `symmetry()` by `DecomposeR` and `xnet`. Both names are kept because
    they are the plain English names for what they return here (the atom
    coordinate matrix of a frame, and its shell-symmetry code),
    `dseams` does not depend on or re-export those packages, and
    neither name collides inside this package's own namespace.

### Presubmission inquiry

None of the listed categories is an exact match: `data munging` is the
closest honest fit (see above), but `chill_plus()`, `cages()`,
`primitive_rings()` and `symmetry()` classify structures (CHILL+ ice
labels, ring and cage membership, shell symmetry) computed from a
neighbour graph, rather than only reshaping values already present in
the input file (see the function-by-function detail above). Given that,
a pre-submission inquiry to confirm scope before opening the full review
issue is the right next step, rather than asserting a category that may
not survive editor triage. The following is a draft of that inquiry, for
Rohit to review, edit and post himself; it has not been sent.

> **Draft presubmission inquiry (not yet posted)**
>
> Title: Presubmission inquiry: dseams, an R interface to the d-SEAMS
> ice/water structural-analysis engine
>
> `dseams` (<https://github.com/d-SEAMS/dseams-r>) reads LAMMPS dump and
> XYZ molecular-dynamics trajectories and returns R data frames of CHILL+
> ice labels, Franzblau primitive ring counts, hexagonal/double-diamond
> cage membership, and Steinhardt bond-orientational order parameters,
> computed by the bundled d-SEAMS C++ engine (compiled into the package,
> not called as an external program). I am unsure which package-fit
> category this falls under. `scientific software wrappers` is excluded
> by its own definition, since the engine is a C++ library linked into
> the package rather than a wrapped external utility. `data munging`
> looks closest, since the package parses a scientific file format
> produced by a simulation workflow into structured, documented data
> frames, but several of its functions classify structures rather than
> only reshape them. Does `dseams` fit the Software Peer Review scope,
> and if so under which category?

## Technical checks

Confirm each of the following by checking the box.

- [x] I have read the [rOpenSci packaging guide](https://devguide.ropensci.org/building.html).
- [x] I have read the [author guide](https://devguide.ropensci.org/softwarereview_author.html) and I expect to maintain this package for at least 2 years or to find a replacement.

This package:

- [x] does not violate the Terms of Service of any service it interacts with.
- [x] has a CRAN and OSI accepted license.
- [x] contains a [README with instructions for installing the development version](https://ropensci.github.io/dev_guide/building.html#readme).
- [x] includes [documentation with examples for all functions, created with roxygen2](https://ropensci.github.io/dev_guide/building.html#documentation).
- [x] contains a vignette with examples of its essential functions and uses.
- [x] has a [test suite](https://ropensci.github.io/dev_guide/building.html#testing).
- [x] has [continuous integration](https://ropensci.github.io/dev_guide/ci.html), including reporting of test coverage.

## Use of Generative AI

- [x] Generative AI tools were used to produce some of the material in this submission.

Generative AI tools were used while drafting and revising parts of this repository, including portions of the documentation and this submission issue. I have reviewed all AI-assisted contributions, including the parts of this file, and take full responsibility for the correctness of the code and the accuracy of the statements made here.

## Publication options

- [x] Do you intend for this package to go on CRAN?
- [ ] Do you intend for this package to go on Bioconductor?

- [ ] Do you wish to submit an Applications Article about your package to [Methods in Ecology and Evolution](http://besjournals.onlinelibrary.wiley.com/hub/journal/10.1111/(ISSN)2041-210X/)? If so:

<details>
<summary>MEE Options</summary>

- [ ] The package is novel and will be of interest to the broad readership of the journal.
- [ ] The manuscript describing the package is no longer than 3000 words.
- [ ] You intend to archive the code for the package in a long-term repository which meets the requirements of the journal (see [MEE's Policy on Publishing Code](https://besjournals.onlinelibrary.wiley.com/hub/journal/2041210x/policyonpublishingcode.html))
- (*Scope: Do consider MEE's [Aims and Scope](http://besjournals.onlinelibrary.wiley.com/hub/journal/10.1111/(ISSN)2041-210X/aims-and-scope/read-full-aims-and-scope.html) for your manuscript. We make no guarantee that your manuscript will be within MEE scope.*)
- (*Although not required, we strongly recommend having a full manuscript prepared when you submit here.*)
- (*Please do not submit your package separately to Methods in Ecology and Evolution*)

</details>

After software review, rOpenSci can co-submit an accepted package to the
Journal of Open Source Software. That needs a paper, which the repository
does not have yet. It is not requested by the checkboxes above.

## Code of conduct

- [x] I agree to abide by [rOpenSci's Code of Conduct](https://ropensci.org/code-of-conduct/) during the review process and in maintaining my package should it be accepted.

## pkgcheck

Continuous integration is the four workflows in `.github/workflows/`.
The run history is the Actions page:
<https://github.com/d-SEAMS/dseams-r/actions>.

- `r-cmd-check.yml` (`name: R-CMD-check`) runs on pushes and pull
  requests to `main`, `develop`, and `release/**`, and on
  `workflow_dispatch`. The bundled job copies the engine at the pin in
  `tools/seams-core.ref` and runs `R CMD check --no-manual --as-cran`
  on Linux (R release and devel), macOS, and Windows. Linux installs
  binutils. The macOS job installs Homebrew llvm and puts its `bin`
  directory on `PATH`, because rewriting the bundled readers needs
  llvm-objcopy. Linux and macOS then run `tools/check-reader-symbols.sh`
  and fail if objcopy, nm, ar, or the C compiler is missing. On the
  Linux release cell that job also checks that `cpp11::cpp_register()`
  leaves `R/cpp11.R` and `src/cpp11.cpp` unchanged. The linked job
  builds seams-core at that pin, runs `tools/check-reader-symbols.sh`,
  and runs `R CMD check --no-manual` with the package linked against
  that build. Both jobs set
  `_R_CHECK_FORCE_SUGGESTS_=true`.
- `test-coverage.yml` (`name: test-coverage`) runs on pushes and pull
  requests to `main` and `release/**`, and on `workflow_dispatch`.
  It links the package to a seams-core build at the pin and runs covr
  on the R code (`.github/coverage.R`). `.covrignore` lists `src` and
  `.pixi`, so the engine copy and the C and C++ glue under `src/` are
  outside that figure. The workflow writes the per-file table to the
  job summary and uploads the coverage object as an artifact. It does
  not upload the figure to a coverage service.
- `pkgdown.yml` (`name: pkgdown`) runs on pushes and pull requests to
  `main`, and on `workflow_dispatch`. It builds the pkgdown site,
  checks the site and README links, and on a push to `main` publishes
  the site to GitHub Pages (<https://r.dseams.info/>). A later job
  checks the links on the published pages.
- `release.yml` (`name: Release`) runs on a `v*` tag. It checks that
  the tag names the `Version` field in DESCRIPTION and that
  `tools/seams-core.ref` pins `d-SEAMS/seams-core` at that tag, runs
  `R CMD check --as-cran --no-manual`, and publishes the source
  tarball for `d-SEAMS/dseams-r`.

`molfiles/src/ply.c` and `molfiles/src/ply.h` (Georgia Institute of
Technology, 1998) permit use, copying, modification, and distribution
on condition that the software is not sold. They are shipped and are
not compiled. `molfiles/src/plyplugin.cxx` includes `ply.c`, so that
condition would apply if plyplugin were compiled. plyplugin is not in
the compiled list. `LICENSE.note` states this.

`pkgcheck` was not run for this revision. The check that was run is
`pixi run check`, which runs `R CMD check --as-cran --no-manual` on the
bundled tarball `dseams_2.14.1.tar.gz`, on R 4.5.3 (2026-03-11),
platform `x86_64-conda-linux-gnu`, on Ubuntu 24.04.5 LTS. R was compiled
by `x86_64-conda-linux-gnu-cc (conda-forge gcc 14.4.0-7) 14.4.0` and
`GNU Fortran (conda-forge gcc 14.4.0-7) 14.4.0`.
`_R_CHECK_COMPILATION_FLAGS_KNOWN_=-march=nocona` was set, because this
R adds `-march=nocona`. `DSEAMS_ROOT`, `SEAMS_BIN`, and
`SEAMS_CPP_ORACLE` were unset. The check used `--no-manual`, so it does
not check the PDF or HTML manual. It finished:

```
Status: 1 NOTE
```

0 errors | 0 warnings | 1 note

The note is:

```
* checking CRAN incoming feasibility ... [3s/12s] NOTE
Maintainer: 'Rohit Goswami <rgoswami@ieee.org>'

New submission

Size of tarball: 7951863 bytes
```

Installed package size is reported as INFO, not as a note:

```
* checking installed package size ... INFO
  installed size is 15.0Mb
  sub-directories of 1Mb or more:
    libs  14.4Mb
```

`checking compilation flags used ... OK`. The install prints
`rustc 1.100.0 (0ef1bc386 2026-11-09)`,
`cargo 1.100.0 (3acc79c0c 2026-11-05)`, and
`Running CMake version 3.28.3`. The C++ compile line defines
`-DSEAMS_HAS_READCON=1`.

The testthat run inside that check prints:

```
[ FAIL 0 | WARN 0 | SKIP 8 | PASS 205 ]
```

Six skips are `DSEAMS_ROOT is not set` (`test-doc-examples.R` lines
21, 27, 32, 37, and 54, and `test-ice.R` line 96). One skip is
`DSEAMS_ROOT is not set; SEAMS_CPP_ORACLE is not set`
(`test-doc-examples.R` line 99). One skip is `SEAMS_BIN is not set`
(`test-ice.R` line 77). The archive rewrite is not one of these
tests. `tools/check-reader-symbols.sh` runs it and exits if objcopy,
nm, ar, or the C compiler is missing.

The examples print `nframes()` of `tiny_multi_cuh2.con` as 2 and
`read_frame()` as `dseams frame 1 atoms 4`. `con` there is
`dseams_example("tiny_multi_cuh2.con")`.

`R CMD check` runs `test_check("dseams")` from `tests/testthat.R`
inside the unpacked source, where `00_pkg_src` still has
`tools/check-submission.R` and `tools/reader-symbols.sh`, so that run
does not skip the submission test or the symbol-map tests. `docs/` and
`codemeta.json` are listed in `.Rbuildignore` and are not in
`00_pkg_src`.

A check linked against a built seams-core, a check in a network
namespace with no network, and `pkgcheck` were not run.

Names shared with other packages stay. `positions()` is the frame
coordinate matrix and `symmetry()` is the shell-symmetry code. `dseams` does not depend on the other packages that export
those names, and neither name collides inside this package.

`tests/testthat/test-ice.R` compares a mean Steinhardt q3 to 0.374897
with `expect_equal(..., tolerance = 1e-4)`. `tests/testthat/test-s3.R`
compares two means with `expect_equal(..., tolerance = 0)`.

`srr-standards.md` is the srr assessment. The package is not
statistical software, so it does not carry `@srrstats` tags.
