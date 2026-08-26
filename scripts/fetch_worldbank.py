"""
Pull the SAME schema from the live World Bank WDI API.

Run this on your own machine (it needs outbound access to api.worldbank.org):

    pip install requests pandas
    python scripts/fetch_worldbank.py --start 2000 --end 2023

Writes data/world_bank_indicators_real.csv with identical columns to the synthetic
file, so the cleaning pipeline you build works against either one.

Note on the CO2 indicator: the World Bank retired EN.ATM.CO2E.PC (CDIAC-based).
Current per-capita CO2 lives under EN.GHG.CO2.PC.CE.AR5. This script tries the new
code first and falls back to the legacy one, because a lot of tutorials still use it
and you will hit empty columns if you do not handle this.
"""

import argparse
import time

import pandas as pd
import requests

BASE = "https://api.worldbank.org/v2"

COUNTRIES = ["USA", "CAN", "MEX", "BRA", "ARG", "GBR", "DEU", "FRA", "ITA", "ESP",
             "NLD", "SWE", "NOR", "POL", "RUS", "TUR", "CHN", "JPN", "KOR", "AUS",
             "IDN", "THA", "VNM", "IND", "SAU", "EGY", "ZAF", "NGA", "KEN", "ETH"]

INDICATORS = {
    "gdp_usd": ["NY.GDP.MKTP.CD"],
    "population": ["SP.POP.TOTL"],
    "life_expectancy": ["SP.DYN.LE00.IN"],
    "unemployment_rate": ["SL.UEM.TOTL.ZS"],           # ILO modelled estimate
    "co2_emissions_per_capita": ["EN.GHG.CO2.PC.CE.AR5", "EN.ATM.CO2E.PC"],
    "access_to_electricity_pct": ["EG.ELC.ACCS.ZS"],
}


def fetch(indicator, start, end):
    """Return {(iso3, year): value} for one indicator, following pagination."""
    out, page = {}, 1
    while True:
        r = requests.get(
            f"{BASE}/country/{';'.join(COUNTRIES)}/indicator/{indicator}",
            params={"format": "json", "per_page": 1000, "date": f"{start}:{end}", "page": page},
            timeout=60,
        )
        r.raise_for_status()
        payload = r.json()
        if not isinstance(payload, list) or len(payload) < 2 or payload[1] is None:
            break
        meta, rows = payload[0], payload[1]
        for row in rows:
            iso = row.get("countryiso3code") or ""
            if iso and row["value"] is not None:
                out[(iso, int(row["date"]))] = row["value"]
        if page >= meta.get("pages", 1):
            break
        page += 1
        time.sleep(0.2)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--start", type=int, default=2000)
    ap.add_argument("--end", type=int, default=2023)
    ap.add_argument("--out", default="data/world_bank_indicators_real.csv")
    args = ap.parse_args()

    # country metadata (region + income group) straight from the API
    meta = requests.get(f"{BASE}/country/{';'.join(COUNTRIES)}",
                        params={"format": "json", "per_page": 500}, timeout=60).json()[1]
    info = {c["id"]: (c["name"], c["region"]["value"], c["incomeLevel"]["value"]) for c in meta}

    frames = {}
    for col, codes in INDICATORS.items():
        for code in codes:
            data = fetch(code, args.start, args.end)
            if data:
                print(f"{col:28s} <- {code}  ({len(data)} observations)")
                frames[col] = data
                break
        else:
            print(f"{col:28s} <- NO DATA from any of {codes}")
            frames[col] = {}

    records = []
    for iso in COUNTRIES:
        name, region, income = info.get(iso, (iso, "", ""))
        for year in range(args.start, args.end + 1):
            rec = {"country_name": name, "country_code": iso, "region": region,
                   "income_group": income, "year": year}
            for col in INDICATORS:
                rec[col] = frames[col].get((iso, year))
            rec["source_file"] = "worldbank_api_v2"
            rec["ingested_at"] = pd.Timestamp.utcnow().strftime("%Y-%m-%d %H:%M:%S")
            records.append(rec)

    df = pd.DataFrame(records)
    df.to_csv(args.out, index=False)
    print(f"\nwrote {args.out}  ({len(df)} rows)")
    print("null rate per column:")
    print((df.isna().mean() * 100).round(1).to_string())


if __name__ == "__main__":
    main()
