USE world_bank_project;

-- 
-- DATA TRANSFORMATION
-- 

-- Check current column data types
DESCRIBE cleaned_world_bank_data;


-- 
-- SECTION 2: CREATE TABLE FOR ANALYSIS
-- 

DROP TABLE IF EXISTS analysis_world_bank_data;

CREATE TABLE analysis_world_bank_data (
    country_name VARCHAR(255),
    country_code VARCHAR(10),
    region VARCHAR(255),
    income_group VARCHAR(255),

    year INT,

    gdp_usd DECIMAL(20,2),
    population BIGINT,
    life_expectancy DECIMAL(5,2),
    unemployment_rate DECIMAL(5,2),
    co2_emissions_per_capita DECIMAL(10,3),
    access_to_electricity_pct DECIMAL(5,2),

    source_file VARCHAR(255),
    ingested_at VARCHAR(255)
);


-- Test that cleaned numeric values can be converted successfully
SELECT
    CAST(year AS DECIMAL(4,0)) AS test_year,
    CAST(gdp_usd AS DECIMAL(20,2)) AS test_gdp,
    CAST(population AS DECIMAL(20,0)) AS test_population,
    CAST(life_expectancy AS DECIMAL(5,2)) AS test_life_expectancy,
    CAST(unemployment_rate AS DECIMAL(5,2)) AS test_unemployment,
    CAST(co2_emissions_per_capita AS DECIMAL(10,3)) AS test_co2,
    CAST(access_to_electricity_pct AS DECIMAL(5,2)) AS test_electricity
FROM cleaned_world_bank_data;

-- Check that conversion produced no warnings
SHOW WARNINGS;


-- Copy cleaned data into the analysis-ready table
INSERT INTO analysis_world_bank_data (
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
)
SELECT
    country_name,
    country_code,
    region,
    income_group,
    CAST(year AS DECIMAL(4,0)),
    CAST(gdp_usd AS DECIMAL(20,2)),
    CAST(population AS DECIMAL(20,0)),
    CAST(life_expectancy AS DECIMAL(5,2)),
    CAST(unemployment_rate AS DECIMAL(5,2)),
    CAST(co2_emissions_per_capita AS DECIMAL(10,3)),
    CAST(access_to_electricity_pct AS DECIMAL(5,2)),
    source_file,
    ingested_at
FROM cleaned_world_bank_data;


-- Verify row count
SELECT COUNT(*) AS analysis_rows
FROM analysis_world_bank_data;


-- Preview transformed data
SELECT *
FROM analysis_world_bank_data
LIMIT 10;


-- Verify new data types
DESCRIBE analysis_world_bank_data;

-- 
-- CREATE GDP PER CAPITA
-- 

-- Add GDP per capita column
ALTER TABLE analysis_world_bank_data
ADD COLUMN gdp_per_capita DECIMAL(20,2)
AFTER population;

-- Calculate the new values
SET SQL_SAFE_UPDATES = 0;

UPDATE analysis_world_bank_data
SET gdp_per_capita =
    ROUND(gdp_usd / NULLIF(population, 0), 2);

SET SQL_SAFE_UPDATES = 1;

-- Inspect the result
SELECT
    country_name,
    year,
    gdp_usd,
    population,
    gdp_per_capita
FROM analysis_world_bank_data
ORDER BY country_name, year
LIMIT 20;

-- Check for missing or NULL gdp per capita values
SELECT
    country_name,
    year,
    gdp_usd,
    population,
    gdp_per_capita
FROM analysis_world_bank_data
WHERE gdp_per_capita IS NULL;
-- Nigeria and Turkiye. One is missing GDP and population value for the other.

DESCRIBE analysis_world_bank_data;

-- 
-- TRANSFORMATION VALIDATION
-- 

SELECT COUNT(*) AS total_rows
FROM analysis_world_bank_data;

SELECT
    MIN(year) AS earliest_year,
    MAX(year) AS latest_year
FROM analysis_world_bank_data;

SELECT *
FROM analysis_world_bank_data
WHERE population <= 0;

SELECT *
FROM analysis_world_bank_data
WHERE gdp_per_capita < 0;

SELECT
    country_name,
    year,
    gdp_usd,
    population,
    gdp_per_capita
FROM analysis_world_bank_data
WHERE gdp_per_capita IS NULL;

-- 
-- PHASE 6 SUMMARY
-- 

-- Data transformation completed:
-- - Created analysis-ready table
-- - Converted text fields into proper numeric data types
-- - Verified numeric conversions
-- - Created GDP per capita
-- - Confirmed 720 analysis-ready rows
-- - Validated year range and transformed values
-- - Dataset is ready for SQL analysis