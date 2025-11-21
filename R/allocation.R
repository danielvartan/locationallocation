#' Compute the maximal coverage location-allocation for continuous problems
#'
#' `allocation()` is used to allocate facilities in a continuous location
#' problem. It uses the accumulated cost algorithm to find the optimal location
#' for the facilities based on the demand, travel time, and weights for the
#' demand, and target travel time threshold and share of the demand to be
#' covered.
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
#'   - A [`sf`][sf::sf()] object with the newly allocated facilities.
#'   - A [`raster`][raster::raster()] RasterLayer object representing the travel
#'   time map with the newly allocated facilities.
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

  traveltime = raster::projectRaster(traveltime, demand)

  raster::crs(traveltime) <- "+proj=longlat +datum=WGS84 +no_defs +type=crs"

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

  }  else if(is.null(weights) ) {

    demand <- demand^exp_demand
  }

  totalpopconstant = raster::cellStats(demand, 'sum', na.rm = TRUE)

  demand <-  raster::overlay(demand, traveltime, fun = function(x, y) {
    x[y<=objectiveminutes] <- NA
    return(x)
  })

  iter <- 1
  k_save <- c(1)

  repeat {
    iter <- iter + 1

    if (heur == "kd") {
      all <- spatialEco::sp.kde(
        x = sf::st_as_sf(raster::rasterToPoints(demand, spatial=TRUE)),
        y = all$layer,
        bw = 0.0083333,
        ref = terra::rast(demand),
        res=0.0008333333,
        standardize = TRUE,
        scale.factor = 10000
      )
    } else if (heur == "max") {
      all = raster::which.max(demand)
    }

    pos = as.data.frame(raster::xyFromCell(demand, all))

    new_facilities <- if(exists("new_facilities")){
      rbind(new_facilities, sf::st_as_sf(pos, coords = c("x", "y"), crs = 4326))
    } else {
      sf::st_as_sf(pos, coords = c("x", "y"), crs = 4326)
    }

    merged_facilities <- dplyr::bind_rows(as.data.frame(sf::st_geometry(facilities)), as.data.frame(new_facilities))

    points = as.data.frame(sf::st_coordinates(merged_facilities$geometry))

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

    traveltime_raster_new <- mask_raster_to_polygon(traveltime_raster_new, bb_area)

    demand <- raster::overlay(demand, traveltime_raster_new, fun = function(x, y) {
      x[y<=objectiveminutes] <- NA
      return(x)
    })

    k = raster::cellStats(demand, 'sum', na.rm = TRUE)/totalpopconstant

    k_save[iter] = k

    print(paste0("Fraction of unmet demand:  ", k*100, " %"))
    # exit if the condition is met
    if (k < (1 - objectiveshare)) {
      break
    } else if (k == k_save[iter-1] ) {
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
    merged_facilities[-c(1:nrow(facilities)),],
    traveltime_raster_new
  )
}
