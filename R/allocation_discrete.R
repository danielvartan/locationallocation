#' Compute the maximal coverage location-allocation for discrete problems
#'
#' @description
#'
#' `allocation_discrete()` allocates facilities in a discrete location problem.
#' It uses the accumulated cost algorithm to identify optimal facility locations
#' based on the share of demand to be covered, given a user-defined set
#' of candidate locations and a maximum number of allocable facilities.
#'
#' If a `objectiveshare` parameter is specified, the algorithm identifies the
#' best set of size of up to `n_fac` facilities to achieve the targeted coverage
#' share. The problem is solved using a statistical heuristic approach that
#' generates samples of the candidate locations (on top of the existing
#' locations) and selects the facilities in the one that minimizes the objective
#' function.
#'
#' See [`allocation()`][allocation()] for continuous location-allocation
#' problems.
#'
#' @param candidate A [`sf`][sf::st_as_sf()] object with the candidate
#'   locations for the new facilities.
#' @param n_fac (optional) A positive [integerish][checkmate::test_integerish()]
#'   number indicating the maximum number of facilities that can be allocated
#'   (default: `Inf`).
#' @param n_samples (optional) A positive
#'   [integerish][checkmate::test_integerish()] number indicating the number of
#'   samples to generate in the heuristic approach for identifying the best set
#'   of facilities to be allocated (default: `1000`).
#' @param par (optional) A [`logical`][base::logical()] flag indicating whether
#'   to run the function in [parallel][parallel::parLapply()] or not
#'   (default: `FALSE`).
#'
#' @return A [`list`][base::list] with the following elements:
#'   - `objective_minutes`: The value of the `objectiveminutes` parameter used.
#'   - `objective_share`: The value of the `objectiveshare` parameter used.
#'   - `facilities`: A [`sf`][sf::sf()] object with the newly allocated
#'   facilities.
#'   - `travel_time`: A [`raster`][raster::raster()] RasterLayer object
#'   representing the travel time map with the newly allocated facilities.
#'   - `unmet_demand`: A [`numeric`][base::numeric()] value indicating the share
#'   of demand that remains unmet after allocating the new facilities.
#'
#' @template params-objectiveshare-b
#' @inheritParams allocation
#' @family location-allocation functions
#' @keywords location-allocation
#' @export
#'
#' @examples
#' \dontrun{
#'   library(dplyr)
#'   library(sf)
#'
#'   allocation_data <-
#'     naples_population |>
#'     allocation_discrete(
#'       traveltime = traveltime,
#'       bb_area = naples_shape,
#'       facilities = naples_fountains,
#'       candidate = naples_shape |> st_sample(20),
#'       n_fac = 2,
#'       weights = naples_hot_days,
#'       objectiveminutes = 15,
#'       objectiveshare = 0.9
#'     )
#'
#'   allocation_data |> glimpse()
#'
#'   allocation_data |> allocation_plot(naples_shape)
#' }
allocation_discrete <- function(
  demand,
  bb_area,
  candidate,
  facilities = NULL,
  n_fac = Inf,
  n_samples = 1000,
  traveltime = NULL,
  mode = "walk",
  dowscaling_model_type = "lm",
  res_output = 100,
  weights = NULL,
  objectiveminutes = 15,
  objectiveshare = NULL,
  approach = "norm",
  exp_demand = 1,
  exp_weights = 1,
  par = FALSE
) {
  checkmate::assert_class(demand, "RasterLayer")
  assert_bb_area(bb_area)
  checkmate::assert_multi_class(candidate, c("sf", "sfc"))
  assert_facilities(facilities, null_ok = TRUE)
  checkmate::assert_count(n_fac, positive = TRUE)
  checkmate::assert_number(n_fac, lower = 1)
  checkmate::assert_count(n_samples, positive = TRUE)
  assert_traveltime(traveltime, null_ok = TRUE)
  checkmate::assert_choice(mode, choices = c("walk", "fastest"))
  checkmate::assert_choice(dowscaling_model_type, choices = c("lm", "rf"))
  checkmate::assert_count(res_output, positive = TRUE)
  checkmate::assert_class(weights, "RasterLayer", null.ok = TRUE)
  checkmate::assert_count(objectiveminutes, positive = TRUE)
  checkmate::assert_number(objectiveshare, lower = 0, upper = 1, null.ok = TRUE)
  checkmate::assert_choice(approach, choices = c("norm", "absweights"))
  checkmate::assert_number(exp_demand, lower = 0)
  checkmate::assert_number(exp_weights, lower = 0)
  checkmate::assert_flag(par)

  sf::sf_use_s2(TRUE)

  if (is.null(traveltime)) {
    if (!is.null(facilities)) {
      cli::cli_alert_info(
        paste0(
          "Travel time layer not detected. ",
          "Running {.strong {cli::col_red('traveltime()')}} function first."
        )
      )

      traveltime <-
        facilities |>
        traveltime(
          bb_area = bb_area,
          mode = mode,
          dowscaling_model_type = dowscaling_model_type,
          res_output = res_output
        )
    }
  } else {
    traveltime_raster_outer <- traveltime
  }

  assert_minimal_coverage(
    traveltime = traveltime,
    demand = demand,
    objectiveminutes = objectiveminutes,
    threshold = objectiveshare,
    null_ok = TRUE
  )

  if (is.null(facilities)) {
    facilities <-
      data.frame(x = 0, y = 0) |>
      sf::st_as_sf(coords = c("x", "y"), crs = 4326) |>
      magrittr::extract(-1, )
  }

  demand <- demand |> mask_raster_to_polygon(bb_area)

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

  if (!exists("traveltime_raster_outer")) {
    traveltime <-
      demand |>
      raster::`values<-`(objectiveminutes + 1) |>
      mask_raster_to_polygon(bb_area)

    friction <-
      bb_area |>
      friction(
        mode = mode,
        dowscaling_model_type = dowscaling_model_type,
        res_output = res_output
      )

    traveltime_raster_outer <- list(traveltime, friction)
  }

  totalpopconstant <- demand |> raster::cellStats("sum", na.rm = TRUE)

  traveltime_raster_outer[[1]] <-
    traveltime_raster_outer[[1]] |>
    raster::`crs<-`(
      value = "+proj=longlat +datum=WGS84 +no_defs +type=crs"
    ) |>
    raster::projectRaster(demand) |>
    raster::`crs<-`(
      value = "+proj=longlat +datum=WGS84 +no_defs +type=crs"
    )

  demand <-
    demand |>
    raster::overlay(
      traveltime_raster_outer[[1]],
      fun = function(x, y) {
        x[y <= objectiveminutes] <- NA

        x
      }
    )

  demand_raster_bk <- demand

  if (is.null(objectiveshare)) {
    samples <-
      n_samples |>
      replicate(
        candidate |>
          sf::st_as_sf() |>
          nrow() |>
          seq_len() |>
          sample(n_fac,  replace = FALSE),
      )

    runner <- function(i) {
      demand_rasterio <- demand_raster_bk

      points <-
        facilities |>
        sf::st_coordinates() |>
        rbind(
          candidate |>
            sf::st_as_sf() |>
            sf::st_coordinates() |>
            magrittr::extract(samples[, i], )
        )

      points <- data.frame(X = points[, 1], Y = points[, 2])
      n_points <- points |> dim() |> magrittr::extract(1)
      xy_matrix <- points_to_matrix(points, n_points)

      traveltime_raster_new <-
        traveltime_raster_outer[[2]][[3]] |>
        gdistance::accCost(xy_matrix) |>
        raster::crop(raster::extent(demand_rasterio)) |>
        raster::`crs<-`(
          value = "+proj=longlat +datum=WGS84 +no_defs +type=crs"
        ) |>
        raster::projectRaster(demand_rasterio) |>
        raster::`crs<-`(
          value = "+proj=longlat +datum=WGS84 +no_defs +type=crs"
        ) |>
        mask_raster_to_polygon(bb_area)

      demand_rasterio <-
        demand_rasterio |>
        raster::overlay(
          traveltime_raster_new,
          fun = function(x, y) {
            x[y <= objectiveminutes] <- NA

            x
          }
        )

      demand_rasterio |>
        raster::cellStats("sum", na.rm = TRUE) |>
        magrittr::divide_by(totalpopconstant)
    }

    if (par == TRUE) {
      if (.Platform$OS.type == "unix") {
        outer <-
          n_samples |>
          seq_len() |>
          parallel::mclapply(
            runner,
            mc.cores = parallel::detectCores() - 1
          )
      } else {
        # Use `parLapply` for Windows.
        cl <- parallel::makeCluster(parallel::detectCores() - 1)

        cl |>
          parallel::clusterExport(
            varlist = ls(envir = .GlobalEnv)
          )

        cl |>
          parallel::clusterExport(
            varlist = ls(envir = environment()),
            envir = environment()
          )

        # Get all currently loaded packages (names only).
        # Load each package on every cluster worker.
        cl |>
          parallel::clusterEvalQ(
            {
              # Loop through the package names and load them.
              packages <- .packages()

              for (i in packages) {
                suppressMessages(require(i, character.only = TRUE))
              }
            }
          )

        outer <-
          cl |>
          parallel::parLapply(
            seq_len(n_samples),
            runner
          )

        parallel::stopCluster(cl)
        gc()
      }
    } else {
      outer <-
        n_samples |>
        seq_len() |>
        cli::cli_progress_along("Iterating") |>
        lapply(runner)
    }

    demand <- demand_raster_bk

    points <-
      facilities |>
      sf::st_coordinates() |>
      rbind(
        candidate |>
          sf::st_as_sf() |>
          sf::st_coordinates() |>
          magrittr::extract(
            samples[, which.min(unlist(outer))],
          )
      )

    points <- data.frame(X = points[, 1], Y = points[, 2])
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

    list(
      objective_minutes = objectiveminutes,
      objective_share = objectiveshare,
      facilities =
        candidate |>
        sf::st_as_sf() |>
        magrittr::extract(
          samples |>
            magrittr::extract(,
              outer |>
                unlist() |>
                which.min()
            ), # Do not remove the comma!
        ),
      travel_time = traveltime_raster_new,
      unmet_demand = k
    )
  } else {
    kiters <- seq(2, n_fac)
    kiter <- kiters[1] - 1

    repeat {
      kiter <- kiter + 1

      cli::cli_alert_info(
        "Iteration with {.strong {cli::col_yellow(kiter)}} facilities."
      )

      samples <-
        n_samples |>
        replicate(
          candidate |>
            sf::st_as_sf() |>
            nrow() |>
            seq_len() |>
            sample(kiter,  replace = FALSE),
        )

      runner <- function(i) {
        demand_rasterio <- demand_raster_bk

        points <-
          facilities |>
          sf::st_coordinates() |>
          rbind(
            candidate |>
              sf::st_as_sf() |>
              sf::st_coordinates() |>
              magrittr::extract(samples[, i], )
          )

        points <- data.frame(X = points[, 1], Y = points[, 2])
        n_points <- points |> dim() |> magrittr::extract(1)
        xy_matrix <- points_to_matrix(points, n_points)

        traveltime_raster_new <-
          traveltime_raster_outer[[2]][[3]] |>
          gdistance::accCost(xy_matrix) |>
          raster::crop(raster::extent(demand_rasterio)) |>
          raster::`crs<-`(
            value = "+proj=longlat +datum=WGS84 +no_defs +type=crs"
          ) |>
          raster::projectRaster(demand_rasterio) |>
          raster::`crs<-`(
            value = "+proj=longlat +datum=WGS84 +no_defs +type=crs"
          ) |>
          mask_raster_to_polygon(bb_area)

        demand_rasterio <-
          demand_rasterio |>
          raster::overlay(
            traveltime_raster_new,
            fun = function(x, y) {
              x[y <= objectiveminutes] <- NA

              x
            }
          )

        demand_rasterio |>
          raster::cellStats("sum", na.rm = TRUE) |>
          magrittr::divide_by(totalpopconstant)
      }

      if (par == TRUE) {
        if (.Platform$OS.type == "unix") {
          outer <-
            n_samples |>
            seq_len() |>
            parallel::mclapply(
              runner,
              mc.cores = parallel::detectCores() - 1
            )
        } else {
          # Use `parLapply` for Windows.
          cl <- parallel::makeCluster(parallel::detectCores() - 1)

          cl |>
            parallel::clusterExport(
              varlist = ls(envir = .GlobalEnv)
            )

          cl |>
            parallel::clusterExport(
              varlist = ls(envir = environment()),
              envir = environment()
            )

          # Get all currently loaded packages (names only).
          # Load each package on every cluster worker.
          cl |>
            parallel::clusterEvalQ(
              {
                # Loop through the package names and load them.
                packages <- .packages()

                for (i in packages) {
                  suppressMessages(require(i, character.only = TRUE))
                }
              }
            )

          outer <-
            cl |>
            parallel::parLapply(
              seq_len(n_samples),
              runner
            )

          parallel::stopCluster(cl)
          gc()
        }
      } else {
        outer <-
          n_samples |>
          seq_len() |>
          cli::cli_progress_along("Iterating") |>
          lapply(runner)
      }

      demand <- demand_raster_bk

      points <-
        facilities |>
        sf::st_coordinates() |>
        rbind(
          candidate |>
            sf::st_as_sf() |>
            sf::st_coordinates() |>
            magrittr::extract(
              samples[, which.min(unlist(outer))],
            )
        )

      points <- data.frame(X = points[, 1], Y = points[, 2])
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

      cli::cli_alert_info(
        paste0(
          "Coverage share attained: ",
          "{.strong {cli::col_red(round((1 - k) * 100, 5))}}%."
        )
      )

      if (k < (1 - objectiveshare) || kiter == n_fac) break
    }

    if ((1 - k) >= objectiveshare) {
      cli::cli_alert_info(
        paste0(
          "Target coverage share of ",
          "{.strong {cli::col_blue((objectiveshare * 100))}}% ",
          "attained with ",
          "{.strong {cli::col_red(kiter)}} facilities."
        ),
        wrap = TRUE
      )
    } else {
      cli::cli_alert_warning(
        paste0(
          "The target coverage share could not be attained with the ",
          "maximum number of allocable facilities targeted by the ",
          "{.strong {cli::col_red('n_fac')}} parameter."
        ),
        wrap = TRUE
      )
    }

    list(
      objective_minutes = objectiveminutes,
      objective_share = objectiveshare,
      facilities =
        candidate |>
        sf::st_as_sf() |>
        magrittr::extract(
          samples[, which.min(unlist(outer))],
        ),
      traveltime = traveltime_raster_new,
      unmet_demand = k
    )
  }
}
