
library(devtools)
library(sf)
library(tidyverse)

setwd("C:/Users/Utente/OneDrive - IIASA/Current papers/cooling_centers_allocation/locationallocation/")

# usethis::use_pkgdown()
# usethis::use_gpl3_license()
# usethis::use_author(
#   given = "Giacomo",
#   family = "Falchetta",
#   role = c("aut", "cre"),
#   email = "giacomo.falchetta@cmcc.it",
#   comment = c(ORCID = "0000-0003-2607-2195")
# )
# usethis::use_citation()
# usethis::use_github_action("pkgdown")

##

devtools::document()

###

devtools::install_github("giacfalk/locationallocation")

pkgdown::build_site()

remove.packages("locationallocation")

