assert_traveltime <- function(x, null_ok = FALSE) {
  checkmate::assert_flag(null_ok)

  if (is.null(x) || isTRUE(null_ok)) {
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

  if (is.null(x) || isTRUE(null_ok)) {
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

  if (is.null(x) || isTRUE(null_ok)) {
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

  if (is.null(x) || isTRUE(null_ok)) {
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

  if (is.null(x) || isTRUE(null_ok)) {
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
