# Principles

The following seven principles guide how Antarctic and Southern Ocean data should be managed, described, and shared to maximise their long-term value and interoperability.

:::{list-table}
:header-rows: 1
:widths: 20 35 45

* - Principle
  - Statement
  - Context
* - **Metadata**
  - Data are best represented by metadata described with an internationally recognised standard.
  - Metadata should carry attributes that enable discovery, access, context, and reuse. Well-structured metadata is easily exchanged across repositories and catalogues, and indexed by federated search tools.
* - **Data Granularity**
  - Data are best described and archived in their most granular, usable form appropriate to the discipline and data type.
  - Some disciplines are well served by project-level metadata; for others, utility is significantly improved when data are described and archived at a finer level of granularity.
* - **Data are Standardised**
  - Standardised data formats in widespread use worldwide increase data utility.
  - Standard formats promote data system interoperability and simplify aggregation across multiple data sources.
* - **Data are Defined with Controlled Vocabularies**
  - Data should be evaluated for attributes that carry different meanings to producers and users, and across disciplines.
  - Controlled vocabularies promote interoperability and reuse by ensuring shared understanding of terms.

    A layered approach to vocabularies is recommended:

    - [GCMD Keywords](https://www.earthdata.nasa.gov/learn/find-data/idn/gcmd-keywords) are used at the dataset level to describe the overall scientific topics and support discovery
    - [Climate Forecast (CF) Conventions](https://cfconventions.org/) are used where possible for standardised variable naming, ensuring compatibility with widely used data formats (e.g. NetCDF).
    - [NERC Vocabulary](https://vocab.nerc.ac.uk/) vocabularies are used to extend CF conventions, providing standardised, domain-specific terms for parameters and metadata elements where suitable CF terms do not exist.

    Together, these vocabularies support both data discovery (GCMD) and semantic precision and interoperability (CF and NERC).
* - **Data are Accessible**
  - Data are most accessible when available in an immediately usable form.
  - Data should be published as soon as practicable. A URL in the metadata pointing directly to a single data file enables automated systems and AI-driven workflows to integrate with the data. Files locked in non-standardised archives, behind passwords, or within access-restricted systems are significantly harder to consume programmatically.
* - **Data Repositories are Trustworthy**
  - Third-party repositories should be evaluated for quality and carry recognised certification.
  - Long-term preservation must be guaranteed. Repositories with [CoreTrustSeal](https://www.coretrustseal.org/) certification provide assurance of quality and longevity. Good repository selection also promotes data discovery and ensures data legacy.
* - **CARE Principles for Indigenous Data Governance**
  - Indigenous data should be managed so that Indigenous governance over the data and its use is respected.
  - The application of all other principles must never compromise [Māori Data Sovereignty](https://www.royalsociety.org.nz/assets/Mana-Raraunga-DataSovereignty-web-V1.pdf). The [CARE Principles](https://doi.org/10.5334/dsj-2020-043) — Collective Benefit, Authority to Control, Responsibility, and Ethics — provide the framework for Indigenous data governance.
:::
