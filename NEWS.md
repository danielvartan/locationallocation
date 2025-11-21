# locationallocation 0.1.1.9000 (development version)

- Refactored the codebase for better maintainability.
- Fixed R-CMD-check issues.
- Added a `NEWS.md` file to track changes to the package.
- Added an R-CMD-check GitHub Action workflow.
- Added [`lintr`](https://lintr.r-lib.org/) for code consistency. The package now follow the [tidy tools manifesto](https://tidyverse.tidyverse.org/articles/manifesto.html), the [tidyverse design principles](https://design.tidyverse.org/), and the [tidyverse style guide](https://style.tidyverse.org/).
- Added [`checkmate`](https://mllg.github.io/checkmate/) for defensive programming.
- Added [`testthat`](https://testthat.r-lib.org/) for unit testing.
- Added [`spelling`](https://docs.ropensci.org/spelling/) for spell checking.
- Added [Contributor Code of Conduct v3](https://www.contributor-covenant.org/version/3/0/code_of_conduct/) to incentive contributions.
- Added the demo data as exports, and changed their names to: `naples_shape`, `naples_population`, `naples_fountains`, and `naples_hot_days`.
- Removed `demo_data_load()`, as it is no longer necessary.
- Added default values to `allocation()`, `allocation_discrete()` and other functions.
- Added `CITATION.cff` and `codemeta.json` files for better citation and metadata.
- Removed the `fasterize` dependency due to compatibility issues on Linux systems.
- Updated package dependencies to their latest versions.
- Updated documentation.

# locationallocation 0.1.1

- Updated weighting approach and added weights normalization and exponentiation arguments.

# locationallocation 0.1.0

- First release! 🎉

# locationallocation 0.0.1 (pre-release)

# locationallocation 0.0.0.9000

- Initial version.
