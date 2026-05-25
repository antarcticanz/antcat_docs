# Search

GeoNetwork's legacy Q Search endpoint (`/srv/eng/q`) has been replaced by an ElasticSearch API. All queries use HTTP `POST` to:

```text
https://antcat.antarcticanz.govt.nz/geonetwork/srv/api/search/records/_search
```

The request body is JSON; the response is JSON. The examples below use Python (`requests`) and `curl`.

---

## Keyword

Search across all fields for a term.

::::{tab-set}
:::{tab-item} Python
:sync: python
```python
import requests

url = "https://antcat.antarcticanz.govt.nz/geonetwork/srv/api/search/records/_search"

query = {
    "from": 0,
    "size": 10,
    "query": {
        "query_string": {
            "query": "ocean"
        }
    }
}

response = requests.post(url, json=query)
records = response.json()["hits"]["hits"]
```
:::
:::{tab-item} curl
:sync: curl
```bash
curl -X POST "https://antcat.antarcticanz.govt.nz/geonetwork/srv/api/search/records/_search" \
  -H "Content-Type: application/json" \
  -d '{"from":0,"size":10,"query":{"query_string":{"query":"ocean"}}}'
```
:::
::::

---

## Records carrying data

Filter to records that include a data download link.

::::{tab-set}
:::{tab-item} Python
:sync: python
```python
query = {
    "from": 0,
    "size": 10,
    "query": {
        "query_string": {
            "query": '+linkProtocol:"WWW:DOWNLOAD-1.0-http--download"'
        }
    }
}

response = requests.post(url, json=query)
records = response.json()["hits"]["hits"]
```
:::
:::{tab-item} curl
:sync: curl
```bash
curl -X POST "https://antcat.antarcticanz.govt.nz/geonetwork/srv/api/search/records/_search" \
  -H "Content-Type: application/json" \
  -d '{"from":0,"size":10,"query":{"query_string":{"query":"+linkProtocol:\"WWW:DOWNLOAD-1.0-http--download\""}}}'
```
:::
::::

---

## Keyword + data filter

Combine a text search with the download filter.

::::{tab-set}
:::{tab-item} Python
:sync: python
```python
query = {
    "from": 0,
    "size": 10,
    "query": {
        "query_string": {
            "query": 'ocean +linkProtocol:"WWW:DOWNLOAD-1.0-http--download"'
        }
    }
}

response = requests.post(url, json=query)
records = response.json()["hits"]["hits"]
```
:::
:::{tab-item} curl
:sync: curl
```bash
curl -X POST "https://antcat.antarcticanz.govt.nz/geonetwork/srv/api/search/records/_search" \
  -H "Content-Type: application/json" \
  -d '{"from":0,"size":10,"query":{"query_string":{"query":"ocean +linkProtocol:\"WWW:DOWNLOAD-1.0-http--download\""}}}'
```
:::
::::

---

## All records

Return all public catalogue records. Increase `size` or use `from` to paginate.

::::{tab-set}
:::{tab-item} Python
:sync: python
```python
query = {
    "from": 0,
    "size": 1000,
    "query": {
        "match_all": {}
    }
}

response = requests.post(url, json=query)
records = response.json()["hits"]["hits"]
total   = response.json()["hits"]["total"]["value"]
```
:::
:::{tab-item} curl
:sync: curl
```bash
curl -X POST "https://antcat.antarcticanz.govt.nz/geonetwork/srv/api/search/records/_search" \
  -H "Content-Type: application/json" \
  -d '{"from":0,"size":1000,"query":{"match_all":{}}}'
```
:::
::::
