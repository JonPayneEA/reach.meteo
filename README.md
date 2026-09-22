# reach.meteo

`reach.meteo` provides a consistent R interface for discovering, cataloguing, downloading, reading and analysing public Met Office meteorological data.

The package supports three product families:

- UK radar observations;
- UKV deterministic forecasts;
- MOGREPS-UK ensemble forecasts.

The package separates remote discovery from file transfer. Catalogue and plotting functions inspect object metadata first. `download_data()` performs the transfer only after the user has reviewed the selected product, dispatches, variables, lead times and expected volume.

## Status

`reach.meteo` is a Tier 2 analytical package developed in the Flode style. The public Met Office object stores are unsupported services. Check catalogue completeness, source metadata, units and results before operational use.

## Core workflow

All supported products follow the same broad sequence:

```text
Define product
    ↓
Discover or select time coverage
    ↓
Build a filtered request
    ↓
Catalogue remote objects
    ↓
Review variables, timesteps and transfer volume
    ↓
Download selected files
    ↓
Read fields or extract point and polygon values
    ↓
Analyse and plot
```

Radar is observation-based and does not use forecast dispatch selection. UKV and MOGREPS-UK use a dispatch-first workflow so the package does not traverse the full forecast archive.

## Installation

Install from GitHub after replacing the placeholder with the repository account:

```r
install.packages("pak")

pak::pak(
  "YOUR-GITHUB-ACCOUNT/reach.meteo"
)
```

For local package development:

```r
install.packages(
  c(
    "devtools",
    "testthat"
  )
)

devtools::load_all(
  ".",
  reset = TRUE
)

devtools::test()

devtools::check()
```

Generate documentation after editing roxygen2 comments:

```r
devtools::document()
```

## Package design

### Remote catalogues

A remote catalogue contains object metadata, not downloaded meteorological arrays. Typical fields include:

```text
key
size_bytes
last_modified
variable
forecast_reference_time
valid_time
lead_time_hours
run_type
```

### Local catalogues

`download_data()` adds local file paths and returns a local catalogue. Reading and spatial extraction functions operate on those files.

### Exact variable names

Forecast object selection uses exact logical variable names such as:

```r
"precipitation_rate.nc"
```

This avoids accidental matches against related products such as one-hour maxima or interval accumulations.

### No implicit downloads

The following operations do not download NetCDF or radar files:

```r
available_dispatches()
select_dispatches()
forecast_request()
catalogue()
check_forecast_timesteps()
plot_forecast_timesteps()
plot_dispatch_timesteps()
```

The transfer begins only when the user calls:

```r
download_data()
```

# Radar observations

## Define the radar product

```r
library(reach.meteo)

radar_product <- uk_radar()

radar_product
```

Radar observations do not have forecast dispatches or lead times. Build the radar catalogue directly:

```r
radar_catalogue <- catalogue(
  radar_product
)

radar_catalogue
```

Inspect the available variables before downloading:

```r
available_variables(
  radar_catalogue
)
```

Filter the remote catalogue to the required variable and period using the package's radar catalogue filters. Review the result before transfer:

```r
radar_selected <- filter_catalogue(
  radar_catalogue,
  variable = "rainfall_rate",
  start_time = as.POSIXct(
    "2026-09-01 00:00:00",
    tz = "UTC"
  ),
  end_time = as.POSIXct(
    "2026-09-01 06:00:00",
    tz = "UTC"
  )
)

radar_selected
```

Download the selected observations:

```r
radar_local <- download_data(
  radar_selected,
  destination = file.path(
    "data",
    "radar"
  )
)
```

Read one radar field:

```r
radar_field <- read_field(
  product = radar_product,
  file = radar_local@records$local_file[1]
)

radar_field
```

Plot the raster data:

```r
terra::plot(
  radar_field@data
)
```

Extract a point value:

```r
radar_point <- extract_points(
  radar_field,
  points = data.frame(
    point_id = "Peterborough",
    longitude = -0.2437,
    latitude = 52.5695
  ),
  method = "bilinear"
)

radar_point
```

Extract polygon summaries:

```r
catchment_values <- extract_polygons(
  radar_field,
  polygons = catchments,
  fun = "mean"
)

catchment_values
```

# UKV deterministic forecasts

## Define a UKV product

```r
ukv_product <- ukv(
  variables = "precipitation_rate.nc"
)

ukv_product
```

## Discover recent dispatches

UKV dispatches use a flat timestamped prefix beneath the deterministic product path. Discovery lists dispatch prefixes without traversing every forecast object:

```r
ukv_dispatches <- available_dispatches(
  product = ukv_product,
  lookback_days = 2
)

ukv_dispatches

ukv_dispatches@records
```

The dispatch table classifies each UKV run as:

```text
nowcast
short
medium
```

## Select forecast coverage

Latest nowcast:

```r
selected_nowcast <- select_dispatches(
  ukv_dispatches,
  coverage = "nowcast"
)
```

Latest short run:

```r
selected_short <- select_dispatches(
  ukv_dispatches,
  coverage = "short"
)
```

Latest medium run:

```r
selected_medium <- select_dispatches(
  ukv_dispatches,
  coverage = "medium"
)
```

Latest dispatch from each class:

```r
selected_ukv <- select_dispatches(
  ukv_dispatches,
  coverage = "nowcast_short_medium"
)

selected_ukv
```

Select a known dispatch explicitly:

```r
selected_dispatch <- select_dispatches(
  ukv_dispatches,
  dispatch = as.POSIXct(
    "2026-09-01 03:00:00",
    tz = "UTC"
  )
)
```

## Build a request

```r
ukv_request <- forecast_request(
  dispatches = selected_ukv,
  variables = "precipitation_rate.nc",
  minimum_lead_hours = 0,
  maximum_lead_hours = 126
)

ukv_request
```

## Catalogue the selected objects

```r
ukv_remote <- catalogue(
  ukv_request
)

ukv_remote
```

Inspect object records:

```r
ukv_remote@records[
  order(
    forecast_reference_time,
    lead_time_hours
  ),
  .(
    forecast_reference_time,
    run_type,
    valid_time,
    lead_time_hours,
    variable,
    size_bytes,
    key
  )
]
```

## Check UKV timestep availability

```r
ukv_timesteps <- check_forecast_timesteps(
  catalogue = ukv_remote,
  variable = "precipitation_rate.nc"
)

ukv_timesteps
```

Check the observed spacing rather than assuming a fixed interval:

```r
ukv_timesteps[
  order(
    forecast_reference_time,
    lead_time_hours
  ),
  .(
    lead_time_hours,
    interval_hours = c(
      NA_real_,
      diff(
        lead_time_hours
      )
    )
  ),
  by = .(
    run_type,
    forecast_reference_time
  )
]
```

## Plot UKV dispatch coverage

Plot one dispatch:

```r
plot_forecast_timesteps(
  catalogue = ukv_remote,
  variable = "precipitation_rate.nc",
  maximum_lead_hours = 126
)
```

Compare selected nowcast, short and medium dispatches:

```r
plot_dispatch_timesteps(
  catalogue = ukv_remote,
  variable = "precipitation_rate.nc",
  maximum_lead_hours = 126
)
```

The plotting functions return `ggplot` objects, so normal layers can be added:

```r
plot_dispatch_timesteps(
  catalogue = ukv_remote,
  variable = "precipitation_rate.nc",
  maximum_lead_hours = 126
) +
  ggplot2::labs(
    caption = paste(
      "Source: Met Office public forecast object catalogue."
    )
  )
```

## Download UKV data

```r
ukv_local <- download_data(
  ukv_remote,
  destination = file.path(
    "data",
    "ukv"
  ),
  overwrite = FALSE,
  preserve_folders = TRUE
)
```

`download_data()` writes a manifest, uses temporary `.part` files, skips existing non-empty files by default and preserves dispatch folders.

## Read and extract UKV data

Read a selected deterministic field:

```r
ukv_field <- read_field(
  product = ukv_product,
  file = ukv_local@records$local_file[1]
)
```

Extract a point:

```r
ukv_point <- extract_points(
  ukv_field,
  points = data.frame(
    point_id = "Peterborough",
    longitude = -0.2437,
    latitude = 52.5695
  ),
  method = "bilinear"
)
```

Extract catchment means:

```r
ukv_catchments <- extract_polygons(
  ukv_field,
  polygons = catchments,
  fun = "mean"
)
```

# MOGREPS-UK ensemble forecasts

## MOGREPS-UK object structure

MOGREPS-UK uses nested hourly dispatch prefixes:

```text
uk-ensemble/YYYY/MM/DD/THHMMZ/
```

Objects use:

```text
<valid-time>-<lead-time>-<variable>.nc
```

For example:

```text
uk-ensemble/2026/09/01/T0000Z/
20260901T0015Z-PT0000H15M-precipitation_rate.nc
```

The inspected files contain three internal realisations. The package reads the NetCDF `realization` coordinate and does not infer member IDs from the path.

Six successive hourly cycles can be aligned by valid time to form an 18-forecast time-lagged ensemble.

## Define the MOGREPS-UK product

```r
mogreps_product <- mogreps_uk(
  variables = "precipitation_rate.nc"
)
```

## Discover and select six dispatches

```r
mogreps_dispatches <- available_dispatches(
  product = mogreps_product,
  lookback_days = 2
)

selected_mogreps <- select_dispatches(
  mogreps_dispatches,
  coverage = "latest_six"
)
```

## Build and catalogue the request

```r
mogreps_request <- forecast_request(
  dispatches = selected_mogreps,
  variables = "precipitation_rate.nc",
  minimum_lead_hours = 0,
  maximum_lead_hours = 126
)

mogreps_remote <- catalogue(
  mogreps_request
)

mogreps_remote
```

Review the object count and transfer volume before downloading:

```r
mogreps_remote@records[
  ,
  .(
    objects = .N,
    transfer_gib = sum(
      size_bytes,
      na.rm = TRUE
    ) / 1024^3,
    first_valid_time = min(
      valid_time
    ),
    final_valid_time = max(
      valid_time
    )
  ),
  by = forecast_reference_time
]
```

## Download MOGREPS-UK data

```r
mogreps_local <- download_data(
  mogreps_remote,
  destination = file.path(
    "data",
    "mogreps"
  ),
  overwrite = FALSE
)
```

## Inspect one downloaded ensemble file

```r
ensemble_file <- read_ensemble_file(
  mogreps_local$records$local_file[1]
)

ensemble_file$realisations

ensemble_file$data
```

Raster layers are renamed using the native identifiers:

```text
realisation_20
realisation_21
realisation_22
```

The actual IDs are read from every file. They are not hard-coded.

## Extract all internal realisations at one point

```r
point_dt <- extract_ensemble_point(
  mogreps_local,
  longitude = -0.2437,
  latitude = 52.5695,
  point_id = "Peterborough",
  method = "bilinear"
)

point_dt
```

Each row retains:

```text
point_id
longitude
latitude
forecast_reference_time
valid_time
lead_time_hours
variable
realisation
member_id
value
units
source_file
```

The package combines dispatch and native realisation to create a unique time-lagged member ID:

```text
20260901T0000Z_r20
```

## Compose the 18-member time-lagged ensemble

```r
lagged_dt <- compose_time_lagged_ensemble(
  point_dt,
  dispatches = 6,
  require_members = 18,
  incomplete = "retain"
)
```

Inspect member availability:

```r
attr(
  lagged_dt,
  "member_availability"
)
```

Plot it:

```r
plot_member_availability(
  lagged_dt,
  required_members = 18
)
```

Retain only valid times with all 18 forecasts:

```r
complete_dt <- compose_time_lagged_ensemble(
  point_dt,
  dispatches = 6,
  require_members = 18,
  incomplete = "drop"
)
```

The common 18-member period is shorter than the T+126 horizon of each source cycle because the six cycles start at different times.

## Convert precipitation rate

```r
rate_dt <- convert_precipitation_rate(
  complete_dt,
  value_column = "value",
  unit_column = "units",
  unknown = "error"
)
```

Recognised `kg m-2 s-1` values are converted to `mm h-1`. Unknown units cause an error by default so values are not silently relabelled.

## Plot the 18 member rate series

```r
plot_ensemble_series(
  rate_dt,
  value_column = "rate_mm_per_hour",
  y_label = "Precipitation rate (mm h-1)",
  title = paste(
    "MOGREPS-UK precipitation rate at Peterborough"
  )
)
```

Summarise the ensemble:

```r
rate_summary_dt <- summarise_ensemble(
  rate_dt,
  value_column = "rate_mm_per_hour",
  require_members = 18
)

plot_ensemble_summary(
  rate_summary_dt,
  y_label = "Precipitation rate (mm h-1)",
  title = "MOGREPS-UK precipitation-rate summary"
)
```

## Calculate interval and cumulative precipitation from rate

```r
accumulated_dt <- accumulate_ensemble(
  rate_dt,
  source = "rate",
  value_column = "rate_mm_per_hour",
  method = "trapezoidal",
  require_complete = TRUE
)
```

The package:

- derives durations from consecutive valid times;
- applies trapezoidal integration to adjacent rates;
- starts every member from a common zero;
- rejects duplicate or non-increasing times;
- rejects negative interval depths;
- stops cumulative totals after a missing interval.

Plot cumulative member totals:

```r
plot_ensemble_cumulative(
  accumulated_dt,
  title = paste(
    "MOGREPS-UK cumulative precipitation at Peterborough"
  )
)
```

Plot cumulative percentile bands:

```r
plot_cumulative_summary(
  accumulated_dt,
  require_members = 18,
  title = paste(
    "MOGREPS-UK cumulative precipitation summary"
  )
)
```

Compare final totals:

```r
plot_final_member_totals(
  accumulated_dt
)
```

## Native accumulation products

MOGREPS-UK includes products such as:

```text
precipitation_accumulation-PT15M.nc
precipitation_accumulation-PT01H.nc
rainfall_accumulation-PT15M.nc
rainfall_accumulation-PT01H.nc
snowfall_accumulation-PT15M.nc
snowfall_accumulation-PT01H.nc
hail_fall_accumulation-PT15M.nc
hail_fall_accumulation-PT01H.nc
```

These represent interval accumulations and must not be integrated as rates. After conversion to millimetres, sum them directly:

```r
accumulated_dt <- accumulate_ensemble(
  interval_dt,
  source = "interval_accumulation",
  value_column = "interval_precipitation_mm"
)
```

# Catalogue and download controls

## Inspect before transfer

Always inspect:

```r
remote

remote$records[
  ,
  .(
    objects = .N,
    transfer_gib = sum(
      size_bytes,
      na.rm = TRUE
    ) / 1024^3
  )
]
```

## Restartable downloads

`download_data()`:

- writes a CSV manifest before transfer;
- preserves dispatch directories;
- skips existing non-empty files unless `overwrite = TRUE`;
- downloads to temporary `.part` files;
- renames a file only after successful completion;
- retries failed requests.

## Do not commit downloaded data

The included `.gitignore` excludes:

```text
data/
outputs/
*.part
.RData
.Rhistory
```

# Development standards

The package follows Flode coding conventions:

- mandatory file headers;
- snake_case verb names for functions;
- descriptive snake_case nouns for variables;
- `_dt` suffixes for `data.table` objects;
- explicit namespaces in package code;
- `data.table` conventions where guidance differs from tidyverse;
- roxygen2 documentation for public functions;
- inline comments explaining decisions, assumptions and failure conditions;
- `data.table::fwrite()` for delimited outputs;
- no `.RData` workflow.

# Tests and checks

Run:

```r
devtools::document()

devtools::test()

devtools::check()
```

The package test suite covers:

- MOGREPS nested path parsing;
- valid-time and lead-time parsing;
- six-cycle composition;
- 18-member completeness;
- precipitation-rate conversion;
- accumulation over unequal intervals;
- cumulative totals;
- plot return classes.

GitHub Actions runs package checks for pushes and pull requests.

# Limitations

- Public Met Office object stores are unsupported services.
- Catalogue completeness must be assessed for the requested product, variable and lead range.
- Native realisation identifiers can rotate between cycles.
- The package aligns time-lagged forecasts by valid time, not lead time.
- The complete 18-member period is shorter than each source cycle's full horizon.
- Rate integration estimates interval depth. Native accumulation products are preferable where their semantics match the analysis.
- Users must check source units and metadata before operational interpretation.

# Licence

The package uses the MIT licence. Source meteorological data retains its own licence and attribution requirements.
