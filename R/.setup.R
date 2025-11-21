# Load Packages -----

library(ggplot2)
library(here)
library(knitr)
library(magrittr)
library(ragg)

# Set Options -----

options(
  dplyr.print_min = 6,
  dplyr.print_max = 6,
  pillar.max_footer_lines = 2,
  pillar.min_chars = 15,
  scipen = 10,
  digits = 10,
  stringr.view_n = 6,
  pillar.bold = TRUE,
  width = 77 # 80 - 3 for #> Comment
)

# Set Variables -----

set.seed(2025)

# Set `knitr`` -----

clean_cache()

opts_chunk$set(
  comment = "#>",
  collapse = TRUE,
  root.dir = here(),
  dev = "ragg_png",
  fig.showtext = TRUE
)

# Set `ggplot2` Theme -----

theme_set(
  theme_bw() +
    theme(
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      legend.frame = element_blank(),
      legend.ticks = element_line(color = "white")
    )
)
