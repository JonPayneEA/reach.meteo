# ============================================================
# Tool: Ensemble point extraction
# Description: Extracts every internal realisation at one point across a local catalogue.
# Flode Module: reach.io / reach.ensemble / reach.viz
# Author: Jonathan Payne, jon.payne@environment-agency.gov.uk
# Created: 2026-09-22
# Modified: 2026-09-22 - JP: Initial GitHub-ready implementation
# Tier: 2
# Inputs: Local catalogue, longitude, latitude and interpolation method.
# Outputs: A long data.table of point forecasts.
# Dependencies: terra; data.table.
# ============================================================


#' Extract a MOGREPS ensemble at one point
#'
#' @param x A local catalogue returned by [download_data()].
#' @param longitude WGS84 longitude.
#' @param latitude WGS84 latitude.
#' @param point_id Point identifier.
#' @param method `bilinear` or `simple`.
#' @return A long data.table with one row per member and valid time.
#' @export
extract_ensemble_point <- function(
  x,
  longitude,
  latitude,
  point_id = "point",
  method = c("bilinear", "simple")
) {
  if (!inherits(x, "reach_meteo_catalogue") || x$source != "local") {
    stop("x must be a local catalogue returned by download_data().", call. = FALSE)
  }
  method <- match.arg(method)
  point <- terra::vect(
    data.frame(id = point_id, longitude = longitude, latitude = latitude),
    geom = c("longitude", "latitude"), crs = "EPSG:4326", keepgeom = TRUE
  )

  tables <- lapply(seq_len(nrow(x$records)), function(index) {
    file <- x$records[["local_file"]][index]
    ensemble <- read_ensemble_file(file)
    point_projected <- terra::project(point, terra::crs(ensemble$data))
    values <- terra::extract(ensemble$data, point_projected, method = method)
    values <- as.numeric(values[1L, setdiff(names(values), "ID"), drop = TRUE])
    units <- tryCatch(terra::units(ensemble$data)[1L], error = function(error) NA_character_)
    data.table::data.table(
      point_id = point_id,
      longitude = longitude,
      latitude = latitude,
      forecast_reference_time = x$records[["forecast_reference_time"]][index],
      valid_time = x$records[["valid_time"]][index],
      lead_time_hours = x$records[["lead_time_hours"]][index],
      variable = x$records[["variable"]][index],
      realisation = ensemble$realisations,
      value = values,
      units = units,
      source_file = normalizePath(file, winslash = "/", mustWork = TRUE)
    )
  })
  result_dt <- data.table::rbindlist(tables, use.names = TRUE, fill = TRUE)
  data.table::set(
    result_dt,
    j = "member_id",
    value = paste0(
      format(result_dt[["forecast_reference_time"]], "%Y%m%dT%H%MZ", tz = "UTC"),
      "_r", result_dt[["realisation"]]
    )
  )
  data.table::setorderv(result_dt, c("valid_time", "forecast_reference_time", "realisation"))
  result_dt[]
}
