coverage_message <- function(allocation) {
  assert_allocation(allocation)

  n_fac <- #nolint
    allocation |>
    magrittr::extract2("facilities") |>
    sf::st_geometry() |>
    length()

  coverage <- allocation |> magrittr::extract2("coverage")
  unmet_demand <- allocation |> magrittr::extract2("unmet_demand")

  objective_minutes <- #nolint
    allocation |>
    magrittr::extract2("objective_minutes")

  objective_share <- allocation |> magrittr::extract2("objective_share")

  if (is.null(objective_share)) {
    cli::cli_alert_info(
      paste0(
        "{.strong {cli::col_red(n_fac)}} facilities ",
        "allocated within the ",
        "{.strong {cli::col_yellow(objective_minutes)}} ",
        "minutes threshold. ",
        "The maximum coverage share attained was ",
        "{.strong {cli::col_green(round(coverage * 100, 5))}}%."
      ),
      wrap = TRUE
    )
  } else if (coverage >= objective_share) {
    cli::cli_alert_success(
      paste0(
        "Target coverage share of ",
        "{.strong {cli::col_blue((objective_share * 100))}}% ",
        "attained with ",
        "{.strong {cli::col_red(n_fac)}} facilities ",
        "within the ",
        "{.strong {cli::col_yellow(objective_minutes)}} ",
        "minutes threshold. ",
        "The achieved coverage share is ",
        "{.strong {cli::col_green(round(coverage * 100, 5))}}%."
      ),
      wrap = TRUE
    )
  } else {
    cli::cli_alert_danger(
      paste0(
        "The target coverage share of ",
        "{.strong {cli::col_blue((objective_share * 100))}}% ",
        "could not be attained with ",
        "{.strong {cli::col_red(n_fac)}} ",
        "facilities within the ",
        "{.strong {cli::col_yellow(objective_minutes)}} ",
        "minutes threshold. ",
        "The maximum coverage share attained was ",
        "{.strong {cli::col_green(round((1 - unmet_demand) * 100, 5))}}%."
      ),
      wrap = TRUE
    )

    invisible(1 - unmet_demand)
  }
}
