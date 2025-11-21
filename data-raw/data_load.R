library(here)
library(raster)
library(sf)
library(usethis)

#' Demo data for locationallocation
#'
#' @description
#'
#' This function loads in the global environment four demo data objects to test
#' the functions of the locationallocation package:
#'
#' - naples_shape: a sf polygon geometry object representing the administrative
#'   boundary of the city of Naples, Italy.
#' - naples_fountains: a sf point geometry object representing the water
#'   fountains in the city of Naples, Italy.
#' - naples_population: a raster Raster object representing the population
#'   density in the city of Naples, Italy.
#' - naples_hot_days: a raster Raster object representing the number of hot
#'   days in the city of Naples, Italy.
#'
#' @return An invisible `NULL`. This function is used for its side effect.
#'
#' @family utility functions
#' @noRd
data_load <- function() {
  variables <- list(
    list(
      file = here::here("data-raw", "napoli.gpkg"),
      fun = sf::read_sf,
      name = "naples_shape"
    ),
    list(
      file = here::here("data-raw", "napoli_water_fountains.gpkg"),
      fun = sf::read_sf,
      name = "naples_fountains"
    ),
    list(
      file = here::here("data-raw", "pop_napoli.tif"),
      fun = raster::raster,
      name = "naples_population"
    ),
    list(
      file = here::here("data-raw", "hotdays_napoli.tif"),
      fun = raster::raster,
      name = "naples_hot_days"
    )
  )

  for (i in variables) {
    assign(i$name, i$fun(i$file), envir = .GlobalEnv)
  }

  invisible()
}

usethis::use_data(
  naples_shape,
  naples_fountains,
  naples_population,
  naples_hot_days,
  overwrite = TRUE
)
