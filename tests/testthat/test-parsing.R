# ============================================================
# Tool: MOGREPS parser tests
# Description: Tests request-independent filename and path parsing.
# Flode Module: reach.io / reach.ensemble / reach.viz
# Author: Jonathan Payne, jon.payne@environment-agency.gov.uk
# Created: 2026-09-22
# Modified: 2026-09-22 - JP: Initial GitHub-ready implementation
# Tier: 2
# Inputs: Synthetic object keys.
# Outputs: testthat expectations.
# Dependencies: testthat.
# ============================================================


test_that("MOGREPS file identity is parsed", {
  fixture <- file.path(
    tempdir(), "uk-ensemble", "2026", "09", "01", "T0000Z",
    "20260901T0015Z-PT0000H15M-precipitation_rate.nc"
  )
  dir.create(dirname(fixture), recursive = TRUE, showWarnings = FALSE)
  file.create(fixture)
  identity <- reach.meteo:::.parse_file_identity(fixture)
  expect_equal(identity$lead_time_hours, 0.25)
  expect_equal(identity$variable, "precipitation_rate.nc")
  expect_equal(identity$forecast_reference_time, as.POSIXct("2026-09-01 00:00:00", tz = "UTC"))
  expect_equal(identity$valid_time, as.POSIXct("2026-09-01 00:15:00", tz = "UTC"))
})
