# rOpenSci software-review submission (draft)

Draft for Rohit Goswami to review. This file is the issue body. It has not
been opened on <https://github.com/ropensci/software-review>. Confirm the
author attestations and the coauthor GitHub handles before pasting it into
a new issue.

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
Version submitted: 2.14.0
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
Version: 2.14.0
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
	- [ ] data munging
	- [ ] data deposition
    - [ ] data validation and testing
	- [ ] workflow automation
	- [ ] version control
	- [ ] citation management and bibliometrics
	- [x] scientific software wrappers
	- [ ] field and lab reproducibility tools
	- [ ] database software bindings
	- [ ] geospatial data
	- [ ] translation
    - [ ] rOpenSci internal tools

- Explain how and why the package falls under these categories (briefly, 1-2 sentences):

  `dseams` is a wrapper around the d-SEAMS C++ engine. It reads a LAMMPS
  dump or an XYZ file and returns data frames of ice labels, ring counts,
  cages, and order parameters. The numerical work is the bundled engine.

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

  No pre-submission inquiry.

-   Explain reasons for any [`pkgcheck` items](https://docs.ropensci.org/pkgcheck/) which your package is unable to pass.

  See the pkgcheck summary at the end of this file. Standards from the
  statistical-software track are assessed in
  `srr-standards.md`. `dseams` is not statistical
  software, so the category standards (Bayesian, regression, machine
  learning, distributions, exploratory data analysis, spatial, time
  series, unsupervised learning) do not apply, and the package does not
  carry `@srrstats` tags.

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

The pkgcheck run recorded in earlier drafts (pkgcheck 0.3.4) predates the
move of the package into d-SEAMS/dseams-r, and its CI and coverage lines
described seams-core. Run `pkgcheck::pkgcheck()` again on the pushed
default branch and paste its summary here before opening the issue.

What the repository gives pkgcheck now:

- CI: `.github/workflows/r-cmd-check.yml` (`name: R-CMD-check`) checks
  the source package on Linux, macOS and Windows and links a seams-core
  build at the pin. `.github/workflows/test-coverage.yml`
  (`name: test-coverage`) runs covr. pkgcheck keeps runs whose name
  matches `cmd` or `coverage`, so both count once they have run on the
  default branch.
- Coverage: covr on the R code is 100 percent (`R/capi.R`,
  `R/dseams-package.R`, `R/dseams.R`, `R/s3.R`) with the package linked
  against seams-core and `SEAMS_CPP_ORACLE` set, as the test-coverage
  workflow runs it. `.covrignore` leaves out `src/`, the engine copy and
  the C and C++ glue, which seams-core and the oracle test check, and
  `.pixi/`, the local toolchain. The workflow writes the figure to the
  job summary; nothing uploads it to a coverage service.
- `R CMD check --as-cran` of the bundled tarball on R 4.5.3: 0 errors,
  0 warnings, 1 note (`New submission`).

Expected notes, not checklist failures:

- Ruhila S has no ORCID in the repository, so none was added.
- `positions` and `symmetry` are also exported by other CRAN packages.
  They stay, because those are the names of the frame coordinates and the
  shell label.
- `expect_equal()` stays in the ice tests where the comparison is a count
  or a mean. `goodpractice` prefers `expect_identical()` for exact
  values.

`srr-standards.md` is the srr assessment. The package
is not statistical software, so it does not carry `@srrstats` tags.
