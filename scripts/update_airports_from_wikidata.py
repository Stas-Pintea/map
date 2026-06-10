#!/usr/bin/env python3
import csv
import io
import json
import re
import ssl
import urllib.parse
import urllib.request

OURAIRPORTS_AIRPORTS_URL = "https://davidmegginson.github.io/ourairports-data/airports.csv"
WIKIDATA_ENDPOINT = "https://query.wikidata.org/sparql"
USER_AGENT = "ski-map-airports-updater/2.0"

AIRPORT_TYPES = {"large_airport", "medium_airport", "small_airport"}
INTERNATIONAL_AIRPORT_QID = "Q644371"
IATA_RE = re.compile(r"^[A-Z0-9]{3}$")


def fetch_url(url: str, ssl_ctx) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=120, context=ssl_ctx) as response:
        return response.read().decode("utf-8-sig")


def fetch_wikidata_international_iatas(ssl_ctx) -> set[str]:
    query = f"""
SELECT ?iata WHERE {{
  ?item wdt:P31/wdt:P279* wd:{INTERNATIONAL_AIRPORT_QID}.
  ?item wdt:P238 ?iata.
}}
"""
    url = WIKIDATA_ENDPOINT + "?" + urllib.parse.urlencode({"format": "json", "query": query})
    req = urllib.request.Request(
        url,
        headers={"Accept": "application/sparql-results+json", "User-Agent": USER_AGENT},
    )
    with urllib.request.urlopen(req, timeout=120, context=ssl_ctx) as response:
        data = json.load(response)

    iatas = set()
    for row in data.get("results", {}).get("bindings", []):
        iata = row.get("iata", {}).get("value", "").strip().upper()
        if IATA_RE.fullmatch(iata):
            iatas.add(iata)
    return iatas


def is_international(row: dict[str, str], international_iatas: set[str]) -> bool:
    iata = row["iata_code"].strip().upper()
    searchable_text = f"{row.get('name', '')} {row.get('keywords', '')}".lower()
    return iata in international_iatas or "international" in searchable_text


def build_airports() -> list[dict]:
    ssl_ctx = ssl._create_unverified_context()
    international_iatas = fetch_wikidata_international_iatas(ssl_ctx)
    airports_csv = fetch_url(OURAIRPORTS_AIRPORTS_URL, ssl_ctx)

    airports = []
    seen_iatas = set()
    for row in csv.DictReader(io.StringIO(airports_csv)):
        iata = row["iata_code"].strip().upper()
        if not IATA_RE.fullmatch(iata):
            continue
        if iata in seen_iatas:
            continue
        if row["type"] not in AIRPORT_TYPES:
            continue
        if row["scheduled_service"] != "yes":
            continue
        if not is_international(row, international_iatas):
            continue

        airports.append(
            {
                "id": f"airport-{iata.lower()}",
                "name": row["name"].strip(),
                "country": row["iso_country"].strip(),
                "iata": iata,
                "lat": round(float(row["latitude_deg"]), 6),
                "lng": round(float(row["longitude_deg"]), 6),
            }
        )
        seen_iatas.add(iata)

    airports.sort(key=lambda airport: (airport["country"], airport["name"], airport["iata"]))
    return airports


def main():
    airports = build_airports()
    with open("data/airports.json", "w", encoding="utf-8") as f:
        json.dump(airports, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"Saved {len(airports)} airports to data/airports.json")


if __name__ == "__main__":
    main()
