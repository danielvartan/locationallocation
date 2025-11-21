# Plot results of the `allocation_discrete()` function

`allocation_plot_discrete()` is used to plot the results of the
[`allocation_discrete`](https://giacfalk.github.io/locationallocation/reference/allocation_discrete.md)
function. It shows the potential locations for new facilities and the
coverage attained.

## Usage

``` r
allocation_plot_discrete(allocation, bb_area)
```

## Arguments

- allocation:

  The output of the
  [`allocation_discrete`](https://giacfalk.github.io/locationallocation/reference/allocation_discrete.md)
  function.

- bb_area:

  A [`sf`](https://r-spatial.github.io/sf/reference/st_as_sf.html)
  boundary box object with the area of interest.

## Value

A [`ggplot2`](https://ggplot2.tidyverse.org/reference/ggplot.html) plot
showing the potential locations for new facilities.

## See also

Other plot functions:
[`allocation_plot()`](https://giacfalk.github.io/locationallocation/reference/allocation_plot.md)

## Examples

``` r
if (FALSE)     ggplot2::labs(x = NULL, y = NULL) +
  library(sf)

  candidates <- naples_shape |> st_sample(20)
#> Error in st_sample(naples_shape, 20): could not find function "st_sample"

  traveltime <- traveltime(
    facilities = naples_fountains,
    bb_area = naples_shape,
    dowscaling_model_type = "lm",
    mode = "walk",
    res_output = 100
  )
#> ℹ Downloading friction data from the Malaria Atlas Project
#> <GMLEnvelope>
#> ....|-- lowerCorner: 40.79281558987 14.1353871711579
#> ....|-- upperCorner: 40.9149179937145 14.3527090131438
#> ✔ Downloading friction data from the Malaria Atlas Project [38.5s]
#> 
#> ℹ Downloading data from OpenStreetMap
#> Selecting best model parameters
#> Loading required package: ggplot2
#> Loading required package: lattice
#> 
#> Attaching package: ‘caret’
#> The following object is masked from ‘package:future’:
#> 
#>     cluster
#> Parameters retained: intercept = 1
#> | - iteration 1
#> | -- updating model
#> | -- updating predictions
#> | -- RMSE = 0.017
#> | - iteration 2
#> | -- updating model
#> | -- updating predictions
#> | -- RMSE = 0.016
#> | - iteration 3
#> | -- updating model
#> | -- updating predictions
#> | -- RMSE = 0.016
#> Retaining model fitted at iteration 3
#> ✔ Downloading data from OpenStreetMap [29.6s]
#> 
#> ℹ Computing transition matrix and geocorrection
#> ✔ Computing transition matrix and geocorrection [3.1s]
#> 
#> ℹ Computing travel time map
#> Warning: [mask] CRS do not match
#> ✔ Computing travel time map [950ms]
#> 

  allocation <-
    naples_population |>
    allocation_discrete(
      traveltime = traveltime,
      bb_area = naples_shape,
      facilities = naples_fountains,
      candidate = candidates,
      n_fac = 2,
      weights = NULL,
      objectiveminutes = 15,
      dowscaling_model_type = "lm",
      mode = "walk",
      res_output = 100,
      n_samples = 1000,
      par = TRUE
    )
#> Error: object 'candidates' not found

  allocation |> allocation_plot(naples_shape)
#> Error in assert_allocation(allocation): allocation must be an output object from the allocation() or
#> allocation_discrete() functions.
 # \dontrun{}
```
