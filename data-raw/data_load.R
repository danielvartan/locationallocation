library(here)
library(raster)
library(sf)
library(usethis)

#' Load Demo Data for Testing
#'
#' `data_load()` loads in the global environment four demo data objects to test
#' the functions of the `locationallocation` package.
#'
#' - `naples_shape`: A [`sf`][sf::st_as_sf()] polygon geometry object
#'   representing the administrative boundary of the city of Naples, Italy.
#' - `naples_fountains`: A [`sf`][sf::st_as_sf()] point geometry object
#'   representing the water fountains in the city of Naples, Italy.
#' - `naples_population`: A [`Raster`][raster::raster()] object representing the
#'   population density in the city of Naples, Italy.
#' - `naples_hot_days`: A [`Raster`][raster::raster()] object representing the
#'   number of hot days in the city of Naples, Italy.
#'
#' @return An invisible `NULL`. This function is used for its side effect.
#'
#' @family utility functions
#' @noRd
data_load <- function() {
  variables <- list(
    list(
      file = here::here("data-raw", "napoli-shape.gpkg"),
      fun = sf::read_sf,
      name = "naples_shape"
    ),
    list(
      file = here::here("data-raw", "naples-fountains.gpkg"),
      fun = sf::read_sf,
      name = "naples_fountains"
    ),
    list(
      file = here::here("data-raw", "naples-population.tif"),
      fun = \(x) raster::readAll(raster::raster(x)),
      name = "naples_population"
    ),
    list(
      file = here::here("data-raw", "naples-hot-days.tif"),
      fun = \(x) raster::readAll(raster::raster(x)),
      name = "naples_hot_days"
    )
  )

  for (i in variables) {
    assign(i$name, i$fun(i$file), envir = .GlobalEnv)
  }

  invisible()
}

data_load()

usethis::use_data(
  naples_shape,
  naples_fountains,
  naples_population,
  naples_hot_days,
  overwrite = TRUE
)
