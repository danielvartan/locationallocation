add_plot_annotation <- function(
  plot,
  annotation_location = "br",
  annotation_scale = TRUE,
  annotation_north_arrow = TRUE
) {
  checkmate::assert_class(plot, "ggplot")
  checkmate::assert_flag(annotation_scale)
  checkmate::assert_flag(annotation_north_arrow)

  checkmate::assert_choice(
    annotation_location,
    choices = c("bl", "br", "tl", "tr")
  )

  if (isTRUE(annotation_scale)) {
    plot <-
      plot +
      ggspatial::annotation_scale(
        location = annotation_location,
        style = "tick",
        height = ggplot2::unit(0.5, "lines")
      )

    annotation_pad_y_diff <- 0
  } else {
    annotation_pad_y_diff <- 0.75
  }

  if (grepl("^t", annotation_location)) {
    annotation_pad_y_diff <- annotation_pad_y_diff + 0.25
    annotation_pad_y <- ggplot2::unit(1.75 - annotation_pad_y_diff, "lines")
  } else {
    annotation_pad_y <- ggplot2::unit(1.25 - annotation_pad_y_diff, "lines")
  }

  if (isTRUE(annotation_north_arrow)) {
    plot <-
      plot +
      ggspatial::annotation_north_arrow(
        location = annotation_location,
        height = ggplot2::unit(2, "lines"),
        width = ggplot2::unit(2, "lines"),
        pad_x = ggplot2::unit(0.25, "lines"),
        pad_y = annotation_pad_y,
        style = ggspatial::north_arrow_fancy_orienteering
      )
  }

  plot
}
