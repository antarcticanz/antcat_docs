# Data Formatting

These tutorials walk through real Antarctic data workflows — from raw lab or instrument output to clean, FAIR-ready files. Each tutorial is available in both R and Python and shows the data structure at every stage of processing.

| Tutorial | Data Type | Input | Output |
|----------|-----------|-------|--------|
| {doc}`ssfc_tutorial` | Chemical contaminants in tissue | Wide-format lab CSV | Tidy CSVs split by contaminant class |
| {doc}`netcdf_tutorial` | Moored CTD time series | Per-depth CSVs | CF-1.12 compliant NetCDF |

:::{tip}
Run each script from the directory containing your input CSV files. No `setwd()` or absolute paths needed — just set that folder as your working directory before running.
:::
