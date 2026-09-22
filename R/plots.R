# ============================================================
# Tool: MOGREPS ensemble plots
# Description: Creates ggplot2 member, summary, availability and cumulative charts.
# Flode Module: reach.io / reach.ensemble / reach.viz
# Author: Jonathan Payne, jon.payne@environment-agency.gov.uk
# Created: 2026-09-22
# Modified: 2026-09-22 - JP: Initial GitHub-ready implementation
# Tier: 2
# Inputs: Long ensemble data or summary tables.
# Outputs: ggplot objects.
# Dependencies: ggplot2; scales; data.table.
# ============================================================


#' Plot ensemble member series
#' @param x Long ensemble data.
#' @param value_column Numeric value column.
#' @param y_label Y-axis label.
#' @param title Plot title.
#' @return A ggplot object.
#' @export
plot_ensemble_series <- function(x, value_column, y_label = value_column, title = NULL) {
  data_dt <- data.table::as.data.table(data.table::copy(x))
  data.table::set(data_dt, j = ".plot_value", value = data_dt[[value_column]])
  if (!"dispatch_label" %in% names(data_dt)) {
    data.table::set(data_dt, j = "dispatch_label", value = format(data_dt$forecast_reference_time, "%d %b %H:%M", tz = "UTC"))
  }
  ggplot2::ggplot(data_dt, ggplot2::aes(
    x = valid_time, y = .plot_value, group = member_id,
    colour = dispatch_label, linetype = factor(realisation)
  )) +
    ggplot2::geom_line(linewidth = 0.4, alpha = 0.75, na.rm = TRUE) +
    ggplot2::scale_x_datetime(date_breaks = "12 hours", date_labels = "%d %b\n%H:%M", timezone = "UTC") +
    ggplot2::labs(title = title, x = "Valid time (UTC)", y = y_label, colour = "Source dispatch", linetype = "Realisation") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(), legend.position = "bottom", plot.title.position = "plot")
}

#' Plot ensemble percentile bands
#' @param x Summary returned by [summarise_ensemble()].
#' @param y_label Y-axis label.
#' @param title Plot title.
#' @return A ggplot object.
#' @export
plot_ensemble_summary <- function(x, y_label, title = NULL) {
  ggplot2::ggplot(x, ggplot2::aes(x = valid_time)) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = p10, ymax = p90), fill = "#56B4E9", alpha = 0.25) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = p25, ymax = p75), fill = "#0072B2", alpha = 0.35) +
    ggplot2::geom_line(ggplot2::aes(y = median), colour = "#003B5C", linewidth = 0.9) +
    ggplot2::geom_line(ggplot2::aes(y = mean), colour = "#D55E00", linewidth = 0.7, linetype = "dashed") +
    ggplot2::scale_x_datetime(date_breaks = "12 hours", date_labels = "%d %b\n%H:%M", timezone = "UTC") +
    ggplot2::labs(title = title, x = "Valid time (UTC)", y = y_label) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(), plot.title.position = "plot")
}

#' Plot cumulative ensemble members
#' @param x Accumulated ensemble data.
#' @param title Plot title.
#' @return A ggplot object.
#' @export
plot_ensemble_cumulative <- function(x, title = NULL) {
  plot_ensemble_series(x, "cumulative_precipitation_mm", "Cumulative precipitation (mm)", title)
}

#' Plot cumulative ensemble summary
#' @param x Accumulated ensemble data.
#' @param require_members Required member count.
#' @param title Plot title.
#' @return A ggplot object.
#' @export
plot_cumulative_summary <- function(x, require_members = 18L, title = NULL) {
  summary_dt <- summarise_ensemble(x, "cumulative_precipitation_mm", require_members)
  plot_ensemble_summary(summary_dt, "Cumulative precipitation (mm)", title)
}

#' Plot member availability
#' @param x Time-lagged ensemble data.
#' @param required_members Required member count.
#' @return A ggplot object.
#' @export
plot_member_availability <- function(x, required_members = 18L) {
  availability_dt <- attr(x, "member_availability")
  if (is.null(availability_dt)) {
    availability_dt <- data.table::as.data.table(x)[, .(members = data.table::uniqueN(member_id)), by = valid_time]
  }
  ggplot2::ggplot(availability_dt, ggplot2::aes(valid_time, members)) +
    ggplot2::geom_hline(yintercept = required_members, colour = "#D55E00", linetype = "dashed") +
    ggplot2::geom_step(colour = "#009E73", linewidth = 0.75) +
    ggplot2::scale_y_continuous(breaks = scales::pretty_breaks()) +
    ggplot2::labs(title = "MOGREPS-UK member availability", x = "Valid time (UTC)", y = "Members") +
    ggplot2::theme_minimal(base_size = 11)
}

#' Plot final cumulative totals by member
#' @param x Accumulated ensemble data.
#' @return A ggplot object.
#' @export
plot_final_member_totals <- function(x) {
  totals_dt <- data.table::as.data.table(x)[, .(
    final_total_mm = tail(cumulative_precipitation_mm, 1L),
    dispatch_label = tail(format(forecast_reference_time, "%d %b %H:%M", tz = "UTC"), 1L)
  ), by = member_id]
  totals_dt[, member_order := factor(member_id, levels = member_id[order(final_total_mm)])]
  ggplot2::ggplot(totals_dt, ggplot2::aes(member_order, final_total_mm, fill = dispatch_label)) +
    ggplot2::geom_col() + ggplot2::coord_flip() +
    ggplot2::labs(title = "Final cumulative totals", x = "Time-lagged member", y = "Cumulative precipitation (mm)", fill = "Dispatch") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom")
}
