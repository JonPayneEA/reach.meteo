# ============================================================
# Tool: MOGREPS parser tests
# Description: Tests request-independent filename and path parsing.
# Flode Module: reach.io / reach.ensemble / reach.viz
# Author: Jonathan Payne, jon.payne@environment-agency.gov.uk
# Created: 2026-09-22
# Modified: 2026-10-01 - JP: tests for .str_match()
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

test_that(".str_match returns one row per input with groups as columns", {
  x <- c("20260901T0015Z-PT0001H30M-rain.nc", "no-lead-time-here.nc")
  m <- reach.meteo:::.str_match(x, "PT([0-9]{4})H([0-9]{2})M")
  expect_equal(dim(m), c(2L, 3L))
  expect_equal(m[1L, ], c("PT0001H30M", "0001", "30"))
  expect_true(all(is.na(m[2L, ])))
})

test_that(".str_match keeps its shape when nothing matches", {
  m <- reach.meteo:::.str_match("nothing", "PT([0-9]{4})H([0-9]{2})M")
  expect_equal(dim(m), c(1L, 3L))
  expect_true(is.na(m[1L, 2L]))
})
