#' Plot results of the `allocation()` and `allocation_discrete()` functions
#'
#' @description
#'
#' `allocation_plot()` plot the results of the [`allocation`][allocation()] and
#' `allocation_discrete()` functions, showing the potential locations for new
#' facilities and the coverage attained.
#'
#' @param allocation The output of the [`allocation`][allocation()] or
#' `allocation_discrete()` function.
#'
#' @return A [`ggplot2`][ggplot2::ggplot()] plot showing the potential locations
#'   for new facilities.
#'
#' @template params-bb-area
#' @family plot functions
#' @keywords reporting
#' @export
#'
#' @examples
#'
#' ## Plotting Results of the `allocation()` Function -----
#'
#' \dontrun{
#'   traveltime_data <- traveltime(
#'     facilities = naples_fountains,
#'     bb_area = naples_shape,
#'     dowscaling_model_type = "lm",
#'     mode = "walk",
#'     res_output = 100
#'   )
#'
#'   allocation_data <-
#'     naples_population |>
#'     allocation(
#'       traveltime = traveltime_data,
#'       bb_area = naples_shape,
#'       facilities = naples_fountains,
#'       weights = NULL,
#'       objectiveminutes = 15,
#'       objectiveshare = 0.99,
#'       heur = "max",
#'       dowscaling_model_type = "lm",
#'       mode = "walk",
#'       res_output = 100
#'     )
#'
#'   allocation_data |> allocation_plot(naples_shape)
#' }
#'
#' ## Plotting Results of the `allocation_discrete()` Function -----
#'
#' \dontrun{
#'   library(sf)
#'
#'   traveltime <- traveltime(
#'     facilities = naples_fountains,
#'     bb_area = naples_shape,
#'     dowscaling_model_type = "lm",
#'     mode = "walk",
#'     res_output = 100
#'   )
#'
#'   allocation_data <-
#'     naples_population |>
#'     allocation_discrete(
#'       traveltime = traveltime,
#'       bb_area = naples_shape,
#'       facilities = naples_fountains,
#'       candidate = naples_shape |> st_sample(20),
#'       n_fac = 2,
#'       weights = NULL,
#'       objectiveminutes = 15,
#'       dowscaling_model_type = "lm",
#'       mode = "walk",
#'       res_output = 100,
#'       n_samples = 1000,
#'       par = TRUE
#'     )
#'
#'   allocation_data |> allocation_plot(naples_shape)
#' }
allocation_plot <- function(allocation, bb_area) {
  assert_allocation(allocation)
  assert_bb_area(bb_area)

  # R CMD Check variable bindings fix
  # nolint start
  x <- y <- layer <- NULL
  # nolint end

  max_limit <-
    allocation$travel_time |>
    raster::values() |>
    max(na.rm = TRUE)

  ggplot2::ggplot() +
    ggplot2::geom_raster(
      mapping = ggplot2::aes(x = x, y = y, fill = layer),
      data =
        allocation[[2]] |>
        mask_raster_to_polygon(bb_area) |>
        raster::as.data.frame(xy = TRUE) |>
        stats::na.omit()
    ) +
    ggplot2::geom_sf(
      data = sf::st_as_sf(allocation[[1]]),
      color = "black",
      size = 2.5
    ) +
    ggplot2::scale_fill_distiller(
      palette = "Spectral",
      direction = -1,
      limits = c(0, max_limit)
    ) +
    ggplot2::labs(
      x = NULL,
      y = NULL,
      fill = "Minutes"
    ) +
    ggplot2::theme_bw() +
    ggplot2::theme(panel.grid = ggplot2::element_blank())
}
