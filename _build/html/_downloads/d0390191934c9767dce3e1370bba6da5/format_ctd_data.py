# SHWD NetCDF Builder
# ====================
# Builds a CF-1.12 compliant NetCDF file from per-depth CSV files of
# detided moored CTD observations (HWD2 borehole, Ross Ice Shelf).
#
# Input:  shwd*_NoTides.csv (one file per instrument depth)
# Output: hwd2_ctd_detided.nc
#
# Run from the directory containing the input CSV files.
# Requires: numpy, pandas, netCDF4

import glob
import numpy as np
import pandas as pd
from netCDF4 import Dataset

# ============================================================
# 1. READ ALL DEPTH FILES
# ============================================================

files = sorted(glob.glob("shwd*_NoTides.csv"))
assert len(files) > 0, "No shwd*_NoTides.csv files found in current directory"

ds_notides = {
    f: pd.read_csv(f, parse_dates=["time"])
    for f in files
}

# ============================================================
# 2. DIAGNOSTIC: check timestamps are clean 30-min intervals
# ============================================================

step_s = 1800  # 30 minutes in seconds

diagnostics = []
for fname, df in ds_notides.items():
    t = pd.to_datetime(df["time"], utc=True).sort_values()
    gaps = t.diff().dropna().dt.total_seconds()
    diagnostics.append({
        "file":      fname,
        "start":     t.iloc[0],
        "end":       t.iloc[-1],
        "n_obs":     len(t),
        "min_gap_s": gaps.min(),
        "max_gap_s": gaps.max(),
    })

diag_df = pd.DataFrame(diagnostics)
print(diag_df.to_string())

assert diag_df["start"].nunique() == 1, "Files do not all start at the same time"
assert (diag_df["min_gap_s"] == step_s).all() and (diag_df["max_gap_s"] == step_s).all(), \
    "Timestamps are not all exactly 30 min apart"

# ============================================================
# 3. BUILD THE MASTER TIME GRID
# ============================================================
# Timestamps are confirmed clean — use start/end directly from the diagnostic.

min_t = diag_df["start"].min()
max_t = diag_df["end"].max()

master_time = pd.date_range(start=min_t, end=max_t, freq="30min", tz="UTC")
print(f"Time axis: {len(master_time)} steps from {min_t} to {max_t}")

# ============================================================
# 3. FIXED METADATA AND FILE CREATION
# ============================================================

depths  = [328, 366, 416, 496, 616]   # instrument depths (dbar)
lat_val = -80.65828
lon_val =  174.4613
fill    = np.nan

out_file = "hwd2_ctd_detided.nc"
nc = Dataset(out_file, "w", format="NETCDF4")

origin    = pd.Timestamp("1970-01-01", tz="UTC")
time_vals = (master_time - origin).total_seconds().values

nc.createDimension("time",  len(time_vals))
nc.createDimension("depth", len(depths))

# ============================================================
# 4. COORDINATE VARIABLES
# ============================================================

t_var = nc.createVariable("time", "f8", ("time",))
t_var.standard_name         = "time"
t_var.long_name             = "Time"
t_var.units                 = "seconds since 1970-01-01 00:00:00"
t_var.calendar              = "proleptic_gregorian"
t_var.coverage_content_type = "coordinate"
t_var[:]                    = time_vals

d_var = nc.createVariable("depth", "f8", ("depth",))
d_var.standard_name         = "depth"
d_var.long_name             = "Depth of instrument below sea surface"
d_var.units                 = "dbar"
d_var.positive              = "down"
d_var.coverage_content_type = "coordinate"
d_var[:]                    = depths

lat_var = nc.createVariable("latitude", "f8")
lat_var.standard_name = "latitude"
lat_var.long_name     = "Latitude of mooring"
lat_var.units         = "degrees_north"
lat_var[:]            = lat_val

lon_var = nc.createVariable("longitude", "f8")
lon_var.standard_name = "longitude"
lon_var.long_name     = "Longitude of mooring"
lon_var.units         = "degrees_east"
lon_var[:]            = lon_val

# ============================================================
# 5. DATA ARRAYS
# ============================================================

def fill_array(col_name):
    arr = np.full((len(master_time), len(depths)), fill)
    for j, df in enumerate(ds_notides.values()):
        t_j = pd.DatetimeIndex(df["time"]).tz_localize("UTC")
        idx = master_time.get_indexer(t_j)
        valid = idx >= 0
        arr[idx[valid], j] = df[col_name].values[valid]
    return arr

fields = {
    "sea_water_pressure":                 "sea_water_pressure (dbar)",
    "sea_water_absolute_salinity":        "sea_water_absolute_salinity (g kg-1)",
    "sea_water_conservative_temperature": "sea_water_conservative_temperature (degree_C)",
}

for var_name, col_name in fields.items():
    arr = fill_array(col_name)
    v = nc.createVariable(var_name, "f8", ("time", "depth"), fill_value=fill)
    v.standard_name         = var_name
    v.long_name             = var_name.replace("_", " ").title()
    v.coverage_content_type = "physicalMeasurement"
    v.coordinates           = "latitude longitude"
    v.comment               = "Quality-controlled with tidal cycles removed."
    v[:]                    = arr

# ============================================================
# 6. GLOBAL ATTRIBUTES
# ============================================================

nc.Conventions         = "CF-1.12"
nc.featureType         = "timeSeries"
nc.title               = ("Central Ross Ice Shelf Cavity Moored Observations "
                           "(CTD, detided) 2018-2022")
nc.summary             = ("Detided timeseries from moored oceanographic instruments "
                           "at the HWD2 borehole beneath the central Ross Ice Shelf. "
                           "Tidal cycles have been removed.")
nc.creator_name        = "Yingpu Xiahou"
nc.creator_email       = "xiahouli@outlook.com"
nc.creator_institution = "Earth Sciences New Zealand"
nc.creator_url         = "https://orcid.org/0000-0003-1279-0014"
nc.time_coverage_start = "2018-01-06T00:00:00Z"
nc.time_coverage_end   = "2022-08-06T15:30:00Z"
nc.geospatial_lat_min  = lat_val
nc.geospatial_lat_max  = lat_val
nc.geospatial_lon_min  = lon_val
nc.geospatial_lon_max  = lon_val
nc.metadata_link       = "https://www.seanoe.org/data/00973/108458"
nc.publisher_name      = "SEANOE"
nc.publisher_url       = "https://www.seanoe.org/"
nc.license             = "https://creativecommons.org/licenses/by/4.0/"

nc.close()
print(f"Wrote: {out_file}")
