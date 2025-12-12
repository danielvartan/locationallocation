#' Download and downscale a friction surface layer
#'
#' @description
#'
#' `friction()` retrieves a
#' [friction surface](https://en.wikipedia.org/wiki/Friction_of_distance) layer
#' from the Malaria Atlas Project ([MAP](https://malariaatlas.org/)) database
#' (Hay et al., 2006; Malaria Atlas Project, 2015, 2019) and optionally
#' downscale it to the spatial resolution of the analysis using road network
#' data from OpenStreetMap (n.d.) ([OSM](https://www.openstreetmap.org/)).
#'
#' This function requires an active internet connection.
#'
#' @template params-bb-area
#' @param mode (optional) A [`character`][base::character()] string indicating
#'   the mode of transport. Options are `"fastest"` and `"walk"` (default =
#'   `"walk"`).
#'   - For `"fastest"`: The friction layer accounts for multiple modes of
#' transport, including walking, cycling, driving, and public transport, and are
#' based on the Malaria Atlas Project (2019) *Global Travel Speed Friction
#' Surface*.
#'   - For `"walk"`: The friction layer accounts only for walking speeds and is
#'  based on the Malaria Atlas Project (2015) *Global Walking Only Friction
#'  Surface*.
#' @param dowscaling_model_type (optional) A [`character`][base::character()]
#'   string indicating the type of model used for the spatial downscaling of the
#'   friction layer. Options are `"lm"` (linear model) and `"rf"` (random
#'   forest) (default: `"lm"`).
#' @param res_output (optional) A positive
#'   [integerish][checkmate::test_integerish()] number indicating the spatial
#'   resolution of the friction raster (and of the analysis), in meters. If the
#'   resolution is less than `1000`, a spatial downscaling approach is used
#'   (default: `100`).
#' @template params-cache
#' @template params-file
#'
#' @return An [invisible][base::invisible] [`list`][base::list] with the
#'   following elements:
#'   - `friction_layer`: A [`RasterLayer`][raster::raster()] object with the
#'   friction surface layer.
#'   - `transition_matrix`: A [`TransitionLayer`][gdistance::transition()] with
#'   the transition matrix for cost-distance calculations.
#'   - `geocorrection_matrix`: A [`TransitionLayer`][gdistance::transition()]
#'   with the geocorrection matrix for accurate distance calculations.
#'
#' @family travel time functions
#' @keywords cats
#' @export
#'
#' @references
#'
#' Hay, S. I., & Snow, R. W. (2006). The Malaria Atlas Project: Developing
#' global maps of malaria risk. *PLOS Medicine*, *3*(12), e473.
#' \doi{10.1371/journal.pmed.0030473}
#'
#' Malaria Atlas Project. (2015). *Friction surface: Global travel speed
#' friction surface* (Version 201501).
#' \url{https://data.malariaatlas.org/maps}
#'
#' Malaria Atlas Project. (2019). *Friction surface: Global walking only
#' friction surface* (Version 202001).
#' \url{https://data.malariaatlas.org/maps}
#'
#' OpenStreetMap Foundation. (n.d.). *OpenStreetMap* \[Computer software\].
#' \url{https://www.openstreetmap.org}
#'
#' @examples
#' \dontrun{
#'   naples_shape |> friction()
#' }
friction <- function(
  bb_area,
  mode = "walk",
  dowscaling_model_type = "lm",
  res_output = 100,
  cache = FALSE,
  file = NULL
) {
  assert_bb_area(bb_area)
  checkmate::assert_choice(mode, choices = c("walk", "fastest"))
  checkmate::assert_choice(dowscaling_model_type, choices = c("lm", "rf"))
  checkmate::assert_count(res_output)
  checkmate::assert_flag(cache)
  checkmate::assert_string(file, null.ok = TRUE)
  assert_internet()

  handle <- curl::new_handle(timeout = 120)

  if (!is.null(file)) {
    cli::cli_progress_step("Using user-provided friction data file")

    checkmate::assert_file_exists(file)

    friction_layer <- file |> terra::rast()

    friction_layer <-
      friction_layer |>
      terra::crop(
        bb_area |>
          sf::st_transform(sf::st_crs(friction_layer)) |>
          terra::ext()
      ) |>
      raster::raster()
  } else {
    if (mode == "fastest") {
      dataset <- "Accessibility__201501_Global_Travel_Speed_Friction_Surface"
    } else if (mode == "walk") {
      dataset <- "Accessibility__202001_Global_Walking_Only_Friction_Surface"
    }

    if (isTRUE(cache)) {
      friction_layer <- get_cache_data(dataset, bb_area)
    } else {
      cli::cli_progress_step(
        "Downloading friction data from the Malaria Atlas Project"
      )

      friction_layer <-
        dataset |>
        malariaAtlas::getRaster(
          extent = matrix(sf::st_bbox(bb_area), ncol = 2),
        ) |>
        raster::raster()
    }
  }

  if (res_output < 1000) {
    cli::cli_progress_step("Downloading data from OpenStreetMap")

    x <-
      bb_area |>
      sf::st_bbox() |>
      osmdata::opq() |>
      osmdata::add_osm_feature(key = "highway") |>
      # fmt: skip
      osmdata::osmdata_sf () # Do not change! #nolint

    r <-
      bb_area |>
      sf::st_transform(crs = 3395) |>
      raster::extent() |>
      raster::raster(res = res_output, crs = sf::st_crs(3395)$proj4string)

    streets <-
      x$osm_lines |>
      sf::st_transform(crs = 3395) |>
      sf::st_buffer(res_output) |>
      terra::vect() |>
      terra::rasterize(
        r |> terra::rast(),
        background = NA,
        fun = "sum"
      ) |>
      raster::raster()

    d <-
      streets |>
      terra::rast() |>
      terra::project(y = sf::st_crs(4326)$proj4string)

    terra::values(d) <- ifelse(
      terra::values(d) < 0,
      0,
      terra::values(d)
    )

    terra::values(d) <- ifelse(
      is.na(terra::values(d)),
      0,
      terra::values(d)
    )

    d <-
      d |>
      raster::raster() |>
      raster::crop(friction_layer)

    d_2 <- d

    d <- raster::stack(d, d_2)

    names(d) <- paste0("l", 1:raster::nlayers(d))

    min_iter <- 2
    max_iter <- 10
    p_train <- 0.5

    if (length(unique(raster::values(friction_layer))) == 1) {
      raster::values(friction_layer) <-
        stats::runif(
          min = unique(raster::values(friction_layer)) * 0.9,
          max = unique(raster::values(friction_layer)) * 1.1,
          n = length(raster::values(friction_layer))
        )
    }

    res_rf <- dissever::dissever(
      coarse = friction_layer, # stack of fine resolution covariates
      fine = d, # coarse resolution raster
      method = dowscaling_model_type, # regression method used for disseveration
      p = p_train, # proportion of pixels sampled for training regression model
      min_iter = min_iter, # minimum iterations
      max_iter = max_iter, # maximum iterations
      verbose = TRUE
    )

    raster::values(res_rf$map) <- ifelse(
      raster::values(res_rf$map) <= 0,
      min(raster::values(friction_layer), na.rm = TRUE),
      raster::values(res_rf$map)
    )

    friction_layer <- res_rf$map
  } else {
    friction_layer <- friction_layer
  }

  cli::cli_progress_step("Computing transition matrix and geocorrection")

  transition_matrix <-
    friction_layer |>
    # RAM intensive, can be very slow for large areas.
    gdistance::transition(\(x) 1 / mean(x), 16)

  geocorrection_matrix <- gdistance::geoCorrection(transition_matrix)

  list(
    friction_layer = friction_layer,
    transition_matrix = transition_matrix,
    geocorrection_matrix = geocorrection_matrix
  ) |>
    invisible()
}
