
library(devtools)
library(here)
library(remotes)
library(sf)
library(tidyverse)

#  setwd("C:/Users/falchetta/OneDrive - IIASA/Current papers/
# cooling_centers_allocation/locationallocation/")

##

install_github("giacfalk/locationallocation")

library(locationallocation)

#######
#######
#######

terra::plot(naples_population)
terra::plot(naples_shape$geom, add=T, col="transparent")
terra::plot(sf::st_filter(naples_fountains, naples_shape)$geom, add=T, col="blue")

#
here("man", "figures", "map_demand_existing_facilities.png") |>
  png(height = 1000, width = 1500, res=200)

terra::plot(naples_population)
terra::plot(naples_shape$geom, add=T, col="transparent")
terra::plot(sf::st_filter(naples_fountains, naples_shape)$geom, add=T, col="blue")
dev.off()
#

####

out_tt <- traveltime(
  facilities=naples_fountains,
  bb_area=naples_shape,
  dowscaling_model_type="lm",
  mode="walk",
  res_output=100
)

traveltime_plot(
  traveltime=out_tt,
  bb_area=naples_shape,
  facilities = naples_fountains,
  contour_traveltime=NULL
)

traveltime_plot(
  traveltime=out_tt,
  bb_area=naples_shape,
  facilities = naples_fountains,
  contour_traveltime=15
)

here("man", "figures", "traveltime_map_fountains_walk.png") |>
  ggsave(height = 5, width = 5, scale=1.3)

####

out_tt2 <- traveltime(
  facilities=naples_fountains,
  bb_area=naples_shape,
  dowscaling_model_type="lm",
  mode="fastest",
  res_output=100
)

traveltime_plot(
  traveltime=out_tt2,
  bb_area=naples_shape,
  facilities = naples_fountains,
  contour_traveltime=NULL
)

traveltime_plot(
  traveltime=out_tt2,
  bb_area=naples_shape,
  facilities = naples_fountains,
  contour_traveltime=15
)

ggsave("traveltime_map_fountains_fastest.png", height = 5, width = 5, scale=1.3)


###

traveltime_stats(
  traveltime = out_tt,
  demand = naples_population,
  breaks=c(5, 10, 15, 30),
  objectiveminutes=5
)

here("man", "figures", "traveltime_curve_fountains_waol.png") |>
  ggsave(height = 3, width = 5, scale=1.3)

traveltime_stats(traveltime = out_tt2, demand = naples_population, breaks=c(5, 10, 15, 30), objectiveminutes=5)

here("man", "figures", "traveltime_curve_fountains_fastest.png") |>
  ggsave(height = 3, width = 5, scale=1.3)


###

output_allocation <- allocation(
  demand = naples_population,
  traveltime=out_tt,
  bb_area = naples_shape,
  facilities=naples_fountains,
  weights=NULL,
  objectiveminutes=15,
  objectiveshare=0.99,
  heur="max",
  dowscaling_model_type="lm",
  mode="walk",
  res_output=100
)

allocation_plot(output_allocation, bb_area = naples_shape)

here("man", "figures", "allocation_15mins_fountains.png") |>
  ggsave(height = 5, width = 5, scale=1.3)

###

output_allocation_weighted <- allocation(
  demand = naples_population,
  traveltime=out_tt,
  bb_area = naples_shape,
  facilities=naples_fountains,
  weights=naples_hot_days,
  objectiveminutes=15,
  objectiveshare=0.99,
  heur="max",
  dowscaling_model_type="lm",
  mode="walk",
  res_output=100,
  approach = "norm"
)

allocation_plot(output_allocation_weighted, bb_area = naples_shape)

here("man", "figures", "allocation_15mins_fountains_weighted.png") |>
  ggsave(height = 5, width = 5, scale=1.3)


output_allocation_weighted_expdemand2 <- allocation(
  demand = naples_population,
  traveltime=out_tt,
  bb_area = naples_shape,
  facilities=naples_fountains,
  weights=naples_hot_days,
  objectiveminutes=15,
  objectiveshare=0.99,
  heur="max",
  dowscaling_model_type="lm",
  mode="walk",
  res_output=100,
  approach = "norm",
  exp_demand = 2
)

allocation_plot(output_allocation_weighted_expdemand2, bb_area = naples_shape)

here(
  "man",
  "figures",
  "allocation_15mins_fountains_weighted_exp_demand2.png"
) |>
  ggsave(height = 5, width = 5, scale=1.3)


####
####

set.seed(333)

candidates <- st_sample(naples_shape, 20)

set.seed(333)

### add allocation by target share (similar to allocation, but force pixel selection among locations where facilities can be placed)

output_allocation_discrete <- allocation_discrete(
  demand = naples_population,
  traveltime=NULL,
  bb_area = naples_shape,
  facilities=naples_fountains,
  candidate=candidates,
  n_fac = 2,
  weights=NULL,
  objectiveminutes=15,
  dowscaling_model_type="lm",
  mode="walk",
  res_output=100,
  n_samples=1000,
  par=TRUE
)

allocation_plot_discrete(output_allocation_discrete, bb_area = naples_shape)

here("man", "figures", "allocation_discrete_fountains.png") |>
  ggsave(height = 5, width = 5, scale=1.3)

###

set.seed(333)

output_allocation_discrete_weighted <-
  allocation_discrete(
    demand = naples_population,
    traveltime = out_tt,
    bb_area = naples_shape,
    facilities=naples_fountains,
    candidate=candidates,
    n_fac = 5,
    weights=naples_hot_days,
    objectiveminutes=15,
    dowscaling_model_type="lm",
    mode="walk",
    res_output=100,
    n_samples=1000,
    par=TRUE,
    exp_demand = 1,
    approach = "norm"
  )

output_allocation_discrete_weighted |>
  allocation_plot_discrete(bb_area = naples_shape)

here("man", "figures", "allocation_discrete_fountains_weighted.png") |>
  ggsave(height = 5, width = 5, scale=1.3)

###

###

set.seed(333)

output_allocation_discrete_weighted_2 <- allocation_discrete(
  demand = naples_population,
  traveltime = out_tt,
  bb_area = naples_shape,
  facilities=naples_fountains,
  candidate=candidates,
  n_fac = 5,
  weights=naples_hot_days,
  objectiveminutes=15,
  dowscaling_model_type="lm",
  mode="walk",
  res_output=100,
  n_samples=1000,
  par=T,
  exp_demand = 2,
  approach = "norm"
)

allocation_plot_discrete(
  output_allocation_discrete_weighted_2,
  bb_area = naples_shape
)

here("man", "figures", "allocation_discrete_fountains_weighted_2.png") |>
  ggsave(height = 5, width = 5, scale=1.3)

###

set.seed(333)

output_allocation_discrete_targetshare <- allocation_discrete(
  demand = naples_population,
  traveltime=NULL,
  bb_area = naples_shape,
  facilities=naples_fountains,
  candidate=candidates,
  n_fac = 15,
  objectiveshare=0.95,
  weights=NULL,
  objectiveminutes=15,
  dowscaling_model_type="lm",
  mode="walk",
  res_output=100,
  n_samples=10000,
  par=TRUE
)

output_allocation_discrete_targetshare |>
  allocation_plot_discrete(bb_area = naples_shape)

here("man", "figures", "allocation_discrete_fountains_targetshare.png") |>
  ggsave(height = 5, width = 5, scale=1.3)


set.seed(333)

output_allocation_discrete_from_scratch <- allocation_discrete(
  demand = naples_population,
  traveltime=NULL,
  bb_area = naples_shape,
  facilities=NULL,
  candidate=candidates,
  n_fac = 10,
  weights=NULL,
  objectiveminutes=15,
  dowscaling_model_type="lm",
  mode="walk",
  res_output=1000,
  n_samples=1000,
  par=TRUE
)

output_allocation_discrete_from_scratch |>
  allocation_plot_discrete(bb_area = naples_shape)

here("man", "figures", "allocation_discrete_fromscratch_fountains.png") |>
  ggsave(height = 5, width = 5, scale=1.3)
