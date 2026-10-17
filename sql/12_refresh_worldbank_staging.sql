-- Run with psql, not the pgAdmin Query Tool.
\set ON_ERROR_STOP on

-- Replace staging with the saved official-data snapshot.
-- Commit only if the imported row count and country-year keys pass.

BEGIN;

TRUNCATE TABLE worldbank.indicators_staging;

\copy worldbank.indicators_staging (country_name, country_code, region, income_group, year, gdp_usd, population, life_expectancy, unemployment_rate, co2_emissions_per_capita, access_to_electricity_pct, source_file, ingested_at) FROM 'C:/Users/mpume/Downloads/world-bank-sql-data-pipeline/data/official/2026-10-15/world_bank_indicators.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8')

DO $$
BEGIN
    IF (SELECT COUNT(*) FROM worldbank.indicators_staging) <> 720 THEN
        RAISE EXCEPTION 'Import failed validation: expected 720 rows';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM worldbank.indicators_staging
        GROUP BY country_code, year
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'Import failed validation: duplicate country-years';
    END IF;
END;
$$;

COMMIT;

SELECT COUNT(*) AS staging_rows
FROM worldbank.indicators_staging;