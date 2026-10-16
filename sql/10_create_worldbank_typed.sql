CREATE TABLE worldbank.indicators_typed (
    country_name TEXT,
    country_code TEXT NOT NULL,
    region TEXT,
    income_group TEXT,
    year INTEGER NOT NULL,
    gdp_usd NUMERIC,
    population BIGINT,
    life_expectancy NUMERIC,
    unemployment_rate NUMERIC,
    co2_emissions_per_capita NUMERIC,
    access_to_electricity_pct NUMERIC,
    source_file TEXT,
    ingested_at TIMESTAMPTZ,

    PRIMARY KEY (country_code, year)
);

-- Load official data from staging into the typed table.
-- Convert years and indicators to numeric types and interpret ingestion times as UTC.
-- Preserve staging data and commit the insert as one transaction.
BEGIN;

INSERT INTO worldbank.indicators_typed (
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
FROM worldbank.indicators_staging;

COMMIT;

SELECT COUNT(*) AS typed_rows
FROM worldbank.indicators_typed;

-- Preview GDP per capita using the typed data.
SELECT
    country_name,
    year,
    ROUND(gdp_usd / NULLIF(population, 0), 2) AS gdp_per_capita_usd
FROM worldbank.indicators_typed
WHERE year = 2023
ORDER BY gdp_per_capita_usd DESC NULLS LAST;