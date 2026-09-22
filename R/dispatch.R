# ============================================================
# Tool: MOGREPS dispatch discovery
# Description: Discovers nested MOGREPS-UK hourly forecast cycles.
# Flode Module: reach.io / reach.ensemble / reach.viz
# Author: Jonathan Payne, jon.payne@environment-agency.gov.uk
# Created: 2026-09-22
# Modified: 2026-09-22 - JP: Initial GitHub-ready implementation
# Tier: 2
# Inputs: Product and lookback period.
# Outputs: A reach_meteo_dispatches object.
# Dependencies: data.table.
# ============================================================


#' Discover recent forecast dispatches
#'
#' @param product A product created by [mogreps_uk()].
#' @param lookback_days Positive number of UTC days to inspect.
#' @param quiet Suppress progress messages.
#' @return A dispatch object containing dispatch times and prefixes.
#' @export
available_dispatches <- function(product, lookback_days = 2, quiet = FALSE) {
  if (!inherits(product, "reach_meteo_product")) {
    stop("product must be created by mogreps_uk().", call. = FALSE)
  }
  if (length(lookback_days) != 1L || is.na(lookback_days) || lookback_days <= 0) {
    stop("lookback_days must be one positive number.", call. = FALSE)
  }

  end_date <- as.Date(Sys.time(), tz = "UTC")
  start_date <- as.Date(Sys.time() - lookback_days * 86400, tz = "UTC")
  date_values <- seq(start_date, end_date, by = "day")
  candidate_times <- as.POSIXct(
    unlist(lapply(date_values, function(date_value) {
      paste(format(date_value, "%Y-%m-%d"), sprintf("%02d:00:00", 0:23))
    })),
    tz = "UTC"
  )
  cutoff <- as.POSIXct(Sys.time(), tz = "UTC") - lookback_days * 86400
  candidate_times <- candidate_times[
    candidate_times >= cutoff & candidate_times <= as.POSIXct(Sys.time(), tz = "UTC")
  ]

  prefixes <- paste0(product$prefix, format(candidate_times, "%Y/%m/%d/T%H%MZ/", tz = "UTC"))
  records_dt <- data.table::data.table(
    dispatch = candidate_times,
    run_type = "ensemble",
    prefix = prefixes
  )
  # Prefix existence is checked lazily during catalogue construction.
  structure(
    list(product = product, records = records_dt, retrieved_at = Sys.time()),
    class = "reach_meteo_dispatches"
  )
}

#' Select MOGREPS-UK dispatches
#'
#' @param x Dispatches returned by [available_dispatches()].
#' @param coverage Either `latest` or `latest_six`.
#' @param dispatch Optional explicit dispatch times.
#' @return A selected dispatch object.
#' @export
select_dispatches <- function(x, coverage = c("latest", "latest_six"), dispatch = NULL) {
  if (!inherits(x, "reach_meteo_dispatches")) stop("x must be dispatches.", call. = FALSE)
  records_dt <- data.table::copy(x$records)

  if (!is.null(dispatch)) {
    wanted <- as.POSIXct(dispatch, tz = "UTC")
    records_dt <- records_dt[dispatch %in% wanted]
  } else {
    coverage <- match.arg(coverage)
    count <- if (coverage == "latest") 1L else 6L
    data.table::setorderv(records_dt, "dispatch")
    records_dt <- tail(records_dt, count)
  }
  if (!nrow(records_dt)) stop("No dispatches matched the selection.", call. = FALSE)
  structure(
    list(product = x$product, records = records_dt, retrieved_at = x$retrieved_at),
    class = "reach_meteo_dispatches"
  )
}

#' @export
print.reach_meteo_dispatches <- function(x, ...) {
  cat("<reach.meteo dispatches>\n")
  print(x$records)
  invisible(x)
}
