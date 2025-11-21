# locationallocation <a href = "https://giacfalk.github.io/locationallocation/"><img src = "man/figures/logo.svg" align="right" width="120" /></a>

<!-- badges: start -->
[![Project Status: Active - The project has reached a stable, usable state and is being actively developed.](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)
[![](https://img.shields.io/badge/doi-10.31223/X5XQ69-1284C5.svg)](https://doi.org/10.31223/X5XQ69)
[![R build status](https://github.com/giacfalk/locationallocation/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/giacfalk/locationallocation/actions)
[![License: GPLv3](https://img.shields.io/badge/license-GPLv3-bd0000.svg)](https://www.gnu.org/licenses/gpl-3.0)
<!-- badges: end -->

## Overview

`locationallocation` is an [R](https://www.r-project.org/) package to solve Maximal Coverage Location-Allocation problems using geospatial data.

## Background

Assessing and planning infrastructure and networks over space conditional to a spatially distributed demand and with consideration of accessibility and spatial justice goals and under infrastructure allocation constraints is a key policy objective. This class of problems is generally defined as "Maximal Coverage Location-Allocation (MCLA)" spatial optimization problems.

locationallocation, an R package to solve MCLA problems using geospatial data in widely used R programming language geospatial libraries. The locationallocation package allows to produce travel time maps and spatially optimize the allocation of facilities/infrastructure based on spatial accessibility criteria weighted by one or more variables or a function of those.

## Potential Applications

Potential applications of the package extend to the domains of public infrastructure assessment and planning (public services provision, e.g. transport, social services, healthcare, parks), urban environmental and climate risk reduction interventions, logistics and hubs allocation, commercial and strategic decisions.

## Installation

You can install `locationallocation` using the [`remotes`](https://github.com/r-lib/remotes) package:

``` r
# install.packages(remotes)
remotes::install_github("giacfalk/locationallocation")
```

## Usage

Operate the package as follows.

First, load the package.

``` r
library(locationallocation)
```

As an example, We demonstrate how the package can tackle urban-scale climate risk through robust infrastructure assessment and geospatial planning. We run the `demo_data_load()` function to load a set of demo datasets to run the package's function. The demo data contains the coordinate-point location of public drinking water fountains in the city of Naples, Italy, as well as a gridded population raster data from GHS-POP, a 100-m resolution map of heat hazard (number of days with Wet-Bulb Globe Temperature greater than 25° C in the historical period 2008-2017, obtained from the UrbClim model), and the administrative boundaries of the city.

<p align="center">
<img src="man/figures/map_demand_existing_facilities.png" alt="" width="600"/>
</p>


Then, we can use the `traveltime` function to generate a map of the current accessibility to the facility point sf input (here, naples_fountains) within the specified geographical boundaries, and with a chosen travel mode (walk or fastest), and a given output spatial resolution (in meters; achieved using dissevering spatial downscaling techniques). Once the function has run successfully, we can generate a map of the resulting layer using the `traveltime_plot` function.

``` r
demo_data_load()

out_tt <- traveltime(facilities=naples_fountains, bb_area=naples_shape, dowscaling_model_type="lm", mode="walk", res_output=100)

traveltime_plot(traveltime=out_tt,  bb_area=naples_shape, facilities = naples_fountains)

```
<p align="center">
<img src="man/figures/traveltime_map_fountains.png" alt="" width="600"/>
</p>

We can also produce a summary plot and statistic based on the output of the traveltime function and a given demand (e.g., population) raster, as well as a given time threshold parameter:

``` r
traveltime_stats(traveltime = out_tt, demand = naples_population, breaks=c(5, 10, 15, 30), objectiveminutes=5)
```

which will print a summary cumulative curve plot and an output message such as:

``` r
[1] "38.54 % of demand layer within the objectiveminutes threshold."
```

We can now  use the `allocation` function to optimize the spatial allocation of new water fountains to ensure that (virtually) everyone (i.e., the totality of the raster layer specified by the `demand` parameter) can walk to one within 15 minutes, as specified by the `objectiveminutes` parameter:

``` r
output_allocation <- allocation(demand = naples_population, traveltime=out_tt, bb_area = naples_shape, facilities=naples_fountains, weights=NULL, objectiveminutes=15, objectiveshare=0.99, heur="max", dowscaling_model_type="lm", mode="walk", res_output=100)

allocation_plot(output_allocation, bb_area = naples_shape)

```
<p align="center">
<img src="man/figures/allocation_15mins_fountains.png" alt="" width="600"/>
</p>

Note that is is also possible to solve an allocation problem specifying a `weights` parameter, to attribute more relative importance or priority to areas where the demand is overlapping with some weighting factors (defined by another raster layer), such as exposure to hot days, as in the following example:

``` r
output_allocation_weighted <- allocation(demand = naples_population, traveltime=out_tt, bb_area = naples_shape, facilities=naples_fountains, weights=naples_hot_days, objectiveminutes=15, objectiveshare=0.99, heur="max", dowscaling_model_type="lm", mode="walk", res_output=100)

allocation_plot(output_allocation_weighted, bb_area = naples_shape)
```

<p align="center">
<img src="man/figures/allocation_15mins_fountains_weighted.png" alt="" width="600"/>
</p>

It is also possible to define different demand and weighting layers normalization and exponentiation (to increase the relative role of the two with respect to one another) via the `approach`, `exp_demand`, and `exp_weights` parameters (see the package help file for more details):

``` r
output_allocation_weighted_2 <- allocation(demand = naples_population, traveltime=out_tt, bb_area = naples_shape, facilities=naples_fountains, weights=naples_hot_days, objectiveminutes=15, objectiveshare=0.99, heur="max", dowscaling_model_type="lm", mode="walk", res_output=100, approach = "norm", exp_demand = 2, exp_weights = 1)

```

A variant of the allocation problem is the case when the set of candidate locations to allocate new facilities is discrete (and not continuous over the study area, as in the previous example). In this case, the user needs to provide a discrete set of location points into the `candidate` parameter of the allocation_discrete function, as well as a maximum number of facilities (`n_fac` parameter) that can be selected among the candidate locations. The function will apply a quasi-optimality heuristic (using a randomization based approach, where the number of replications - defined by the `n_samples` parameters - will gradually approach the global optimum but it will linearly increase the computational time. Of course, also in the case of the discrete allocation problem, a weight layer and weights normalization and exponentiation parameters can be set as arguments to the function.

``` r
candidates <- st_sample(naples_shape, 20)

output_allocation_discrete <- allocation_discrete(demand = naples_population, traveltime=NULL, bb_area = naples_shape, facilities=naples_fountains, candidate=candidates, n_fac = 2, weights=NULL, objectiveminutes=15, dowscaling_model_type="lm", mode="walk", res_output=100, n_samples=1000, par=T)

allocation_plot_discrete(output_allocation_discrete, bb_area = naples_shape)
```

<p align="center">
<img src="man/figures/allocation_discrete_fountains.png" alt="" width="600"/>
</p>

Consider the scenario where the user wants to select up to `n_fac` facilities to attain a given `objectiveshare` of the total demand (if this is feasible):

``` r
output_allocation_discrete_targetshare <- allocation_discrete(demand = naples_population, traveltime=NULL, bb_area = naples_shape, facilities=naples_fountains, candidate=candidates, n_fac = 15, objectiveshare=0.85, weights=NULL, objectiveminutes=15, dowscaling_model_type="lm", mode="walk", res_output=100, n_samples=1000, par=T)

allocation_plot_discrete(output_allocation_discrete_targetshare, bb_area = naples_shape)
```

<p align="center">
<img src="man/figures/allocation_discrete_fountains_targetshare.png" alt="" width="600"/>
</p>

Finally, consider the case of a problem where there are no existing facilities to start with, and hence the discrete location-allocation problem needs to optimize the allocation to cover as much as possible of the demand within the limited set of discrete choices over space to allocate new facilities, as well as the constraint set by the maximum number of allocable facilities:

``` r
set.seed(333)

output_allocation_discrete_from_scratch <- allocation_discrete(demand = naples_population, traveltime=NULL, bb_area = naples_shape, facilities=NULL, candidate=candidates, n_fac = 10, weights=NULL, objectiveminutes=15, dowscaling_model_type="lm", mode="walk", res_output=1000, n_samples=1000, par=T)

allocation_plot_discrete(output_allocation_discrete_from_scratch, bb_area = naples_shape)
```
<p align="center">
<img src="man/figures/allocation_discrete_fromscratch_fountains.png" alt="" width="600"/>
</p>

## Citation

If you use this package in your research, please cite it to acknowledge the effort put into its development and maintenance. Your citation helps support its continued improvement.

Falchetta, G. (2025). locationallocation: Solving Maximal Coverage Location-Allocation geospatial infrastructure assessment and planning problems \[Preprint, manuscript submitted for publication\]. _EarthArXiv_. <https://doi.org/10.31223/X5XQ69>

A BibLaTeX entry for LaTeX users is:

```latex
@article{falchetta2025,
  title = {locationallocation: Solving Maximal Coverage Location-Allocation geospatial infrastructure assessment and planning problems},
  author = {{Giacomo Falchetta}},
  year = {2025},
  journal = {EarthArXiv},
  doi = {10.31223/x5xq69},
  langid = {en},
  note = {Preprint, manuscript submitted for publication},
}
```

## License

[![License: GPLv3](https://img.shields.io/badge/license-GPLv3-bd0000.svg)](https://www.gnu.org/licenses/gpl-3.0)

``` text
Copyright (C) 2025 Giacomo Falchetta

locationallocation is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any
later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see <https://www.gnu.org/licenses/>.
```
