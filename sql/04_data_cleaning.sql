USE world_bank_project;

-- Create a copy of the raw data
CREATE TABLE cleaned_world_bank_data AS
SELECT *
FROM raw_world_bank_data;

SELECT COUNT(*) AS total_rows
FROM cleaned_world_bank_data;

-- Remove extra spaces in the data
UPDATE cleaned_world_bank_data
SET
    country_name = TRIM(country_name),
    country_code = TRIM(country_code),
    region = TRIM(region),
    income_group = TRIM(income_group);
    
-- Fix the wrong data compared to the reference data
UPDATE cleaned_world_bank_data c
JOIN country_reference r
    ON c.country_code = r.country_code
SET
    c.country_name = r.country_name,
    c.region = r.region,
    c.income_group = r.income_group;

-- Fix the incorrect country codes with the reference data
SELECT
    c.country_name,
    c.country_code AS incorrect_code,
    r.country_code AS correct_code
FROM cleaned_world_bank_data c
JOIN country_reference r
    ON c.country_name = r.country_name
WHERE c.country_code <> r.country_code;

-- Fixing the incorrect country codes
UPDATE cleaned_world_bank_data c
JOIN country_reference r
    ON c.country_name = r.country_name
SET c.country_code = r.country_code
WHERE c.country_code <> r.country_code;

-- Checking that the updates worked from dirty to clean
SELECT DISTINCT
    c.country_name,
    c.country_code
FROM cleaned_world_bank_data c
LEFT JOIN country_reference r
    ON c.country_code = r.country_code
WHERE r.country_code IS NULL;

-- Verify the countries that appeared from the reference data
SELECT *
FROM country_reference
WHERE country_name IN (
    'Iran',
    'European Union',
    'Australia',
    'South Africa',
    'World'
);

-- Fix the country code for South Africa and Australia
UPDATE cleaned_world_bank_data c
JOIN country_reference r
    ON c.country_name = r.country_name
SET c.country_code = r.country_code
WHERE c.country_code <> r.country_code; 

-- Checking for the duplicate values in the cleaned table
SELECT
    country_name,
    year,
    COUNT(*) AS duplicate_count
FROM cleaned_world_bank_data
GROUP BY country_name, year
HAVING COUNT(*) > 1;

-- Determine if the data is exact duplicate or conflicting duplicate
SELECT *
FROM cleaned_world_bank_data
WHERE (country_name = 'Australia' AND year = '2000')
   OR (country_name = 'Korea, Rep.' AND year = '2000')
   OR (country_name = 'Vietnam' AND year = '2013')
   OR (country_name = 'India' AND year = '2011')
ORDER BY country_name, year;

-- Duplicate cleaning notes:
-- Australia 2000: exact duplicate
-- India 2011: exact duplicate
-- Korea, Rep. 2000: conflicting duplicate (life_expectancy)
-- Vietnam 2013: conflicting duplicate (life_expectancy)
--
-- Exact duplicates can be safely deduplicated.
-- Conflicting duplicates require further investigation before correction.


-- Inspect rows containing missing values

SELECT *
FROM cleaned_world_bank_data
WHERE country_name IS NULL OR TRIM(country_name) = ''
   OR country_code IS NULL OR TRIM(country_code) = ''
   OR region IS NULL OR TRIM(region) = ''
   OR income_group IS NULL OR TRIM(income_group) = ''
   OR year IS NULL OR TRIM(year) = ''
   OR gdp_usd IS NULL OR TRIM(gdp_usd) = ''
   OR population IS NULL OR TRIM(population) = ''
   OR life_expectancy IS NULL OR TRIM(life_expectancy) = ''
   OR unemployment_rate IS NULL OR TRIM(unemployment_rate) = ''
   OR co2_emissions_per_capita IS NULL OR TRIM(co2_emissions_per_capita) = ''
   OR access_to_electricity_pct IS NULL OR TRIM(access_to_electricity_pct) = '';
   
-- Missing value findings:
-- Kenya: multiple fields are missing.
-- China: unemployment_rate is missing.
-- Nigeria: gdp_usd is missing.
-- Türkiye: population is missing.
--
-- Missing values will not automatically be replaced with 0 or estimated.
-- Records will be retained or quarantined based on whether they can be reliably used in final analysis

-- Kenya missing values

SELECT *
FROM cleaned_world_bank_data
WHERE country_name = 'Kenya'
  AND (
       country_code IS NULL OR TRIM(country_code) = ''
       OR region IS NULL OR TRIM(region) = ''
       OR income_group IS NULL OR TRIM(income_group) = ''
       OR year IS NULL OR TRIM(year) = ''
       OR gdp_usd IS NULL OR TRIM(gdp_usd) = ''
       OR population IS NULL OR TRIM(population) = ''
       OR life_expectancy IS NULL OR TRIM(life_expectancy) = ''
       OR unemployment_rate IS NULL OR TRIM(unemployment_rate) = ''
       OR co2_emissions_per_capita IS NULL OR TRIM(co2_emissions_per_capita) = ''
       OR access_to_electricity_pct IS NULL OR TRIM(access_to_electricity_pct) = ''
  );

-- Kenya record contains extensive missing data:
-- region, income_group, GDP, population, life expectancy,
-- unemployment rate, CO2 emissions and electricity access.
-- The record cannot provide meaningful analysis.
-- Marked for quarantine rather than estimating missing values.


--
-- INVALID VALUES
--

-- Check negative GDP
SELECT *
FROM cleaned_world_bank_data
WHERE CAST(gdp_usd AS DECIMAL(30,2)) < 0;

-- Check negative population
SELECT *
FROM cleaned_world_bank_data
WHERE CAST(population AS DECIMAL(30,2)) < 0;

-- Check unrealistic life expectancy
SELECT *
FROM cleaned_world_bank_data
WHERE CAST(life_expectancy AS DECIMAL(10,2)) < 0
   OR CAST(life_expectancy AS DECIMAL(10,2)) > 120;

-- Check invalid unemployment rates
SELECT *
FROM cleaned_world_bank_data
WHERE CAST(unemployment_rate AS DECIMAL(10,2)) < 0
   OR CAST(unemployment_rate AS DECIMAL(10,2)) > 100;

-- Check negative CO2 emissions
SELECT *
FROM cleaned_world_bank_data
WHERE CAST(co2_emissions_per_capita AS DECIMAL(10,2)) < 0;

-- Check invalid electricity access
SELECT *
FROM cleaned_world_bank_data
WHERE CAST(access_to_electricity_pct AS DECIMAL(10,2)) < 0
   OR CAST(access_to_electricity_pct AS DECIMAL(10,2)) > 100;
   

-- Replace confirmed impossible values with NULL

UPDATE cleaned_world_bank_data
SET life_expectancy = NULL
WHERE CAST(life_expectancy AS DECIMAL(10,2)) > 120
   OR CAST(life_expectancy AS DECIMAL(10,2)) < 0;

UPDATE cleaned_world_bank_data
SET unemployment_rate = NULL
WHERE CAST(unemployment_rate AS DECIMAL(10,2)) > 100
   OR CAST(unemployment_rate AS DECIMAL(10,2)) < 0;

UPDATE cleaned_world_bank_data
SET co2_emissions_per_capita = NULL
WHERE CAST(co2_emissions_per_capita AS DECIMAL(10,2)) < 0;

UPDATE cleaned_world_bank_data
SET access_to_electricity_pct = NULL
WHERE CAST(access_to_electricity_pct AS DECIMAL(10,2)) > 100
   OR CAST(access_to_electricity_pct AS DECIMAL(10,2)) < 0;
   
SELECT *
FROM cleaned_world_bank_data
WHERE CAST(access_to_electricity_pct AS DECIMAL(10,2)) < 0
   OR CAST(access_to_electricity_pct AS DECIMAL(10,2)) > 100;

-- The value was not updated to NULL for United Kingdom with unemployment rate
SET SQL_SAFE_UPDATES = 0;

UPDATE cleaned_world_bank_data
SET unemployment_rate = NULL
WHERE country_name = 'United Kingdom'
  AND year = '2005'
  AND unemployment_rate = '652.0';

SELECT country_name, year, unemployment_rate
FROM cleaned_world_bank_data
WHERE country_name = 'United Kingdom'
  AND year = '2005';

SET SQL_SAFE_UPDATES = 1;

-- More values were not set to NULL after update so we fixed it
-- We use country codes now so it matches the reference data

SET SQL_SAFE_UPDATES = 0;

-- Egypt: invalid life expectancy
UPDATE cleaned_world_bank_data
SET life_expectancy = NULL
WHERE country_code = 'EGY'
  AND year = '2010'
  AND life_expectancy = '187.4';

-- South Africa: invalid CO2 emissions
UPDATE cleaned_world_bank_data
SET co2_emissions_per_capita = NULL
WHERE country_code = 'ZAF'
  AND year = '2023'
  AND co2_emissions_per_capita = '-6.5';

-- Egypt: invalid electricity access
UPDATE cleaned_world_bank_data
SET access_to_electricity_pct = NULL
WHERE country_code = 'EGY'
  AND year = '2011'
  AND access_to_electricity_pct = '101.02';

SET SQL_SAFE_UPDATES = 1;

-- Verify for the NULL value UPDATE

WITH missing_values AS (

    SELECT country_name, year, 'region' AS column_name
    FROM cleaned_world_bank_data
    WHERE region IS NULL OR TRIM(region) = ''

    UNION ALL

    SELECT country_name, year, 'income_group'
    FROM cleaned_world_bank_data
    WHERE income_group IS NULL OR TRIM(income_group) = ''

    UNION ALL

    SELECT country_name, year, 'gdp_usd'
    FROM cleaned_world_bank_data
    WHERE gdp_usd IS NULL OR TRIM(gdp_usd) = ''

    UNION ALL

    SELECT country_name, year, 'population'
    FROM cleaned_world_bank_data
    WHERE population IS NULL OR TRIM(population) = ''

    UNION ALL

    SELECT country_name, year, 'life_expectancy'
    FROM cleaned_world_bank_data
    WHERE life_expectancy IS NULL OR TRIM(life_expectancy) = ''

    UNION ALL

    SELECT country_name, year, 'unemployment_rate'
    FROM cleaned_world_bank_data
    WHERE unemployment_rate IS NULL OR TRIM(unemployment_rate) = ''

    UNION ALL

    SELECT country_name, year, 'co2_emissions_per_capita'
    FROM cleaned_world_bank_data
    WHERE co2_emissions_per_capita IS NULL
       OR TRIM(co2_emissions_per_capita) = ''

    UNION ALL

    SELECT country_name, year, 'access_to_electricity_pct'
    FROM cleaned_world_bank_data
    WHERE access_to_electricity_pct IS NULL
       OR TRIM(access_to_electricity_pct) = ''
)

SELECT *
FROM missing_values
ORDER BY country_name, year, column_name;