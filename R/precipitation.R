# ============================================================
# Tool: Precipitation conversion and accumulation
# Description: Converts precipitation rate and calculates interval and cumulative depth.
# Flode Module: reach.io / reach.ensemble / reach.viz
# Author: Jonathan Payne, jon.payne@environment-agency.gov.uk
# Created: 2026-09-22
# Modified: 2026-09-22 - JP: Initial GitHub-ready implementation
# Tier: 2
# Inputs: Long ensemble data with values, units and valid times.
# Outputs: A data.table with rate, interval and cumulative precipitation.
# Dependencies: data.table.
# ============================================================


#' Convert precipitation rate to millimetres per hour
#'
#' @param x Ensemble data containing `value` and `units`.
#' @param value_column Source value column.
#' @param unit_column Source unit column.
#' @param unknown Action for unknown units.
#' @return A copy with `rate_mm_per_hour`.
#' @export
convert_precipitation_rate <- function(
  x,
  value_column = "value",
  unit_column = "units",
  unknown = c("error", "retain")
) {
  unknown <- match.arg(unknown)
  data_dt <- data.table::as.data.table(data.table::copy(x))
  units <- tolower(gsub("\\s+", " ", trimws(data_dt[[unit_column]])))
  per_second <- grepl("kg.*m-?2.*s-?1|kg/m\\^?2/s|kg m\\^-2 s\\^-1", units)
  mm_per_hour <- grepl("mm.*h-?1|mm/h|mm h\\^-1", units)
  recognised <- per_second | mm_per_hour
  if (unknown == "error" && any(!recognised | is.na(recognised))) {
    bad <- unique(data_dt[[unit_column]][!recognised | is.na(recognised)])
    stop("Unrecognised precipitation units: ", paste(bad, collapse = ", "), call. = FALSE)
  }
  converted <- as.numeric(data_dt[[value_column]])
  converted[per_second] <- converted[per_second] * 3600
  data.table::set(data_dt, j = "rate_mm_per_hour", value = converted)
  data_dt[]
}

.cumulative_protected <- function(values) {
  output <- rep(NA_real_, length(values))
  total <- 0
  gap <- FALSE
  for (index in seq_along(values)) {
    if (gap || is.na(values[index])) {
      gap <- TRUE
    } else {
      total <- total + values[index]
      output[index] <- total
    }
  }
  output
}

#' Accumulate an ensemble precipitation forecast
#'
#' @param x Time-lagged ensemble data.
#' @param source `rate` or `interval_accumulation`.
#' @param value_column Rate or interval-depth column.
#' @param method Integration method for rates. Currently `trapezoidal`.
#' @param require_complete Retain only complete valid times.
#' @return Data with interval and cumulative precipitation.
#' @export
accumulate_ensemble <- function(
  x,
  source = c("rate", "interval_accumulation"),
  value_column = NULL,
  method = "trapezoidal",
  require_complete = TRUE
) {
  source <- match.arg(source)
  if (!identical(method, "trapezoidal")) stop("Only trapezoidal integration is supported.", call. = FALSE)
  data_dt <- data.table::as.data.table(data.table::copy(x))
  if (require_complete && "complete" %in% names(data_dt)) data_dt <- data_dt[complete == TRUE]
  if (!nrow(data_dt)) stop("No rows remain for accumulation.", call. = FALSE)
  data.table::setorderv(data_dt, c("member_id", "valid_time"))

  if (source == "rate") {
    if (is.null(value_column)) value_column <- "rate_mm_per_hour"
    data.table::set(data_dt, j = "working_value", value = as.numeric(data_dt[[value_column]]))
    data_dt[, interval_hours := c(NA_real_, as.numeric(diff(valid_time), units = "hours")), by = member_id]
    if (any(data_dt$interval_hours <= 0, na.rm = TRUE)) stop("Valid times must increase within each member.", call. = FALSE)
    data_dt[, previous_value := data.table::shift(working_value), by = member_id]
    data_dt[, interval_precipitation_mm := ifelse(
      is.na(interval_hours), 0,
      (previous_value + working_value) / 2 * interval_hours
    )]
    data_dt[!is.na(interval_hours) & (is.na(previous_value) | is.na(working_value)), interval_precipitation_mm := NA_real_]
  } else {
    if (is.null(value_column)) value_column <- "interval_precipitation_mm"
    data.table::set(data_dt, j = "interval_precipitation_mm", value = as.numeric(data_dt[[value_column]]))
  }

  if (any(data_dt$interval_precipitation_mm < 0, na.rm = TRUE)) {
    stop("Negative interval precipitation was found.", call. = FALSE)
  }
  data_dt[, cumulative_precipitation_mm := .cumulative_protected(interval_precipitation_mm), by = member_id]
  data_dt[]
}

#' Summarise an ensemble
#'
#' @param x Ensemble data.
#' @param value_column Numeric value column.
#' @param require_members Optional exact member count.
#' @return Summary statistics by valid time.
#' @export
summarise_ensemble <- function(x, value_column, require_members = NULL) {
  data_dt <- data.table::as.data.table(data.table::copy(x))
  value <- data_dt[[value_column]]
  data.table::set(data_dt, j = ".summary_value", value = as.numeric(value))
  summary_dt <- data_dt[!is.na(.summary_value), .(
    members = data.table::uniqueN(member_id),
    minimum = min(.summary_value),
    p10 = as.numeric(stats::quantile(.summary_value, 0.10, names = FALSE)),
    p25 = as.numeric(stats::quantile(.summary_value, 0.25, names = FALSE)),
    median = stats::median(.summary_value),
    mean = mean(.summary_value),
    p75 = as.numeric(stats::quantile(.summary_value, 0.75, names = FALSE)),
    p90 = as.numeric(stats::quantile(.summary_value, 0.90, names = FALSE)),
    maximum = max(.summary_value)
  ), by = valid_time]
  if (!is.null(require_members)) summary_dt <- summary_dt[members == require_members]
  data.table::setorderv(summary_dt, "valid_time")
  summary_dt[]
}
