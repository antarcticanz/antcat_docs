# Schema.org

The catalogue implements a Schema.org metadata profile for all public records. Schema.org is a structured data format developed by Bing, Google, and Yahoo to make web content machine-readable. The catalogue uses it so that Google Dataset Search and POLDER Federated Search can efficiently crawl and index its records. It is also used by the Oceanum Datamesh.

The following fields are carried in each record's Schema.org profile:

| Field | Description |
|:------|:------------|
| `name` | Record title |
| `datePublished` | Publication date |
| `description` | Abstract |
| `identifier` | DOI |
| `keywords` | Subject keywords |
| `creator` | Data creator(s) |
| `publisher` | Publishing organisation |
| `distribution` | `DataDownload` for data files; `DataLink` (custom field) for resource links |
| `spatialCoverage` | Geographic extent |
| `temporalCoverage` | Temporal extent |
| `license` | Data licence |
| `citation` | Recommended citation |

:::{seealso}
- [Science On Schema.Org (SOSO) Guidance Documents](https://github.com/ESIPFed/science-on-schema.org)
- [POLDER Best Practice Guide to Implementing Schema.Org for Data Discovery](https://repository.oceanbestpractices.org/bitstream/handle/11329/2301/POLDER%20schema.org%20Best%20Practice%20Guide.pdf?sequence=1)
:::
