# SSFC Chemical Contaminant Data Processor
# ==========================================
# Reshapes and standardises tissue contaminant data from a wide-format
# lab CSV into three tidy, FAIR-ready output files — one per contaminant class.
#
# Input:  transformed_chemical_data_example.csv (tidy format: samples as rows, contaminants as columns)
# Output: trace_metals_in_biomatter.csv
#         polycyclic_aromatic_hydrocarbons_in_biomatter.csv
#         polychlorinated_biphenyls_in_biomatter.csv
#
# Run from the directory containing transformed_chemical_data_example.csv.
# Requires: pandas

import re
import pandas as pd
from datetime import datetime, timezone

# ============================================================
# 1. READ AND RESHAPE
# ============================================================

df = pd.read_csv("transformed_chemical_data_example.csv")

# Wide -> long (pivot_longer equivalent)
df_long = df.melt(
    id_vars=["species", "type", "unit"],
    var_name="name",
    value_name="value"
)

# Long -> wide: contaminants (species) become columns, samples become rows
df_wide = (
    df_long
    .pivot_table(
        index=["type", "unit", "name"],
        columns="species",
        values="value",
        aggfunc="first"
    )
    .reset_index()
)
df_wide.columns.name = None

# Split by contaminant class; drop all-NA columns within each group
groups = {
    t: df_wide[df_wide["type"] == t].dropna(axis=1, how="all").copy()
    for t in df_wide["type"].unique()
}

# ============================================================
# 2. CREATE SAMPLE IDs
# ============================================================
# Sample name format: "ANZ21201--SB2-1--Sphaerotylus--3194448.1"
#                      expedition--station-rep--species--sampleID.rep

def make_id(name: str) -> str:
    parts = name.split("--")
    return f"{parts[1]}-{parts[2]}"

for key, grp in groups.items():
    grp["id"] = grp["name"].apply(make_id)
    grp.drop(columns=["name", "unit", "type"], inplace=True)

    meas_cols = [c for c in grp.columns if c != "id"]
    grp.rename(columns={c: f"{c} [mg/kg]" for c in meas_cols}, inplace=True)

    groups[key] = grp[["id"] + [c for c in grp.columns if c != "id"]]

# ============================================================
# 3. ADD SPATIAL AND TEMPORAL METADATA
# ============================================================

for key, grp in groups.items():
    grp["latitude"]  = -77.85383
    grp["longitude"] = 166.7759
    grp["time"]      = datetime(2023, 10, 21, tzinfo=timezone.utc)
    grp.columns      = [c.lower() for c in grp.columns]

    front = ["id", "time", "latitude", "longitude"]
    rest  = [c for c in grp.columns if c not in front]
    groups[key] = grp[front + rest]

# ============================================================
# 4. STANDARDISE NAMING AND DATA TYPES
# ============================================================

# Trace metals: enforce numeric type
tm = groups["trace metals"]
num_cols = [c for c in tm.columns if c not in ("id", "time")]
groups["trace metals"][num_cols] = tm[num_cols].apply(pd.to_numeric, errors="coerce")

# PAHs: correct two non-standard names
pah_key = "Polycyclic Aromatic Hydrocarbons in Biomatter"
groups[pah_key].rename(columns={
    "benzo[a]pyrene (bap) [mg/kg]":     "benzo[a]pyrene [mg/kg]",
    "indeno(1,2,3-c,d)pyrene [mg/kg]":  "indeno[1,2,3-cd]pyrene [mg/kg]",
}, inplace=True)

# PCBs: expand abbreviated prefix to full name
pcb_key = "Polychlorinated biphenyls in Biomatter"
groups[pcb_key].rename(
    columns=lambda c: re.sub(r"(?i)^pcb-", "polychlorinated biphenyl ", c),
    inplace=True
)

# ============================================================
# 5. EXPORT
# ============================================================

name_map = {
    "trace metals":
        "trace_metals_in_biomatter.csv",
    "Polycyclic Aromatic Hydrocarbons in Biomatter":
        "polycyclic_aromatic_hydrocarbons_in_biomatter.csv",
    "Polychlorinated biphenyls in Biomatter":
        "polychlorinated_biphenyls_in_biomatter.csv",
}

for key, filename in name_map.items():
    groups[key].to_csv(filename, index=False)
    print(f"Wrote: {filename}")
