#' Compute the maximal coverage location-allocation for continuous problems
#'
#' @description
#'
#' `allocation()` allocate facilities in a continuous location problem. It uses
#' the accumulated cost algorithm to find the optimal location for the
#' facilities based on the share of the demand to be covered.
#'
#' See [`allocation_discrete()`][allocation_discrete()] for discrete
#' location-allocation problems.
#'
#' @param weights (optional) A raster with the weights for the demand (default:
#' `NULL`).
#' @param heur (optional) The heuristic approach to be used. Options are `"max"`
#'   and `"kd"` (default: `"max"`).
#' @param approach (optional) The approach to be used for the allocation.
#'   Options are `"norm"` and `"absweights"`. If "norm", the allocation is based
#'   on the normalized demand raster multiplied by the normalized weights
#'   raster. If `"absweights"`, the allocation is based on the normalized demand
#'   raster multiplied by the raw weights raster (default: `"norm"`).
#' @param exp_demand (optional) The exponent for the demand raster. Default is
#'   1. A higher value will give less relative weight to areas with higher
#'   demand - with respect to the weights layer. This is useful in cases where
#'   the users want to increase the allocation in areas with higher values in
#'   the weights layer (default: `1`).
#' @param exp_weights (optional) The exponent for the weights raster. Default is
#'   1. A higher value will give less relative weight to areas with higher
#'   weights - with respect to the demand layer. This is useful in cases where
#'   the users want to increase the allocation in areas with higher values in
#'   the demand layer (default: `1`).
#'
#' @return A [`list`][base::list] with the following elements:
#'   - `facilities`: A [`sf`][sf::sf()] object with the newly allocated
#'   facilities.
#'   - `travel_time`: A [`raster`][raster::raster()] RasterLayer object
#'   representing the travel time map with the newly allocated facilities.
#'
#' @template params-demand
#' @template params-facilities
#' @template params-bb-area
#' @template params-traveltime-b
#' @template params-objectiveminutes
#' @template params-objectiveshare-a
#' @inheritParams friction
#' @family location-allocation functions
#' @keywords location-allocation
#' @export
#'
#' @examples
#' \dontrun{
#'   library(dplyr)
#'
#'   allocation_data <-
#'     naples_population |>
#'     allocation(
#'       bb_area = naples_shape,
#'       facilities = naples_fountains,
#'       weights = naples_hot_day
#'     )
#'
#'   allocation_data |> glimpse()
#'
#'   allocation_data |> allocation_plot(naples_shape)
#' }
allocation <- function(
  demand,
  bb_area,
  facilities,
  traveltime = NULL,
  mode = "walk",
  dowscaling_model_type = "lm",
  res_output = 100,
  weights = NULL,
  objectiveminutes = 15,
  objectiveshare = 0.99,
  heur = "max",
  approach = "norm",
  exp_demand = 1,
  exp_weights = 1
) {
  checkmate::assert_class(demand, "RasterLayer")
  assert_bb_area(bb_area)
  assert_facilities(facilities)
  assert_traveltime(traveltime, null_ok = TRUE)
  checkmate::assert_choice(mode, choices = c("walk", "fastest"))
  checkmate::assert_choice(dowscaling_model_type, choices = c("lm", "rf"))
  checkmate::assert_count(res_output, positive = TRUE)
  checkmate::assert_class(weights, "RasterLayer", null.ok = TRUE)
  checkmate::assert_count(objectiveminutes, positive = TRUE)
  checkmate::assert_number(objectiveshare, lower = 0, upper = 1)
  checkmate::assert_choice(heur, choices = c("max", "kd"))
  checkmate::assert_choice(approach, choices = c("norm", "absweights"))
  checkmate::assert_number(exp_demand, lower = 0)
  checkmate::assert_number(exp_weights, lower = 0)

  sf::sf_use_s2(TRUE)

  if (is.null(traveltime)) {
    cli::cli_alert_info(
      paste0(
        "Travel time layer not detected. ",
        "Running {.strong {cli::col_red('traveltime()')}} function first."
      )
    )

    traveltime <- traveltime(
      facilities = facilities,
      bb_area = bb_area,
      mode = mode,
      dowscaling_model_type = dowscaling_model_type,
      res_output = res_output
    )
  }

  traveltime_raster_outer <- traveltime

  demand <- demand |> mask_raster_to_polygon(bb_area)

  traveltime <-
    traveltime_raster_outer[[1]] |>
    mask_raster_to_polygon(bb_area)

  raster::crs(traveltime) <-
    "+proj=longlat +datum=WGS84 +no_defs +type=crs"

  traveltime <- raster::projectRaster(traveltime, demand)

  raster::crs(traveltime) <- "+proj=longlat +datum=WGS84 +no_defs +type=crs"

  if (!is.null(weights) && approach == "norm") {
    weights <- weights |> mask_raster_to_polygon(bb_area)

    demand <-
      demand |>
      normalize_raster() |>
      magrittr::raise_to_power(exp_demand) |>
      magrittr::multiply_by(
        weights |>
          normalize_raster() |>
          magrittr::raise_to_power(exp_weights)
      )
  } else if (!is.null(weights) && approach == "absweights") {
    weights <- weights |> mask_raster_to_polygon(bb_area)

    demand <-
      demand |>
      normalize_raster() |>
      magrittr::raise_to_power(exp_demand) |>
      magrittr::multiply_by(
        weights |>
          magrittr::raise_to_power(exp_weights)
      )
  } else if (is.null(weights)) {
    demand <- demand |> magrittr::raise_to_power(exp_demand)
  }

  totalpopconstant <- demand |> raster::cellStats("sum", na.rm = TRUE)

  demand <-
    demand |>
    raster::overlay(
      traveltime,
      fun = function(x, y) {
        x[y <= objectiveminutes] <- NA

        x
      }
    )

  iter <- 1
  k_save <- 1

  repeat {
    iter <- iter + 1

    if (heur == "kd") {
      all <- spatialEco::sp.kde(
        x = sf::st_as_sf(raster::rasterToPoints(demand, spatial = TRUE)),
        y = all$layer,
        bw = 0.0083333,
        ref = terra::rast(demand),
        res = 0.0008333333,
        standardize = TRUE,
        scale.factor = 10000
      )
    } else if (heur == "max") {
      all <- raster::which.max(demand)
    }

    pos <-
      demand |>
      raster::xyFromCell(all) |>
      as.data.frame()

    if (exists("new_facilities")) {
      new_facilities <-
        new_facilities |>
        rbind(
          pos |>
            sf::st_as_sf(
              coords = c("x", "y"),
              crs = 4326
            )
        )
    } else {
      new_facilities <-
        pos |>
        sf::st_as_sf(
          coords = c("x", "y"),
          crs = 4326
        )
    }

    merged_facilities <-
      facilities |>
      sf::st_geometry() |>
      as.data.frame() |>
      dplyr::bind_rows(as.data.frame(new_facilities))

    points <-
      merged_facilities |>
      magrittr::extract2("geometry") |>
      sf::st_coordinates() |>
      as.data.frame()

    n_points <- points |> dim() |> magrittr::extract(1)
    xy_matrix <- points_to_matrix(points, n_points)

    traveltime_raster_new <-
      traveltime_raster_outer[[2]][[3]] |>
      gdistance::accCost(xy_matrix) |>
      raster::crop(raster::extent(demand)) |>
      raster::`crs<-`(
        value = "+proj=longlat +datum=WGS84 +no_defs +type=crs"
      ) |>
      raster::projectRaster(demand) |>
      raster::`crs<-`(
        value = "+proj=longlat +datum=WGS84 +no_defs +type=crs"
      ) |>
      mask_raster_to_polygon(bb_area)

    demand <-
      demand |>
      raster::overlay(
        traveltime_raster_new,
        fun = function(x, y) {
          x[y <= objectiveminutes] <- NA

          x
        }
      )

    k <-
      demand |>
      raster::cellStats("sum", na.rm = TRUE) |>
      magrittr::divide_by(totalpopconstant)

    k_save[iter] <- k

    cli::cli_alert_info(
      paste0(
        "Iteration {.strong {cli::col_yellow(iter - 1)}}: ",
        "Fraction of unmet demand: ",
        "{.strong {cli::col_red(round(k * 100, 5))}}%."
      )
    )

    if (k < (1 - objectiveshare)) {
      break
    } else if (k == k_save[iter - 1]) {
      raster::values(demand)[all] <- NA
    }
  }

  cli::cli_alert_info(
    paste0(
      "{.strong {cli::col_red(nrow(as.data.frame(new_facilities)))}} ",
      "facilities added to attain coverage of ",
      "{.strong {cli::col_blue(objectiveshare * 100)}}% ",
      "within ",
      "{.strong {cli::col_green(objectiveminutes)}} ",
      "minutes threshold."
    )
  )

  list(
    facilities =
      merged_facilities |>
      magrittr::extract(-c(seq_len(nrow(facilities))), ),
    travel_time = traveltime_raster_new
  )
}
