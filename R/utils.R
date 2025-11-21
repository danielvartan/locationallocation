count_facilities <- function(facilities) {
  assert_facilities(facilities)

  sf::st_geometry(facilities) |> length()
}

facilities_coordinates <- function(facilities, bb_area = NULL) {
  assert_facilities(facilities)
  assert_bb_area(bb_area, null_ok = TRUE)

  if (!is.null(bb_area)) {
    facilities <-
      facilities |>
      sf::st_filter(bb_area)
  }

  facilities |>
    sf::st_coordinates() |>
    dplyr::as_tibble()
}

points_to_matrix <- function(points) {
  checkmate::assert_tibble(points, ncols = 2)
  checkmate::assert_set_equal(colnames(points), c("X", "Y"))

  data.frame() |>
    magrittr::inset(seq_len(nrow(points)), 1, points["X"]) |>
    magrittr::inset(seq_len(nrow(points)), 2, points["Y"]) |>
    as.matrix()
}
