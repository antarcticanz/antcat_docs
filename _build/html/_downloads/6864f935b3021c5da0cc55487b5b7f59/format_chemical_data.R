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

library(tidyverse)

# ============================================================
# 1. READ AND RESHAPE
# ============================================================

ds_tissue <- read.csv("transformed_chemical_data_example.csv", check.names = FALSE) %>%
  # Wide -> long: each row is one contaminant x one sample
  pivot_longer(., -c("species", "type", "unit")) %>%
  # Long -> wide: contaminants become columns, samples become rows
  pivot_wider(., names_from = "species", values_from = "value") %>%
  # Split into a named list by contaminant class
  split(., factor(.$type, levels = unique(.$type))) %>%
  # Drop columns that are entirely NA within each class
  map(~ select(.x, where(~ !all(is.na(.)))))


# ============================================================
# 2. CREATE SAMPLE IDs
# ============================================================
# Sample name format: "ANZ21201--SB2-1--Sphaerotylus--3194448.1"
#                      expedition--station-rep--species--sampleID.rep

ds_tissue <- ds_tissue %>%
  map(~ .x %>%
        rowwise() %>%
        mutate(
          id = paste0(
            str_split(name, "--")[[1]][2],   # station-rep  e.g. "SB2-1"
            "-",
            str_split(name, "--")[[1]][3]    # tissue       e.g. "Sphaerotylus"
          )
        ) %>%
        ungroup() %>%
        select(-name, -unit, -type) %>%
        rename_with(~ paste0(.x, " [mg/kg]"), -id) %>%
        select(id, everything())
  )


# ============================================================
# 3. ADD SPATIAL AND TEMPORAL METADATA
# ============================================================

ds_tissue <- ds_tissue %>%
  map(~ .x %>%
        mutate(
          latitude  = -77.85383,
          longitude = 166.7759,
          time      = ymd_hms("2023-10-21T00:00:00Z")
        ) %>%
        rename_with(tolower) %>%
        select(id, time, latitude, longitude, everything())
  )


# ============================================================
# 4. STANDARDISE NAMING AND DATA TYPES
# ============================================================

# Trace metals: enforce numeric type
ds_tissue$`trace metals` <- ds_tissue$`trace metals` %>%
  mutate(across(-c(id, time), as.numeric))

# PAHs: correct two non-standard names
ds_tissue$`Polycyclic Aromatic Hydrocarbons in Biomatter` <-
  ds_tissue$`Polycyclic Aromatic Hydrocarbons in Biomatter` %>%
  rename(
    `benzo[a]pyrene [mg/kg]`         = `benzo[a]pyrene (bap) [mg/kg]`,
    `indeno[1,2,3-cd]pyrene [mg/kg]` = `indeno(1,2,3-c,d)pyrene [mg/kg]`
  )

# PCBs: expand abbreviated prefix to full name
ds_tissue$`Polychlorinated biphenyls in Biomatter` <-
  ds_tissue$`Polychlorinated biphenyls in Biomatter` %>%
  rename_with(~ str_replace_all(., regex("^pcb-", ignore_case = TRUE),
                                "polychlorinated biphenyl "))


# ============================================================
# 5. EXPORT
# ============================================================

write.csv(ds_tissue$`trace metals`,
          "trace_metals_in_biomatter.csv", row.names = FALSE)

write.csv(ds_tissue$`Polycyclic Aromatic Hydrocarbons in Biomatter`,
          "polycyclic_aromatic_hydrocarbons_in_biomatter.csv", row.names = FALSE)

write.csv(ds_tissue$`Polychlorinated biphenyls in Biomatter`,
          "polychlorinated_biphenyls_in_biomatter.csv", row.names = FALSE)

cat("Done.\n")
