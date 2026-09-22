# ============================================================
# Tool: Plot tests
# Description: Checks that all public plot functions return ggplot objects.
# Flode Module: reach.io / reach.ensemble / reach.viz
# Author: Jonathan Payne, jon.payne@environment-agency.gov.uk
# Created: 2026-09-22
# Modified: 2026-09-22 - JP: Initial GitHub-ready implementation
# Tier: 2
# Inputs: Synthetic ensemble tables.
# Outputs: testthat expectations.
# Dependencies: testthat; ggplot2; data.table.
# ============================================================


test_that("ensemble plots return ggplot objects", {
  fixture_dt <- data.table::data.table(
    valid_time = rep(as.POSIXct(c("2026-09-01 00:00:00", "2026-09-01 01:00:00"), tz = "UTC"), 2),
    forecast_reference_time = rep(as.POSIXct(c("2026-08-31 23:00:00", "2026-09-01 00:00:00"), tz = "UTC"), each = 2),
    member_id = rep(c("m1", "m2"), each = 2),
    realisation = rep(c(1L, 2L), each = 2),
    value = c(1, 2, 2, 3)
  )
  expect_s3_class(plot_ensemble_series(fixture_dt, "value"), "ggplot")
})
