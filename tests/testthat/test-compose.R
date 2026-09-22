# ============================================================
# Tool: Time-lagged ensemble tests
# Description: Tests valid-time alignment and member completeness.
# Flode Module: reach.io / reach.ensemble / reach.viz
# Author: Jonathan Payne, jon.payne@environment-agency.gov.uk
# Created: 2026-09-22
# Modified: 2026-09-22 - JP: Initial GitHub-ready implementation
# Tier: 2
# Inputs: Synthetic long ensemble data.
# Outputs: testthat expectations.
# Dependencies: testthat; data.table.
# ============================================================


test_that("six three-member cycles form 18 members", {
  dispatches <- as.POSIXct("2026-09-01 00:00:00", tz = "UTC") - rev(0:5) * 3600
  fixture_dt <- data.table::rbindlist(lapply(dispatches, function(dispatch) {
    data.table::data.table(
      forecast_reference_time = dispatch,
      valid_time = as.POSIXct("2026-09-01 12:00:00", tz = "UTC"),
      realisation = 1:3,
      member_id = paste0(format(dispatch, "%Y%m%dT%H%MZ", tz = "UTC"), "_r", 1:3),
      value = 1:3,
      units = "kg m-2 s-1"
    )
  }))
  result_dt <- compose_time_lagged_ensemble(fixture_dt, incomplete = "error")
  expect_equal(data.table::uniqueN(result_dt$member_id), 18L)
  expect_true(all(result_dt$complete))
})
