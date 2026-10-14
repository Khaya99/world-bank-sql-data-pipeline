# Official API extraction progress — 15 October 2026

## Completed

- Added a shared GET helper with up to three retries after the initial attempt for temporary failures, backoff and Retry-After handling.
- Added per-indicator expected, available, missing and unexpected country-year counts. Missing observations stay blank; zero remains a value.
- Ran the extractor for 30 countries, six indicators and 2000–2023.
- Saved 720 unique country-year rows and 4,320 non-null indicator values in `data/official/2026-10-15/world_bank_indicators.csv`, separate from the synthetic dataset. The extraction log is beside it.
- Added reusable offline tests for retry behaviour and completeness reporting.

## Reproduce

From the repository root, install the existing script dependencies into your chosen Python environment:

```text
python -m pip install requests pandas
python -B -m unittest discover -s tests -v
python scripts/fetch_worldbank.py --start 2000 --end 2023 --out data/official/new_download.csv
```

Use a fresh output filename to preserve previous snapshots. The output directory must already exist.

## Scope and limitations

The saved CSV is a flattened official-data extraction, not an untouched raw API response. Its ingestion timestamps are UTC. The run log records the indicator codes selected, including the CO2 fallback choice. Current country metadata is not a historical classification for every observation year. Source revisions may change future downloads.

Completeness does not establish statistical accuracy, and the script still needs stricter API payload validation and duplicate detection before dictionary assignment. No PostgreSQL load or Tableau refresh has been performed for this snapshot. Existing synthetic-data findings remain separate. A pandas deprecation warning for the existing timestamp call did not prevent extraction.

## Next milestone

Design and load a separate PostgreSQL staging table for official observations, preserving source identity and validating before publishing analytical results.
