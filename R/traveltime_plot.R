#' Plot results of the `traveltime()` function
#'
#' @description
#'
#' `traveltime_plot()` plot the results of the [`traveltime()`][traveltime()]
#' function, showing the travel time from the facilities to the area of
#' interest.
#'
#' @param contour_traveltime (optional) A number indicating the contour
#'   thresholds for the travel time (default: `15`).
#'
#' @return A [`ggplot2`][ggplot2::ggplot()] plot showing the travel time from
#'   the  facilities to the area of interest.
#'
#' @template params-traveltime-a
#' @template params-bb-area
#' @template params-facilities
#' @family travel time functions
#' @keywords reporting
#' @export
#'
#' @examples
#' \dontrun{
#'   traveltime_data <-
#'     naples_fountains |>
#'     traveltime(
#'       bb_area = naples_shape,
#'       dowscaling_model_type = "lm",
#'       mode = "walk",
#'       res_output = 100
#'     )
#'
#'   traveltime_data |>
#'     traveltime_plot(
#'       bb_area = naples_shape,
#'       facilities = naples_fountains
#'     )
#' }
traveltime_plot <- function(
  traveltime,
  bb_area,
  facilities = NULL,
  contour_traveltime = 15
) {
  assert_traveltime(traveltime)
  assert_bb_area(bb_area)
  assert_facilities(facilities)
  checkmate::assert_numeric(contour_traveltime, lower = 1, null.ok = TRUE)

  # R CMD Check variable bindings fix
  # nolint start
  x <- y <- layer <- NULL
  # nolint end

  data <-
    traveltime[[1]] |>
    mask_raster_to_polygon(bb_area) |>
    raster::as.data.frame(xy = TRUE) |>
    stats::na.omit()

  plot <-
    ggplot2::ggplot() +
    ggplot2::geom_raster(
      mapping = ggplot2::aes(x = x, y = y, fill = layer),
      data = data
    ) +
    ggplot2::scale_fill_distiller(
      palette = "Spectral",
      direction = -1
    ) +
    ggplot2::geom_sf(
      data = facilities |> sf::st_filter(bb_area),
      color = ifelse(
        is.null(facilities),
        "transparent",
        "black"
      ),
      size = 0.5
    ) +
    ggplot2::labs(
      x = NULL,
      y = NULL,
      fill = "Minutes"
    ) +
    ggplot2::theme_bw() +
    ggplot2::theme(panel.grid = ggplot2::element_blank())

  if (!is.null(contour_traveltime)) {
    plot +
      ggplot2::geom_contour(
        mapping = ggplot2::aes(x = x, y = y, z = layer),
        data = data,
        color = "black",
        breaks = contour_traveltime
      )
  } else {
    plot
  }
}
