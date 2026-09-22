# ============================================================
# Tool: MOGREPS point forecast example
# Description: Demonstrates the complete 18-member point forecast workflow.
# Flode Module: reach.io / reach.ensemble / reach.viz
# Author: Jonathan Payne, jon.payne@environment-agency.gov.uk
# Created: 2026-09-22
# Modified: 2026-09-22 - JP: Initial GitHub-ready implementation
# Tier: 2
# Inputs: Public AWS data and WGS84 point coordinates.
# Outputs: Local NetCDF files, data tables and ggplot objects.
# Dependencies: reach.meteo; data.table; ggplot2.
# ============================================================


library(reach.meteo)

product <- mogreps_uk("precipitation_rate.nc")
dispatches <- available_dispatches(product, lookback_days = 2)
selected <- select_dispatches(dispatches, coverage = "latest_six")
request <- forecast_request(selected, "precipitation_rate.nc", maximum_lead_hours = 126)
remote <- catalogue(request)
local <- download_data(remote, "data/mogreps")

point_dt <- extract_ensemble_point(
  local,
  longitude = -0.2437,
  latitude = 52.5695,
  point_id = "Peterborough"
)

lagged_dt <- compose_time_lagged_ensemble(
  point_dt,
  dispatches = 6,
  require_members = 18,
  incomplete = "drop"
)

rate_dt <- convert_precipitation_rate(lagged_dt)
accumulated_dt <- accumulate_ensemble(rate_dt, source = "rate")

plot_ensemble_series(
  rate_dt,
  "rate_mm_per_hour",
  "Precipitation rate (mm h-1)",
  "MOGREPS-UK precipitation rate"
)
plot_ensemble_cumulative(accumulated_dt, "MOGREPS-UK cumulative precipitation")
plot_cumulative_summary(accumulated_dt, 18, "Cumulative precipitation summary")
