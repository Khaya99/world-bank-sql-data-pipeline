-- Run with psql, not the pgAdmin Query Tool.
-- One transaction: refresh staging, validate, upsert, then commit.
-- Uses the saved snapshot; this script does not fetch fresh API data.
-- All six indicators must be present for this snapshot. Review these
-- rules before using other periods or datasets where missingness is valid.
\set ON_ERROR_STOP on

BEGIN;

-- Fail instead of waiting indefinitely for a conflicting transaction.
SET LOCAL lock_timeout = '10s';

TRUNCATE TABLE worldbank.indicators_staging;

\copy worldbank.indicators_staging (country_name, country_code, region, income_group, year, gdp_usd, population, life_expectancy, unemployment_rate, co2_emissions_per_capita, access_to_electricity_pct, source_file, ingested_at) FROM 'C:/Users/mpume/Downloads/world-bank-sql-data-pipeline/data/official/2026-10-15/world_bank_indicators.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8')

-- These rules apply to the saved 30-country, 2000-2023 snapshot.
DO $$
BEGIN
    IF (SELECT COUNT(*) FROM worldbank.indicators_staging) <> 720 THEN
        RAISE EXCEPTION 'Expected 720 staging rows';
    END IF;

    -- Check formats before attempting numeric and timestamp conversions.
    IF EXISTS (
        SELECT 1 FROM worldbank.indicators_staging
        WHERE country_code IS NULL
           OR country_code NOT IN (
               'USA','CAN','MEX','BRA','ARG','GBR','DEU','FRA','ITA','ESP',
               'NLD','SWE','NOR','POL','RUS','TUR','CHN','JPN','KOR','AUS',
               'IDN','THA','VNM','IND','SAU','EGY','ZAF','NGA','KEN','ETH')
           OR NULLIF(TRIM(year), '') IS NULL
           OR NOT pg_input_is_valid(year, 'integer')
           OR source_file IS DISTINCT FROM 'worldbank_api_v2'
           OR NULLIF(TRIM(ingested_at), '') IS NULL
           OR NOT pg_input_is_valid(ingested_at, 'timestamp')
           OR LOWER(TRIM(ingested_at)) IN ('infinity', '-infinity')
    ) THEN
        RAISE EXCEPTION 'Invalid country, year, source or ingestion timestamp';
    END IF;

    IF EXISTS (
        SELECT 1 FROM worldbank.indicators_staging
        CROSS JOIN LATERAL (VALUES
            (gdp_usd), (population), (life_expectancy),
            (unemployment_rate), (co2_emissions_per_capita),
            (access_to_electricity_pct)
        ) AS checks(value)
        WHERE NULLIF(TRIM(value), '') IS NULL
           OR NOT pg_input_is_valid(value, 'numeric')
           OR LOWER(TRIM(value)) IN ('nan', 'infinity', '+infinity', '-infinity', 'inf', '+inf', '-inf')
    ) THEN
        RAISE EXCEPTION 'Missing, nonnumeric or nonfinite indicator value';
    END IF;

    IF EXISTS (
        SELECT 1 FROM worldbank.indicators_staging
        WHERE year::INTEGER NOT BETWEEN 2000 AND 2023
           OR gdp_usd::NUMERIC < 0
           OR population::NUMERIC <= 0
           OR population::NUMERIC > 9223372036854775807
           OR population::NUMERIC <> TRUNC(population::NUMERIC)
           OR life_expectancy::NUMERIC <= 0
           OR unemployment_rate::NUMERIC NOT BETWEEN 0 AND 100
           OR co2_emissions_per_capita::NUMERIC < 0
           OR access_to_electricity_pct::NUMERIC NOT BETWEEN 0 AND 100
    ) THEN
        RAISE EXCEPTION 'Year or indicator value outside the accepted range';
    END IF;

    IF EXISTS (
        SELECT 1 FROM worldbank.indicators_staging
        GROUP BY country_code, year::INTEGER HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'Duplicate country-year combination';
    END IF;
END;
$$;

-- Update the typed table only after validation passes.
INSERT INTO worldbank.indicators_typed AS target (
    country_name, country_code, region, income_group, year,
    gdp_usd, population, life_expectancy, unemployment_rate,
    co2_emissions_per_capita, access_to_electricity_pct,
    source_file, ingested_at
)
SELECT
    country_name,
    country_code,
    region,
    income_group,
    year::INTEGER,
    gdp_usd::NUMERIC,
    population::NUMERIC::BIGINT,
    life_expectancy::NUMERIC,
    unemployment_rate::NUMERIC,
    co2_emissions_per_capita::NUMERIC,
    access_to_electricity_pct::NUMERIC,
    source_file,
    ingested_at::TIMESTAMP AT TIME ZONE 'UTC'
FROM worldbank.indicators_staging

ON CONFLICT (country_code, year)
DO UPDATE SET
    country_name = EXCLUDED.country_name,
    region = EXCLUDED.region,
    income_group = EXCLUDED.income_group,
    gdp_usd = EXCLUDED.gdp_usd,
    population = EXCLUDED.population,
    life_expectancy = EXCLUDED.life_expectancy,
    unemployment_rate = EXCLUDED.unemployment_rate,
    co2_emissions_per_capita = EXCLUDED.co2_emissions_per_capita,
    access_to_electricity_pct = EXCLUDED.access_to_electricity_pct,
    source_file = EXCLUDED.source_file,
    ingested_at = EXCLUDED.ingested_at;

COMMIT;

SELECT
    (SELECT COUNT(*) FROM worldbank.indicators_staging) AS staging_rows,
    (SELECT COUNT(*) FROM worldbank.indicators_typed) AS typed_rows;
