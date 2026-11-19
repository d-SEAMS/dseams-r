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
Other Package Authors Github handles: (comma separated, delete if none) <!--author-others--><!--end-author-others-->
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
    person("Ruhila", "S", role = "ctb"),
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
URL: https://docs.dseams.info, https://github.com/d-SEAMS/dseams-r,
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
author (`aut`) and Ruhila S a contributor (`ctb`) in the DESCRIPTION.
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
  parses LAMMPS dump and XYZ trajectories (the output format of a
  molecular-dynamics workflow) into an R-native `dseams_frame`; `chill_plus()`,
  `cages()`, `primitive_rings()`, `steinhardt()` and `q4_q6()` turn that
  frame into documented, S3-classed data frames (`dseams_ice`,
  `dseams_cages`, `dseams_rings`, `dseams_steinhardt`, `dseams_q4_q6`).
  That said, several of those functions classify or count structures
  rather than only reformat them, so the fit is not as clean as the
  guide's own `data munging` examples (`plateR`, `phonfieldwork`); see the
  presubmission-inquiry note below.

-   Who is the target audience and what are scientific applications of this package?

  People who analyse molecular-dynamics trajectories of water, ice, and
  clathrate hydrates in R. The functions identify hexagonal ice, cubic ice,
  clathrate cages, and the hydrogen-bond ring network in a frame.

-   Are there other R packages that accomplish the same thing? If so, how does yours differ or meet [our criteria for best-in-category](https://ropensci.github.io/dev_guide/policies.html#overlap)?

  No CRAN package performs CHILL+ ice classification, Franzblau primitive
  rings, and the d-SEAMS cage census. Neighbouring tools are outside R
  (the d-SEAMS engine itself, and Python and visualisation codes such as
  OVITO). `dseams` is the R binding of that engine, with the same ice Ih
  reference counts the other bindings use (128 hexagonal waters and 256
  six-membered rings on `ice1h.lammpstrj`).

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

  Three further pkgcheck/goodpractice items need explaining rather than
  fixing (see the pkgcheck summary below for the full output they come
  from):

  - Long-line linter hits (36, mostly in `R/capi.R` and
    `inst/examples/`): these are single-expression `.Call()` wrappers and
    `@return` lines that run 81-117 characters, a few past the 80-column
    guideline. Wrapping a one-argument-per-line `.Call()` in a file of
    near-identical thin wrappers would add noise, not readability, so
    they stay as single lines.
  - Function names duplicated in other packages: `positions()` is also
    exported by `mixvlmc`, `splus2R` and `splusTimeSeries`, and
    `symmetry()` by `DecomposeR` and `xnet`. Both names are kept because
    they are the plain English names for what they return here (the atom
    coordinate matrix of a frame, and its reclassified point-group
    label), `dseams` does not depend on or re-export those packages, and
    neither name collides inside this package's own namespace.
  - Authors without ORCID: Ruhila S (`ctb`) has no ORCID on file in the
    repository. The DESCRIPTION lists only the package's existing
    authors as given in the repository; this draft does not add ORCIDs
    on their behalf or add authors.

### Presubmission inquiry

None of the listed categories is an exact match: `data munging` is the
closest honest fit (see above), but the guide's own examples for that
category (`plateR`, `phonfieldwork`) only reformat data, while several
`dseams` functions classify structures (CHILL+ ice labels, ring and cage
membership) rather than just reshape them. Given that, a pre-submission
inquiry to confirm scope before opening the full review issue is the
right next step, rather than asserting a category that may not survive
editor triage. The following is a draft of that inquiry, for Rohit to
review, edit and post himself; it has not been sent.

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

`pkgcheck::pkgcheck(".")` (pkgcheck 0.3.4.5, pkgstats 0.2.5.4) and
`R CMD check --as-cran --no-manual` were run against commit `7d1ac794` of
this branch, with R 4.5.3 and a vendored copy of the seams-core v2.14.1
engine (`sh tools/vendor.sh`). Full logs are in the handoff bundle
(`logs/pkgcheck.log` for both pkgcheck and the goodpractice checks it
runs, `logs/r-cmd-check-as-cran.log`, `logs/testthat.log`,
`logs/covr.log`, `logs/pkgdown-build-site.log`).

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
  against seams-core and `SEAMS_CPP_ORACLE` set, as the test-coverage
  workflow runs it (confirmed from that run's own log: "dseams Coverage:
  100.00%"). `.covrignore` leaves out `src/`, the engine copy and the C
  and C++ glue, which seams-core and the oracle test check, and
  `.pixi/`, the local toolchain. The workflow writes the figure to the
  job summary; nothing uploads it to a coverage service. A local,
  unlinked run of `covr::package_coverage()` in this review (no
  `DSEAMS_ROOT`/`SEAMS_CPP_ORACLE`, so the oracle-comparison code paths
  are skipped rather than exercised) measured 75 percent; that gap is
  expected from AGENTS.md's own note that those tests skip without a
  linked seams-core build, not a regression from the CI figure above.
- `R CMD check --as-cran --no-manual` of the bundled tarball on R 4.5.3
  (the version `pixi.toml:10`'s `r-base = ">=4.4,<4.6"` pin installs):
  **0 errors, 0 warnings, 2 notes** (`New submission`; `unable to verify
  current time` under "checking for future file timestamps"). The CI job
  linked above reports a clean `Status: OK` for the same
  `--as-cran --no-manual` invocation, on R 4.6.2 (its own log says so).
  Neither this repository's workflows nor the pinned `check-r-package`
  action set `NOT_CRAN` or `_R_CHECK_SYSTEM_CLOCK_` anywhere
  (`.github/workflows/r-cmd-check.yml` sets only
  `_R_CHECK_FORCE_SUGGESTS_`, at lines 44 and 94); those two settings
  play no part here. What the pinned action does set, when otherwise
  unset, is `_R_CHECK_CRAN_INCOMING_=false`
  (`check-r-package/action.yaml:47` at the commit
  `.github/workflows/r-cmd-check.yml:80` pins, `f9a764fe`). R's own
  `tools:::check.R` reads that variable to decide whether to run
  `check_CRAN_incoming()` at all (gated at lines 7729-7737 in R 4.5.3,
  7958-7966 in R 4.6.2): when it is false the whole "checking CRAN
  incoming feasibility" step is skipped outright, not just its message,
  which is why CI's log has no such step and no `New submission` NOTE.

  The second note is not suppressed by any variable, and this review
  cannot fully verify why CI's run avoids it. `--as-cran` always forces
  the future-file-timestamp check on (`_R_CHECK_FUTURE_FILE_TIMESTAMPS_
  = "TRUE"` at `check.R:7404` in R 4.5.3, `check.R:7612` in R 4.6.2),
  and `_R_CHECK_SYSTEM_CLOCK_` defaults to `TRUE` in both versions
  (`check.R:521` / `check.R:527`) when nothing sets it, as is the case
  here. R 4.5.3 (this review's run) then queries `worldtimeapi.org`
  (https, then http) and, failing both, `worldclockapi.com`, noting
  "unable to verify current time" only if all three fail
  (`check.R:515-553`); repeating that exact lookup in this review's own
  sandbox, right now, fails on all three. R 4.6.2 (CI's run) instead
  tries an HTTP date header from `https://CRAN.R-project.org` first,
  then `timeapi.io`, then `worldtimeapi.org` (the same check, lines
  515-553 in 4.6.2's `check.R`) -- a different, CRAN-anchored set of
  endpoints, and CRAN itself is reachable from this sandbox. Whether
  CI's run actually succeeded via `CRAN.R-project.org` or one of the
  other two is unverified from here: the CI log only records
  `checking for future file timestamps ... OK`, and `check.R` does not
  log which attempt succeeded.
  `.github/workflows/release.yml` repeats `--as-cran --no-manual` on a
  `v*` tag and publishes the source tarball only for d-SEAMS/dseams-r.

Expected notes, not checklist failures:

- Ruhila S (`ctb`) has no ORCID in the repository. The DESCRIPTION lists
  only the package's existing authors; this draft adds neither an ORCID
  nor a new author to clear the item.
- `positions()` is also exported by `mixvlmc`, `splus2R` and
  `splusTimeSeries`; `symmetry()` by `DecomposeR` and `xnet`. Both stay:
  they are the plain names for the frame coordinate matrix and the
  reclassified point-group label, `dseams` does not depend on those
  packages, and the names are unambiguous inside this package.
- 36 lines over 80 columns (`lintr_line_length_linter`): 21 in
  `R/capi.R`, 11 across `inst/examples/r_capi.R` (8) and
  `inst/examples/science_tutorials.R` (3), 2 in
  `tests/testthat/test-s3.R`, and 1 each in `R/dseams.R` and
  `tests/testthat/test-doc-examples.R`. Most are single-expression
  `.Call()` wrappers or `@return`/example lines; they stay as single
  lines rather than being wrapped mid-call, which would scatter a short,
  mechanical wrapper file across more lines without adding information.
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
