# reach.meteo

`reach.meteo` provides dispatch-first access to public Met Office forecast data. Version 0.4.0 adds a complete MOGREPS-UK workflow: nested cycle discovery, NetCDF realisation reading, six-cycle time-lagged ensembles, point extraction, precipitation accumulation and `ggplot2` charts.

## Status

This package is a Tier 2 analytical tool. The public Met Office AWS data is unsupported. Review results before operational use.

## Design principles

- Filter dispatches, variables and lead times before download.
- Preserve native MOGREPS realisation identifiers.
- Identify a time-lagged member using both dispatch and realisation.
- Align time-lagged forecasts by valid time, not lead time.
- Treat precipitation rates and interval accumulations differently.
- Stop cumulative totals at a missing interval. Do not bridge gaps silently.
- Return `ggplot2` objects so users can add normal layers and themes.

## Installation

```r
# install.packages("pak")
pak::pak("YOUR-GITHUB-ACCOUNT/reach.meteo")
```

For local development:

```r
devtools::load_all(".")
devtools::test()
devtools::check()
```

## Quick start: 18-member MOGREPS-UK point forecast

```r
library(reach.meteo)

product <- mogreps_uk(
  variables = "precipitation_rate.nc"
)

dispatches <- available_dispatches(
  product,
  lookback_days = 2
)

selected <- select_dispatches(
  dispatches,
  coverage = "latest_six"
)

request <- forecast_request(
  selected,
  variables = "precipitation_rate.nc",
  maximum_lead_hours = 126
)

remote <- catalogue(request)
remote

local <- download_data(
  remote,
  destination = "data/mogreps"
)

point_dt <- extract_ensemble_point(
  local,
  longitude = -0.2437,
  latitude = 52.5695,
  point_id = "Peterborough",
  method = "bilinear"
)

lagged_dt <- compose_time_lagged_ensemble(
  point_dt,
  dispatches = 6,
  require_members = 18,
  incomplete = "drop"
)

rate_dt <- convert_precipitation_rate(
  lagged_dt,
  unknown = "error"
)

accumulated_dt <- accumulate_ensemble(
  rate_dt,
  source = "rate",
  value_column = "rate_mm_per_hour",
  require_complete = TRUE
)
```

## Plot the forecast

```r
plot_ensemble_series(
  rate_dt,
  value_column = "rate_mm_per_hour",
  y_label = "Precipitation rate (mm h-1)",
  title = "MOGREPS-UK precipitation rate at Peterborough"
)

plot_ensemble_cumulative(
  accumulated_dt,
  title = "MOGREPS-UK cumulative precipitation at Peterborough"
)

plot_cumulative_summary(
  accumulated_dt,
  require_members = 18,
  title = "MOGREPS-UK cumulative precipitation summary"
)

plot_member_availability(
  lagged_dt,
  required_members = 18
)
```

## Native accumulation products

MOGREPS-UK also supplies interval products such as:

```text
precipitation_accumulation-PT15M.nc
precipitation_accumulation-PT01H.nc
rainfall_accumulation-PT15M.nc
rainfall_accumulation-PT01H.nc
```

Do not integrate these as rates. After extraction and conversion to millimetres, call:

```r
accumulated_dt <- accumulate_ensemble(
  interval_dt,
  source = "interval_accumulation",
  value_column = "interval_precipitation_mm"
)
```

## MOGREPS-UK structure

The object hierarchy is:

```text
uk-ensemble/YYYY/MM/DD/THHMMZ/
<valid-time>-<lead-time>-<variable>.nc
```

Each inspected file contains three internal realisations. Six hourly cycles therefore provide up to 18 time-lagged forecasts at a common valid time. The package reads the realisation coordinate from every file instead of hard-coding identifiers.

## Outputs and reproducibility

`download_data()` writes `download_manifest.csv` before transfer. It preserves dispatch directories, skips existing non-empty files by default, downloads to `.part` files and renames only after success.

## Repository checks

The included GitHub Actions workflow runs:

```r
devtools::test()
devtools::check()
```

## Flode code style

The package follows the Flode conventions used by the Forecasting and Warning Team:

- full mandatory header blocks in every R source file;
- snake_case verbs for functions;
- descriptive snake_case variables;
- `_dt` suffixes for data.table objects;
- explicit namespaces in package code;
- `data.table` conventions where style guidance differs from tidyverse;
- roxygen2 documentation for public functions;
- inline comments explaining decisions and assumptions;
- `data.table::fwrite()` for delimited outputs;
- no `.RData` files.

## Limitations

- `available_dispatches()` constructs recent hourly prefixes. `catalogue()` confirms which prefixes contain matching objects.
- Completeness is assessed for the requested variable and valid times, not for every product in a cycle.
- Rate accumulation uses trapezoidal integration. Native interval-accumulation products are preferable where their semantics match the analysis.
- The common period with all 18 forecasts is shorter than the T+126 horizon of each source cycle because the cycles begin at different times.

## Licence

MIT. Met Office source data retains its own licence and attribution requirements.
