-- Run with psql, not the pgAdmin Query Tool.
-- One transaction: refresh staging, validate, upsert, then commit.
-- Uses the saved snapshot; this script does not fetch fresh API data.
-- All six indicators must be present for this snapshot. Review these
-- rules before using other periods or datasets where missingness is valid.
\set ON_ERROR_STOP on
\set AUTOCOMMIT on
\set ON_ERROR_ROLLBACK off
\set refresh_failed false

-- Save the run's start separately from the data refresh.
INSERT INTO worldbank.pipeline_runs (pipeline_name)
VALUES ('worldbank_refresh_and_upsert')
RETURNING run_id AS logged_run_id
\gset

-- Continue only far enough to record an error, then exit.
\set ON_ERROR_STOP off
BEGIN;
\ir maintenance/log_refresh_failure.sql
\if :refresh_failed
    -- Stop in the calling script, not just the included helper.
    \set ON_ERROR_STOP on
    DO $$ BEGIN RAISE EXCEPTION 'Refresh failed; inspect worldbank.pipeline_runs and terminal errors'; END $$;
\endif

-- Fail instead of waiting indefinitely for a conflicting transaction.
SET LOCAL lock_timeout = '10s';
\ir maintenance/log_refresh_failure.sql
\if :refresh_failed
    -- Stop in the calling script, not just the included helper.
    \set ON_ERROR_STOP on
    DO $$ BEGIN RAISE EXCEPTION 'Refresh failed; inspect worldbank.pipeline_runs and terminal errors'; END $$;
\endif

TRUNCATE TABLE worldbank.indicators_staging;
\ir maintenance/log_refresh_failure.sql
\if :refresh_failed
    -- Stop in the calling script, not just the included helper.
    \set ON_ERROR_STOP on
    DO $$ BEGIN RAISE EXCEPTION 'Refresh failed; inspect worldbank.pipeline_runs and terminal errors'; END $$;
\endif

\copy worldbank.indicators_staging (country_name, country_code, region, income_group, year, gdp_usd, population, life_expectancy, unemployment_rate, co2_emissions_per_capita, access_to_electricity_pct, source_file, ingested_at) FROM 'C:/Users/mpume/Downloads/world-bank-sql-data-pipeline/data/official/2026-10-15/world_bank_indicators.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8')
\ir maintenance/log_refresh_failure.sql
\if :refresh_failed
    -- Stop in the calling script, not just the included helper.
    \set ON_ERROR_STOP on
    DO $$ BEGIN RAISE EXCEPTION 'Refresh failed; inspect worldbank.pipeline_runs and terminal errors'; END $$;
\endif

-- Local file errors may not set psql ERROR. Validation below also
-- rejects the empty staging table if the file could not be opened.

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

\ir maintenance/log_refresh_failure.sql
\if :refresh_failed
    -- Stop in the calling script, not just the included helper.
    \set ON_ERROR_STOP on
    DO $$ BEGIN RAISE EXCEPTION 'Refresh failed; inspect worldbank.pipeline_runs and terminal errors'; END $$;
\endif

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
\ir maintenance/log_refresh_failure.sql
\if :refresh_failed
    -- Stop in the calling script, not just the included helper.
    \set ON_ERROR_STOP on
    DO $$ BEGIN RAISE EXCEPTION 'Refresh failed; inspect worldbank.pipeline_runs and terminal errors'; END $$;
\endif

-- Save success together with the refreshed data.
UPDATE worldbank.pipeline_runs
SET status = 'succeeded',
    finished_at = clock_timestamp(),
    staging_rows = (
        SELECT COUNT(*) FROM worldbank.indicators_staging
    ),
    typed_rows = (
        SELECT COUNT(*) FROM worldbank.indicators_typed
    )
WHERE run_id = :logged_run_id
  AND status = 'running';
\ir maintenance/log_refresh_failure.sql
\if :refresh_failed
    -- Stop in the calling script, not just the included helper.
    \set ON_ERROR_STOP on
    DO $$ BEGIN RAISE EXCEPTION 'Refresh failed; inspect worldbank.pipeline_runs and terminal errors'; END $$;
\endif

COMMIT;
\ir maintenance/log_refresh_failure.sql
\if :refresh_failed
    -- Stop in the calling script, not just the included helper.
    \set ON_ERROR_STOP on
    DO $$ BEGIN RAISE EXCEPTION 'Refresh failed; inspect worldbank.pipeline_runs and terminal errors'; END $$;
\endif

\set ON_ERROR_STOP on

-- Report the outcome of this execution.
SELECT run_id, status, staging_rows, typed_rows,
       finished_at - started_at AS duration
FROM worldbank.pipeline_runs
WHERE run_id = :logged_run_id;
