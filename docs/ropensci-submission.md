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
Version submitted: 2.14.1
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
Version: 2.14.1
Date: 2026-11-17
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
    (2020) <doi:10.1021/acs.jcim.0c00031>). Reads 'LAMMPS' dumps and
    'XYZ' files and returns data frames of 'CHILL+' ice labels
    (Nguyen and Molinero (2015) <doi:10.1021/jp510289t>), primitive
    ring counts (Franzblau (1991) <doi:10.1103/PhysRevB.44.4925>),
    hexagonal and double-diamond cages, and Steinhardt bond-orientational
    order parameters (Steinhardt, Nelson and Ronchetti (1983)
    <doi:10.1103/PhysRevB.28.784>). The engine is compiled from bundled
    C++ sources.
License: MIT + file LICENSE
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
SystemRequirements: C++20
NeedsCompilation: yes
Config/testthat/edition: 3
X-schema.org-keywords: molecular-dynamics, trajectory-analysis, ice,
    clathrate-hydrates, ring-statistics, d-seams
Roxygen: list(markdown = TRUE)
Config/roxygen2/version: 8.1.1
```

The R package is the root of that repository. Amrita Goswami is an
author (`aut`) and Ruhila Goswami a contributor (`ctb`) in the DESCRIPTION.
Their GitHub handles are not recorded in the repository; add Amrita
Goswami's between the author markers above if she should be on the issue.

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
  point-group code from an RMSD to a reference ice template.
  `steinhardt()` (`R/dseams.R:321-335`) and `q4_q6()` (`R/dseams.R:354-363`)
  are the closest to a plain reformat, computing bond-orientational order
  parameters per atom and returning them as data frames. See the
  presubmission-inquiry note below.

-   Who is the target audience and what are scientific applications of this package?

  People who analyse molecular-dynamics trajectories of water, ice, and
  clathrate hydrates in R. The functions identify hexagonal ice, cubic ice,
  clathrate cages, and the hydrogen-bond ring network in a frame.

-   Are there other R packages that accomplish the same thing? If so, how does yours differ or meet [our criteria for best-in-category](https://ropensci.github.io/dev_guide/policies.html#overlap)?

  Checked the live CRAN package index
  (<https://CRAN.R-project.org/web/packages/available_packages_by_name.html>,
  fetched during this review; the exact search and full result list
  are in `logs/cran-search.log`) for "chill", "clathrate", "hydrate",
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
  CHILL+ labels, primitive rings, or cage/point-group classification.
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

  See the pkgcheck summary at the end of this file. Standards from the
  statistical-software track are assessed in
  `srr-standards.md`. `dseams` is not statistical
  software, so the category standards (Bayesian, regression, machine
  learning, distributions, exploratory data analysis, spatial, time
  series, unsupervised learning) do not apply, and the package does not
  carry `@srrstats` tags.

  Two further pkgcheck/goodpractice items need explaining rather than
  fixing (see the pkgcheck summary below for the full output they come
  from):

  - Function names duplicated in other packages: `positions()` is also
    exported by `mixvlmc`, `splus2R` and `splusTimeSeries`, and
    `symmetry()` by `DecomposeR` and `xnet`. Both names are kept because
    they are the plain English names for what they return here (the atom
    coordinate matrix of a frame, and its reclassified point-group
    label), `dseams` does not depend on or re-export those packages, and
    neither name collides inside this package's own namespace.

### Presubmission inquiry

None of the listed categories is an exact match: `data munging` is the
closest honest fit (see above), but `chill_plus()`, `cages()`,
`primitive_rings()` and `symmetry()` classify structures (CHILL+ ice
labels, ring and cage membership, point-group symmetry) computed from a
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

`pkgcheck::pkgcheck(".", use_cache = FALSE)` (pkgcheck 0.3.4.5, pkgstats
0.2.5.4) and `R CMD check --as-cran --no-manual` were run on the
submission branch, at package version 2.14.1 (the `Version` field in
the DESCRIPTION pasted above), with R 4.5.3 and a vendored copy of the
seams-core v2.14.1 engine (`sh tools/vendor.sh`). This cites the
version rather than a commit, because each review round rewrites this
submission as a fresh set of commits on top of the last accepted
round, applied with `git format-patch`/`git am`; a local commit hash
from the sandbox that produced these checks would not exist in that
upstream history and so could never be looked up there. Full logs are
in the handoff bundle (`logs/pkgcheck.log` for both pkgcheck and the
goodpractice checks it runs, `logs/r-cmd-check-as-cran.log`,
`logs/testthat.log`, `logs/covr.log`, `logs/pkgdown-build-site.log`).

What the repository gives pkgcheck:

- CI: `.github/workflows/r-cmd-check.yml` (`name: R-CMD-check`) checks
  the source package on Linux, macOS and Windows and links a seams-core
  build at the pin. `.github/workflows/test-coverage.yml`
  (`name: test-coverage`) runs covr. pkgcheck keeps runs whose name
  matches `cmd` or `coverage`, so both count once they have run on the
  default branch. The most recent `main` runs of both (2026-11-19,
  `d-SEAMS/dseams-r` run IDs 44552815028 and 44552815409) are green.
- Coverage: covr on the R code is 100 percent (`R/capi.R`,
  `R/dseams-package.R`, `R/dseams.R`, `R/s3.R`) with the package linked
  against a seams-core build at the pin (`DSEAMS_ROOT`, `SEAMS_LIBDIR`,
  `SEAMS_BIN` and `SEAMS_CPP_ORACLE` all set), as the test-coverage
  workflow runs it; this review re-checked run 44552815409 directly
  (`gh run view --job=135686626700 --log`), whose own log reads "dseams
  Coverage: 100.00%". `.covrignore` leaves out `src/`, the engine copy
  and the C and C++ glue, which seams-core and the oracle test check,
  and `.pixi/`, the local toolchain. The workflow writes the figure to
  the job summary; nothing uploads it to a coverage service. A bundled,
  unlinked run of `covr::package_coverage()` in this review (no
  `DSEAMS_ROOT`, `SEAMS_LIBDIR` or `SEAMS_CPP_ORACLE`) measured 62.8
  percent overall, with `R/capi.R` at 19.75 percent: most of that file's
  coverage comes from `tests/testthat/test-doc-examples.R`'s comparison
  against `binding_oracle`, which needs the package itself linked
  against a seams-core build (`SEAMS_LIBDIR`), not only `DSEAMS_ROOT` and
  `SEAMS_CPP_ORACLE` (see the comment at
  `tests/testthat/test-doc-examples.R:63-66`: the bundled copy omits the
  optional CON reader the oracle test's fixtures need). That gap is
  expected from AGENTS.md's own note that those tests skip without a
  linked seams-core build, not a regression from the CI figure above.
- `R CMD check --as-cran --no-manual` of the bundled tarball on R 4.5.3
  (the version `pixi.toml:10`'s `r-base = ">=4.4,<4.6"` pin installs):
  **0 errors, 0 warnings, 2 notes** (`New submission`; `unable to verify
  current time` under "checking for future file timestamps"). The CI job
  linked above reports a clean `Status: OK` for the same
  `--as-cran --no-manual` invocation, on R 4.6.2 (its own log says so).
  This repository's own workflow files set only
  `_R_CHECK_FORCE_SUGGESTS_` directly (`.github/workflows/r-cmd-check.yml`
  lines 44 and 94); both notes are instead explained by what the two
  pinned actions the "bundled" job runs set on its behalf.

  `r-lib/actions/setup-r` (`.github/workflows/r-cmd-check.yml:59`,
  pinned to commit `f9a764fe`) unconditionally exports
  `_R_CHECK_SYSTEM_CLOCK_=FALSE` for the rest of the job, and
  `NOT_CRAN=true` if nothing has already set it
  (`setREnvironmentVariables()` in its compiled source,
  `setup-r/src/installer.ts:826-829`, called at line 94 of that same
  file). `r-lib/actions/check-r-package`
  (`.github/workflows/r-cmd-check.yml:80`), which runs later in the same
  job, separately sets `_R_CHECK_CRAN_INCOMING_=false` when that is
  otherwise unset (`check-r-package/action.yaml:47`).

  R's own `tools:::check.R` reads `_R_CHECK_CRAN_INCOMING_` to decide
  whether to run `check_CRAN_incoming()` at all (gated at lines
  7729-7737 in R 4.5.3, 7958-7966 in R 4.6.2): when it is `false`, the
  whole "checking CRAN incoming feasibility" step, and with it the
  `New submission` NOTE, is skipped outright rather than just silenced.
  That is why CI's log has no such step at all.

  `_R_CHECK_SYSTEM_CLOCK_` governs a separate, nested block inside the
  future-file-timestamp check. Verified directly against R 4.5.3's
  `tools:::check.R` (the version `pixi.toml` pins, and this review's
  local run used): that block spans lines 521-568. When the variable
  is the default `TRUE` (nothing in `pixi.toml` or this review's local
  setup changes it), the check queries `worldtimeapi.org` (https, then
  http) and, failing both, `worldclockapi.com`, and NOTEs "unable to
  verify current time" only if all three fail; when it is `FALSE`, that
  whole online-lookup block is skipped, and only a separate, unrelated
  check of the built tarball's own file modification times runs
  afterwards. This review repeated R 4.5.3's exact three-endpoint lookup
  live in its own sandbox and all three fail there, reproducing the
  NOTE locally. On CI, `setup-r` has already set
  `_R_CHECK_SYSTEM_CLOCK_=FALSE` by the time `check-r-package` runs
  `R CMD check`, so the online lookup never runs on CI at all;
  `checking for future file timestamps ... OK` in that job's log is the
  separate, unrelated file-timestamp check passing (nothing in the
  tarball has a future modification time), not a successful time query.
  `NOT_CRAN=true` plays no part in either NOTE: the string `NOT_CRAN`
  does not appear anywhere in `tools:::check.R`, and `dseams`'s own
  tests do not call `skip_on_cran()` or otherwise read that variable.
  `.github/workflows/release.yml` repeats `--as-cran --no-manual` on a
  `v*` tag and publishes the source tarball only for d-SEAMS/dseams-r.

Expected notes, not checklist failures:

- `positions()` is also exported by `mixvlmc`, `splus2R` and
  `splusTimeSeries`; `symmetry()` by `DecomposeR` and `xnet`. Both stay:
  they are the plain names for the frame coordinate matrix and the
  reclassified point-group label, `dseams` does not depend on those
  packages, and the names are unambiguous inside this package.
- `expect_equal()` stays in the ice tests where the comparison is a count
  or a mean. `goodpractice` prefers `expect_identical()` for exact
  values.
- The goodpractice run also reports one `R CMD check` WARNING ("LaTeX
  errors when creating PDF version") and the ERROR behind it (`pdflatex
  is not available`). That comes from `pkgcheck`'s own internal
  `rcmdcheck()` call, which does not pass `--no-manual` and so tries to
  typeset the PDF manual; it is an artifact of a review sandbox without a
  LaTeX toolchain, not of the package, and does not appear in the
  `--no-manual` result above or in CI (which installs no LaTeX either,
  and also does not build the manual).

`srr-standards.md` is the srr assessment. The package
is not statistical software, so it does not carry `@srrstats` tags.
