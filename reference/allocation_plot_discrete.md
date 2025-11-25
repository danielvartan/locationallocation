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
if (FALSE) { # \dontrun{
  library(sf)

  candidates <- naples_shape |> st_sample(20)

  traveltime <- traveltime(
    facilities = naples_fountains,
    bb_area = naples_shape,
    dowscaling_model_type = "lm",
    mode = "walk",
    res_output = 100
  )

  allocation_data <-
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

  allocation_data |> allocation_plot(naples_shape)
} # }
```
