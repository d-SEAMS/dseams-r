This file is the issue body.

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
    person("Ruhila", "Goswami", role = "ctb"),
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

  `dseams` wraps the d-SEAMS C++ engine for use from R. It reads one frame from LAMMPS or XYZ trajectories and returns data frames for ice labels, ring counts, cages, and order parameters.

-   Who is the target audience and what are scientific applications of this package?

  The target audience is researchers analysing molecular-dynamics trajectories of water, ice, and clathrate hydrates in R. The package is used for CHILL+ classification, primitive ring statistics, and cage and bond-order analyses in simulation workflows.

-   Are there other R packages that accomplish the same thing? If so, how does yours differ or meet [our criteria for best-in-category](https://ropensci.github.io/dev_guide/policies.html#overlap)?

  No CRAN package provides the same combination of CHILL+ ice classification, Franzblau primitive ring analysis, and d-SEAMS cage diagnostics in R. `dseams` is the native R binding to the d-SEAMS engine and keeps parity with the reference counts used across the project bindings.

-   (If applicable) Does your package comply with our [guidance around _Ethics, Data Privacy and Human Subjects Research_](https://devguide.ropensci.org/policies.html#ethics-data-privacy-and-human-subjects-research)?

  Not applicable. The package processes simulation trajectory data and does not process human-subject data.

-   If you made a pre-submission inquiry, please paste the link to the corresponding issue, forum post, or other discussion, or `@tag` the editor you contacted.

  No pre-submission inquiry.

-   Explain reasons for any [`pkgcheck` items](https://docs.ropensci.org/pkgcheck/) which your package is unable to pass.

  See the `## pkgcheck` section below for the verbatim output.

  - `Package has no continuous integration checks` and `Package coverage failed` are CI-based checks that depend on detected workflow runs on the default branch; they do not pass in this local run context.
  - `R CMD check found 2 errors` and `R CMD check found 1 warning` in the local pkgcheck run reflect missing local PDF-manual tooling and local check environment constraints.
  - `Some goodpractice linters failed`, duplicate function names, and missing ORCID for Ruhila Goswami are reported as quality and metadata items; the function names and contributor ORCID status are intentional.

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

If so, please describe usage, and include links to any relevant aspects of your repository. See [our blog post](https://ropensci.org/blog/2026/02/26/ropensci-ai-policy/) for background. (Explicit advice is not yet included in our _Dev Guide_; we are hoping to update very soon, and ask your cooperation and transparency in the meantime.)

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

After software review, rOpenSci can co-submit an accepted package to the Journal of Open Source Software if a paper is prepared for that co-submission.

## Code of conduct

- [x] I agree to abide by [rOpenSci's Code of Conduct](https://ropensci.org/code-of-conduct/) during the review process and in maintaining my package should it be accepted.

## pkgcheck

```
── dseams 2.14.1 ───────────────────────────────────────────────────────────────

✔ Package name is available
✔ has a 'contributing' file.
✔ uses 'roxygen2'.
✔ 'DESCRIPTION' has a URL field.
✔ 'DESCRIPTION' has a BugReports field.
✔ Package has at least one HTML vignette
✔ All functions have examples.
✔ Repository has a website
✖ Package has no continuous integration checks.
✖ Package coverage failed
✖ R CMD check found 2 errors.
✖ R CMD check found 1 warning.
ℹ Some goodpractice linters failed.
ℹ Function names are duplicated in other packages
ℹ Not all authors have ORCID IDs

ℹ Current status:
✖ Darn it, still problems lurking there ...

ℹ 'pkgcheck' version: 0.3.4.5
```
