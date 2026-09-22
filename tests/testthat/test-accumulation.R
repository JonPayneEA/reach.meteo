# ============================================================
# Tool: Precipitation accumulation tests
# Description: Tests unit conversion, integration and gap protection.
# Flode Module: reach.io / reach.ensemble / reach.viz
# Author: Jonathan Payne, jon.payne@environment-agency.gov.uk
# Created: 2026-09-22
# Modified: 2026-09-22 - JP: Initial GitHub-ready implementation
# Tier: 2
# Inputs: Synthetic ensemble rate series.
# Outputs: testthat expectations.
# Dependencies: testthat; data.table.
# ============================================================


test_that("per-second rates convert to mm per hour", {
  fixture_dt <- data.table::data.table(
    value = c(0.001, 0.002),
    units = "kg m-2 s-1"
  )
  result_dt <- convert_precipitation_rate(fixture_dt)
  expect_equal(result_dt$rate_mm_per_hour, c(3.6, 7.2))
})

test_that("constant rate integrates over actual intervals", {
  fixture_dt <- data.table::data.table(
    valid_time = as.POSIXct(c("2026-09-01 00:00:00", "2026-09-01 01:00:00", "2026-09-01 03:00:00"), tz = "UTC"),
    member_id = "m1",
    rate_mm_per_hour = 2,
    complete = TRUE
  )
  result_dt <- accumulate_ensemble(fixture_dt, source = "rate")
  expect_equal(result_dt$interval_precipitation_mm, c(0, 2, 4))
  expect_equal(result_dt$cumulative_precipitation_mm, c(0, 2, 6))
})
