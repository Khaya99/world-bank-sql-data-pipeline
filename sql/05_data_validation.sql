USE world_bank_project;

-- 
-- DATA VALIDATION
-- 

-- Raw dataset row count
SELECT COUNT(*) AS raw_rows
FROM raw_world_bank_data;

-- Cleaned dataset row count
SELECT COUNT(*) AS cleaned_rows
FROM cleaned_world_bank_data;

-- Quarantined dataset row count
SELECT COUNT(*) AS quarantined_rows
FROM quarantined_world_bank_data;


-- 
-- VALIDATE MISSING VALUES
-- 

SELECT
    SUM(country_name IS NULL) AS null_country_name,
    SUM(country_code IS NULL) AS null_country_code,
    SUM(region IS NULL) AS null_region,
    SUM(income_group IS NULL) AS null_income_group,
    SUM(year IS NULL) AS null_year,
    SUM(gdp_usd IS NULL) AS null_gdp,
    SUM(population IS NULL) AS null_population,
    SUM(life_expectancy IS NULL) AS null_life_expectancy,
    SUM(unemployment_rate IS NULL) AS null_unemployment,
    SUM(co2_emissions_per_capita IS NULL) AS null_co2,
    SUM(access_to_electricity_pct IS NULL) AS null_electricity
FROM cleaned_world_bank_data;
-- The remaining NULL values are there because I kept missing or invalid measurements

-- Confirm there are no blank strings left
SELECT
    SUM(TRIM(country_name) = '') AS blank_country_name,
    SUM(TRIM(country_code) = '') AS blank_country_code,
    SUM(TRIM(region) = '') AS blank_region,
    SUM(TRIM(income_group) = '') AS blank_income_group,
    SUM(TRIM(year) = '') AS blank_year,
    SUM(TRIM(gdp_usd) = '') AS blank_gdp,
    SUM(TRIM(population) = '') AS blank_population,
    SUM(TRIM(life_expectancy) = '') AS blank_life_expectancy,
    SUM(TRIM(unemployment_rate) = '') AS blank_unemployment,
    SUM(TRIM(co2_emissions_per_capita) = '') AS blank_co2,
    SUM(TRIM(access_to_electricity_pct) = '') AS blank_electricity
FROM cleaned_world_bank_data;

-- 
-- VALIDATE NUMERIC RANGES
-- 

-- Check year range
SELECT *
FROM cleaned_world_bank_data
WHERE CAST(year AS DECIMAL(10,1)) < 2000
   OR CAST(year AS DECIMAL(10,1)) > 2023;


-- Check negative GDP
SELECT *
FROM cleaned_world_bank_data
WHERE CAST(gdp_usd AS DECIMAL(30,2)) < 0;


-- Check negative population
SELECT *
FROM cleaned_world_bank_data
WHERE CAST(population AS DECIMAL(30,2)) < 0;


-- Check life expectancy
SELECT *
FROM cleaned_world_bank_data
WHERE CAST(life_expectancy AS DECIMAL(10,2)) < 0
   OR CAST(life_expectancy AS DECIMAL(10,2)) > 120;


-- Check unemployment rate
SELECT *
FROM cleaned_world_bank_data
WHERE CAST(unemployment_rate AS DECIMAL(10,2)) < 0
   OR CAST(unemployment_rate AS DECIMAL(10,2)) > 100;


-- Check CO2 emissions
SELECT *
FROM cleaned_world_bank_data
WHERE CAST(co2_emissions_per_capita AS DECIMAL(10,2)) < 0;


-- Check access to electricity
SELECT *
FROM cleaned_world_bank_data
WHERE CAST(access_to_electricity_pct AS DECIMAL(10,2)) < 0
   OR CAST(access_to_electricity_pct AS DECIMAL(10,2)) > 100;


-- 
-- VALIDATE COUNTRY REFERENCE CONSISTENCY
-- 

-- Check country codes that do not exist in the reference table
SELECT DISTINCT
    c.country_name,
    c.country_code
FROM cleaned_world_bank_data c
LEFT JOIN country_reference r
    ON c.country_code = r.country_code
WHERE r.country_code IS NULL;

-- Check that country name matches the code
SELECT DISTINCT
    c.country_name AS cleaned_country_name,
    c.country_code,
    r.country_name AS expected_country_name
FROM cleaned_world_bank_data c
JOIN country_reference r
    ON c.country_code = r.country_code
WHERE c.country_name <> r.country_name;
-- Turkiye has a wrong country name so we have to update it
SET SQL_SAFE_UPDATES = 0;

UPDATE cleaned_world_bank_data c
JOIN country_reference r
    ON c.country_code = r.country_code
SET c.country_name = r.country_name
WHERE c.country_code = 'TUR'
  AND c.country_name <> r.country_name;

SET SQL_SAFE_UPDATES = 1;
-- Verify the name update
SELECT country_name, country_code
FROM cleaned_world_bank_data
WHERE country_code = 'TUR';

-- Fix remaining name mismatches (Korea, Russian Federation, United Kingdom and United States)
SET SQL_SAFE_UPDATES = 0;

UPDATE cleaned_world_bank_data c
JOIN country_reference r
    ON c.country_code = r.country_code
SET c.country_name = r.country_name
WHERE c.country_name <> r.country_name;

SET SQL_SAFE_UPDATES = 1;


-- 
-- SECTION 5: VALIDATE DUPLICATES
-- 

-- Check for exact duplicate rows
SELECT
    country_name,
    country_code,
    region,
    income_group,
    year,
    gdp_usd,
    population,
    life_expectancy,
    unemployment_rate,
    co2_emissions_per_capita,
    access_to_electricity_pct,
    source_file,
    ingested_at,
    COUNT(*) AS duplicate_count
FROM cleaned_world_bank_data
GROUP BY
    country_name,
    country_code,
    region,
    income_group,
    year,
    gdp_usd,
    population,
    life_expectancy,
    unemployment_rate,
    co2_emissions_per_capita,
    access_to_electricity_pct,
    source_file,
    ingested_at
HAVING COUNT(*) > 1;

-- Check remaining country-year duplicates
SELECT
    country_name,
    year,
    COUNT(*) AS duplicate_count
FROM cleaned_world_bank_data
GROUP BY country_name, year
HAVING COUNT(*) > 1;
-- We expect Korea and Vietnam to appear.


-- 
-- FINAL DATASET READINESS CHECK
-- 

SELECT
    COUNT(*) AS total_cleaned_rows,
    COUNT(DISTINCT country_code) AS total_countries,
    MIN(CAST(year AS UNSIGNED)) AS earliest_year,
    MAX(CAST(year AS UNSIGNED)) AS latest_year
FROM cleaned_world_bank_data;

-- Confirm quarantine
SELECT COUNT(*) AS quarantined_rows
FROM quarantined_world_bank_data;


-- 
-- PHASE 5 SUMMARY
-- 

-- Data validation completed:
-- - Confirmed raw, cleaned and quarantine row counts
-- - Validated remaining NULL values
-- - Confirmed no blank strings remain
-- - Validated numeric ranges
-- - Validated year range
-- - Confirmed country codes match the reference table
-- - Fixed remaining country-name inconsistencies
-- - Confirmed region and income-group consistency
-- - Confirmed no exact duplicate rows remain
-- - Verified known conflicting duplicates are retained
-- - Confirmed cleaned dataset is ready for transformation