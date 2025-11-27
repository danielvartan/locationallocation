assert_traveltime <- function(x, null_ok = FALSE) {
  checkmate::assert_flag(null_ok)

  if (is.null(x) && isTRUE(null_ok)) {
    TRUE
  } else {
    name <- deparse(substitute(x)) #nolint

    if (
      !checkmate::test_list(x) ||
        length(x) != 2 ||
        !checkmate::test_class(x[[1]], "RasterLayer") ||
        !checkmate::test_class(x[[2]], "list") ||
        length(x[[2]]) != 3
    ) {
      cli::cli_abort(
        paste0(
          "{.strong {cli::col_red(name)}} ",
          "must be an output object from the ",
          "{.strong {cli::col_blue('traveltime()')}} ",
          "function."
        )
      )
    } else {
      TRUE
    }
  }
}

assert_bb_area <- function(x, null_ok = FALSE) {
  checkmate::assert_flag(null_ok)

  if (is.null(x) && isTRUE(null_ok)) {
    TRUE
  } else {
    name <- deparse(substitute(x)) #nolint

    if (!inherits(x, "sf") || nrow(x) == 0) {
      cli::cli_abort(
        paste0(
          "{.strong {cli::col_red(name)}} ",
          "must be a non-empty {.strong sf} polygon."
        )
      )
    } else {
      TRUE
    }
  }
}

assert_facilities <- function(x, null_ok = FALSE) {
  checkmate::assert_flag(null_ok)

  if (is.null(x) && isTRUE(null_ok)) {
    TRUE
  } else {
    name <- deparse(substitute(x)) #nolint

    if (!inherits(x, "sf") || nrow(x) == 0) {
      cli::cli_abort(
        paste0(
          "{.strong {cli::col_red(name)}} ",
          "must be a non-empty {.strong sf} point geometry data frame."
        )
      )
    } else {
      TRUE
    }
  }
}

assert_allocation <- function(x, null_ok = FALSE) {
  checkmate::assert_flag(null_ok)

  if (is.null(x) && isTRUE(null_ok)) {
    TRUE
  } else {
    name <- deparse(substitute(x)) #nolint

    if (
      !inherits(x, "list") ||
        length(x) != 2 ||
        !inherits(x[[1]], "sfc") ||
        !inherits(x[[2]], "RasterLayer")
    ) {
      cli::cli_abort(
        paste0(
          "{.strong {cli::col_red(name)}} ",
          "must be an output object from the ",
          "{.strong allocation()} function."
        )
      )
    } else {
      TRUE
    }
  }
}

assert_allocation_discrete <- function(x, null_ok = FALSE) {
  checkmate::assert_flag(null_ok)

  if (is.null(x) && isTRUE(null_ok)) {
    TRUE
  } else {
    name <- deparse(substitute(x)) #nolint

    if (
      !inherits(x, "list") ||
        length(x) != 3 ||
        !inherits(x[[1]], "sf") ||
        !inherits(x[[2]], "RasterLayer") ||
        !inherits(x[[3]], "numeric")
    ) {
      cli::cli_abort(
        paste0(
          "{.strong {cli::col_red(name)}} ",
          "must be an output object from the ",
          "{.strong allocation_discrete()} function."
        )
      )
    } else {
      TRUE
    }
  }
}

assert_minimal_coverage <- function(
  traveltime,
  demand,
  objectiveminutes,
  threshold,
  null_ok = FALSE
) {
  assert_traveltime(traveltime)
  checkmate::assert_class(demand, "RasterLayer")
  checkmate::assert_number(threshold, lower = 0, upper = 1)
  checkmate::assert_flag(null_ok)

  # R CMD Check variable bindings fix
  # nolint start
  traveltime_values <- demand_values <- NULL
  # nolint end

  raster::crs(demand) <- "+proj=longlat +datum=WGS84 +no_defs +type=crs"

  if (is.null(threshold) && isTRUE(null_ok)) {
    TRUE
  } else {
    data_curve <-
      traveltime[[1]] |>
      raster::`crs<-`(
        value = "+proj=longlat +datum=WGS84 +no_defs +type=crs"
      ) |>
      raster::projectRaster(demand) |>
      raster::`crs<-`(
        value = "+proj=longlat +datum=WGS84 +no_defs +type=crs"
      ) |>
      raster::values() |>
      data.frame(raster::values(demand)) |>
      stats::na.omit(data_curve) |>
      magrittr::set_colnames(c("traveltime_values", "demand_values")) |>
      dplyr::arrange(traveltime_values) |>
      dplyr::as_tibble()

    percent_within_objective <-
      data_curve |>
      dplyr::filter(traveltime_values <= objectiveminutes) |>
      dplyr::pull(demand_values) |>
      sum(na.rm = TRUE) |>
      magrittr::divide_by(
        data_curve |>
          dplyr::pull(demand_values) |>
          sum(na.rm = TRUE)
      )

    if (percent_within_objective >= threshold) {
      cli::cli_abort(
        paste0(
          "The initial coverage within ",
          "{.strong {cli::col_yellow(objectiveminutes)}} minutes is ",
          "{.strong ",
          "{cli::col_red(round(percent_within_objective * 100, 5))}}%, ",
          "which meets or exceeds the ",
          "{.strong {cli::col_blue(threshold * 100)}}% objective. ",
          "No additional facilities are required. ",
          "Use {.strong traveltime_stats()} ",
          "to review travel time statistics."
        ),
        wrap = TRUE
      )
    } else {
      TRUE
    }
  }
}

assert_internet <- function() {
  if (!curl::has_internet()) {
    cli::cli_abort(
      paste0(
        "An {.strong {cli::col_red('internet connection')}} ",
        "is required to run this function."
      )
    )
  } else {
    TRUE
  }
}
