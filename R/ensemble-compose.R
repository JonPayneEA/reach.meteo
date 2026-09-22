# ============================================================
# Tool: Time-lagged ensemble composition
# Description: Aligns successive MOGREPS cycles by valid time.
# Flode Module: reach.io / reach.ensemble / reach.viz
# Author: Jonathan Payne, jon.payne@environment-agency.gov.uk
# Created: 2026-09-22
# Modified: 2026-09-22 - JP: Initial GitHub-ready implementation
# Tier: 2
# Inputs: Long point forecasts.
# Outputs: A data.table with completeness metadata.
# Dependencies: data.table.
# ============================================================


#' Compose a time-lagged ensemble
#'
#' @param x Long point forecasts from [extract_ensemble_point()].
#' @param dispatches Number of newest cycles to retain.
#' @param require_members Required members at a complete valid time.
#' @param incomplete How to handle incomplete valid times.
#' @return A data.table with a `complete` column.
#' @export
compose_time_lagged_ensemble <- function(
  x,
  dispatches = 6L,
  require_members = 18L,
  incomplete = c("retain", "drop", "error")
) {
  incomplete <- match.arg(incomplete)
  data_dt <- data.table::as.data.table(data.table::copy(x))
  needed <- c("forecast_reference_time", "valid_time", "member_id")
  missing <- setdiff(needed, names(data_dt))
  if (length(missing)) stop("x lacks: ", paste(missing, collapse = ", "), call. = FALSE)

  selected_dispatches <- tail(sort(unique(data_dt[["forecast_reference_time"]])), dispatches)
  data_dt <- data_dt[forecast_reference_time %in% selected_dispatches]
  availability_dt <- data_dt[, .(
    members = data.table::uniqueN(member_id),
    dispatches = data.table::uniqueN(forecast_reference_time)
  ), by = valid_time]
  data.table::set(availability_dt, j = "complete", value = availability_dt[["members"]] == require_members)
  data_dt <- merge(data_dt, availability_dt, by = "valid_time", all.x = TRUE, sort = FALSE)

  if (incomplete == "drop") data_dt <- data_dt[complete == TRUE]
  if (incomplete == "error" && any(!data_dt$complete)) {
    stop("One or more valid times do not contain the required members.", call. = FALSE)
  }
  attr(data_dt, "member_availability") <- availability_dt
  attr(data_dt, "required_members") <- require_members
  data.table::setorderv(data_dt, c("valid_time", "forecast_reference_time", "realisation"))
  data_dt[]
}
