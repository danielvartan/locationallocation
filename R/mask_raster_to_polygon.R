#' Mask a `RasterLayer` object to a `sf` object
#'
#' This function rapidly masks a [`RasterLayer`][raster::raster()] object to
#' a [`sf`][sf::st_as_sf()] object.
#'
#' @param ras A [`RasterLayer`][raster::raster()] object.
#' @param mask A [`RasterLayer`][raster::raster()] or [`sf`][sf::st_as_sf()]
#' object.
#' @param inverse A [`logical`][base::logical()] flag. If `TRUE`, the mask
#'   is inverted (default: `FALSE`).
#' @param updatevalue The value to update the [`RasterLayer`][raster::raster()]
#'   object with (default: `NA`).
#'
#' @family utility functions
#' @keywords masking
#' @export
#'
#' @examples
#' naples_population |> mask_raster_to_polygon(naples_shape)
mask_raster_to_polygon <- function (
  ras,
  mask,
  inverse = FALSE,
  updatevalue = NA
) {
  checkmate::assert_class(ras, "RasterLayer")
  checkmate::assert_multi_class(mask, c("Raster", "sf"))
  checkmate::assert_flag(inverse)
  checkmate::assert_atomic(updatevalue, len = 1)

  if (inherits(mask, "sf")) {
    test <-
      mask |>
      sf::st_geometry_type() |>
      as.character() |>
      magrittr::is_in(c("POLYGON", "MULTIPOLYGON"))

    if (isFALSE(test)) {
      cli::cli_abort(
        paste0(
          "The {.strong {cli::col_red('mask')}} parameter ",
          "must be a {.strong sf} object of type ",
          "{.strong POLYGON} or {.strong MULTIPOLYGON}."
        )
      )
    }

    mask <-
      mask |>
      sf::st_crop(
        c(
          xmin = raster::xmin(ras),
          ymin = raster::ymin(ras),
          xmax = raster::xmax(ras),
          ymax = raster::ymax(ras)
        )
      ) |>
      sf::st_cast() |>
      terra::vect() |>
      suppressWarnings()
  }

  ras |>
    terra::rast() |>
    terra::mask(mask, inverse = inverse) |>
    raster::raster()
}
