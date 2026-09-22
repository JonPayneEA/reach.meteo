# ============================================================
# Tool: MOGREPS NetCDF reader
# Description: Reads internal realisation layers and metadata from one MOGREPS file.
# Flode Module: reach.io / reach.ensemble / reach.viz
# Author: Jonathan Payne, jon.payne@environment-agency.gov.uk
# Created: 2026-09-22
# Modified: 2026-09-22 - JP: Initial GitHub-ready implementation
# Tier: 2
# Inputs: A local NetCDF path.
# Outputs: A reach_meteo_ensemble_file object.
# Dependencies: terra; hdf5r.
# ============================================================


.read_realisation_ids <- function(file) {
  handle <- hdf5r::H5File$new(file, mode = "r")
  on.exit(try(handle$close_all(), silent = TRUE), add = TRUE)
  root_names <- names(handle)
  name <- if ("realization" %in% root_names) {
    "realization"
  } else if ("realisation" %in% root_names) {
    "realisation"
  } else {
    stop("No realization coordinate found in: ", file, call. = FALSE)
  }
  as.integer(as.vector(handle[[name]]$read()))
}

.parse_file_identity <- function(file) {
  path <- normalizePath(file, winslash = "/", mustWork = TRUE)
  filename <- basename(path)
  valid_text <- sub("^([0-9]{8}T[0-9]{4}Z).*$", "\\1", filename)
  lead <- stringr::str_match(filename, "PT([0-9]{4})H([0-9]{2})M")
  dispatch <- stringr::str_match(path, "uk-ensemble/([0-9]{4})/([0-9]{2})/([0-9]{2})/T([0-9]{4})Z/")
  list(
    source_file = path,
    valid_time = as.POSIXct(valid_text, format = "%Y%m%dT%H%MZ", tz = "UTC"),
    lead_time_hours = as.numeric(lead[, 2L]) + as.numeric(lead[, 3L]) / 60,
    forecast_reference_time = as.POSIXct(
      paste0(dispatch[, 2L], dispatch[, 3L], dispatch[, 4L], "T", dispatch[, 5L], "Z"),
      format = "%Y%m%dT%H%MZ", tz = "UTC"
    ),
    variable = sub("^[0-9]{8}T[0-9]{4}Z-PT[0-9]{4}H[0-9]{2}M-", "", filename)
  )
}

#' Read a MOGREPS-UK ensemble file
#'
#' @param file Local NetCDF path.
#' @param realisations Optional native realisation identifiers to retain.
#' @return An object containing the raster, native IDs and forecast metadata.
#' @export
read_ensemble_file <- function(file, realisations = NULL) {
  if (!file.exists(file)) stop("File does not exist: ", file, call. = FALSE)
  raster <- terra::rast(file)
  ids <- .read_realisation_ids(file)
  if (terra::nlyr(raster) != length(ids)) {
    stop("Raster layer count does not match realization count.", call. = FALSE)
  }
  if (!is.null(realisations)) {
    missing <- setdiff(realisations, ids)
    if (length(missing)) stop("Realisations not found: ", paste(missing, collapse = ", "), call. = FALSE)
    keep <- ids %in% realisations
    raster <- raster[[which(keep)]]
    ids <- ids[keep]
  }
  names(raster) <- paste0("realisation_", ids)
  structure(
    c(list(data = raster, realisations = ids), .parse_file_identity(file)),
    class = "reach_meteo_ensemble_file"
  )
}
