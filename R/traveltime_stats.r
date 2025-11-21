#' Summarize results of the `traveltime()` function
#'
#' `traveltime_stats()` generates a summary of the
#' [`traveltime()`][traveltime()] function results, producing a statistic for
#' the percent of demand which is covered within a given objective travel time
#' along with a cumulative curve plot.
#'
#' @param breaks (optional) A [`numeric`][base::numeric()] object indicating the
#'   breaks (in minutes) for the cumulative curve plot
#'   (default: `c(5, 10, 15, 30)`).
#' @param print (optional) A [`logical`][base::logical()] flag indicating
#' whether to print the results to the console (default: `TRUE`).
#'
#' @return A [`list`][base::list] containing:
#'   - `percent`: A [`numeric`][base::numeric()] value indicating the percent of
#'     demand covered within the objective travel time.
#'   - `data`: A [`data.frame`][base::data.frame()] object with the data used to
#'   generate the cumulative curve plot.
#'   - `plot`: A [`ggplot`][ggplot2::ggplot()] object with the cumulative curve
#'   plot.
#'
#' @template params-traveltime-a
#' @template params-demand
#' @template params-objectiveminutes
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
#'     traveltime_stats(
#'       demand = naples_population,
#'       breaks = c(5, 10, 15, 30),
#'       objectiveminutes = 15
#'     )
#' }
traveltime_stats <- function(
  traveltime,
  demand,
  breaks = c(5, 10, 15, 30),
  objectiveminutes = 15,
  print = TRUE
) {
  assert_traveltime(traveltime)
  checkmate::assert_class(demand, "RasterLayer")
  checkmate::assert_numeric(breaks, min.len = 1)
  checkmate::assert_number(objectiveminutes, lower = 1)
  checkmate::assert_flag(print)

  # R CMD Check variable bindings fix
  # nolint start
  values.t1. <- values.pop. <- P15_cumsum <- th <- NULL
  # nolint end

  data_curve <-
    traveltime[[1]] |>
    raster::`crs<-`(value = "+proj=longlat +datum=WGS84 +no_defs +type=crs") |>
    raster::projectRaster(demand) |>
    raster::`crs<-`(value = "+proj=longlat +datum=WGS84 +no_defs +type=crs") |>
    raster::values() |>
    data.frame(raster::values(demand)) |>
    stats::na.omit(data_curve) |>
    magrittr::set_colnames(c("values.t1.", "values.pop.")) |>
    dplyr::arrange(values.t1.) |>
    dplyr::mutate(
      P15_cumsum =
        values.pop. |>
          cumsum() |>
          magrittr::divide_by(sum(values.pop., na.rm = TRUE)) |>
          magrittr::multiply_by(100),
      th =
        values.t1. |>
        cut(
          breaks = c(-Inf, breaks, Inf),
          labels = c(
            paste0("<", breaks),
            paste0(">", dplyr::last(breaks))
          )
        )
    )

  percent_within_objective <-
    data_curve |>
      dplyr::pull(values.pop.) |>
      magrittr::extract(data_curve$values.t1. <= objectiveminutes) |>
      sum(na.rm = TRUE) |>
      magrittr::divide_by(
        data_curve |>
          dplyr::pull(values.pop.) |>
          sum(na.rm = TRUE)
      ) |>
      magrittr::multiply_by(100) |>
      round(2)

  plot <-
    data_curve |>
    ggplot2::ggplot() +
    ggplot2::geom_step(
      ggplot2::aes(x = values.t1., y = P15_cumsum, color = th)
    ) +
    ggplot2::scale_color_brewer(
      palette = "Reds",
      direction = 1
    ) +
    ggplot2::labs(
      x = "Travel time",
      y = "Cumulative coverage (%)",
      color = "Minutes"
    ) +
    ggplot2::theme_bw() +
    ggplot2::theme(panel.grid = ggplot2::element_blank())

  if (isTRUE(print)) {
    cli::cli_alert_info(
      paste0(
        "{.strong {cli::col_blue(percent_within_objective)}}", "% ",
        "of coverage within the ",
        "{.strong {cli::col_red(objectiveminutes)}} ",
        "minutes threshold."
      )
    )

    print(plot)
  }

  list(
    percent = percent_within_objective,
    data = data_curve,
    plot = plot
  ) |>
    invisible()
}
