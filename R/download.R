# ============================================================
# Tool: Restartable forecast downloads
# Description: Downloads selected objects with manifests and temporary files.
# Flode Module: reach.io / reach.ensemble / reach.viz
# Author: Jonathan Payne, jon.payne@environment-agency.gov.uk
# Created: 2026-09-22
# Modified: 2026-09-22 - JP: Initial GitHub-ready implementation
# Tier: 2
# Inputs: A remote catalogue and destination directory.
# Outputs: A local catalogue and CSV manifest.
# Dependencies: httr2; data.table.
# ============================================================


#' Download forecast objects
#'
#' @param x A remote catalogue.
#' @param destination Destination directory.
#' @param overwrite Replace existing non-empty files.
#' @param manifest Write a CSV manifest before downloading.
#' @return A local catalogue.
#' @export
download_data <- function(x, destination, overwrite = FALSE, manifest = TRUE) {
  if (!inherits(x, "reach_meteo_catalogue")) stop("x must be a catalogue.", call. = FALSE)
  records_dt <- data.table::copy(x$records)
  encoded <- vapply(records_dt[["key"]], .encode_s3_key, character(1))
  object_urls <- paste0(x$product$endpoint, "/", encoded)
  dispatch_labels <- format(records_dt[["forecast_reference_time"]], "%Y%m%dT%H%MZ", tz = "UTC")
  local_files <- file.path(destination, dispatch_labels, records_dt[["filename"]])
  data.table::set(records_dt, j = "object_url", value = object_urls)
  data.table::set(records_dt, j = "local_file", value = local_files)

  dir.create(destination, recursive = TRUE, showWarnings = FALSE)
  if (manifest) data.table::fwrite(records_dt, file.path(destination, "download_manifest.csv"))

  for (index in seq_len(nrow(records_dt))) {
    local_path <- records_dt[["local_file"]][index]
    dir.create(dirname(local_path), recursive = TRUE, showWarnings = FALSE)
    existing <- file.exists(local_path) && !is.na(file.info(local_path)$size) && file.info(local_path)$size > 0
    if (existing && !overwrite) next

    temporary_path <- paste0(local_path, ".part")
    if (file.exists(temporary_path)) unlink(temporary_path)
    tryCatch(
      {
        httr2::request(records_dt[["object_url"]][index]) |>
          httr2::req_retry(max_tries = 5) |>
          httr2::req_perform(path = temporary_path)
        if (!file.rename(temporary_path, local_path)) stop("Could not rename temporary file.")
      },
      error = function(error) {
        if (file.exists(temporary_path)) unlink(temporary_path)
        stop("Download failed: ", conditionMessage(error), call. = FALSE)
      }
    )
  }

  structure(
    list(product = x$product, request = x$request, records = records_dt, source = "local"),
    class = "reach_meteo_catalogue"
  )
}
