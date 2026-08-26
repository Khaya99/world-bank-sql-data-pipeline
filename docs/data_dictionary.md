# Data dictionary

`data/world_bank_indicators_raw.csv` — one row per country-year (in principle; the raw file
violates this and that is the point).

| Column | Target type | Unit | Valid range | Notes |
|---|---|---|---|---|
| `country_name` | TEXT | — | must resolve to `country_reference.country_name` | Arrives with aliases, casing and whitespace variants. Not a reliable key. |
| `country_code` | CHAR(3) | ISO 3166-1 alpha-3 | must exist in `country_reference` | The intended join key. Also arrives padded/lower-cased, and occasionally mismatched to the name. |
| `region` | TEXT | — | 6 World Bank regions | `Aggregates` marks a non-country row. |
| `income_group` | TEXT | — | Low / Lower middle / Upper middle / High income | |
| `year` | INTEGER | calendar year | 2000–2023 | Arrives as `2010`, `2010.0`, `FY2015`. Two rows fall outside coverage. |
| `gdp_usd` | NUMERIC(20,2) | current US$, **units not millions** | > 0 | A few rows are in millions. Some carry `$` and thousands separators. |
| `population` | BIGINT | persons | > 0 | A few rows are in thousands. Some carry float artefacts. |
| `life_expectancy` | NUMERIC(5,2) | years at birth | 35–95 | Decimal-shifted and absurd values present. |
| `unemployment_rate` | NUMERIC(5,2) | % of labour force | 0–45 | ILO-modelled convention. Some rows scaled ×100; some carry `%`. |
| `co2_emissions_per_capita` | NUMERIC(8,3) | metric tons per person | 0–45 | Negative values present. Some rows use a comma decimal separator. |
| `access_to_electricity_pct` | NUMERIC(5,2) | % of population | 0–100 | Values above 100 present. |
| `source_file` | TEXT | — | — | Provenance. Two extract vintages plus a manual addendum. |
| `ingested_at` | TIMESTAMP | — | — | **Your tie-breaker for conflicting duplicates** — later ingest wins, if you decide that is the right rule. |

## Grain and keys

- Intended grain: one row per (`country_code`, `year`).
- Natural key after cleaning: (`country_code`, `year`).
- `country_reference.csv` is the conformed dimension. Every fact row should join to it;
  ones that do not are orphans and belong in quarantine, not in the fact table.

## Missingness

Null is encoded nine ways in the raw file. Normalise all of these to `NULL` before casting:

```
''   'N/A'   'NA'   '-'   '..'   'NaN'   'NULL'   '#N/A'   'unknown'
```

`..` is the World Bank's own missing marker, so it is worth handling by name rather than
by a catch-all.

## Derived fields you should compute, not expect

- `gdp_per_capita = gdp_usd / population`
- `co2_total = co2_emissions_per_capita * population`
- `log_gdp_per_capita` — needed for the life-expectancy relationship to appear at all.
