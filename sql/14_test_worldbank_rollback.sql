-- Run with psql. Run while no other pipeline session is changing these tables.
-- This test intentionally raises an error and NEVER commits the test batch.
\set ON_ERROR_STOP on
SET lock_timeout = '10s';
CREATE TEMP TABLE before_staging AS TABLE worldbank.indicators_staging;
CREATE TEMP TABLE before_typed AS TABLE worldbank.indicators_typed;

BEGIN;

-- Fail instead of waiting indefinitely for a conflicting transaction.
SET LOCAL lock_timeout = '10s';

TRUNCATE TABLE worldbank.indicators_staging;

\copy worldbank.indicators_staging (country_name, country_code, region, income_group, year, gdp_usd, population, life_expectancy, unemployment_rate, co2_emissions_per_capita, access_to_electricity_pct, source_file, ingested_at) FROM 'C:/Users/mpume/Downloads/world-bank-sql-data-pipeline/data/official/2026-10-15/world_bank_indicators.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8')


-- Deliberately make one percentage invalid without changing the CSV file.
UPDATE worldbank.indicators_staging
SET unemployment_rate = '101'
WHERE country_code = 'ZAF' AND year = '2023';

-- Continue past the expected validation error only so we can roll back.
\set ON_ERROR_STOP off
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


\set validation_failed :ERROR
\set validation_sqlstate :SQLSTATE
ROLLBACK;
\set ON_ERROR_STOP on

\if :validation_failed
\else
    \echo FAIL: invalid batch was not rejected. Test changes were rolled back.
    \quit 1
\endif

SELECT :'validation_sqlstate' = 'P0001' AS expected_error \gset
\if :expected_error
\else
    \echo FAIL: unexpected SQL error; inspect the message above.
    \quit 1
\endif

-- Compare all values, including duplicates, rather than counts alone.
SELECT
    NOT EXISTS (
        (TABLE before_staging EXCEPT ALL TABLE worldbank.indicators_staging)
        UNION ALL
        (TABLE worldbank.indicators_staging EXCEPT ALL TABLE before_staging)
    ) AS staging_unchanged,
    NOT EXISTS (
        (TABLE before_typed EXCEPT ALL TABLE worldbank.indicators_typed)
        UNION ALL
        (TABLE worldbank.indicators_typed EXCEPT ALL TABLE before_typed)
    ) AS typed_unchanged
\gset

\if :staging_unchanged
\else
    \echo FAIL: staging differs from its pre-test snapshot.
    \quit 1
\endif
\if :typed_unchanged
\else
    \echo FAIL: typed data differs from its pre-test snapshot.
    \quit 1
\endif

\echo PASS: invalid batch rejected; staging and typed data unchanged.
