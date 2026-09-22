# ============================================================
# Tool: MOGREPS-UK product definition
# Description: Defines the public MOGREPS-UK object-store product.
# Flode Module: reach.io / reach.ensemble / reach.viz
# Author: Jonathan Payne, jon.payne@environment-agency.gov.uk
# Created: 2026-09-22
# Modified: 2026-09-22 - JP: Initial GitHub-ready implementation
# Tier: 2
# Inputs: Optional logical variable names.
# Outputs: A reach_meteo_product list.
# Dependencies: Base R.
# ============================================================


#' Define the MOGREPS-UK product
#'
#' @param variables Optional exact object-variable names.
#' @return A product definition used by the package workflow.
#' @export
mogreps_uk <- function(variables = character()) {
  structure(
    list(
      product_id = "mogreps-uk",
      bucket = "met-office-uk-ensemble-model-data",
      endpoint = paste0(
        "https://met-office-uk-ensemble-model-data.",
        "s3.eu-west-2.amazonaws.com"
      ),
      prefix = "uk-ensemble/",
      variables = as.character(variables),
      time_zone = "UTC"
    ),
    class = "reach_meteo_product"
  )
}
