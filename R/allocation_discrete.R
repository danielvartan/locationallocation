#' Compute the maximal coverage location-allocation for discrete problems
#'
#' `allocation_discrete()` is used to allocate facilities in a discrete location
#' problem. It uses the accumulated cost algorithm to find the optimal location
#' for the facilities based on a user-defined set of locations, objective travel
#' time, and (maximum) number of allocable facilities.
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
#'   - A [`sf`][sf::sf()] object with the newly allocated facilities.
#'   - A [`raster`][raster::raster()] RasterLayer object representing the travel
#'   time map with the newly allocated facilities.
#'   - A [`numeric`][base::numeric()] value indicating the share of demand
#'   covered within the objective travel time after the allocation.
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
#'   allocation_data |> allocation_plot_discrete(naples_shape)
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

  if (is.null(objectiveshare)) {
    if (is.null(traveltime) && !is.null(facilities)) {
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
    } else if (is.null(facilities)) {
      out <-
        bb_area |>
        friction(
          mode = mode,
          dowscaling_model_type = dowscaling_model_type,
          res_output = res_output
        )
    }

    facilities <- ifelse(
      is.null(facilities),
      data.frame(x = 0,y = 0) |>
        sf::st_as_sf(coords = c("x", "y"), crs = 4326) |>
        magrittr::extract(-1,),
      facilities
    )

    demand <- mask_raster_to_polygon(demand, bb_area)
    traveltime_raster_outer <- traveltime

    normalize_raster <- function(r) {
      r_min <- raster::cellStats(r, stat='min')
      r_max <- raster::cellStats(r, stat='max')
      (r - r_min) / (r_max - r_min)
    }

    if(!is.null(weights) & approach=="norm"){ # optimize based on risk (exposure*hazard), and not on exposure only
      weights <- mask_raster_to_polygon(weights, bb_area)
      demand <- (normalize_raster(demand)^exp_demand)*(normalize_raster(weights)^exp_weights)

    } else if(!is.null(weights) & approach=="absweights"){ # optimize based on risk (exposure*hazard), and not on exposure only
      weights <- mask_raster_to_polygon(weights, bb_area)
      demand <- (normalize_raster(demand)^exp_demand)*(weights^exp_weights)

    } else if(is.null(weights) ) {

      demand <- demand^exp_demand
    }

    totalpopconstant = raster::cellStats(demand, 'sum', na.rm = TRUE)

    if(!exists("traveltime_raster_outer")){
      traveltime <- demand
      raster::values(traveltime) <- objectiveminutes + 1
      traveltime <- mask_raster_to_polygon(traveltime, bb_area)

      traveltime_raster_outer <- list(traveltime, out)
    }

    raster::crs(traveltime_raster_outer[[1]]) <- "+proj=longlat +datum=WGS84 +no_defs +type=crs"
    traveltime_raster_outer[[1]] <- raster::projectRaster(traveltime_raster_outer[[1]], demand)
    raster::crs(traveltime_raster_outer[[1]]) <- "+proj=longlat +datum=WGS84 +no_defs +type=crs"

    demand <-  raster::overlay(demand, traveltime_raster_outer[[1]], fun = function(x, y) {
      x[y<=objectiveminutes] <- NA
      return(x)
    })

    demand_raster_bk <- demand

    samples <- replicate(n_samples, sample(1:nrow(sf::st_as_sf(candidate)), n_fac, replace = F))

    runner <- function(i){
      demand_rasterio <- demand_raster_bk
      points <- rbind(sf::st_coordinates(facilities), sf::st_coordinates(sf::st_as_sf(candidate))[samples[,i],])
      points <- data.frame(x=points[,1], y=points[,2])

      # Fetch the number of points
      temp <- dim(points)
      n.points <- temp[1]

      # Convert the points into a matrix
      xy.data.frame <- data.frame()
      xy.data.frame[1:n.points,1] <- points[,1]
      xy.data.frame[1:n.points,2] <- points[,2]
      xy.matrix <- as.matrix(xy.data.frame)

      # Run the accumulated cost algorithm to make the final output map. This can be quite slow (potentially hours).
      traveltime_raster_new <- gdistance::accCost(traveltime_raster_outer[[2]][[3]], xy.matrix)

      traveltime_raster_new = raster::crop(traveltime_raster_new, raster::extent(demand_rasterio))

      raster::crs(traveltime_raster_new) <- "+proj=longlat +datum=WGS84 +no_defs +type=crs"

      traveltime_raster_new <- raster::projectRaster(traveltime_raster_new, demand_rasterio)

      raster::crs(traveltime_raster_new) <- "+proj=longlat +datum=WGS84 +no_defs +type=crs"

      traveltime_raster_new <- mask_raster_to_polygon(traveltime_raster_new, bb_area)

      demand_rasterio <- raster::overlay(demand_rasterio, traveltime_raster_new, fun = function(x, y) {
        x[y<=objectiveminutes] <- NA
        return(x)
      })

      raster::cellStats(demand_rasterio, 'sum', na.rm = TRUE)/totalpopconstant
    }

    if (par == TRUE) {
      # Determine OS
      if (.Platform$OS.type == "unix") {
        # Use mclapply for Unix-based systems
        outer <- parallel::mclapply(1:n_samples, runner, mc.cores = parallel::detectCores() - 1)
      } else {
        # Use parLapply for Windows
        cl <- parallel::makeCluster(parallel::detectCores() - 1)
        parallel::clusterExport(cl, varlist = ls(envir = .GlobalEnv))
        parallel::clusterExport(cl, varlist = ls(envir = environment()), envir = environment())
        # Get all currently loaded packages (names only)
        # Load each package on every cluster worker
        parallel::clusterEvalQ(cl, {
          # Loop through the package names and load them
          packages <- .packages()
          for (p in packages) {
            suppressMessages(require(p, character.only = TRUE))
          }
        })
        outer <- parallel::parLapply(cl, 1:n_samples, runner)
        parallel::stopCluster(cl)  # Clean up cluster
        gc()
      }
    } else {
      # Fallback to standard lapply
      outer <- lapply(1:n_samples, runner)
    }

    demand <- demand_raster_bk
    points <- rbind(sf::st_coordinates(facilities), sf::st_coordinates(sf::st_as_sf(candidate))[samples[,  which.min(unlist(outer))],])
    points <- data.frame(x=points[,1], y=points[,2])

    # Fetch the number of points
    temp <- dim(points)
    n.points <- temp[1]

    # Convert the points into a matrix
    xy.data.frame <- data.frame()
    xy.data.frame[1:n.points,1] <- points[,1]
    xy.data.frame[1:n.points,2] <- points[,2]
    xy.matrix <- as.matrix(xy.data.frame)

    # Run the accumulated cost algorithm to make the final output map. This can be quite slow (potentially hours).
    traveltime_raster_new <- gdistance::accCost(traveltime_raster_outer[[2]][[3]], xy.matrix)

    traveltime_raster_new = raster::crop(traveltime_raster_new, raster::extent(demand))

    raster::crs(traveltime_raster_new) <- "+proj=longlat +datum=WGS84 +no_defs +type=crs"

    traveltime_raster_new <- raster::projectRaster(traveltime_raster_new, demand)

    raster::crs(traveltime_raster_new) <- "+proj=longlat +datum=WGS84 +no_defs +type=crs"

    traveltime_raster_new_min <- mask_raster_to_polygon(traveltime_raster_new, bb_area)

    demand <- raster::overlay(demand, traveltime_raster_new_min, fun = function(x, y) {
      x[y<=objectiveminutes] <- NA
      return(x)
    })

    k = raster::cellStats(demand, 'sum', na.rm = TRUE)/totalpopconstant
  } else if (is.numeric(objectiveshare)) {
    if (is.null(traveltime) & !is.null(facilities)) {
      print("Travel time layer not detected. Running traveltime function first.")
      traveltime_raster_outer <- traveltime(facilities=facilities, bb_area=bb_area, dowscaling_model_type=dowscaling_model_type, mode=mode, res_output=res_output)
    } else if (is.null(facilities)) {
      out <- friction(bb_area=bb_area, mode=mode, res_output=res_output, dowscaling_model_type=dowscaling_model_type)
    } else if (!is.null(traveltime)) {
      traveltime_raster_outer <- traveltime
    }

    facilities <- ifelse(
      is.null(facilities),
      sf::st_as_sf(
        data.frame(x = 0,y = 0),
        coords = c("x", "y"),
        crs = 4326
      )[-1,],
      facilities
    )

    demand <- mask_raster_to_polygon(demand, bb_area)

    ###

    normalize_raster <- function(r) {
      r_min <- raster::cellStats(r, stat='min')
      r_max <- raster::cellStats(r, stat='max')
      (r - r_min) / (r_max - r_min)
    }

    # optimize based on risk (exposure*hazard), and not on exposure only
    if (!is.null(weights) & approach=="norm") {
      weights <- mask_raster_to_polygon(weights, bb_area)
      demand <- (
        normalize_raster(demand)^exp_demand) *
        (normalize_raster(weights)^exp_weights)
    # optimize based on risk (exposure*hazard), and not on exposure only
    } else if (!is.null(weights) & approach=="absweights") {
      weights <- mask_raster_to_polygon(weights, bb_area)
      demand <-
        (normalize_raster(demand)^exp_demand) * (weights^exp_weights)
    } else if(is.null(weights) ) {
      demand <- demand^exp_demand
    }

    totalpopconstant = raster::cellStats(demand, 'sum', na.rm = TRUE)

    if (!exists("traveltime_raster_outer")) {
      traveltime <- demand
      raster::values(traveltime) <- objectiveminutes + 1
      traveltime <- mask_raster_to_polygon(traveltime, bb_area)
      traveltime_raster_outer <- list(traveltime, out)
    }

    raster::crs(traveltime_raster_outer[[1]]) <-
      "+proj=longlat +datum=WGS84 +no_defs +type=crs"

    traveltime_raster_outer[[1]] <- raster::projectRaster(
      traveltime_raster_outer[[1]],
      demand
    )

    raster::crs(traveltime_raster_outer[[1]]) <-
      "+proj=longlat +datum=WGS84 +no_defs +type=crs"

    demand <-  raster::overlay(
      demand,
      traveltime_raster_outer[[1]],
      fun = function(x, y) {
        x[y<=objectiveminutes] <- NA
        return(x)
      }
    )

    demand_raster_bk <- demand

    kiters = 2:n_fac
    kiter = kiters[1] - 1

    repeat {
      kiter = kiter + 1

      print(paste0("Iteration with ", kiter, " facilities."))

      samples <- replicate(
        n_samples,
        sample(1:nrow(sf::st_as_sf(candidate)), kiter, replace = FALSE)
      )

      runner <- function(i) {
        demand_rasterio <- demand_raster_bk

        points = rbind(sf::st_coordinates(facilities), sf::st_coordinates(sf::st_as_sf(candidate))[samples[,i],])
        points <- data.frame(x=points[,1], y=points[,2])

        # Fetch the number of points
        temp <- dim(points)
        n.points <- temp[1]

        # Convert the points into a matrix
        xy.data.frame <- data.frame()
        xy.data.frame[1:n.points,1] <- points[,1]
        xy.data.frame[1:n.points,2] <- points[,2]
        xy.matrix <- as.matrix(xy.data.frame)

        # Run the accumulated cost algorithm to make the final output map. This can be quite slow (potentially hours).
        traveltime_raster_new <-
          traveltime_raster_outer[[2]][[3]] |>
          gdistance::accCost(xy.matrix) |>
          raster::crop(raster::extent(demand_rasterio))

        raster::crs(traveltime_raster_new) <-
          "+proj=longlat +datum=WGS84 +no_defs +type=crs"

        traveltime_raster_new <-
          traveltime_raster_new |>
          raster::projectRaster(demand_rasterio)

        raster::crs(traveltime_raster_new) <-
          "+proj=longlat +datum=WGS84 +no_defs +type=crs"

        traveltime_raster_new <-
          traveltime_raster_new |>
          mask_raster_to_polygon(bb_area)

        demand_rasterio <-
          demand_rasterio |>
          raster::overlay(
            traveltime_raster_new,
            fun = function(x, y) {
              x[y<=objectiveminutes] <- NA
              return(x)
            }
        )

        raster::cellStats(demand_rasterio, 'sum', na.rm = TRUE) |>
          magrittr::divide_by(totalpopconstant)
      }

      if (par == TRUE) {
        # Determine OS
        if (.Platform$OS.type == "unix") {
          # Use mclapply for Unix-based systems
          outer <- parallel::mclapply(1:n_samples, runner, mc.cores = parallel::detectCores() - 1)
        } else {
          # Use parLapply for Windows
          cl <- parallel::makeCluster(parallel::detectCores() - 1)
          parallel::clusterExport(cl, varlist = ls(envir = .GlobalEnv))
          parallel::clusterExport(cl, varlist = ls(envir = environment()), envir = environment())
          # Get all currently loaded packages (names only)
          # Load each package on every cluster worker
          parallel::clusterEvalQ(cl, {
            # Loop through the package names and load them
            packages <- .packages()
            for (p in packages) {
              suppressMessages(require(p, character.only = TRUE))
            }
          })
          outer <- parallel::parLapply(cl, 1:n_samples, runner)
          parallel::stopCluster(cl)  # Clean up cluster
          gc()
        }
      } else {
        # Fallback to standard lapply
        outer <- lapply(1:n_samples, runner)
      }

      demand <- demand_raster_bk

      points <- rbind(
        sf::st_coordinates(facilities),
        sf::st_coordinates(
          sf::st_as_sf(candidate))[samples[, which.min(unlist(outer))],]
        )

      points <- data.frame(x = points[,1], y = points[,2])

      # Fetch the number of points
      temp <- dim(points)
      n.points <- temp[1]

      # Convert the points into a matrix
      xy.data.frame <- data.frame()
      xy.data.frame[1:n.points,1] <- points[,1]
      xy.data.frame[1:n.points,2] <- points[,2]
      xy.matrix <- as.matrix(xy.data.frame)

      # Run the accumulated cost algorithm to make the final output map. This can be quite slow (potentially hours).
      traveltime_raster_new <-
        traveltime_raster_outer[[2]][[3]] |>
        gdistance::accCost(xy.matrix) |>
        raster::crop(raster::extent(demand))

      raster::crs(traveltime_raster_new) <-
        "+proj=longlat +datum=WGS84 +no_defs +type=crs"

      traveltime_raster_new <-
        traveltime_raster_new |>
        raster::projectRaster(demand)

      raster::crs(traveltime_raster_new) <-
        "+proj=longlat +datum=WGS84 +no_defs +type=crs"

      traveltime_raster_new_min <-
        traveltime_raster_new |>
        mask_raster_to_polygon(bb_area)

      demand <-
        demand |>
        raster::overlay(
          traveltime_raster_new_min,
          fun = function(x, y) {
            x[y<=objectiveminutes] <- NA
            return(x)
          }
      )

      k <-
        raster::cellStats(demand, 'sum', na.rm = TRUE) |>
        magrittr::divide_by(totalpopconstant)

      print(paste0("Coverage share attained: ", 1-k))

      if (kiter == n_fac) {
        cli::cli_alert_warning(
          paste0(
            "The target coverage share could not be attained with the ",
            "maximum number of allocable facilities targeted by the ",
            "{.code n_fac} parameter."
          ),
          wrap = TRUE
        )
      }

      if (k < (1-objectiveshare) | kiter==n_fac) {
        break
      }
    }

    cli::cli_alert_info(
      paste0(
        "Target coverage share of ",
        "{.strong {objectiveshare}} attained with ",
        "{.strong {kiter} facilities"
      )
    )

    return(
      list(
        sf::st_as_sf(candidate)[samples[,which.min(unlist(outer))],],
        traveltime_raster_new_min,
        k
      )
    )
  }

  list(
    sf::st_as_sf(candidate)[samples[,which.min(unlist(outer))],],
    traveltime_raster_new_min,
    k
  )
}
