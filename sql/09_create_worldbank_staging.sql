-- Confirm which database this tab is connected to.
SELECT current_database();

-- Create a separate area for official World Bank data.
CREATE SCHEMA IF NOT EXISTS worldbank;

-- Verify that the schema exists.
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name = 'worldbank';

-- Receive official API data before validation.
CREATE TABLE IF NOT EXISTS worldbank.indicators_staging (
    country_name TEXT,
    country_code TEXT,
    region TEXT,
    income_group TEXT,
    year TEXT,
    gdp_usd TEXT,
    population TEXT,
    life_expectancy TEXT,
    unemployment_rate TEXT,
    co2_emissions_per_capita TEXT,
    access_to_electricity_pct TEXT,
    source_file TEXT,
    ingested_at TEXT
);

-- Check the table's columns and their order.
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'worldbank'
  AND table_name = 'indicators_staging'
ORDER BY ordinal_position;

SELECT COUNT(*) AS imported_rows
FROM worldbank.indicators_staging;

-- Check country coverage and the imported year range.
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT country_code) AS countries,
    MIN(year::INTEGER) AS first_year,
    MAX(year::INTEGER) AS last_year
FROM worldbank.indicators_staging;

-- Find repeated country-year combinations.
SELECT country_code, year, COUNT(*) AS occurrences
FROM worldbank.indicators_staging
GROUP BY country_code, year
HAVING COUNT(*) > 1;

-- Confirm the recorded source.
SELECT source_file, COUNT(*) AS rows_from_source
FROM worldbank.indicators_staging
GROUP BY source_file;

-- Count missing values in each indicator
-- COUNT(*) counts all rows. The second COUNT() counts values after blank text and spaces have been treated as missing.
SELECT
    COUNT(*) - COUNT(NULLIF(TRIM(gdp_usd), '')) AS missing_gdp,
    COUNT(*) - COUNT(NULLIF(TRIM(population), '')) AS missing_population,
    COUNT(*) - COUNT(NULLIF(TRIM(life_expectancy), '')) AS missing_life_expectancy,
    COUNT(*) - COUNT(NULLIF(TRIM(unemployment_rate), '')) AS missing_unemployment,
    COUNT(*) - COUNT(NULLIF(TRIM(co2_emissions_per_capita), '')) AS missing_co2,
    COUNT(*) - COUNT(NULLIF(TRIM(access_to_electricity_pct), '')) AS missing_electricity
FROM worldbank.indicators_staging;

-- Check that the indicators text values can be converted to numbers
SELECT country_code, year, indicator, value
FROM worldbank.indicators_staging
CROSS JOIN LATERAL (
    VALUES
        ('GDP', gdp_usd),
        ('Population', population),
        ('Life expectancy', life_expectancy),
        ('Unemployment', unemployment_rate),
        ('CO2', co2_emissions_per_capita),
        ('Electricity access', access_to_electricity_pct)
) AS checks(indicator, value)
WHERE NOT pg_input_is_valid(TRIM(value), 'numeric');

-- Check for values outside the expected range
SELECT country_code, year,
       gdp_usd, population, life_expectancy,
       unemployment_rate, co2_emissions_per_capita,
       access_to_electricity_pct
FROM worldbank.indicators_staging
WHERE gdp_usd::NUMERIC < 0
   OR population::NUMERIC <= 0
   OR life_expectancy::NUMERIC <= 0
   OR unemployment_rate::NUMERIC NOT BETWEEN 0 AND 100
   OR co2_emissions_per_capita::NUMERIC < 0
   OR access_to_electricity_pct::NUMERIC NOT BETWEEN 0 AND 100;