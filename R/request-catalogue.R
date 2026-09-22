# ============================================================
# Tool: Forecast requests and catalogues
# Description: Builds dispatch-scoped, variable-filtered object manifests.
# Flode Module: reach.io / reach.ensemble / reach.viz
# Author: Jonathan Payne, jon.payne@environment-agency.gov.uk
# Created: 2026-09-22
# Modified: 2026-09-22 - JP: Initial GitHub-ready implementation
# Tier: 2
# Inputs: Selected dispatches, variables and lead-time limits.
# Outputs: Request and catalogue objects.
# Dependencies: data.table; stringr.
# ============================================================


#' Create a forecast request
#'
#' @param dispatches Selected dispatches.
#' @param variables Exact object-variable names.
#' @param minimum_lead_hours Minimum lead time.
#' @param maximum_lead_hours Maximum lead time.
#' @return A forecast request.
#' @export
forecast_request <- function(
  dispatches,
  variables,
  minimum_lead_hours = 0,
  maximum_lead_hours = 126
) {
  if (!inherits(dispatches, "reach_meteo_dispatches")) {
    stop("dispatches must be returned by select_dispatches().", call. = FALSE)
  }
  structure(
    list(
      product = dispatches$product,
      dispatches = dispatches,
      variables = as.character(variables),
      minimum_lead_hours = as.numeric(minimum_lead_hours),
      maximum_lead_hours = as.numeric(maximum_lead_hours)
    ),
    class = "reach_meteo_request"
  )
}

#' Build a dispatch-scoped object catalogue
#'
#' @param x A forecast request.
#' @param quiet Suppress listing messages.
#' @return A filtered object catalogue.
#' @export
catalogue <- function(x, quiet = FALSE) {
  if (!inherits(x, "reach_meteo_request")) stop("x must be a forecast request.", call. = FALSE)

  tables <- lapply(seq_len(nrow(x$dispatches$records)), function(index) {
    dispatch_time <- x$dispatches$records[["dispatch"]][index]
    prefix <- x$dispatches$records[["prefix"]][index]
    if (!quiet) message("Listing ", prefix)
    records_dt <- .list_s3_objects(x$product$endpoint, prefix)
    if (nrow(records_dt)) {
      data.table::set(records_dt, j = "forecast_reference_time", value = dispatch_time)
    }
    records_dt
  })
  records_dt <- data.table::rbindlist(tables, use.names = TRUE, fill = TRUE)
  if (!nrow(records_dt)) stop("No objects were found below the selected prefixes.", call. = FALSE)

  data.table::set(records_dt, j = "filename", value = basename(records_dt[["key"]]))
  variable_pattern <- paste0("-", x$variables, collapse = "|")
  records_dt <- records_dt[grepl(paste0("(", variable_pattern, ")$"), filename)]
  if (!nrow(records_dt)) stop("No objects matched the requested variables.", call. = FALSE)

  valid_text <- sub("^([0-9]{8}T[0-9]{4}Z).*$", "\\1", records_dt[["filename"]])
  lead_match <- stringr::str_match(records_dt[["filename"]], "PT([0-9]{4})H([0-9]{2})M")
  data.table::set(records_dt, j = "valid_time", value = as.POSIXct(valid_text, format = "%Y%m%dT%H%MZ", tz = "UTC"))
  data.table::set(
    records_dt,
    j = "lead_time_hours",
    value = as.numeric(lead_match[, 2L]) + as.numeric(lead_match[, 3L]) / 60
  )
  data.table::set(
    records_dt,
    j = "variable",
    value = sub("^[0-9]{8}T[0-9]{4}Z-PT[0-9]{4}H[0-9]{2}M-", "", records_dt[["filename"]])
  )
  records_dt <- records_dt[
    !is.na(lead_time_hours) &
      lead_time_hours >= x$minimum_lead_hours &
      lead_time_hours <= x$maximum_lead_hours
  ]
  data.table::setorderv(records_dt, c("forecast_reference_time", "lead_time_hours"))
  structure(
    list(product = x$product, request = x, records = records_dt, source = "remote"),
    class = "reach_meteo_catalogue"
  )
}

#' @export
print.reach_meteo_request <- function(x, ...) {
  cat("<reach.meteo request>\n")
  cat("Variables:", paste(x$variables, collapse = ", "), "\n")
  cat("Lead range:", x$minimum_lead_hours, "to", x$maximum_lead_hours, "hours\n")
  invisible(x)
}

#' @export
print.reach_meteo_catalogue <- function(x, ...) {
  cat("<reach.meteo catalogue>\n")
  cat("Objects:", nrow(x$records), "\n")
  print(x$records[, .(forecast_reference_time, valid_time, lead_time_hours, variable, size_bytes)])
  invisible(x)
}
