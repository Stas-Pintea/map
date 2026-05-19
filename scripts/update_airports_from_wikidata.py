#!/usr/bin/env python3
import json
import ssl
import time
import urllib.parse
import urllib.request

ENDPOINT = "https://query.wikidata.org/sparql"
USER_AGENT = "ski-map-airports-updater/1.0"
BATCH_SIZE = 700


def parse_wkt_point(wkt: str):
    try:
        body = wkt[wkt.index("(") + 1:wkt.index(")")]
        lon, lat = body.split()
        return float(lat), float(lon)
    except Exception:
        return None


def fetch_batch(offset: int, limit: int, ssl_ctx):
    query = f'''
SELECT ?item ?itemLabel ?coord ?countryLabel ?iata WHERE {{
  ?item wdt:P31 wd:Q1248784.
  ?item wdt:P625 ?coord.
  OPTIONAL {{ ?item wdt:P17 ?country. }}
  OPTIONAL {{ ?item wdt:P238 ?iata. }}
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en". }}
}}
LIMIT {limit}
OFFSET {offset}
'''
    url = ENDPOINT + "?" + urllib.parse.urlencode({"format": "json", "query": query})
    req = urllib.request.Request(url, headers={"Accept": "application/sparql-results+json", "User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=90, context=ssl_ctx) as response:
        return json.load(response)


def build_airports():
    ssl_ctx = ssl._create_unverified_context()
    airports = []
    offset = 0

    while True:
        data = fetch_batch(offset, BATCH_SIZE, ssl_ctx)
        rows = data.get("results", {}).get("bindings", [])
        if not rows:
            break

        for row in rows:
            point = parse_wkt_point(row.get("coord", {}).get("value", ""))
            if not point:
                continue

            lat, lng = point
            item_url = row.get("item", {}).get("value", "")
            qid = item_url.rsplit("/", 1)[-1] if item_url else ""

            airports.append({
                "id": f"airport-{qid.lower()}" if qid else f"airport-{len(airports) + 1}",
                "name": row.get("itemLabel", {}).get("value", "Airport"),
                "country": row.get("countryLabel", {}).get("value", "Unknown"),
                "iata": row.get("iata", {}).get("value", ""),
                "lat": round(lat, 6),
                "lng": round(lng, 6),
            })

        if len(rows) < BATCH_SIZE:
            break

        offset += BATCH_SIZE
        time.sleep(0.2)

    deduped = []
    seen = set()
    for airport in airports:
        if airport["id"] in seen:
            continue
        seen.add(airport["id"])
        deduped.append(airport)

    deduped.sort(key=lambda x: (x["country"], x["name"]))
    return deduped


def main():
    airports = build_airports()
    with open("data/airports.json", "w", encoding="utf-8") as f:
        json.dump(airports, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"Saved {len(airports)} airports to data/airports.json")


if __name__ == "__main__":
    main()
