#' Plot results of the `allocation()` function
#'
#' `allocation_plot()` is used to plot the results of the
#' [`allocation`][allocation()] function. It shows the potential locations for
#' new facilities and the coverage attained.
#'
#' @param allocation The output of the [`allocation`][allocation()]
#'   function.
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
allocation_plot <- function(allocation, bb_area) {
  assert_allocation(allocation)
  assert_bb_area(bb_area)

  # R CMD Check variable bindings fix
  # nolint start
  x <- y <- layer <- NULL
  # nolint end

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
      data = sf::st_as_sf(
        allocation[[1]]),
        color = "black",
        size = 2.5
    ) +
    ggplot2::scale_fill_distiller(
      palette = "Spectral",
      direction = -1
    ) +
    ggplot2::labs(
      x = NULL,
      y = NULL,
      fill = "Minutes"
    ) +
    ggplot2::theme_bw() +
    ggplot2::theme(panel.grid = ggplot2::element_blank())
}

#' Plot results of the `allocation_discrete()` function
#'
#' `allocation_plot_discrete()` is used to plot the results of the
#' [`allocation_discrete`][allocation_discrete()] function. It shows the
#' potential locations for new facilities and the coverage attained.
#'
#' @param allocation The output of the
#'   [`allocation_discrete`][allocation_discrete()] function.
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
#' \dontrun{    ggplot2::labs(x = NULL, y = NULL) +
#'   library(sf)
#'
#'   candidates <- naples_shape |> st_sample(20)
#'
#'   traveltime <- traveltime(
#'     facilities = naples_fountains,
#'     bb_area = naples_shape,
#'     dowscaling_model_type = "lm",
#'     mode = "walk",
#'     res_output = 100
#'   )
#'
#'   allocation <-
#'     naples_population |>
#'     allocation_discrete(
#'       traveltime = traveltime,
#'       bb_area = naples_shape,
#'       facilities = naples_fountains,
#'       candidate = candidates,
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
#'   allocation |> allocation_plot(naples_shape)
#' }
allocation_plot_discrete <- function(allocation, bb_area){
  assert_allocation(allocation)
  assert_bb_area(bb_area)

  # R CMD Check variable bindings fix
  # nolint start
  x <- y <- layer <- NULL
  # nolint end

  ggplot2::ggplot()+
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
      direction = -1
    ) +
    ggplot2::labs(
      x = NULL,
      y = NULL,
      fill = "Minutes"
    ) +
    ggplot2::theme_bw() +
    ggplot2::theme(panel.grid = ggplot2::element_blank())
}
