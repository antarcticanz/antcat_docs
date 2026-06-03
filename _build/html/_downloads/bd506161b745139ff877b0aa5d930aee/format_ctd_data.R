# SHWD NetCDF Builder
# ====================
# Builds a CF-1.12 compliant NetCDF file from per-depth CSV files of
# detided moored CTD observations (HWD2 borehole, Ross Ice Shelf).
#
# Input:  shwd*_NoTides.csv (one file per instrument depth)
# Output: hwd2_ctd_detided.nc
#
# Run from the directory containing the input CSV files.

library(tidyverse)
library(RNetCDF)
options(scipen = 999)

# =============================================================================
# TUTORIAL: Building a CF-compliant NetCDF file for moored CTD observations
#           (detided / tidal cycles removed)
# =============================================================================
# This script reads per-depth CSV files of detided oceanographic data and writes
# them to a single NetCDF-4 file that follows the CF-1.12 conventions.
#
# We deliberately avoid wrapping steps in functions so every operation is
# visible and traceable — this is an illustrative walkthrough.
# =============================================================================


# =============================================================================
# 1. READ INPUT FILES
# =============================================================================
# Each CSV covers one instrument depth. We collect all of them into a named
# list so we can loop over depths later.

files_notides <- list.files(
  ".",
  pattern = "^shwd.*_NoTides\\.csv$",
  full.names = TRUE
)

stopifnot(length(files_notides) > 0)

# A named list: one data-frame per file (i.e. per depth)
ds_notides <- files_notides |>
  set_names(basename(files_notides)) |>
  map(read_csv)


# =============================================================================
# 2. BUILD THE MASTER TIME GRID
# =============================================================================
# Files have different lengths so we take the union of all timestamps and
# build a regular 30-min grid spanning the full deployment period.

# --- 2a. DIAGNOSTIC: check all files start at the same time and run at
#         even 30-min intervals before building the grid -------------------

step <- 30 * 60  # 30 minutes in seconds (we know the measurements are at 30 min intervals)

start_check <- ds_notides |>
  lapply(function(df) {
    t <- as.POSIXct(df[["time"]], tz = "UTC") |> sort()
    tibble(
      start   = first(t),
      end     = last(t),
      n_obs   = length(t),
      min_gap = min(diff(as.numeric(t))),
      max_gap = max(diff(as.numeric(t)))
    )
  }) |>
  bind_rows(.id = "file")

print(start_check)

# all files should share the same start, and min_gap == max_gap == 1800
stopifnot(n_distinct(start_check$start) == 1)
stopifnot(all(start_check$min_gap == step & start_check$max_gap == step))


# --- 2b. BUILD THE MASTER TIME GRID ---------------------------------------
# Timestamps are confirmed clean — use start/end directly from the diagnostic.

min_t <- min(start_check$start)
max_t <- max(start_check$end)

master_time <- seq(min_t, max_t, by = "30 min")

cat("Time axis:", length(master_time), "steps from", format(min_t), "to", format(max_t), "\n")


# --- 2c. DIAGNOSTIC: confirm each file's timestamps sit on the master grid --
# TRUE = file has an observation at that slot, FALSE = no observation.
# This reveals where each file ends relative to the full deployment period.

time_wide <- ds_notides |>
  names() |>
  lapply(function(fname) {
    t <- as.POSIXct(ds_notides[[fname]][["time"]], tz = "UTC")
    tibble(time = master_time, file = fname, present = master_time %in% t)
  }) |>
  bind_rows() |>
  pivot_wider(names_from = file, values_from = present)

View(time_wide)


# =============================================================================
# 3. FIXED METADATA
# =============================================================================

depths  <- c(328, 366, 416, 496, 616)   # instrument depths extracted from https://doi.org/10.1029/2025JC023511
lat_val <- -80.65828
lon_val <-  174.4613
fill    <- NaN                           # _FillValue for all data variables


# =============================================================================
# 4. CREATE THE NetCDF FILE AND DEFINE DIMENSIONS
# =============================================================================
# ---------------------------------------------------------------------------
# Why only two dimensions — time and depth?
# ---------------------------------------------------------------------------
# CF-1.12 §9 describes several featureTypes for discrete sampling geometries.
# A *timeSeries* featureType represents one fixed location sampled through time.
# When we have multiple depths at the same lat/lon mooring we extend that idea
# to a (time × depth) grid, which is the simplest and most interoperable
# layout for profile-like moored data.
#
# We intentionally omit a 'station' dimension because:
#   • There is only one mooring (HWD2). A station dimension with length 1 adds
#     structural complexity without conveying new information.
#   • Scalar (0-D) variables are the CF-recommended way to store a single
#     fixed coordinate such as latitude, longitude, and station_id when there
#     is no need to index across stations.
#   • Keeping just (time, depth) makes the file immediately readable by tools
#     that expect regular gridded arrays and simplifies downstream analysis.
# ---------------------------------------------------------------------------

out_file <- "hwd2_ctd_detided.nc"
ds       <- create.nc(out_file, format = "netcdf4")

# --- time dimension ---
# Length equals the number of 30-min steps on the master grid.
origin    <- as.POSIXct("1970-01-01 00:00:00", tz = "UTC")
time_vals <- as.numeric(difftime(master_time, origin, units = "secs"))

dim.def.nc(ds, "time", length(time_vals))

# --- depth dimension ---
# One position per instrument. Fixed across the deployment.
dim.def.nc(ds, "depth", length(depths))


# =============================================================================
# 5. COORDINATE VARIABLES
# =============================================================================
# CF requires a coordinate variable for every dimension: a 1-D variable with
# the same name as its dimension and appropriate attributes.

# --- time ---
var.def.nc(ds, "time", "NC_DOUBLE", "time")
att.put.nc(ds, "time", "standard_name",         "NC_CHAR", "time")
att.put.nc(ds, "time", "long_name",             "NC_CHAR", "Time")
att.put.nc(ds, "time", "units",                 "NC_CHAR", "seconds since 1970-01-01 00:00:00")
att.put.nc(ds, "time", "calendar",              "NC_CHAR", "proleptic_gregorian")
att.put.nc(ds, "time", "coverage_content_type", "NC_CHAR", "coordinate")
var.put.nc(ds, "time", time_vals)

# --- depth ---
var.def.nc(ds, "depth", "NC_DOUBLE", "depth")
att.put.nc(ds, "depth", "standard_name",         "NC_CHAR", "depth")
att.put.nc(ds, "depth", "long_name",             "NC_CHAR", "Depth of instrument below sea surface")
att.put.nc(ds, "depth", "units",                 "NC_CHAR", "dbar")
att.put.nc(ds, "depth", "positive",              "NC_CHAR", "down")
att.put.nc(ds, "depth", "coverage_content_type", "NC_CHAR", "coordinate")
var.put.nc(ds, "depth", depths)

# --- latitude (scalar — no dimension argument) ---
# Scalar coordinate variables are dimensionless in NetCDF. Because this mooring
# is fixed in space, one value covers the entire dataset. CF §5.7 endorses
# scalar coordinates for exactly this case.
var.def.nc(ds, "latitude", "NC_DOUBLE", NA)
att.put.nc(ds, "latitude", "standard_name", "NC_CHAR", "latitude")
att.put.nc(ds, "latitude", "long_name",     "NC_CHAR", "Latitude of mooring")
att.put.nc(ds, "latitude", "units",         "NC_CHAR", "degrees_north")
var.put.nc(ds, "latitude", lat_val)

# --- longitude (scalar) ---
var.def.nc(ds, "longitude", "NC_DOUBLE", NA)
att.put.nc(ds, "longitude", "standard_name", "NC_CHAR", "longitude")
att.put.nc(ds, "longitude", "long_name",     "NC_CHAR", "Longitude of mooring")
att.put.nc(ds, "longitude", "units",         "NC_CHAR", "degrees_east")
var.put.nc(ds, "longitude", lon_val)


# =============================================================================
# 6. FILL DATA ARRAYS  —  sea_water_pressure
# =============================================================================
# Files have different lengths so we use match() to slot each depth's
# observations into the correct master_time rows by timestamp.

arr_pressure <- array(
  NA_real_,
  dim      = c(length(master_time), length(depths)),
  dimnames = list(NULL, as.character(depths))
)

for (j in seq_along(depths)) {
  df  <- ds_notides[[j]]
  t_j <- as.POSIXct(df[["time"]], tz = "UTC")
  idx <- match(t_j, master_time)
  arr_pressure[idx, j] <- df[["sea_water_pressure (dbar)"]]
}

arr_pressure[is.na(arr_pressure)] <- fill

var.def.nc(ds, "sea_water_pressure", "NC_DOUBLE", c("time", "depth"))
att.put.nc(ds, "sea_water_pressure", "standard_name",         "NC_CHAR", "sea_water_pressure")
att.put.nc(ds, "sea_water_pressure", "long_name",             "NC_CHAR", "Pressure of sea water")
att.put.nc(ds, "sea_water_pressure", "units",                 "NC_CHAR", "dbar")
att.put.nc(ds, "sea_water_pressure", "coverage_content_type", "NC_CHAR", "physicalMeasurement")
att.put.nc(ds, "sea_water_pressure", "_FillValue",            "NC_DOUBLE", fill)
att.put.nc(ds, "sea_water_pressure", "coordinates",           "NC_CHAR", "latitude longitude")
att.put.nc(ds, "sea_water_pressure", "comment",               "NC_CHAR", "Quality-controlled with tidal cycles removed.")
var.put.nc(ds, "sea_water_pressure", arr_pressure)


# =============================================================================
# 7. FILL DATA ARRAYS  —  sea_water_absolute_salinity
# =============================================================================

arr_salinity <- array(
  NA_real_,
  dim      = c(length(master_time), length(depths)),
  dimnames = list(NULL, as.character(depths))
)

for (j in seq_along(depths)) {
  df  <- ds_notides[[j]]
  t_j <- as.POSIXct(df[["time"]], tz = "UTC")
  idx <- match(t_j, master_time)
  arr_salinity[idx, j] <- df[["sea_water_absolute_salinity (g kg-1)"]]
}

arr_salinity[is.na(arr_salinity)] <- fill

var.def.nc(ds, "sea_water_absolute_salinity", "NC_DOUBLE", c("time", "depth"))
att.put.nc(ds, "sea_water_absolute_salinity", "standard_name",         "NC_CHAR", "sea_water_absolute_salinity")
att.put.nc(ds, "sea_water_absolute_salinity", "long_name",             "NC_CHAR", "Absolute salinity of sea water")
att.put.nc(ds, "sea_water_absolute_salinity", "units",                 "NC_CHAR", "g kg-1")
att.put.nc(ds, "sea_water_absolute_salinity", "coverage_content_type", "NC_CHAR", "physicalMeasurement")
att.put.nc(ds, "sea_water_absolute_salinity", "_FillValue",            "NC_DOUBLE", fill)
att.put.nc(ds, "sea_water_absolute_salinity", "coordinates",           "NC_CHAR", "latitude longitude")
att.put.nc(ds, "sea_water_absolute_salinity", "comment",               "NC_CHAR", "Quality-controlled with tidal cycles removed.")
var.put.nc(ds, "sea_water_absolute_salinity", arr_salinity)


# =============================================================================
# 8. FILL DATA ARRAYS  —  sea_water_conservative_temperature
# =============================================================================

arr_temperature <- array(
  NA_real_,
  dim      = c(length(master_time), length(depths)),
  dimnames = list(NULL, as.character(depths))
)

for (j in seq_along(depths)) {
  df  <- ds_notides[[j]]
  t_j <- as.POSIXct(df[["time"]], tz = "UTC")
  idx <- match(t_j, master_time)
  arr_temperature[idx, j] <- df[["sea_water_conservative_temperature (degree_C)"]]
}

arr_temperature[is.na(arr_temperature)] <- fill

var.def.nc(ds, "sea_water_conservative_temperature", "NC_DOUBLE", c("time", "depth"))
att.put.nc(ds, "sea_water_conservative_temperature", "standard_name",         "NC_CHAR", "sea_water_conservative_temperature")
att.put.nc(ds, "sea_water_conservative_temperature", "long_name",             "NC_CHAR", "Conservative temperature of sea water")
att.put.nc(ds, "sea_water_conservative_temperature", "units",                 "NC_CHAR", "degree_C")
att.put.nc(ds, "sea_water_conservative_temperature", "coverage_content_type", "NC_CHAR", "physicalMeasurement")
att.put.nc(ds, "sea_water_conservative_temperature", "_FillValue",            "NC_DOUBLE", fill)
att.put.nc(ds, "sea_water_conservative_temperature", "coordinates",           "NC_CHAR", "latitude longitude")
att.put.nc(ds, "sea_water_conservative_temperature", "comment",               "NC_CHAR", "Quality-controlled with tidal cycles removed.")
var.put.nc(ds, "sea_water_conservative_temperature", arr_temperature)


# =============================================================================
# 9. GLOBAL ATTRIBUTES
# =============================================================================

att.put.nc(ds, "NC_GLOBAL", "Conventions",         "NC_CHAR", "CF-1.12")
att.put.nc(ds, "NC_GLOBAL", "featureType",         "NC_CHAR", "timeSeries")
att.put.nc(ds, "NC_GLOBAL", "title",               "NC_CHAR",
           "Central Ross Ice Shelf Cavity Moored Observations (CTD, detided) 2018–2022")
att.put.nc(ds, "NC_GLOBAL", "summary",             "NC_CHAR", paste(
  "Detided timeseries from moored oceanographic instruments at the HWD2 borehole",
  "beneath the central Ross Ice Shelf. Tidal cycles have been removed.",
  "These data support studies of under-ice shelf circulation and ice–ocean interactions."
))
att.put.nc(ds, "NC_GLOBAL", "creator_type",        "NC_CHAR", "person")
att.put.nc(ds, "NC_GLOBAL", "creator_name",        "NC_CHAR", "Yingpu Xiahou")
att.put.nc(ds, "NC_GLOBAL", "creator_email",       "NC_CHAR", "xiahouli@outlook.com")
att.put.nc(ds, "NC_GLOBAL", "creator_institution", "NC_CHAR", "Earth Sciences New Zealand")
att.put.nc(ds, "NC_GLOBAL", "creator_url",         "NC_CHAR", "https://orcid.org/0000-0003-1279-0014")
att.put.nc(ds, "NC_GLOBAL", "time_coverage_start", "NC_CHAR", "2018-01-06T00:00:00Z")
att.put.nc(ds, "NC_GLOBAL", "time_coverage_end",   "NC_CHAR", "2022-08-06T15:30:00Z")
att.put.nc(ds, "NC_GLOBAL", "geospatial_lat_min",  "NC_DOUBLE", lat_val)
att.put.nc(ds, "NC_GLOBAL", "geospatial_lat_max",  "NC_DOUBLE", lat_val)
att.put.nc(ds, "NC_GLOBAL", "geospatial_lon_min",  "NC_DOUBLE", lon_val)
att.put.nc(ds, "NC_GLOBAL", "geospatial_lon_max",  "NC_DOUBLE", lon_val)
att.put.nc(ds, "NC_GLOBAL", "metadata_link",       "NC_CHAR", "https://www.seanoe.org/data/00973/108458")
att.put.nc(ds, "NC_GLOBAL", "publisher_name",      "NC_CHAR", "SEANOE")
att.put.nc(ds, "NC_GLOBAL", "publisher_url",       "NC_CHAR", "https://www.seanoe.org/")
att.put.nc(ds, "NC_GLOBAL", "license",             "NC_CHAR", "https://creativecommons.org/licenses/by/4.0/")
att.put.nc(ds, "NC_GLOBAL", "comment",             "NC_CHAR",
           "All variables contain quality-controlled detided timeseries (tidal cycles removed). Variable names follow CF standard names without modification.")


# =============================================================================
# 10. INSPECT AND CLOSE
# =============================================================================

print.nc(ds)
close.nc(ds)

cat("Wrote:", out_file, "\n")
