"""
Generate a realistic, deliberately-dirty country-year panel for a SQL / data-engineering
portfolio project.

Hypothesis under test:
    Do CO2 emissions per capita, unemployment rate and access to electricity
    explain variation in life expectancy? And how do GDP and population relate to each?

Output:
    data/world_bank_indicators_raw.csv   <- the dirty file you ingest and clean
    reference/country_reference.csv      <- clean dimension table (for joins / RI checks)
    docs/dirt_manifest.csv               <- ground truth of every defect injected

IMPORTANT: values are SYNTHETIC but calibrated to real-world magnitudes and trends
(GFC 2009, COVID 2020-21). This is not World Bank data. Use scripts/fetch_worldbank.py
if you need genuine WDI figures.
"""

import csv
import random
from pathlib import Path

import numpy as np

SEED = 20260824
random.seed(SEED)
rng = np.random.default_rng(SEED)

YEAR_START, YEAR_END = 2000, 2023
YEARS = list(range(YEAR_START, YEAR_END + 1))
ROOT = Path(__file__).resolve().parents[1]

# ---------------------------------------------------------------------------
# Country reference: iso3 -> (name, region, income_group)
# ---------------------------------------------------------------------------
REF = {
    "USA": ("United States", "North America", "High income"),
    "CAN": ("Canada", "North America", "High income"),
    "MEX": ("Mexico", "Latin America & Caribbean", "Upper middle income"),
    "BRA": ("Brazil", "Latin America & Caribbean", "Upper middle income"),
    "ARG": ("Argentina", "Latin America & Caribbean", "Upper middle income"),
    "GBR": ("United Kingdom", "Europe & Central Asia", "High income"),
    "DEU": ("Germany", "Europe & Central Asia", "High income"),
    "FRA": ("France", "Europe & Central Asia", "High income"),
    "ITA": ("Italy", "Europe & Central Asia", "High income"),
    "ESP": ("Spain", "Europe & Central Asia", "High income"),
    "NLD": ("Netherlands", "Europe & Central Asia", "High income"),
    "SWE": ("Sweden", "Europe & Central Asia", "High income"),
    "NOR": ("Norway", "Europe & Central Asia", "High income"),
    "POL": ("Poland", "Europe & Central Asia", "High income"),
    "RUS": ("Russian Federation", "Europe & Central Asia", "Upper middle income"),
    "TUR": ("Turkiye", "Europe & Central Asia", "Upper middle income"),
    "CHN": ("China", "East Asia & Pacific", "Upper middle income"),
    "JPN": ("Japan", "East Asia & Pacific", "High income"),
    "KOR": ("Korea, Rep.", "East Asia & Pacific", "High income"),
    "AUS": ("Australia", "East Asia & Pacific", "High income"),
    "IDN": ("Indonesia", "East Asia & Pacific", "Upper middle income"),
    "THA": ("Thailand", "East Asia & Pacific", "Upper middle income"),
    "VNM": ("Vietnam", "East Asia & Pacific", "Lower middle income"),
    "IND": ("India", "South Asia", "Lower middle income"),
    "SAU": ("Saudi Arabia", "Middle East & North Africa", "High income"),
    "EGY": ("Egypt, Arab Rep.", "Middle East & North Africa", "Lower middle income"),
    "ZAF": ("South Africa", "Sub-Saharan Africa", "Upper middle income"),
    "NGA": ("Nigeria", "Sub-Saharan Africa", "Lower middle income"),
    "KEN": ("Kenya", "Sub-Saharan Africa", "Lower middle income"),
    "ETH": ("Ethiopia", "Sub-Saharan Africa", "Low income"),
}

# ---------------------------------------------------------------------------
# Anchors: iso3 -> {indicator: (v2000, v2010, v2019, v2023)}
# 2019 (not 2020) is the last pre-COVID anchor; COVID is applied as an explicit shock.
# gdp in current US$, pop in persons, le in years, unemp %, co2 t/capita, elec %.
# ---------------------------------------------------------------------------
A = {
    #        gdp (USD)                       population                    life exp                unemployment         co2 pc                 electricity
    "USA": ((10.25e12, 15.05e12, 21.38e12, 27.36e12), (282.2e6, 309.3e6, 328.3e6, 334.9e6), (76.6, 78.6, 78.8, 79.3), (4.0, 9.6, 3.7, 3.6), (20.2, 17.4, 14.7, 13.0), (100, 100, 100, 100)),
    "CAN": ((0.744e12, 1.617e12, 1.743e12, 2.140e12), (30.7e6, 34.0e6, 37.6e6, 40.1e6), (79.2, 81.2, 82.2, 81.7), (6.8, 8.1, 5.7, 5.4), (17.3, 16.2, 15.4, 14.0), (100, 100, 100, 100)),
    "MEX": ((0.708e12, 1.058e12, 1.305e12, 1.789e12), (98.9e6, 114.1e6, 125.1e6, 128.5e6), (74.1, 76.0, 75.1, 75.1), (2.6, 5.4, 3.5, 2.8), (3.8, 3.9, 3.5, 3.4), (96.5, 99.0, 100, 100)),
    "BRA": ((0.655e12, 2.209e12, 1.873e12, 2.174e12), (175.9e6, 196.4e6, 211.0e6, 216.4e6), (70.0, 73.3, 75.9, 75.9), (9.5, 8.5, 12.0, 8.0), (1.9, 2.2, 2.2, 2.3), (94.9, 98.7, 99.8, 100)),
    "ARG": ((0.284e12, 0.424e12, 0.447e12, 0.641e12), (37.1e6, 41.2e6, 44.9e6, 46.2e6), (73.8, 75.6, 76.6, 77.7), (15.0, 7.7, 9.8, 6.2), (3.7, 4.4, 4.0, 3.8), (95.0, 98.5, 100, 100)),
    "GBR": ((1.658e12, 2.491e12, 2.857e12, 3.340e12), (58.9e6, 62.8e6, 66.8e6, 68.4e6), (77.8, 80.4, 81.2, 81.3), (5.4, 7.8, 3.8, 4.0), (9.4, 7.9, 5.2, 4.7), (100, 100, 100, 100)),
    "DEU": ((1.947e12, 3.400e12, 3.888e12, 4.526e12), (82.2e6, 81.8e6, 83.1e6, 84.5e6), (78.2, 80.0, 81.3, 81.4), (7.9, 7.0, 3.1, 3.0), (10.4, 9.5, 8.0, 6.8), (100, 100, 100, 100)),
    "FRA": ((1.366e12, 2.647e12, 2.729e12, 3.052e12), (60.9e6, 64.9e6, 67.4e6, 68.2e6), (79.0, 81.7, 82.7, 83.1), (8.6, 8.9, 8.4, 7.3), (6.4, 5.9, 4.5, 4.1), (100, 100, 100, 100)),
    "ITA": ((1.147e12, 2.136e12, 2.011e12, 2.255e12), (56.9e6, 59.3e6, 59.7e6, 58.9e6), (79.8, 82.0, 83.2, 83.7), (10.0, 8.4, 9.9, 7.7), (8.1, 7.0, 5.3, 5.1), (100, 100, 100, 100)),
    "ESP": ((0.596e12, 1.420e12, 1.394e12, 1.581e12), (40.6e6, 46.6e6, 47.1e6, 48.4e6), (79.3, 82.1, 83.6, 83.8), (13.9, 19.9, 14.1, 12.2), (7.3, 6.0, 5.3, 4.7), (100, 100, 100, 100)),
    "NLD": ((0.418e12, 0.847e12, 0.910e12, 1.118e12), (15.9e6, 16.6e6, 17.3e6, 17.9e6), (78.0, 80.9, 82.2, 82.2), (3.1, 5.0, 3.4, 3.6), (10.7, 10.9, 8.6, 7.4), (100, 100, 100, 100)),
    "SWE": ((0.262e12, 0.495e12, 0.533e12, 0.593e12), (8.87e6, 9.38e6, 10.28e6, 10.55e6), (79.7, 81.5, 83.2, 83.4), (5.6, 8.6, 6.8, 7.7), (5.7, 5.1, 3.7, 3.1), (100, 100, 100, 100)),
    "NOR": ((0.171e12, 0.429e12, 0.405e12, 0.485e12), (4.49e6, 4.89e6, 5.35e6, 5.52e6), (78.7, 81.2, 83.2, 83.4), (3.4, 3.6, 3.7, 3.7), (8.5, 9.0, 7.0, 6.3), (100, 100, 100, 100)),
    "POL": ((0.172e12, 0.480e12, 0.597e12, 0.811e12), (38.3e6, 38.0e6, 37.9e6, 36.6e6), (73.8, 76.4, 78.3, 78.5), (16.1, 9.6, 3.3, 2.8), (8.0, 8.4, 8.1, 7.4), (100, 100, 100, 100)),
    "RUS": ((0.260e12, 1.525e12, 1.693e12, 2.021e12), (146.6e6, 143.2e6, 144.4e6, 143.8e6), (65.5, 68.9, 73.1, 73.4), (10.6, 7.4, 4.6, 3.2), (10.6, 11.4, 11.4, 11.4), (100, 100, 100, 100)),
    "TUR": ((0.274e12, 0.777e12, 0.759e12, 1.108e12), (63.2e6, 72.3e6, 83.4e6, 85.3e6), (71.6, 75.1, 77.7, 77.5), (6.5, 10.7, 13.7, 9.4), (3.3, 4.1, 4.8, 5.3), (100, 100, 100, 100)),
    "CHN": ((1.211e12, 6.087e12, 14.28e12, 17.79e12), (1.263e9, 1.338e9, 1.408e9, 1.410e9), (71.7, 74.8, 77.7, 78.6), (3.3, 4.5, 4.6, 4.7), (2.7, 6.0, 7.6, 8.4), (98.8, 99.7, 100, 100)),
    "JPN": ((4.968e12, 5.759e12, 5.118e12, 4.213e12), (126.8e6, 128.1e6, 126.6e6, 124.5e6), (81.1, 82.9, 84.4, 84.0), (4.7, 5.1, 2.4, 2.6), (9.6, 9.2, 8.4, 8.0), (100, 100, 100, 100)),
    "KOR": ((0.576e12, 1.144e12, 1.651e12, 1.713e12), (47.0e6, 49.6e6, 51.7e6, 51.7e6), (76.0, 80.2, 83.3, 83.5), (4.4, 3.7, 3.8, 2.7), (9.4, 11.7, 12.0, 11.6), (100, 100, 100, 100)),
    "AUS": ((0.416e12, 1.147e12, 1.393e12, 1.724e12), (19.2e6, 22.0e6, 25.4e6, 26.6e6), (79.2, 81.7, 83.0, 83.2), (6.3, 5.2, 5.2, 3.7), (17.6, 17.0, 15.6, 14.4), (100, 100, 100, 100)),
    "IDN": ((0.165e12, 0.755e12, 1.119e12, 1.371e12), (214.1e6, 244.0e6, 269.6e6, 277.5e6), (66.2, 68.6, 71.5, 71.1), (6.1, 5.6, 3.6, 3.4), (1.3, 1.8, 2.2, 2.6), (86.3, 93.5, 98.9, 100)),
    "THA": ((0.126e12, 0.341e12, 0.544e12, 0.515e12), (63.1e6, 67.2e6, 71.3e6, 71.8e6), (70.8, 73.9, 79.3, 76.4), (2.4, 1.0, 0.7, 1.0), (2.9, 4.2, 3.9, 3.9), (82.1, 99.3, 100, 100)),
    "VNM": ((0.031e12, 0.116e12, 0.334e12, 0.430e12), (79.9e6, 87.4e6, 96.5e6, 100.3e6), (71.9, 73.7, 73.8, 74.6), (2.3, 1.1, 2.0, 1.6), (0.7, 1.6, 3.3, 3.5), (86.0, 97.6, 99.4, 100)),
    "IND": ((0.468e12, 1.676e12, 2.836e12, 3.550e12), (1.059e9, 1.234e9, 1.383e9, 1.429e9), (62.5, 67.0, 70.5, 72.0), (7.7, 8.3, 5.3, 4.2), (0.9, 1.4, 1.8, 2.0), (59.0, 76.0, 96.6, 100)),
    "SAU": ((0.190e12, 0.528e12, 0.804e12, 1.068e12), (20.7e6, 27.4e6, 34.3e6, 36.9e6), (72.6, 74.5, 76.6, 78.7), (4.6, 5.6, 5.6, 4.9), (14.3, 16.2, 17.2, 18.0), (98.5, 99.5, 100, 100)),
    "EGY": ((0.100e12, 0.219e12, 0.317e12, 0.396e12), (68.8e6, 82.8e6, 100.1e6, 112.7e6), (68.5, 70.4, 70.5, 70.7), (9.0, 9.0, 8.6, 7.0), (1.9, 2.4, 2.3, 2.5), (97.7, 99.6, 100, 100)),
    "ZAF": ((0.136e12, 0.417e12, 0.388e12, 0.378e12), (44.9e6, 51.2e6, 58.1e6, 60.4e6), (56.1, 58.9, 65.3, 66.0), (25.4, 24.7, 28.5, 32.1), (8.2, 8.6, 7.4, 6.7), (71.0, 83.0, 84.4, 87.0)),
    "NGA": ((0.069e12, 0.363e12, 0.448e12, 0.363e12), (122.9e6, 159.4e6, 203.3e6, 223.8e6), (46.3, 51.0, 52.9, 54.5), (3.8, 3.8, 5.6, 3.7), (0.7, 0.8, 0.6, 0.5), (45.0, 51.0, 55.4, 61.0)),
    "KEN": ((0.0128e12, 0.0450e12, 0.1000e12, 0.1078e12), (30.9e6, 41.5e6, 49.4e6, 55.1e6), (51.5, 61.5, 66.1, 63.7), (4.5, 5.9, 5.0, 5.6), (0.30, 0.32, 0.40, 0.42), (15.0, 19.2, 69.7, 76.0)),
    "ETH": ((0.0081e12, 0.0298e12, 0.0960e12, 0.1633e12), (66.2e6, 87.6e6, 114.1e6, 126.5e6), (51.4, 62.0, 66.6, 67.0), (3.0, 2.0, 3.5, 3.3), (0.05, 0.08, 0.13, 0.16), (12.7, 23.0, 48.3, 55.0)),
}

ANCHOR_YEARS = [2000, 2010, 2019, 2023]

# COVID shock: (gdp_2020_mult, gdp_2021_mult, unemp_2020_delta, le_2020_delta, le_2021_delta)
COVID = {
    "USA": (0.978, 1.10, 4.4, -1.8, -2.4), "CAN": (0.946, 1.12, 3.9, -0.6, -0.8),
    "MEX": (0.918, 1.09, 0.9, -4.2, -4.9), "BRA": (0.960, 1.10, 1.9, -1.6, -2.9),
    "ARG": (0.902, 1.11, 1.7, -1.6, -2.7), "GBR": (0.892, 1.10, 0.7, -1.2, -1.0),
    "DEU": (0.962, 1.04, 0.5, -0.4, -0.6), "FRA": (0.922, 1.07, 0.0, -0.6, -0.5),
    "ITA": (0.910, 1.09, -0.6, -1.4, -1.0), "ESP": (0.888, 1.07, 1.4, -1.6, -1.1),
    "NLD": (0.962, 1.06, 0.5, -0.4, -0.5), "SWE": (0.978, 1.06, 1.6, -0.7, -0.2),
    "NOR": (0.972, 1.05, 0.9, -0.1, 0.1), "POL": (0.980, 1.07, 0.0, -1.4, -2.0),
    "RUS": (0.972, 1.06, 1.2, -1.7, -3.7), "TUR": (1.018, 1.11, 0.4, -0.9, -1.4),
    "CHN": (1.022, 1.08, 0.4, -0.1, 0.0), "JPN": (0.956, 1.02, 0.4, 0.1, 0.1),
    "KOR": (0.992, 1.04, 0.2, 0.2, 0.2), "AUS": (0.980, 1.05, 1.3, 0.4, 0.5),
    "IDN": (0.979, 1.04, 0.7, -0.8, -1.5), "THA": (0.938, 1.02, 0.3, -0.3, -0.6),
    "VNM": (1.029, 1.03, 0.2, -0.2, -0.8), "IND": (0.941, 1.09, 2.6, -1.3, -2.6),
    "SAU": (0.955, 1.09, 1.8, -1.0, -1.6), "EGY": (1.036, 1.03, 0.1, -0.4, -0.6),
    "ZAF": (0.940, 1.05, 0.7, -0.1, -3.0), "NGA": (0.982, 1.04, 3.4, -0.3, -0.5),
    "KEN": (0.997, 1.07, 0.7, -0.4, -1.4), "ETH": (1.061, 1.06, 0.2, -0.3, -0.5),
}

# Global financial crisis: 2009 GDP multiplier and unemployment bump (2009-2010)
GFC_GDP = {"USA": 0.978, "GBR": 0.892, "DEU": 0.912, "FRA": 0.928, "ITA": 0.898,
           "ESP": 0.918, "NLD": 0.918, "SWE": 0.868, "NOR": 0.848, "POL": 0.828,
           "RUS": 0.762, "TUR": 0.858, "JPN": 1.048, "KOR": 0.882, "MEX": 0.878,
           "ZAF": 0.888, "BRA": 0.958, "ARG": 0.938, "CAN": 0.928, "AUS": 0.968}


def interp(anchors, year):
    return float(np.interp(year, ANCHOR_YEARS, anchors))


def build_clean_rows():
    rows = []
    for iso, (gdp_a, pop_a, le_a, un_a, co2_a, el_a) in A.items():
        name, region, income = REF[iso]
        # persistent country-level noise so series wobble smoothly, not tick-by-tick
        walk = rng.normal(0, 1, len(YEARS)).cumsum() * 0.35
        for i, y in enumerate(YEARS):
            gdp = interp(gdp_a, y)
            pop = interp(pop_a, y)
            le = interp(le_a, y)
            un = interp(un_a, y)
            co2 = interp(co2_a, y)
            el = interp(el_a, y)

            # --- shocks -------------------------------------------------
            if y == 2009:
                gdp *= GFC_GDP.get(iso, 0.965)
                un += 1.6 if iso in GFC_GDP else 0.4
            elif y == 2010:
                un += 0.6 if iso in GFC_GDP else 0.1

            cg20, cg21, cu20, cl20, cl21 = COVID[iso]
            if y == 2020:
                gdp *= cg20
                un += cu20
                le += cl20
                co2 *= 0.935
            elif y == 2021:
                gdp *= cg20 * cg21
                un += cu20 * 0.55
                le += cl21
                co2 *= 0.975
            elif y == 2022:
                gdp *= 1.005
                un += cu20 * 0.15
                le += cl21 * 0.35

            # --- noise --------------------------------------------------
            gdp *= 1 + walk[i] * 0.012 + rng.normal(0, 0.008)
            pop *= 1 + rng.normal(0, 0.0006)
            le += rng.normal(0, 0.09)
            un = max(0.2, un * (1 + walk[i] * 0.02 + rng.normal(0, 0.03)))
            co2 = max(0.02, co2 * (1 + rng.normal(0, 0.025)))
            el = min(100.0, max(3.0, el + rng.normal(0, 0.35)))

            rows.append({
                "country_name": name,
                "country_code": iso,
                "region": region,
                "income_group": income,
                "year": y,
                "gdp_usd": round(gdp, 0),
                "population": round(pop, 0),
                "life_expectancy": round(le, 1),
                "unemployment_rate": round(un, 2),
                "co2_emissions_per_capita": round(co2, 2),
                "access_to_electricity_pct": round(el, 2),
                "source_file": "wdi_extract_2024Q4.csv",
                "ingested_at": "2026-08-18 04:12:07",
            })
    return rows


# ---------------------------------------------------------------------------
# Dirt injection
# ---------------------------------------------------------------------------
NAME_ALIASES = {
    "USA": ["USA", "United States of America"],
    "GBR": ["UK"],
    "RUS": ["Russia"],
    "KOR": ["South Korea"],
    "TUR": ["Türkiye"],
    "ZAF": ["South Africa "],
    "IRN": ["Iran"],
}
NULL_SENTINELS = ["", "N/A", "NA", "-", "..", "NaN", "NULL", "#N/A", "unknown"]
NUMERIC_COLS = ["gdp_usd", "population", "life_expectancy", "unemployment_rate",
                "co2_emissions_per_capita", "access_to_electricity_pct"]

manifest = []

# Scales every defect count below. 1.0 lands ~5% of rows with at least one defect.
DIRT_SCALE = 1.0


def n(base):
    """Scaled defect count, never below 1 so every defect type stays represented."""
    return max(1, int(round(base * DIRT_SCALE)))


def log(row_key, col, defect, detail):
    manifest.append({"country_year": row_key, "column": col,
                     "defect_type": defect, "detail": detail})


def key(r):
    return f"{r['country_code']}-{r['year']}"


def inject(rows):
    out = [dict(r) for r in rows]
    idx = list(range(len(out)))

    # 1. exact duplicate rows -------------------------------------------------
    for i in rng.choice(idx, n(3), replace=False):
        dup = dict(out[i])
        out.append(dup)
        log(key(dup), "*", "exact_duplicate", "byte-identical repeat of an existing row")

    # 2. conflicting near-duplicates (same country-year, different values) -----
    for i in rng.choice(idx, n(4), replace=False):
        dup = dict(out[i])
        dup["gdp_usd"] = round(float(dup["gdp_usd"]) * float(rng.uniform(0.93, 1.08)), 0)
        dup["life_expectancy"] = round(float(dup["life_expectancy"]) + float(rng.uniform(-1.5, 1.5)), 1)
        dup["source_file"] = "wdi_extract_2025Q1.csv"
        dup["ingested_at"] = "2026-08-19 09:47:55"
        out.append(dup)
        log(key(dup), "gdp_usd,life_expectancy", "conflicting_duplicate",
            "same country-year, later ingest, different values - needs a dedup rule")

    # 3. country name variants ------------------------------------------------
    used = set()
    for iso, aliases in NAME_ALIASES.items():
        if iso == "IRN":
            continue
        cands = [i for i in idx if out[i]["country_code"] == iso and i not in used]
        for alias, i in zip(aliases, rng.choice(cands, min(len(aliases), len(cands)), replace=False)):
            used.add(int(i))
            out[int(i)]["country_name"] = alias
            log(key(out[int(i)]), "country_name", "name_variant",
                f"canonical '{REF[iso][0]}' written as '{alias}'")

    # 4. unit errors ----------------------------------------------------------
    for i in rng.choice(idx, n(2), replace=False):
        out[int(i)]["gdp_usd"] = round(float(out[int(i)]["gdp_usd"]) / 1e6, 2)
        log(key(out[int(i)]), "gdp_usd", "unit_mismatch", "reported in millions USD, not units")
    for i in rng.choice(idx, n(2), replace=False):
        out[int(i)]["population"] = round(float(out[int(i)]["population"]) / 1e3, 1)
        log(key(out[int(i)]), "population", "unit_mismatch", "reported in thousands, not persons")

    # 5. impossible / out-of-domain values ------------------------------------
    for i in rng.choice(idx, n(1), replace=False):
        out[int(i)]["life_expectancy"] = round(float(out[int(i)]["life_expectancy"]) / 10, 2)
        log(key(out[int(i)]), "life_expectancy", "decimal_shift", "value divided by 10 (e.g. 6.7 years)")
    for i in rng.choice(idx, n(1), replace=False):
        out[int(i)]["unemployment_rate"] = round(float(out[int(i)]["unemployment_rate"]) * 100, 1)
        log(key(out[int(i)]), "unemployment_rate", "impossible_value", "percentage scaled by 100")
    for i in rng.choice(idx, n(2), replace=False):
        out[int(i)]["access_to_electricity_pct"] = round(float(rng.uniform(100.4, 103.2)), 2)
        log(key(out[int(i)]), "access_to_electricity_pct", "impossible_value", "above 100%")
    for i in rng.choice(idx, n(1), replace=False):
        out[int(i)]["co2_emissions_per_capita"] = -abs(float(out[int(i)]["co2_emissions_per_capita"]))
        log(key(out[int(i)]), "co2_emissions_per_capita", "impossible_value", "negative emissions")
    for i in rng.choice(idx, n(1), replace=False):
        out[int(i)]["life_expectancy"] = 187.4
        log(key(out[int(i)]), "life_expectancy", "impossible_value", "life expectancy of 187.4 years")

    # 6. float artefacts on integer-like columns ------------------------------
    for i in rng.choice(idx, n(2), replace=False):
        out[int(i)]["population"] = f"{float(out[int(i)]['population']) - 0.00000003:.8f}"
        log(key(out[int(i)]), "population", "float_artefact", "binary float noise, e.g. ...99999997")

    # 7. formatting contamination (numbers stored as text) --------------------
    for i in rng.choice(idx, n(2), replace=False):
        out[int(i)]["gdp_usd"] = "$" + f"{float(out[int(i)]['gdp_usd']):,.0f}"
        log(key(out[int(i)]), "gdp_usd", "text_formatting", "currency symbol and thousands separators")
    for i in rng.choice(idx, n(2), replace=False):
        r = out[int(i)]
        r["unemployment_rate"] = f"{float(r['unemployment_rate'])}%"
        log(key(r), "unemployment_rate", "text_formatting", "trailing percent sign")
    for i in rng.choice(idx, n(1), replace=False):
        r = out[int(i)]
        r["co2_emissions_per_capita"] = str(r["co2_emissions_per_capita"]).replace(".", ",")
        log(key(r), "co2_emissions_per_capita", "text_formatting", "comma used as decimal separator")

    # 8. year column problems -------------------------------------------------
    for i in rng.choice(idx, n(2), replace=False):
        out[int(i)]["year"] = f"{out[int(i)]['year']}.0"
        log(key(out[int(i)]), "year", "type_drift", "year read as float then stringified")
    for i in rng.choice(idx, n(1), replace=False):
        out[int(i)]["year"] = f"FY{out[int(i)]['year']}"
        log(key(out[int(i)]), "year", "type_drift", "fiscal-year prefix")
    i = int(rng.choice(idx))
    out[i]["year"] = 2109
    log(f"{out[i]['country_code']}-2109", "year", "out_of_range", "transposed digits -> future year")
    i = int(rng.choice(idx))
    out[i]["year"] = 1899
    log(f"{out[i]['country_code']}-1899", "year", "out_of_range", "year before dataset coverage")

    # 9. referential integrity breaks ----------------------------------------
    bad_codes = {"ZAF": "ZMB", "AUS": "AUT"}
    for good, bad in bad_codes.items():
        cands = [i for i in idx if out[i]["country_code"] == good]
        i = int(rng.choice(cands))
        out[i]["country_code"] = bad
        log(f"{good}-{out[i]['year']}", "country_code",
            "referential_integrity", f"name says {REF[good][0]} but code is {bad}")

    # 10. orphan country not in the reference table ---------------------------
    for y in (2019, 2020):
        out.append({
            "country_name": "Iran", "country_code": "IRN",
            "region": "Middle East & North Africa", "income_group": "Lower middle income",
            "year": y, "gdp_usd": round(float(rng.uniform(2.0e11, 4.5e11)), 0),
            "population": round(float(rng.uniform(8.1e7, 8.5e7)), 0),
            "life_expectancy": round(float(rng.uniform(76.0, 77.5)), 1),
            "unemployment_rate": round(float(rng.uniform(9.0, 11.5)), 2),
            "co2_emissions_per_capita": round(float(rng.uniform(7.5, 8.5)), 2),
            "access_to_electricity_pct": 100.0,
            "source_file": "manual_addendum.xlsx", "ingested_at": "2026-08-20 16:03:11",
        })
        log(f"IRN-{y}", "*", "orphan_record", "country absent from country_reference.csv")

    # 11. aggregate rows masquerading as countries ----------------------------
    for nm, code in [("World", "WLD"), ("European Union", "EUU")]:
        y = int(rng.choice([2015, 2018, 2021]))
        out.append({
            "country_name": nm, "country_code": code, "region": "Aggregates",
            "income_group": "Aggregates", "year": y,
            "gdp_usd": round(float(rng.uniform(1.5e13, 9.5e13)), 0),
            "population": round(float(rng.uniform(4.4e8, 7.8e9)), 0),
            "life_expectancy": round(float(rng.uniform(64.0, 81.0)), 1),
            "unemployment_rate": round(float(rng.uniform(5.0, 8.0)), 2),
            "co2_emissions_per_capita": round(float(rng.uniform(4.0, 7.0)), 2),
            "access_to_electricity_pct": round(float(rng.uniform(48.0, 100.0)), 2),
            "source_file": "wdi_extract_2024Q4.csv", "ingested_at": "2026-08-18 04:12:07",
        })
        log(f"{code}-{y}", "*", "aggregate_row", "regional/world aggregate mixed in with countries")

    # 12. an almost-empty row -------------------------------------------------
    out.append({
        "country_name": "Kenya", "country_code": "KEN", "region": "", "income_group": "",
        "year": 2024, "gdp_usd": "", "population": "", "life_expectancy": "",
        "unemployment_rate": "", "co2_emissions_per_capita": "",
        "access_to_electricity_pct": "", "source_file": "wdi_extract_2025Q1.csv",
        "ingested_at": "2026-08-19 09:47:55",
    })
    log("KEN-2024", "*", "empty_record", "year outside coverage, every measure blank")

    # 13. scattered null sentinels (cell-level, several flavours) -------------
    all_idx = list(range(len(out)))
    for col, cnt in [("unemployment_rate", 2), ("co2_emissions_per_capita", 2),
                     ("access_to_electricity_pct", 2), ("life_expectancy", 1),
                     ("gdp_usd", 1), ("population", 1)]:
        for i in rng.choice(all_idx, n(cnt), replace=False):
            sent = NULL_SENTINELS[int(rng.integers(0, len(NULL_SENTINELS)))]
            out[int(i)][col] = sent
            log(key(out[int(i)]), col, "null_sentinel", f"missing value encoded as '{sent}'")

    # 14. whitespace / casing noise on the join keys --------------------------
    for i in rng.choice(all_idx, n(2), replace=False):
        r = out[int(i)]
        r["country_code"] = f" {r['country_code']} " if rng.random() < 0.5 else str(r["country_code"]).lower()
        log(key(r), "country_code", "whitespace_or_case", "padded or lower-cased ISO code")

    rng.shuffle(out)
    return out


def main():
    global DIRT_SCALE
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--dirt-scale", type=float, default=0.6,
                    help="multiplier on every defect count (1.0 ~= 5%% of rows affected)")
    DIRT_SCALE = ap.parse_args().dirt_scale

    clean = build_clean_rows()
    dirty = inject(clean)

    cols = ["country_name", "country_code", "region", "income_group", "year",
            "gdp_usd", "population", "life_expectancy", "unemployment_rate",
            "co2_emissions_per_capita", "access_to_electricity_pct",
            "source_file", "ingested_at"]

    (ROOT / "data").mkdir(exist_ok=True)
    (ROOT / "reference").mkdir(exist_ok=True)
    (ROOT / "docs").mkdir(exist_ok=True)

    with open(ROOT / "data/world_bank_indicators_raw.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(dirty)

    with open(ROOT / "reference/country_reference.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["country_code", "country_name", "region", "income_group"])
        for iso, (nm, reg, inc) in sorted(REF.items()):
            w.writerow([iso, nm, reg, inc])

    with open(ROOT / "docs/dirt_manifest.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["country_year", "column", "defect_type", "detail"])
        w.writeheader()
        w.writerows(sorted(manifest, key=lambda m: (m["defect_type"], m["country_year"])))

    touched = {m["country_year"] for m in manifest}
    print(f"clean rows        : {len(clean)}")
    print(f"raw rows written  : {len(dirty)}")
    print(f"defects logged    : {len(manifest)}")
    print(f"rows affected     : ~{len(touched)} ({100 * len(touched) / len(dirty):.1f}% of raw rows)")
    from collections import Counter
    for k, v in Counter(m["defect_type"] for m in manifest).most_common():
        print(f"  {k:26s} {v}")


if __name__ == "__main__":
    main()
